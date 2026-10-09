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
