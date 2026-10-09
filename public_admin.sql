-- STEP 1 (dashboard, not SQL): Authentication > Users > Add user > Create new user
--   Email: coach@4dasistas.ca   Password: 122139   [x] Auto Confirm User
-- STEP 2: run this in the SQL Editor. It gives that one account limited rights.
-- The owner account is untouched. The public admin gets NO delete rights anywhere.

drop policy if exists coach_games_insert on public.games;
drop policy if exists coach_games_update on public.games;
drop policy if exists coach_att_insert on public.attendance;
drop policy if exists coach_att_update on public.attendance;
drop policy if exists coach_players_insert on public.players;
drop policy if exists coach_players_update on public.players;

create policy coach_games_insert on public.games for insert to authenticated
  with check (lower(auth.jwt()->>'email')='coach@4dasistas.ca'
    and (played_at at time zone 'America/Toronto')::date = (now() at time zone 'America/Toronto')::date);
create policy coach_games_update on public.games for update to authenticated
  using (lower(auth.jwt()->>'email')='coach@4dasistas.ca'
    and (played_at at time zone 'America/Toronto')::date = (now() at time zone 'America/Toronto')::date)
  with check ((played_at at time zone 'America/Toronto')::date = (now() at time zone 'America/Toronto')::date);

create policy coach_att_insert on public.attendance for insert to authenticated
  with check (lower(auth.jwt()->>'email')='coach@4dasistas.ca' and session_date = (now() at time zone 'America/Toronto')::date);
create policy coach_att_update on public.attendance for update to authenticated
  using (lower(auth.jwt()->>'email')='coach@4dasistas.ca' and session_date = (now() at time zone 'America/Toronto')::date)
  with check (session_date = (now() at time zone 'America/Toronto')::date);

create policy coach_players_insert on public.players for insert to authenticated
  with check (lower(auth.jwt()->>'email')='coach@4dasistas.ca');
create policy coach_players_update on public.players for update to authenticated
  using (lower(auth.jwt()->>'email')='coach@4dasistas.ca') with check (true);

notify pgrst, 'reload schema';
