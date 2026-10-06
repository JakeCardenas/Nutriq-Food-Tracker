-- Two-user Row Level Security test for the Nutriq schema.
--
-- Run after the migrations, as a superuser (e.g. `postgres`), against either:
--   • a local Supabase database:  psql "$(supabase status -o env | grep DB_URL ...)" -f supabase/tests/rls_isolation_test.sql
--   • a plain Postgres with supabase/tests/local_auth_stub.sql applied first
--     (supabase/tests/run_rls_tests_locally.sh does this for you).
--
-- Every check prints "ok - ..." or aborts with "FAIL: ...".

\set ON_ERROR_STOP on
\set user_a '''11111111-1111-1111-1111-111111111111'''
\set user_b '''22222222-2222-2222-2222-222222222222'''

create schema if not exists nutriq_test;
create or replace function nutriq_test.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then
    raise exception 'FAIL: %', msg;
  end if;
  raise notice 'ok - %', msg;
end;
$$;
grant usage on schema nutriq_test to authenticated, anon;
grant execute on function nutriq_test.ok(boolean, text) to authenticated, anon;

create or replace function nutriq_test.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false);
$$;
grant execute on function nutriq_test.act_as(uuid) to authenticated, anon;

insert into auth.users (id, email) values
  (:user_a, 'rls-a@example.test'),
  (:user_b, 'rls-b@example.test')
on conflict (id) do nothing;

-- ── User A creates data ─────────────────────────────────────────────────────
set role authenticated;
select nutriq_test.act_as(:user_a);

select nutriq_test.ok(
  (public.nutriq_push_profile('{"has_profile": true, "age": 30, "goal": "maintain", "calorie_goal_min": 2000, "calorie_goal_max": 2200, "client_updated_at": 1}')
    ->> 'status') = 'ok',
  'A can save a profile');
select nutriq_test.ok(
  (public.nutriq_push_meal(
    '{"id": "meal-a", "logged_at": "2026-10-06T12:00:00Z", "meal_type": "lunch", "source": "manual", "name": "A lunch", "client_updated_at": 10}',
    '[{"id": "i1", "name": "Rice", "servings": 1, "serving_label": "1 cup", "calories_per_serving": 200, "protein_per_serving": 4}]')
    ->> 'status') = 'ok',
  'A can save a meal with items');
select nutriq_test.ok(
  (public.nutriq_push_saved_food('{"id": "food-a", "name": "Oats", "serving_label": "1 cup", "calories_per_serving": 150, "saved_at": "2026-10-06T08:00:00Z", "client_updated_at": 1}')
    ->> 'status') = 'ok',
  'A can save a food');
select nutriq_test.ok((select count(*) from public.meals) = 1, 'A sees their meal');
select nutriq_test.ok((select count(*) from public.meal_items) = 1, 'A sees their meal item');
select nutriq_test.ok(
  (public.nutriq_push_meal(
    '{"id": "meal-a", "logged_at": "2026-10-06T12:00:00Z", "meal_type": "lunch", "source": "manual", "name": "older edit", "client_updated_at": 5}',
    '[]') ->> 'status') = 'stale',
  'an older edit is refused as stale');
select nutriq_test.ok((select name from public.meals where id = 'meal-a') = 'A lunch', 'stale edit did not overwrite');

-- ── User B cannot see or change A's data ────────────────────────────────────
select nutriq_test.act_as(:user_b);

select nutriq_test.ok((select count(*) from public.profiles) = 0, 'B cannot read A''s profile');
select nutriq_test.ok((select count(*) from public.meals) = 0, 'B cannot read A''s meals');
select nutriq_test.ok((select count(*) from public.meal_items) = 0, 'B cannot read A''s meal items');
select nutriq_test.ok((select count(*) from public.saved_foods) = 0, 'B cannot read A''s saved foods');

