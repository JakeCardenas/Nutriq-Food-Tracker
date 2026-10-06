-- Nutriq cloud schema v1
-- Mirrors lib/domain/models: UserProfile + AppSettings (profiles), Meal (meals),
-- FoodItem (meal_items), SavedFood (saved_foods), ScanFeedback (scan_feedback).
--
-- Ownership: every row carries user_id = auth.users.id. Row Level Security
-- restricts every operation to the signed-in owner. Meal items reference their
-- meal through a composite foreign key (user_id, meal_id) so an item can never be
-- attached to another user's meal.
--
-- Not stored: meal photos (stay on the phone), coach chats (never persisted),
-- Apple Health data (stays on the phone).

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.nutriq_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────────────────────────────────────

create table public.profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  has_profile boolean not null default false,
  age smallint check (age between 13 and 100),
  sex text check (sex in ('female', 'male')),
  height_cm numeric(5, 1) check (height_cm between 100 and 250),
  weight_kg numeric(5, 1) check (weight_kg between 30 and 300),
  goal_weight_kg numeric(5, 1) check (goal_weight_kg between 30 and 300),
  activity text check (activity in ('sedentary', 'light', 'moderate', 'active', 'veryActive')),
  goal text check (goal in ('loseFat', 'maintain', 'gainMuscle', 'buildStrength', 'generalFitness', 'eatConsistently')),
  workout_days_per_week smallint check (workout_days_per_week between 0 and 7),
  health_considerations text[] not null default '{}'
    check (health_considerations <@ array['pregnant', 'breastfeeding', 'medicalCondition']),
  calorie_goal_min integer,
  calorie_goal_max integer,
  calorie_goal_custom boolean not null default false,
  protein_target_g smallint check (protein_target_g between 30 and 300),
  units text not null default 'metric' check (units in ('metric', 'imperial')),
  day_start_hour smallint not null default 0 check (day_start_hour between 0 and 6),
  onboarding_complete boolean not null default false,
  client_updated_at bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calorie_goal_pair check ((calorie_goal_min is null) = (calorie_goal_max is null)),
  -- Absolute bounds. The app also enforces max(1,200, resting energy) on the device.
  constraint calorie_goal_bounds check (
    calorie_goal_min is null
    or (calorie_goal_min >= 1200 and calorie_goal_max <= 6000 and calorie_goal_max - calorie_goal_min >= 100)
  ),
  -- Safeguard mirrored from the app: no calorie or protein targets for minors.
  constraint no_targets_for_minors check (
    age is null or age >= 18 or (calorie_goal_min is null and protein_target_g is null)
  )
);

