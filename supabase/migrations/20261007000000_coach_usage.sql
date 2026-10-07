-- Nutriq AI coach: daily message allowance.
--
-- Run once, after 20261006000000_nutriq_schema.sql. Stores only a count per
-- user per UTC day — never message content. Rows are deleted with the account.

create table public.coach_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  count integer not null default 0 check (count >= 0),
  primary key (user_id, day)
);

alter table public.coach_usage enable row level security;

-- People may read their own counts. Nobody can write them directly: the only
-- way to add to a count is nutriq_coach_take_turn() below, so the allowance
-- can't be reset from the app.
create policy "coach_usage: read own" on public.coach_usage
  for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.coach_usage from anon, authenticated;
grant select on public.coach_usage to authenticated;

-- Takes one AI-coach message from the caller's allowance for today (UTC).
-- Returns the number left after this one, or -1 when today's allowance is used
-- up (nothing is counted then). Called by the `coach` Edge Function with the
-- caller's own sign-in, so it can only ever spend the caller's allowance.
create or replace function public.nutriq_coach_take_turn()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit constant integer := 30;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  insert into public.coach_usage as u (user_id, day, count)
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

revoke execute on function public.nutriq_coach_take_turn() from public, anon;
grant execute on function public.nutriq_coach_take_turn() to authenticated;
