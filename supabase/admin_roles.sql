-- Staff roles: admin (write) vs viewer (read).
-- Run in the Supabase SQL editor if public.admins already exists.
-- Also kept in sync with supabase/admins.sql and schema.sql.

create or replace function public.is_staff(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins a
    where a.user_id = uid and a.role in ('admin', 'viewer')
  );
$$;

revoke all on function public.is_staff(uuid) from public;
grant execute on function public.is_staff(uuid) to authenticated, anon, service_role;

-- Viewers can list the team; only admins can change it.
drop policy if exists "admins read all" on public.admins;
create policy "admins read all" on public.admins
  for select using (public.is_staff());
