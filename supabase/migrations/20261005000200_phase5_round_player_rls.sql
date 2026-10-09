-- Phase 5 follow-up: complete RLS coverage for Round-player setup.
-- Authenticated Tour members may read Round players.
-- Only the Tour organiser may create, update, or delete Round-player setup rows.

alter table public.round_players enable row level security;

drop policy if exists round_players_read on public.round_players;
create policy round_players_read
on public.round_players
for select
to authenticated
using (
  exists (
    select 1
    from public.rounds r
    where r.id = round_players.round_id
      and public.can_read_tour(r.tour_id)
  )
);

drop policy if exists round_players_org_all on public.round_players;
create policy round_players_org_all
on public.round_players
for all
to authenticated
using (
  exists (
    select 1
    from public.rounds r
    where r.id = round_players.round_id
      and public.is_tour_organiser(r.tour_id)
  )
)
with check (
  exists (
    select 1
    from public.rounds r
    where r.id = round_players.round_id
      and public.is_tour_organiser(r.tour_id)
  )
);

-- Keep grants explicit: RLS determines which rows authenticated users can access.
grant select, insert, update, delete on public.round_players to authenticated;
