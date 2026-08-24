-- Run once in Supabase → SQL Editor.
-- Lets the admin console delete Auth users using the signed-in admin JWT
-- (no service_role key required on the Worker).

create or replace function public.admin_delete_auth_user(target uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;
  if target is null then
    raise exception 'target is required.';
  end if;
  if target = auth.uid() then
    raise exception 'You cannot delete your own account from here.';
  end if;

  delete from auth.users where id = target;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

revoke all on function public.admin_delete_auth_user(uuid) from public;
grant execute on function public.admin_delete_auth_user(uuid) to authenticated, service_role;