with u as (update public.meals set name = 'changed by B' where id = 'meal-a' returning 1)
select nutriq_test.ok((select count(*) from u) = 0, 'B cannot update A''s meal');
with u as (update public.profiles set age = 99 returning 1)
select nutriq_test.ok((select count(*) from u) = 0, 'B cannot update A''s profile');
with d as (delete from public.meal_items where meal_id = 'meal-a' returning 1)
select nutriq_test.ok((select count(*) from d) = 0, 'B cannot delete A''s meal items');
with d as (delete from public.meals returning 1)
select nutriq_test.ok((select count(*) from d) = 0, 'B cannot delete A''s meals');

do $$
begin
  begin
    insert into public.meal_items (user_id, meal_id, id, name, servings, serving_label, calories_per_serving)
    values ('11111111-1111-1111-1111-111111111111', 'meal-a', 'evil', 'Injected', 1, '1', 1);
    raise exception 'FAIL: B inserted an item into A''s meal while claiming to be A';
  exception when insufficient_privilege then
    raise notice 'ok - B cannot insert items owned by A';
  end;
  begin
    insert into public.meal_items (user_id, meal_id, id, name, servings, serving_label, calories_per_serving)
    values ('22222222-2222-2222-2222-222222222222', 'meal-a', 'evil', 'Injected', 1, '1', 1);
    raise exception 'FAIL: B attached an item to A''s meal';
  exception when foreign_key_violation or insufficient_privilege then
    raise notice 'ok - B cannot attach an item to A''s meal';
  end;
  begin
    insert into public.meals (user_id, id, logged_at, meal_type, source, client_updated_at)
    values ('11111111-1111-1111-1111-111111111111', 'planted', now(), 'snack', 'manual', 1);
    raise exception 'FAIL: B created a meal owned by A';
  exception when insufficient_privilege then
    raise notice 'ok - B cannot create rows owned by A';
  end;
end;
$$;

-- Same id, different owner: B gets their own row; A's is untouched.
select nutriq_test.ok(
  (public.nutriq_push_meal(
    '{"id": "meal-a", "logged_at": "2026-10-06T19:00:00Z", "meal_type": "dinner", "source": "manual", "name": "B dinner", "client_updated_at": 99}',
    '[]') ->> 'status') = 'ok',
  'B can use the same meal id for their own meal');
select nutriq_test.ok((select count(*) from public.meals) = 1, 'B sees only their own meal');

do $$
begin
  perform public.nutriq_push_profile('{"has_profile": true, "age": 16, "calorie_goal_min": 1500, "calorie_goal_max": 1700, "client_updated_at": 1}');
  raise exception 'FAIL: a minor profile accepted a calorie goal';
exception when check_violation then
  raise notice 'ok - no calorie targets for minors (server check)';
end;
$$;

select public.nutriq_delete_my_data();
select nutriq_test.ok((select count(*) from public.meals) = 0, 'B deleted their own data');

-- ── A's data survived everything B tried ────────────────────────────────────
select nutriq_test.act_as(:user_a);
select nutriq_test.ok((select count(*) from public.meals) = 1, 'A still has exactly one meal');
select nutriq_test.ok((select name from public.meals where id = 'meal-a') = 'A lunch', 'A''s meal name unchanged');
select nutriq_test.ok((select count(*) from public.meal_items) = 1, 'A''s meal item is intact');
select nutriq_test.ok((select age from public.profiles) = 30, 'A''s profile unchanged');

-- ── Signed-out (anon) callers get nothing ───────────────────────────────────
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
do $$
begin
  begin
    perform count(*) from public.meals;
    raise exception 'FAIL: anon could query meals';
  exception when insufficient_privilege then
    raise notice 'ok - anon cannot read meals';
  end;
  begin
    perform public.nutriq_delete_my_data();
    raise exception 'FAIL: anon could call delete function';
  exception when insufficient_privilege then
    raise notice 'ok - anon cannot call sync functions';
  end;
end;
$$;

reset role;
-- Clean up the test users (cascades to their rows).
delete from auth.users where id in (:user_a, :user_b);
drop schema nutriq_test cascade;
\echo 'All RLS isolation checks passed.'
