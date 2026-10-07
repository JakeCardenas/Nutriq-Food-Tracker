-- Daily AI-coach allowance test (migration 20261007000000_coach_usage.sql).
--
-- Run after the migrations, as a superuser — supabase/tests/run_rls_tests_locally.sh does this for you.
-- Every check prints "ok - ..." or aborts with "FAIL: ...".

\set ON_ERROR_STOP on
\set user_a '''33333333-3333-3333-3333-333333333333'''
\set user_b '''44444444-4444-4444-4444-444444444444'''

create schema if not exists nutriq_coach_test;
create or replace function nutriq_coach_test.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then
    raise exception 'FAIL: %', msg;
  end if;
  raise notice 'ok - %', msg;
end;
$$;
create or replace function nutriq_coach_test.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false);
$$;
grant usage on schema nutriq_coach_test to authenticated, anon;
grant execute on all functions in schema nutriq_coach_test to authenticated, anon;

insert into auth.users (id, email) values
  (:user_a, 'coach-a@example.test'),
  (:user_b, 'coach-b@example.test')
on conflict (id) do nothing;

-- B already used their whole allowance yesterday; that must not count today.
insert into public.coach_usage (user_id, day, count)
values (:user_b, (now() at time zone 'utc')::date - 1, 30);

-- ── A uses the allowance ────────────────────────────────────────────────────
set role authenticated;
select nutriq_coach_test.act_as(:user_a);

select nutriq_coach_test.ok(public.nutriq_coach_take_turn() = 29, 'first message of the day leaves 29');
do $$
begin
  for i in 1..29 loop
    perform public.nutriq_coach_take_turn();
  end loop;
end;
$$;
select nutriq_coach_test.ok(public.nutriq_coach_take_turn() = -1, 'message 31 is refused');
select nutriq_coach_test.ok(public.nutriq_coach_take_turn() = -1, 'and stays refused');
select nutriq_coach_test.ok((select count from public.coach_usage) = 30, 'A can read their own count (stops at 30)');

do $$
begin
  begin
    update public.coach_usage set count = 0;
    raise exception 'FAIL: A could reset their count';
  exception when insufficient_privilege then
    raise notice 'ok - A cannot reset their count';
  end;
  begin
    delete from public.coach_usage;
    raise exception 'FAIL: A could delete their count';
  exception when insufficient_privilege then
    raise notice 'ok - A cannot delete their count';
  end;
  begin
    insert into public.coach_usage (user_id, day, count) values (auth.uid(), current_date + 1, 0);
    raise exception 'FAIL: A could insert a count';
  exception when insufficient_privilege then
    raise notice 'ok - A cannot insert counts';
  end;
end;
$$;

-- ── B is independent of A, and yesterday doesn't count ─────────────────────
select nutriq_coach_test.act_as(:user_b);
select nutriq_coach_test.ok(
  (select count(*) from public.coach_usage where user_id = :user_a) = 0,
  'B cannot see A''s usage');
select nutriq_coach_test.ok(public.nutriq_coach_take_turn() = 29, 'B has a fresh allowance today');

-- ── Signed-out callers can't use it ─────────────────────────────────────────
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
do $$
begin
  begin
    perform public.nutriq_coach_take_turn();
    raise exception 'FAIL: anon could take a coach turn';
  exception when insufficient_privilege then
    raise notice 'ok - anon cannot take a coach turn';
  end;
  begin
    perform count(*) from public.coach_usage;
    raise exception 'FAIL: anon could read coach usage';
  exception when insufficient_privilege then
    raise notice 'ok - anon cannot read coach usage';
  end;
end;
$$;

-- ── Deleting the account deletes its counts ─────────────────────────────────
reset role;
delete from auth.users where id in (:user_a, :user_b);
select nutriq_coach_test.ok(
  (select count(*) from public.coach_usage where user_id in (:user_a, :user_b)) = 0,
  'usage rows are deleted with the account');

drop schema nutriq_coach_test cascade;
\echo 'All coach usage checks passed.'
