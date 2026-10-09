-- Phase 5A: Tour setup integrity and readiness validation.
-- Adds editable setup Handicap Index distinct from the frozen Tour Handicap Index.

alter table public.tour_players
  add column if not exists handicap_index numeric;

alter table public.tour_players
  drop constraint if exists tour_players_handicap_index_range;
alter table public.tour_players
  add constraint tour_players_handicap_index_range
  check (handicap_index is null or handicap_index between -10 and 54);

alter table public.tour_players
  drop constraint if exists tour_players_frozen_handicap_index_range;
alter table public.tour_players
  add constraint tour_players_frozen_handicap_index_range
  check (frozen_handicap_index is null or frozen_handicap_index between -10 and 54);

-- Frozen Tour HI is immutable once set. The start operation owns the initial freeze.
create or replace function public.protect_frozen_tour_handicap()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.frozen_handicap_index is not null
     and new.frozen_handicap_index is distinct from old.frozen_handicap_index then
    raise exception 'Frozen Tour Handicap Index is immutable once set';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_frozen_tour_handicap_before on public.tour_players;
create trigger protect_frozen_tour_handicap_before
before update on public.tour_players
for each row execute function public.protect_frozen_tour_handicap();

-- Validate participant cardinality and active Round-player membership.
create or replace function public.validate_round_pairings(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.rounds%rowtype;
  v_match record;
  v_total integer;
  v_a integer;
  v_b integer;
  v_team_a integer;
  v_team_b integer;
begin
  select * into v_round from public.rounds where id=p_round_id;
  if not found then raise exception 'Round not found'; end if;
  if not public.is_tour_organiser(v_round.tour_id) then raise exception 'Only the Tour organiser may validate Round pairings'; end if;

  for v_match in select id, format from public.matches where round_id=p_round_id order by match_number loop
    select count(*),
           count(*) filter (where mp.side='A'),
           count(*) filter (where mp.side='B'),
           count(distinct mp.team_id) filter (where mp.side='A'),
           count(distinct mp.team_id) filter (where mp.side='B')
      into v_total,v_a,v_b,v_team_a,v_team_b
    from public.match_participants mp where mp.match_id=v_match.id;

    if v_match.format='singles' and (v_total<>2 or v_a<>1 or v_b<>1) then
      raise exception 'Singles match % must contain exactly 1 participant per side', v_match.id;
    elsif v_match.format in ('betterball','scramble_drive','alternate_shot')
          and (v_total<>4 or v_a<>2 or v_b<>2) then
      raise exception 'Pair-format match % must contain exactly 2 participants per side', v_match.id;
    end if;

    if v_team_a<>1 or v_team_b<>1 or exists (
      select 1
      from public.match_participants a
      join public.match_participants b on b.match_id=a.match_id and b.side='B'
      where a.match_id=v_match.id and a.side='A' and a.team_id=b.team_id
    ) then
      raise exception 'Match % sides must represent two different Tour teams', v_match.id;
    end if;

    if exists (
      select 1 from public.match_participants mp
      where mp.match_id=v_match.id
        and not exists (
          select 1 from public.round_players rp
          where rp.round_id=p_round_id and rp.tour_player_id=mp.tour_player_id and rp.active
        )
    ) then
      raise exception 'Match % contains a participant who is not active for the Round', v_match.id;
    end if;
  end loop;
end;
$$;

revoke all on function public.validate_round_pairings(uuid) from public;
grant execute on function public.validate_round_pairings(uuid) to authenticated;

-- Structural readiness only: validates setup but does not freeze or start the Tour.
create or replace function public.validate_tour_ready(p_tour_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_count integer;
  v_player_count integer;
  v_round record;
begin
  if not exists (select 1 from public.tours where id=p_tour_id) then raise exception 'Tour not found'; end if;
  if not public.is_tour_organiser(p_tour_id) then raise exception 'Only the Tour organiser may validate Tour readiness'; end if;

  select count(*) into v_team_count from public.teams where tour_id=p_tour_id;
  if v_team_count<>2 then raise exception 'Tour must have exactly two teams'; end if;

  select count(*) into v_player_count from public.tour_players where tour_id=p_tour_id and status<>'withdrawn';
  if v_player_count<2 or mod(v_player_count,2)<>0 then raise exception 'Tour must have an even number of at least two non-withdrawn players'; end if;

  if exists (select 1 from public.tour_players where tour_id=p_tour_id and status<>'withdrawn' and handicap_index is null) then
    raise exception 'Every non-withdrawn Tour player must have a Handicap Index';
  end if;

  if not exists (select 1 from public.rounds where tour_id=p_tour_id) then raise exception 'Tour must have at least one Round'; end if;

  for v_round in select id, course_id, course_tee_id from public.rounds where tour_id=p_tour_id order by round_number loop
    if not exists (select 1 from public.course_tees ct where ct.id=v_round.course_tee_id and ct.course_id=v_round.course_id) then
      raise exception 'Round % tee must belong to selected course', v_round.id;
    end if;
    if (select count(*) from public.course_holes ch where ch.course_tee_id=v_round.course_tee_id)<>18
       or (select count(distinct ch.hole_number) from public.course_holes ch where ch.course_tee_id=v_round.course_tee_id)<>18
       or (select count(distinct ch.stroke_index) from public.course_holes ch where ch.course_tee_id=v_round.course_tee_id)<>18 then
      raise exception 'Round % selected tee is not scoring-ready', v_round.id;
    end if;
    perform public.validate_round_pairings(v_round.id);
  end loop;
end;
$$;

revoke all on function public.validate_tour_ready(uuid) from public;
grant execute on function public.validate_tour_ready(uuid) to authenticated;