create table public.meals (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  logged_at timestamptz not null,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  source text not null check (source in ('demoScan', 'scan', 'manual')),
  name text check (char_length(name) <= 120),
  note text check (char_length(note) <= 500),
  deleted_at timestamptz,
  client_updated_at bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.meal_items (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  meal_id text not null,
  id text not null check (char_length(id) between 1 and 64),
  position integer not null default 0 check (position >= 0),
  name text not null check (char_length(name) between 1 and 200),
  servings numeric(6, 2) not null check (servings >= 0 and servings <= 100),
  serving_label text not null check (char_length(serving_label) <= 120),
  calories_per_serving numeric(7, 1) not null check (calories_per_serving between 0 and 5000),
  protein_per_serving numeric(6, 1) not null default 0 check (protein_per_serving between 0 and 1000),
  carbs_per_serving numeric(6, 1) not null default 0 check (carbs_per_serving between 0 and 1000),
  fat_per_serving numeric(6, 1) not null default 0 check (fat_per_serving between 0 and 1000),
  confidence numeric(3, 2) check (confidence between 0 and 1),
  primary key (user_id, meal_id, id),
  -- The composite key ties each item to a meal owned by the same user.
  foreign key (user_id, meal_id) references public.meals (user_id, id) on delete cascade
);

create table public.saved_foods (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  name text not null check (char_length(name) between 1 and 200),
  serving_label text not null check (char_length(serving_label) <= 120),
  calories_per_serving numeric(7, 1) not null check (calories_per_serving between 0 and 5000),
  protein_per_serving numeric(6, 1) not null default 0 check (protein_per_serving between 0 and 1000),
  carbs_per_serving numeric(6, 1) not null default 0 check (carbs_per_serving between 0 and 1000),
  fat_per_serving numeric(6, 1) not null default 0 check (fat_per_serving between 0 and 1000),
  saved_at timestamptz not null,
  deleted_at timestamptz,
  client_updated_at bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.scan_feedback (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  meal_id text check (char_length(meal_id) <= 64),
  meal_summary text not null check (char_length(meal_summary) <= 500),
  estimated_calories integer not null check (estimated_calories between 0 and 50000),
  rating text not null check (rating in ('tooHigh', 'aboutRight', 'tooLow')),
  was_demo boolean not null default false,
  note text check (char_length(note) <= 300),
  rated_at timestamptz not null,
  deleted_at timestamptz,
  client_updated_at bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index meals_sync_idx on public.meals (user_id, updated_at, id);
create index saved_foods_sync_idx on public.saved_foods (user_id, updated_at, id);
create index scan_feedback_sync_idx on public.scan_feedback (user_id, updated_at, id);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.nutriq_set_updated_at();
create trigger meals_updated_at before update on public.meals
  for each row execute function public.nutriq_set_updated_at();
create trigger saved_foods_updated_at before update on public.saved_foods
  for each row execute function public.nutriq_set_updated_at();
create trigger scan_feedback_updated_at before update on public.scan_feedback
  for each row execute function public.nutriq_set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security: owner-only, every table, every operation
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;
alter table public.saved_foods enable row level security;
alter table public.scan_feedback enable row level security;

revoke all on public.profiles, public.meals, public.meal_items, public.saved_foods, public.scan_feedback from anon;

-- Grant signed-in users exactly what the app needs, so this works whether or not
-- the project "automatically exposes new tables". RLS above limits it to their own rows.
grant usage on schema public to authenticated;
grant select, insert, update, delete
  on public.profiles, public.meals, public.meal_items, public.saved_foods, public.scan_feedback
  to authenticated;

create policy "profiles: owner select" on public.profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "profiles: owner insert" on public.profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "profiles: owner update" on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "profiles: owner delete" on public.profiles for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "meals: owner select" on public.meals for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "meals: owner insert" on public.meals for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "meals: owner update" on public.meals for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "meals: owner delete" on public.meals for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Items are reachable only through a meal owned by the same user.
create policy "meal_items: owner select" on public.meal_items for select to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (select 1 from public.meals m where m.user_id = (select auth.uid()) and m.id = meal_id)
  );
create policy "meal_items: owner insert" on public.meal_items for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.meals m where m.user_id = (select auth.uid()) and m.id = meal_id)
  );
create policy "meal_items: owner update" on public.meal_items for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.meals m where m.user_id = (select auth.uid()) and m.id = meal_id)
  );
create policy "meal_items: owner delete" on public.meal_items for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "saved_foods: owner select" on public.saved_foods for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "saved_foods: owner insert" on public.saved_foods for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "saved_foods: owner update" on public.saved_foods for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "saved_foods: owner delete" on public.saved_foods for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "scan_feedback: owner select" on public.scan_feedback for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "scan_feedback: owner insert" on public.scan_feedback for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "scan_feedback: owner update" on public.scan_feedback for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "scan_feedback: owner delete" on public.scan_feedback for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Sync functions (SECURITY INVOKER: RLS still applies to every statement)
--
-- Each push refuses a write whose client_updated_at is older than the stored
-- one and returns {"status":"stale","current":<row>} so the app can keep the
-- newer version and show the older edit as a conflict.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.nutriq_meal_json(m public.meals)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select to_jsonb(m) || jsonb_build_object(
    'items',
    coalesce(
      (select jsonb_agg(to_jsonb(i) order by i.position)
         from public.meal_items i
        where i.user_id = m.user_id and i.meal_id = m.id),
      '[]'::jsonb
    )
  );
$$;

