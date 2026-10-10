-- Lets a signed-in user delete their own account from inside the app
-- (Settings > Delete account). Both app stores require this for any app
-- that lets people create an account.
--
-- Clients can't delete from auth.users directly, so this runs with the
-- function owner's rights — but it can only ever remove the row belonging
-- to whoever is calling it. Everything that references the user (e.g.
-- card_progress) goes with it via `on delete cascade`.

create function public.delete_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = (select auth.uid());
$$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
