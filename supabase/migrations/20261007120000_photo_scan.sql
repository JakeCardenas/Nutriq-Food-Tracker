-- Nutriq photo estimates: daily scan allowance and a nutrition lookup cache.
--
-- Run once, after 20261007000000_coach_usage.sql. The allowance stores only a
-- count per user per UTC day (never photos or results) and is separate from
-- the coach allowance. The cache holds public USDA FoodData Central values
-- (no user data) and is only readable/writable by the server.

create table public.scan_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  count integer not null default 0 check (count >= 0),
  primary key (user_id, day)
);

alter table public.scan_usage enable row level security;

-- People may read their own counts. Nobody can write them directly: the only
-- way to add to a count is nutriq_scan_take_turn() below.
create policy "scan_usage: read own" on public.scan_usage
  for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.scan_usage from anon, authenticated;
grant select on public.scan_usage to authenticated;

-- Takes one photo estimate from the caller's allowance for today (UTC), with a
-- daily limit of p_limit (clamped to 1–200). Returns the number left after
-- this one, or -1 when today's allowance is used up (nothing is counted then).
-- The scan-photo Edge Function passes its configured limit (SCAN_DAILY_LIMIT)
-- and calls this with the caller's own sign-in. Calling it directly can only
-- spend the caller's own allowance — it never grants a scan.
create or replace function public.nutriq_scan_take_turn(p_limit integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit constant integer := least(greatest(coalesce(p_limit, 1), 1), 200);
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  insert into public.scan_usage as u (user_id, day, count)
  values (v_uid, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, day) do update set count = u.count + 1
    where u.count < v_limit
  returning u.count into v_count;
  if v_count is null then
    return -1;
  end if;
  return v_limit - v_count;
end;
$$;

revoke execute on function public.nutriq_scan_take_turn(integer) from public, anon;
grant execute on function public.nutriq_scan_take_turn(integer) to authenticated;

-- ── Nutrition lookup cache (USDA FoodData Central, public domain) ──────────
-- Values are per 100 g. Written and read only by the scan-photo function with
-- the server key; RLS is on with no policies, so app users can't touch it.
create table public.fdc_food_cache (
  fdc_id bigint primary key,
  description text not null check (char_length(description) <= 200),
  data_type text not null check (char_length(data_type) <= 40),
  kcal_100g numeric(7, 2) not null check (kcal_100g >= 0),
  protein_100g numeric(7, 2) not null check (protein_100g >= 0),
  carbs_100g numeric(7, 2) check (carbs_100g >= 0),
  fat_100g numeric(7, 2) check (fat_100g >= 0),
  fetched_at timestamptz not null default now()
);

-- A normalized search phrase → the food it matched (null = no usable match).
create table public.fdc_query_cache (
  query text primary key check (char_length(query) between 1 and 120),
  fdc_id bigint references public.fdc_food_cache (fdc_id) on delete cascade,
  fetched_at timestamptz not null default now()
);

alter table public.fdc_food_cache enable row level security;
alter table public.fdc_query_cache enable row level security;
revoke all on public.fdc_food_cache, public.fdc_query_cache from anon, authenticated;
grant select, insert, update, delete on public.fdc_food_cache, public.fdc_query_cache to service_role;
