-- Notably: public.admins (run once if tables already exist without this)
-- Also included at the end of supabase/schema.sql — keep the two in step.

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'admin' check (role in ('admin', 'viewer')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create index if not exists admins_email on public.admins (email);

alter table public.admins enable row level security;

-- The policies below have to answer "is the caller an admin?", and the answer
-- lives in this very table. Asking directly — `exists (select 1 from
-- public.admins ...)` inside a policy on public.admins — makes Postgres
-- evaluate the policy to evaluate the policy, and it gives up with
--   42P17: infinite recursion detected in policy for relation "admins"
-- Every read then fails, which the app surfaces as "Admin access required"
-- even though the row is right there.
--
-- security definer is the way out: the function runs as its owner, who is not
-- subject to RLS, so the membership check reads the table without re-entering
-- the policy. It returns only a boolean, so it leaks nothing.
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

-- Signed-in user can see their own row. This is the one the Worker's
-- membership check needs, and it is deliberately not routed through
-- is_admin(): the whole point is that it works before you know the answer.
create policy "admins read own" on public.admins
  for select using (auth.uid() = user_id);

-- Existing admins can list the whole team.
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

-- Bootstrap YOUR account as admin (change the email).
-- Matched case-insensitively against auth.users, so the row can only ever
-- carry a real Auth uid — an address with a typo inserts nothing at all
-- rather than a row that never matches anyone who signs in.
insert into public.admins (user_id, email, role)
select id, email, 'admin'
from auth.users
where lower(email) = lower('admin@gmail.com')
on conflict (user_id) do update
  set email = excluded.email,
      role = 'admin';
