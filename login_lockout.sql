-- Run in Supabase SQL Editor. After 5 wrong PINs for a phone number,
-- login is paused for 15 minutes. A correct login resets the count.
create table if not exists public.login_attempts (
  username text primary key,
  fails int not null default 0,
  locked_until timestamptz
);
alter table public.login_attempts enable row level security;
revoke all on public.login_attempts from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.login_player(p_username text, p_pin text)
 RETURNS TABLE(id text, name text, full_name text, username text, level integer, avatar_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_u text := left(coalesce(p_username, ''), 40);
  v_lock timestamptz;
  v_ok boolean;
begin
  select a.locked_until into v_lock from public.login_attempts a where a.username = v_u;
  if v_lock is not null and v_lock > now() then
    raise exception 'Too many wrong attempts. Try again in % minutes.', greatest(1, ceil(extract(epoch from (v_lock - now())) / 60))::int;
  end if;

  select exists (select 1 from public.players p where p.username = p_username and p.pin = p_pin) into v_ok;

  if v_ok then
    delete from public.login_attempts a where a.username = v_u;
    return query
    select p.id::text, p.name, p.full_name, p.username, p.level, p.avatar_url
    from public.players p
    where p.username = p_username and p.pin = p_pin;
  else
    insert into public.login_attempts as a (username, fails, locked_until)
    values (v_u, 1, null)
    on conflict (username) do update
      set fails = case when a.locked_until is not null and a.locked_until <= now() then 1 else a.fails + 1 end,
          locked_until = case when (case when a.locked_until is not null and a.locked_until <= now() then 1 else a.fails + 1 end) >= 5
                              then now() + interval '15 minutes' else null end;
  end if;
end;
$function$;

notify pgrst, 'reload schema';
