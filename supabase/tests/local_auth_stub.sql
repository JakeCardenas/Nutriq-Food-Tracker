-- Minimal stand-in for Supabase's auth schema and roles, so the migrations and
-- the RLS test can run on a plain local Postgres (no Docker needed).
-- NOT for production — a real Supabase project already has all of this.

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  -- Supabase's server-side role (Edge Functions with the secret key); bypasses RLS.
  if not exists (select from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end;
$$;

create schema if not exists auth;
create table if not exists auth.users (id uuid primary key, email text);

-- Same contract as Supabase: the user id comes from the JWT's "sub" claim.
create or replace function auth.uid() returns uuid language sql stable as $$
  select (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;

grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
grant usage on schema public to anon, authenticated;

-- Mirrors a project created with "Automatically expose new tables" turned OFF
-- (Supabase's recommendation): no automatic table grants, so the migration's own
-- grants must be enough.
alter default privileges in schema public grant all on functions to anon, authenticated;
