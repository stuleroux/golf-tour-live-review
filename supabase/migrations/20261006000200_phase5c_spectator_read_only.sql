-- Phase 5C: separate read-only spectator access for approved public Tour/live data.
-- Spectators never receive invitation or write access.

-- Approved public live-data tables remain protected by RLS.
alter table public.round_players enable row level security;
alter table public.matches enable row level security;
alter table public.match_participants enable row level security;
alter table public.match_confirmations enable row level security;
alter table public.hole_scores enable row level security;
alter table public.team_hole_scores enable row level security;
alter table public.selected_drives enable row level security;
alter table public.alternate_shot_settings enable row level security;

-- Round-scoped public data.
drop policy if exists round_players_public_read on public.round_players;
create policy round_players_public_read on public.round_players
for select to anon
using (exists (
  select 1 from public.rounds r join public.tours t on t.id=r.tour_id
  where r.id=round_players.round_id and t.spectator_enabled
));

drop policy if exists matches_public_read on public.matches;
create policy matches_public_read on public.matches
for select to anon
using (exists (
  select 1 from public.rounds r join public.tours t on t.id=r.tour_id
  where r.id=matches.round_id and t.spectator_enabled
));

-- Match-scoped public data. match_tour() is the established match -> Tour helper.
drop policy if exists match_participants_public_read on public.match_participants;
create policy match_participants_public_read on public.match_participants
for select to anon
using (exists (select 1 from public.tours t where t.id=public.match_tour(match_id) and t.spectator_enabled));

drop policy if exists confirmations_public_read on public.match_confirmations;
create policy confirmations_public_read on public.match_confirmations
for select to anon
using (exists (select 1 from public.tours t where t.id=public.match_tour(match_id) and t.spectator_enabled));

drop policy if exists hole_scores_public_read on public.hole_scores;
create policy hole_scores_public_read on public.hole_scores
for select to anon
using (exists (select 1 from public.tours t where t.id=public.match_tour(match_id) and t.spectator_enabled));

drop policy if exists team_scores_public_read on public.team_hole_scores;
create policy team_scores_public_read on public.team_hole_scores
for select to anon
using (exists (select 1 from public.tours t where t.id=public.match_tour(match_id) and t.spectator_enabled));

drop policy if exists selected_drives_public_read on public.selected_drives;
create policy selected_drives_public_read on public.selected_drives
for select to anon
using (exists (select 1 from public.tours t where t.id=public.match_tour(match_id) and t.spectator_enabled));

drop policy if exists alternate_shot_settings_public_read on public.alternate_shot_settings;
create policy alternate_shot_settings_public_read on public.alternate_shot_settings
for select to anon
using (exists (select 1 from public.tours t where t.id=public.match_tour(match_id) and t.spectator_enabled));

-- Anonymous spectators get SELECT only on explicitly approved public tables.
grant select on public.round_players, public.matches, public.match_participants,
  public.match_confirmations, public.hole_scores, public.team_hole_scores,
  public.selected_drives, public.alternate_shot_settings to anon;

revoke insert, update, delete on public.round_players, public.matches, public.match_participants,
  public.match_confirmations, public.hole_scores, public.team_hole_scores,
  public.selected_drives, public.alternate_shot_settings from anon;

-- Tighten existing snapshot grants to spectator-read-only.
revoke references, trigger, truncate on public.round_course_snapshot, public.round_hole_snapshot from anon;
grant select on public.round_course_snapshot, public.round_hole_snapshot to anon;

-- Invitations remain private and never become spectator-readable.
revoke all on public.invitations from anon;
