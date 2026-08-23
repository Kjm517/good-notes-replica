-- Fix admins table: recreate policies (avoid RLS recursion) + sync your user

-- Helper: bypasses RLS when checking membership (safe, only returns boolean)
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

-- Wipe wrong rows and insert the real Auth user for this email
delete from public.admins;

insert into public.admins (user_id, email, role)
select id, email, 'admin'
from auth.users
where lower(email) = lower('admin@gmail.com');

-- Confirm match (should show same uuid on both sides)
select
  u.id as auth_uid,
  u.email,
  a.user_id as admin_uid,
  a.role,
  (u.id = a.user_id) as matched
from auth.users u
left join public.admins a on a.user_id = u.id
where lower(u.email) = lower('admin@gmail.com');