create or replace function public.nutriq_push_meal(p_meal jsonb, p_items jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id text := p_meal ->> 'id';
  v_client bigint := (p_meal ->> 'client_updated_at')::bigint;
  v_deleted boolean := coalesce((p_meal ->> 'deleted')::boolean, false);
  v_existing public.meals%rowtype;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  select * into v_existing from public.meals where user_id = v_uid and id = v_id for update;

  if found and v_existing.client_updated_at > v_client then
    return jsonb_build_object('status', 'stale', 'current', public.nutriq_meal_json(v_existing));
  end if;

  if v_deleted then
    if found then
      update public.meals set deleted_at = now(), client_updated_at = v_client
       where user_id = v_uid and id = v_id;
      delete from public.meal_items where user_id = v_uid and meal_id = v_id;
    end if;
    return jsonb_build_object('status', 'ok');
  end if;

  insert into public.meals (user_id, id, logged_at, meal_type, source, name, note, deleted_at, client_updated_at)
  values (
    v_uid, v_id, (p_meal ->> 'logged_at')::timestamptz, p_meal ->> 'meal_type', p_meal ->> 'source',
    p_meal ->> 'name', p_meal ->> 'note', null, v_client
  )
  on conflict (user_id, id) do update set
    logged_at = excluded.logged_at,
    meal_type = excluded.meal_type,
    source = excluded.source,
    name = excluded.name,
    note = excluded.note,
    deleted_at = null,
    client_updated_at = excluded.client_updated_at;

  delete from public.meal_items where user_id = v_uid and meal_id = v_id;
  insert into public.meal_items (
    user_id, meal_id, id, position, name, servings, serving_label,
    calories_per_serving, protein_per_serving, carbs_per_serving, fat_per_serving, confidence
  )
  select
    v_uid, v_id, item ->> 'id', (ord - 1)::integer, item ->> 'name', (item ->> 'servings')::numeric,
    item ->> 'serving_label', (item ->> 'calories_per_serving')::numeric,
    coalesce((item ->> 'protein_per_serving')::numeric, 0), coalesce((item ->> 'carbs_per_serving')::numeric, 0),
    coalesce((item ->> 'fat_per_serving')::numeric, 0), (item ->> 'confidence')::numeric
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as t (item, ord);

  return jsonb_build_object('status', 'ok');
end;
$$;

create or replace function public.nutriq_push_profile(p jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_client bigint := (p ->> 'client_updated_at')::bigint;
  v_existing public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  select * into v_existing from public.profiles where user_id = v_uid for update;
  if found and v_existing.client_updated_at > v_client then
    return jsonb_build_object('status', 'stale', 'current', to_jsonb(v_existing));
  end if;

  insert into public.profiles (
    user_id, has_profile, age, sex, height_cm, weight_kg, goal_weight_kg, activity, goal,
    workout_days_per_week, health_considerations, calorie_goal_min, calorie_goal_max, calorie_goal_custom,
    protein_target_g, units, day_start_hour, onboarding_complete, client_updated_at
  ) values (
    v_uid, coalesce((p ->> 'has_profile')::boolean, false), (p ->> 'age')::smallint,
    p ->> 'sex', (p ->> 'height_cm')::numeric, (p ->> 'weight_kg')::numeric, (p ->> 'goal_weight_kg')::numeric,
    p ->> 'activity', p ->> 'goal', (p ->> 'workout_days_per_week')::smallint,
    coalesce(array(select jsonb_array_elements_text(p -> 'health_considerations')), '{}'),
    (p ->> 'calorie_goal_min')::integer, (p ->> 'calorie_goal_max')::integer,
    coalesce((p ->> 'calorie_goal_custom')::boolean, false), (p ->> 'protein_target_g')::smallint,
    coalesce(p ->> 'units', 'metric'), coalesce((p ->> 'day_start_hour')::smallint, 0),
    coalesce((p ->> 'onboarding_complete')::boolean, false), v_client
  )
  on conflict (user_id) do update set
    has_profile = excluded.has_profile,
    age = excluded.age,
    sex = excluded.sex,
    height_cm = excluded.height_cm,
    weight_kg = excluded.weight_kg,
    goal_weight_kg = excluded.goal_weight_kg,
    activity = excluded.activity,
    goal = excluded.goal,
    workout_days_per_week = excluded.workout_days_per_week,
    health_considerations = excluded.health_considerations,
    calorie_goal_min = excluded.calorie_goal_min,
    calorie_goal_max = excluded.calorie_goal_max,
    calorie_goal_custom = excluded.calorie_goal_custom,
    protein_target_g = excluded.protein_target_g,
    units = excluded.units,
    day_start_hour = excluded.day_start_hour,
    onboarding_complete = excluded.onboarding_complete,
    client_updated_at = excluded.client_updated_at;

  return jsonb_build_object('status', 'ok');
end;
$$;

create or replace function public.nutriq_push_saved_food(p jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id text := p ->> 'id';
  v_client bigint := (p ->> 'client_updated_at')::bigint;
  v_existing public.saved_foods%rowtype;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  select * into v_existing from public.saved_foods where user_id = v_uid and id = v_id for update;
  if found and v_existing.client_updated_at > v_client then
    return jsonb_build_object('status', 'stale', 'current', to_jsonb(v_existing));
  end if;

  if coalesce((p ->> 'deleted')::boolean, false) then
    update public.saved_foods set deleted_at = now(), client_updated_at = v_client
     where user_id = v_uid and id = v_id;
    return jsonb_build_object('status', 'ok');
  end if;

  insert into public.saved_foods (
    user_id, id, name, serving_label, calories_per_serving, protein_per_serving, carbs_per_serving,
    fat_per_serving, saved_at, deleted_at, client_updated_at
  ) values (
    v_uid, v_id, p ->> 'name', p ->> 'serving_label', (p ->> 'calories_per_serving')::numeric,
    coalesce((p ->> 'protein_per_serving')::numeric, 0), coalesce((p ->> 'carbs_per_serving')::numeric, 0),
    coalesce((p ->> 'fat_per_serving')::numeric, 0), (p ->> 'saved_at')::timestamptz, null, v_client
  )
  on conflict (user_id, id) do update set
    name = excluded.name,
    serving_label = excluded.serving_label,
    calories_per_serving = excluded.calories_per_serving,
    protein_per_serving = excluded.protein_per_serving,
    carbs_per_serving = excluded.carbs_per_serving,
    fat_per_serving = excluded.fat_per_serving,
    saved_at = excluded.saved_at,
    deleted_at = null,
    client_updated_at = excluded.client_updated_at;

  return jsonb_build_object('status', 'ok');
end;
$$;

create or replace function public.nutriq_push_scan_feedback(p jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id text := p ->> 'id';
  v_client bigint := (p ->> 'client_updated_at')::bigint;
  v_existing public.scan_feedback%rowtype;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  select * into v_existing from public.scan_feedback where user_id = v_uid and id = v_id for update;
  if found and v_existing.client_updated_at > v_client then
    return jsonb_build_object('status', 'stale', 'current', to_jsonb(v_existing));
  end if;

  if coalesce((p ->> 'deleted')::boolean, false) then
    update public.scan_feedback set deleted_at = now(), client_updated_at = v_client
     where user_id = v_uid and id = v_id;
    return jsonb_build_object('status', 'ok');
  end if;

  insert into public.scan_feedback (
    user_id, id, meal_id, meal_summary, estimated_calories, rating, was_demo, note, rated_at,
    deleted_at, client_updated_at
  ) values (
    v_uid, v_id, p ->> 'meal_id', p ->> 'meal_summary', (p ->> 'estimated_calories')::integer,
    p ->> 'rating', coalesce((p ->> 'was_demo')::boolean, false), p ->> 'note',
    (p ->> 'rated_at')::timestamptz, null, v_client
  )
  on conflict (user_id, id) do update set
    meal_id = excluded.meal_id,
    meal_summary = excluded.meal_summary,
    estimated_calories = excluded.estimated_calories,
    rating = excluded.rating,
    was_demo = excluded.was_demo,
    note = excluded.note,
    rated_at = excluded.rated_at,
    deleted_at = null,
    client_updated_at = excluded.client_updated_at;

  return jsonb_build_object('status', 'ok');
end;
$$;

-- Deletes every row the caller owns. Auth account deletion is a separate,
-- server-side Edge Function (it needs the service-role key, which never ships in the app).
create or replace function public.nutriq_delete_my_data()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  delete from public.scan_feedback where user_id = v_uid;
  delete from public.saved_foods where user_id = v_uid;
  delete from public.meal_items where user_id = v_uid;
  delete from public.meals where user_id = v_uid;
  delete from public.profiles where user_id = v_uid;
end;
$$;

revoke execute on function
  public.nutriq_meal_json(public.meals),
  public.nutriq_push_meal(jsonb, jsonb),
  public.nutriq_push_profile(jsonb),
  public.nutriq_push_saved_food(jsonb),
  public.nutriq_push_scan_feedback(jsonb),
  public.nutriq_delete_my_data()
from public, anon;

grant execute on function
  public.nutriq_meal_json(public.meals),
  public.nutriq_push_meal(jsonb, jsonb),
  public.nutriq_push_profile(jsonb),
  public.nutriq_push_saved_food(jsonb),
  public.nutriq_push_scan_feedback(jsonb),
  public.nutriq_delete_my_data()
to authenticated;
