-- Run in Supabase SQL Editor.
--
-- Why this exists: the earlier lockdown_pin.sql used
--     revoke select (pin) on public.players from anon, authenticated;
-- but that does nothing while those roles still hold SELECT on the WHOLE
-- table (a column-level revoke can't carve a hole in a table-level grant).
-- A test on the live site confirmed anyone can still read the pin column.
--
-- This does it the way Postgres actually supports: take away the blanket
-- read, then hand back every column EXCEPT pin.
-- The app already asks only for these columns, so nothing changes for
-- visitors, and the login/RSVP/edit functions are unaffected (they run with
-- their own elevated access).

revoke select on public.players from public, anon, authenticated;

grant select (
  id, name, full_name, nickname, username, phone,
  level, avatar_url, date_joined, active
) on public.players to anon, authenticated;

notify pgrst, 'reload schema';
