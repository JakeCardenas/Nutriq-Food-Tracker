-- Photo-scan allowance and nutrition-cache test (migration 20261007120000_photo_scan.sql).
--
-- Run after the migrations, as a superuser — supabase/tests/run_rls_tests_locally.sh does this for you.
-- Every check prints "ok - ..." or aborts with "FAIL: ...".

\set ON_ERROR_STOP on
\set user_a '''55555555-5555-5555-5555-555555555555'''
\set user_b '''66666666-6666-6666-6666-666666666666'''

create schema if not exists nutriq_scan_test;
create or replace function nutriq_scan_test.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then
    raise exception 'FAIL: %', msg;
  end if;
  raise notice 'ok - %', msg;
end;
$$;
create or replace function nutriq_scan_test.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false);
$$;
grant usage on schema nutriq_scan_test to authenticated, anon, service_role;
grant execute on all functions in schema nutriq_scan_test to authenticated, anon, service_role;

insert into auth.users (id, email) values
  (:user_a, 'scan-a@example.test'),
  (:user_b, 'scan-b@example.test')
on conflict (id) do nothing;

-- ── A spends a 3-scan allowance ─────────────────────────────────────────────
set role authenticated;
select nutriq_scan_test.act_as(:user_a);
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(3) = 2, 'first scan of the day leaves 2 of 3');
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(3) = 1, 'second leaves 1');
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(3) = 0, 'third leaves 0');
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(3) = -1, 'fourth is refused');
select nutriq_scan_test.ok((select count from public.scan_usage) = 3, 'A can read their own count (stops at 3)');
select nutriq_scan_test.ok(
  (select count(*) from public.coach_usage) = 0, 'scans never spend the coach allowance');

do $$
begin
  begin
    update public.scan_usage set count = 0;
    raise exception 'FAIL: A could reset their scan count';
  exception when insufficient_privilege then
    raise notice 'ok - A cannot reset their scan count';
  end;
  begin
    delete from public.scan_usage;
    raise exception 'FAIL: A could delete their scan count';
  exception when insufficient_privilege then
    raise notice 'ok - A cannot delete their scan count';
  end;
  begin
    perform count(*) from public.fdc_food_cache;
    raise exception 'FAIL: A could read the nutrition cache';
  exception when insufficient_privilege then
    raise notice 'ok - signed-in users cannot read the nutrition cache';
  end;
  begin
    insert into public.fdc_query_cache (query, fdc_id) values ('rice', null);
    raise exception 'FAIL: A could write the nutrition cache';
  exception when insufficient_privilege then
    raise notice 'ok - signed-in users cannot write the nutrition cache';
  end;
end;
$$;

-- ── The limit is clamped, and B is independent ──────────────────────────────
select nutriq_scan_test.act_as(:user_b);
select nutriq_scan_test.ok(
  (select count(*) from public.scan_usage where user_id = :user_a) = 0, 'B cannot see A''s scans');
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(0) = 0, 'a limit below 1 counts as 1');
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(0) = -1, 'so the second scan is refused');
select nutriq_scan_test.ok(public.nutriq_scan_take_turn(100000) = 198, 'a huge limit is capped at 200');

-- ── Signed-out callers can't scan ───────────────────────────────────────────
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
do $$
begin
  begin
    perform public.nutriq_scan_take_turn(10);
    raise exception 'FAIL: anon could take a scan turn';
  exception when insufficient_privilege then
    raise notice 'ok - anon cannot take a scan turn';
  end;
  begin
    perform count(*) from public.fdc_query_cache;
    raise exception 'FAIL: anon could read the nutrition cache';
  exception when insufficient_privilege then
    raise notice 'ok - anon cannot read the nutrition cache';
  end;
end;
$$;

-- ── The server (service role) can use the cache ─────────────────────────────
reset role;
set role service_role;
insert into public.fdc_food_cache (fdc_id, description, data_type, kcal_100g, protein_100g, carbs_100g, fat_100g)
values (168878, 'Rice, white, cooked', 'SR Legacy', 130, 2.69, 28.2, 0.28);
insert into public.fdc_query_cache (query, fdc_id) values ('white rice, cooked', 168878), ('zorblax', null);
select nutriq_scan_test.ok(
  (select f.kcal_100g from public.fdc_query_cache q join public.fdc_food_cache f using (fdc_id)
   where q.query = 'white rice, cooked') = 130, 'the server can cache a lookup by food id');
select nutriq_scan_test.ok(
  (select fdc_id is null from public.fdc_query_cache where query = 'zorblax'), 'and remember a query with no match');

-- ── Deleting the account deletes its scan counts ────────────────────────────
reset role;
delete from auth.users where id in (:user_a, :user_b);
select nutriq_scan_test.ok(
  (select count(*) from public.scan_usage where user_id in (:user_a, :user_b)) = 0,
  'scan counts are deleted with the account');
delete from public.fdc_query_cache;
delete from public.fdc_food_cache;

drop schema nutriq_scan_test cascade;
\echo 'All photo scan checks passed.'
