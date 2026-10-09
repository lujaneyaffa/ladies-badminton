-- RUN THIS WHOLE FILE in the Supabase SQL Editor (safe to run more than once).
-- Part 1 fixes iPad photo saving. Part 2 fixes the login lockout bug.

-- ===== PART 1: kiosk photos =====
-- Run in Supabase SQL Editor. Lets the iPad kiosk save a profile photo or a
-- heart emoji for the player who just checked in. It needs the kiosk key and
-- only accepts a heart from the list or a photo stored in that player's folder.
create or replace function public.kiosk_set_avatar(p_key text, p_player_id text, p_avatar text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public._kiosk_ok(p_key) then
    raise exception 'This iPad is not set up as the kiosk';
  end if;
  if not exists (select 1 from public.players where id::text = p_player_id and active is distinct from false) then
    raise exception 'Player not found';
  end if;
  if p_avatar in ('emoji:❤️','emoji:🧡','emoji:💛','emoji:💚','emoji:💙','emoji:💜','emoji:🩷','emoji:🤎')
     or p_avatar like 'https://zcahhfswtdrdmguppqtp.supabase.co/storage/v1/object/public/profile-avatars/self/kiosk-' || p_player_id || '-%' then
    update public.players set avatar_url = p_avatar where id::text = p_player_id;
  else
    raise exception 'That picture is not allowed';
  end if;
end;
$$;
revoke all on function public.kiosk_set_avatar(text, text, text) from public;
grant execute on function public.kiosk_set_avatar(text, text, text) to anon, authenticated;
notify pgrst, 'reload schema';

-- ===== PART 2: login lockout fix =====
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
    on conflict on constraint login_attempts_pkey do update
      set fails = case when a.locked_until is not null and a.locked_until <= now() then 1 else a.fails + 1 end,
          locked_until = case when (case when a.locked_until is not null and a.locked_until <= now() then 1 else a.fails + 1 end) >= 5
                              then now() + interval '15 minutes' else null end;
  end if;
end;
$function$;

notify pgrst, 'reload schema';
