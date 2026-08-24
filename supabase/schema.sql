-- Notably sync schema for Supabase Postgres.
-- Run once in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Mirrors the old Firestore layout under users/{uid}/…
-- App sync uses supabase_flutter with RLS (auth.uid() = user_id).

create table if not exists public.documents (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.pages (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  document_id text not null,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.elements (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  page_id text,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.assets (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.quizzes (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.ink (
  page_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  bytes bytea not null default '\x',
  storage text not null default 'inline' check (storage in ('inline', 'r2')),
  remote_key text,
  updated_at timestamptz not null default now(),
  primary key (user_id, page_id)
);

-- Existing installs: add R2 pointer columns (safe to re-run).
alter table public.ink add column if not exists storage text;
alter table public.ink add column if not exists remote_key text;
update public.ink set storage = 'inline' where storage is null;

create table if not exists public.user_prefs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists documents_user_updated on public.documents (user_id, updated_at);
create index if not exists pages_user_doc_updated on public.pages (user_id, document_id, updated_at);
create index if not exists elements_user_page_updated on public.elements (user_id, page_id, updated_at);
create index if not exists assets_user_updated on public.assets (user_id, updated_at);
create index if not exists quizzes_user_updated on public.quizzes (user_id, updated_at);
create index if not exists ink_user_updated on public.ink (user_id, updated_at);
create index if not exists user_prefs_user_updated on public.user_prefs (user_id, updated_at);

alter table public.documents enable row level security;
alter table public.pages enable row level security;
alter table public.elements enable row level security;
alter table public.assets enable row level security;
alter table public.quizzes enable row level security;
alter table public.ink enable row level security;
alter table public.user_prefs enable row level security;

drop policy if exists "own documents" on public.documents;
drop policy if exists "own pages" on public.pages;
drop policy if exists "own elements" on public.elements;
drop policy if exists "own assets" on public.assets;
drop policy if exists "own quizzes" on public.quizzes;
drop policy if exists "own ink" on public.ink;
drop policy if exists "own user_prefs" on public.user_prefs;

create policy "own documents" on public.documents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own pages" on public.pages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own elements" on public.elements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own assets" on public.assets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own quizzes" on public.quizzes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own ink" on public.ink
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own user_prefs" on public.user_prefs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Table privileges (RLS alone is not enough — roles need GRANT)
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on public.documents to authenticated;
grant select, insert, update, delete on public.pages to authenticated;
grant select, insert, update, delete on public.elements to authenticated;
grant select, insert, update, delete on public.assets to authenticated;
grant select, insert, update, delete on public.quizzes to authenticated;
grant select, insert, update, delete on public.ink to authenticated;
grant select, insert, update, delete on public.user_prefs to authenticated;

grant all on public.documents to service_role;
grant all on public.pages to service_role;
grant all on public.elements to service_role;
grant all on public.assets to service_role;
grant all on public.quizzes to service_role;
grant all on public.ink to service_role;
grant all on public.user_prefs to service_role;

-- ---------------------------------------------------------------------------
-- Admins table — single source of truth for staff console access
-- Bootstrap first admin (SQL Editor, as postgres — bypasses RLS):
--   insert into public.admins (user_id, email, role)
--   select id, email, 'admin' from auth.users where email = 'you@example.com';
-- ---------------------------------------------------------------------------

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'admin' check (role in ('admin', 'viewer')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create index if not exists admins_email on public.admins (email);

alter table public.admins enable row level security;

-- Policies ask "is the caller an admin?" via this table. Using
-- `exists (select 1 from public.admins ...)` *inside* a policy on
-- public.admins causes 42P17 infinite recursion. security definer
-- is_admin() reads the table without re-entering RLS.
create or replace function public.is_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins a
    where a.user_id = uid and a.role = 'admin'
  );
$$;

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated, anon, service_role;

drop policy if exists "admins read own" on public.admins;
drop policy if exists "admins read all" on public.admins;
drop policy if exists "admins insert" on public.admins;
drop policy if exists "admins update" on public.admins;
drop policy if exists "admins delete" on public.admins;

-- Own row without is_admin() — needed for the membership check itself.
create policy "admins read own" on public.admins
  for select using (auth.uid() = user_id);

create policy "admins read all" on public.admins
  for select using (public.is_admin());

create policy "admins insert" on public.admins
  for insert with check (public.is_admin());

create policy "admins update" on public.admins
  for update using (public.is_admin());

create policy "admins delete" on public.admins
  for delete using (public.is_admin());

grant select, insert, update, delete on public.admins to authenticated;
grant all on public.admins to service_role;
