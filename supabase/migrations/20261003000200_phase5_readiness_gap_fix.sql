-- Phase 5A follow-up: close readiness gaps discovered by hosted behavioural testing.
-- A Round is not setup-ready without active Round players and at least one match.

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
  v_active_round_players integer;
  v_match_count integer;
begin
  if not exists (select 1 from public.tours where id=p_tour_id) then
    raise exception 'Tour not found';
  end if;
  if not public.is_tour_organiser(p_tour_id) then
    raise exception 'Only the Tour organiser may validate Tour readiness';
  end if;

  select count(*) into v_team_count from public.teams where tour_id=p_tour_id;
  if v_team_count<>2 then
    raise exception 'Tour must have exactly two teams';
  end if;

  select count(*) into v_player_count
  from public.tour_players
  where tour_id=p_tour_id and status<>'withdrawn';
  if v_player_count<2 or mod(v_player_count,2)<>0 then
    raise exception 'Tour must have an even number of at least two non-withdrawn players';
  end if;

  if exists (
    select 1 from public.tour_players
    where tour_id=p_tour_id
      and status<>'withdrawn'
      and handicap_index is null
  ) then
    raise exception 'Every non-withdrawn Tour player must have a Handicap Index';
  end if;

  if not exists (select 1 from public.rounds where tour_id=p_tour_id) then
    raise exception 'Tour must have at least one Round';
  end if;

  for v_round in
    select id, course_id, course_tee_id
    from public.rounds
    where tour_id=p_tour_id
    order by round_number
  loop
    if not exists (
      select 1 from public.course_tees ct
      where ct.id=v_round.course_tee_id and ct.course_id=v_round.course_id
    ) then
      raise exception 'Round % tee must belong to selected course', v_round.id;
    end if;

    if (select count(*) from public.course_holes ch where ch.course_tee_id=v_round.course_tee_id)<>18
       or (select count(distinct ch.hole_number) from public.course_holes ch where ch.course_tee_id=v_round.course_tee_id)<>18
       or (select count(distinct ch.stroke_index) from public.course_holes ch where ch.course_tee_id=v_round.course_tee_id)<>18 then
      raise exception 'Round % selected tee is not scoring-ready', v_round.id;
    end if;

    select count(*) into v_active_round_players
    from public.round_players rp
    where rp.round_id=v_round.id and rp.active;
    if v_active_round_players=0 then
      raise exception 'Round % must have active Round players', v_round.id;
    end if;

    select count(*) into v_match_count
    from public.matches m
    where m.round_id=v_round.id;
    if v_match_count=0 then
      raise exception 'Round % must have at least one match', v_round.id;
    end if;

    perform public.validate_round_pairings(v_round.id);
  end loop;
end;
$$;

revoke all on function public.validate_tour_ready(uuid) from public;
grant execute on function public.validate_tour_ready(uuid) to authenticated;
