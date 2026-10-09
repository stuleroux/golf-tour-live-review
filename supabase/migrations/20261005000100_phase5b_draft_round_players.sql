-- Phase 5B: permit draft Round-player selection before Tour handicap freeze.
-- Golf mathematics remains in the TypeScript domain engine.

alter table public.round_players
  alter column frozen_tour_handicap_index drop not null,
  alter column course_handicap drop not null;

alter table public.round_players
  drop constraint if exists round_players_frozen_hi_pair;
alter table public.round_players
  add constraint round_players_frozen_hi_pair
  check ((frozen_tour_handicap_index is null) = (course_handicap is null));

alter table public.round_players
  drop constraint if exists round_players_course_handicap_range;
alter table public.round_players
  add constraint round_players_course_handicap_range
  check (course_handicap is null or course_handicap between -100 and 100);

-- Prevent ordinary row edits from changing a finalised Round handicap snapshot.
create or replace function public.protect_round_player_handicap_snapshot()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.frozen_tour_handicap_index is not null and (
     new.frozen_tour_handicap_index is distinct from old.frozen_tour_handicap_index
     or new.course_handicap is distinct from old.course_handicap
  ) then
    raise exception 'Round handicap snapshot is immutable once set';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_round_player_handicap_snapshot_before on public.round_players;
create trigger protect_round_player_handicap_snapshot_before
before update on public.round_players
for each row execute function public.protect_round_player_handicap_snapshot();

-- Persistence boundary only. The caller must calculate Course Handicap using the
-- authoritative TypeScript domain function from the frozen HI and Round snapshot.
create or replace function public.finalise_tour_start(
  p_tour_id uuid,
  p_round_handicaps jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tour public.tours%rowtype;
  v_item jsonb;
  v_round_player_id uuid;
  v_tour_player_id uuid;
  v_round_id uuid;
  v_expected_hi numeric;
  v_input_hi numeric;
  v_course_handicap integer;
  v_expected_count integer;
  v_input_count integer;
begin
  select * into v_tour from public.tours where id=p_tour_id for update;
  if not found then raise exception 'Tour not found'; end if;
  if not public.is_tour_organiser(p_tour_id) then raise exception 'Only the Tour organiser may start the Tour'; end if;
  if v_tour.status not in ('draft','published') then raise exception 'Tour must be draft or published to start'; end if;

  perform public.validate_tour_ready(p_tour_id);

  if exists (
    select 1 from public.tour_players
    where tour_id=p_tour_id and status<>'withdrawn' and handicap_index is null
  ) then raise exception 'Every non-withdrawn Tour player must have a Handicap Index'; end if;

  select count(*) into v_expected_count
  from public.round_players rp
  join public.rounds r on r.id=rp.round_id
  where r.tour_id=p_tour_id and rp.active;

  if jsonb_typeof(p_round_handicaps)<>'array' then raise exception 'Round handicap payload must be a JSON array'; end if;
  select jsonb_array_length(p_round_handicaps) into v_input_count;
  if v_input_count<>v_expected_count then raise exception 'Round handicap payload must contain exactly one item per active Round player'; end if;

  if exists (
    select 1 from jsonb_array_elements(p_round_handicaps) e
    group by (e->>'round_player_id')
    having count(*)<>1
  ) then raise exception 'Round handicap payload contains duplicate Round players'; end if;

  -- Freeze Tour HI exactly once from the organiser-entered setup HI.
  update public.tour_players
  set frozen_handicap_index=handicap_index
  where tour_id=p_tour_id and status<>'withdrawn' and frozen_handicap_index is null;

  for v_item in select * from jsonb_array_elements(p_round_handicaps)
  loop
    begin
      v_round_player_id := (v_item->>'round_player_id')::uuid;
      v_input_hi := (v_item->>'frozen_tour_handicap_index')::numeric;
      v_course_handicap := (v_item->>'course_handicap')::integer;
    exception when others then
      raise exception 'Invalid Round handicap payload item';
    end;

    select rp.tour_player_id, rp.round_id, tp.frozen_handicap_index
      into v_tour_player_id, v_round_id, v_expected_hi
    from public.round_players rp
    join public.rounds r on r.id=rp.round_id
    join public.tour_players tp on tp.id=rp.tour_player_id
    where rp.id=v_round_player_id and rp.active and r.tour_id=p_tour_id
    for update of rp;

    if not found then raise exception 'Round handicap payload references an invalid active Round player'; end if;
    if v_input_hi is distinct from v_expected_hi then raise exception 'Round handicap payload frozen HI does not match Tour frozen HI'; end if;
    if v_course_handicap is null then raise exception 'Course Handicap is required'; end if;
    if not exists (select 1 from public.round_course_snapshot where round_id=v_round_id) then
      raise exception 'Round % course snapshot is required before Tour start', v_round_id;
    end if;

    -- UPDATE bypasses application RLS because the controlled function is SECURITY DEFINER.
    update public.round_players
    set frozen_tour_handicap_index=v_expected_hi,
        course_handicap=v_course_handicap
    where id=v_round_player_id;
  end loop;

  if exists (
    select 1 from public.round_players rp
    join public.rounds r on r.id=rp.round_id
    where r.tour_id=p_tour_id and rp.active
      and (rp.frozen_tour_handicap_index is null or rp.course_handicap is null)
  ) then raise exception 'Every active Round player must have a finalised handicap snapshot'; end if;

  update public.tours set status='live', updated_at=now() where id=p_tour_id;
end;
$$;

revoke all on function public.finalise_tour_start(uuid,jsonb) from public;
grant execute on function public.finalise_tour_start(uuid,jsonb) to authenticated;
