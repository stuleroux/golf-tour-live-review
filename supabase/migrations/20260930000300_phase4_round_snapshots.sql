-- Phase 4: immutable Round course/hole snapshots.

create table if not exists public.round_course_snapshot (
  round_id uuid primary key references public.rounds(id) on delete cascade,
  source_course_id uuid not null,
  source_course_tee_id uuid not null,
  course_name text not null,
  tee_name text not null,
  gender_rating text,
  course_rating numeric not null,
  slope_rating integer not null check (slope_rating between 55 and 155),
  par integer not null check (par between 27 and 90),
  created_at timestamptz not null default now()
);

create table if not exists public.round_hole_snapshot (
  round_id uuid not null references public.rounds(id) on delete cascade,
  hole_number integer not null check (hole_number between 1 and 18),
  par integer not null check (par between 3 and 6),
  stroke_index integer not null check (stroke_index between 1 and 18),
  metres integer check (metres is null or metres > 0),
  primary key (round_id, hole_number),
  unique (round_id, stroke_index)
);

create index if not exists round_course_snapshot_source_tee_idx
  on public.round_course_snapshot(source_course_tee_id);

alter table public.round_course_snapshot enable row level security;
alter table public.round_hole_snapshot enable row level security;

create policy round_course_snapshot_read on public.round_course_snapshot
for select to authenticated
using (exists (
  select 1 from public.rounds r
  where r.id = round_course_snapshot.round_id
    and public.can_read_tour(r.tour_id)
));

create policy round_course_snapshot_public_read on public.round_course_snapshot
for select to anon
using (exists (
  select 1 from public.rounds r
  join public.tours t on t.id = r.tour_id
  where r.id = round_course_snapshot.round_id
    and t.spectator_enabled
));

create policy round_hole_snapshot_read on public.round_hole_snapshot
for select to authenticated
using (exists (
  select 1 from public.rounds r
  where r.id = round_hole_snapshot.round_id
    and public.can_read_tour(r.tour_id)
));

create policy round_hole_snapshot_public_read on public.round_hole_snapshot
for select to anon
using (exists (
  select 1 from public.rounds r
  join public.tours t on t.id = r.tour_id
  where r.id = round_hole_snapshot.round_id
    and t.spectator_enabled
));

-- No direct INSERT/UPDATE/DELETE policies for application roles.
-- Snapshot creation is controlled by this SECURITY DEFINER function.
create or replace function public.snapshot_round_course(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.rounds%rowtype;
  v_course public.courses%rowtype;
  v_tee public.course_tees%rowtype;
  v_hole_count integer;
  v_hole_number_count integer;
  v_si_count integer;
begin
  select * into v_round from public.rounds where id = p_round_id for update;
  if not found then raise exception 'Round not found'; end if;
  if not public.is_tour_organiser(v_round.tour_id) then raise exception 'Only the Tour organiser may snapshot Round course data'; end if;
  if exists (select 1 from public.round_course_snapshot where round_id = p_round_id) then
    raise exception 'Round course snapshot already exists';
  end if;

  select * into v_course from public.courses where id = v_round.course_id;
  if not found then raise exception 'Selected course not found'; end if;

  select * into v_tee from public.course_tees
  where id = v_round.course_tee_id and course_id = v_round.course_id;
  if not found then raise exception 'Round tee must belong to selected course'; end if;

  select count(*), count(distinct hole_number), count(distinct stroke_index)
    into v_hole_count, v_hole_number_count, v_si_count
  from public.course_holes
  where course_tee_id = v_round.course_tee_id;

  if v_hole_count <> 18 or v_hole_number_count <> 18 or v_si_count <> 18 then
    raise exception 'Selected tee must have exactly 18 holes and unique hole numbers/Stroke Indexes 1-18';
  end if;
  if exists (select 1 from public.course_holes where course_tee_id=v_round.course_tee_id and (hole_number not between 1 and 18 or stroke_index not between 1 and 18 or par not between 3 and 6)) then
    raise exception 'Selected tee contains invalid hole data';
  end if;

  insert into public.round_course_snapshot (
    round_id, source_course_id, source_course_tee_id, course_name, tee_name,
    gender_rating, course_rating, slope_rating, par
  ) values (
    p_round_id, v_course.id, v_tee.id, v_course.name, v_tee.tee_name,
    v_tee.gender_rating, v_tee.course_rating, v_tee.slope_rating, v_tee.par
  );

  insert into public.round_hole_snapshot (round_id, hole_number, par, stroke_index, metres)
  select p_round_id, hole_number, par, stroke_index, metres
  from public.course_holes
  where course_tee_id = v_round.course_tee_id
  order by hole_number;
end;
$$;

revoke all on function public.snapshot_round_course(uuid) from public;
grant execute on function public.snapshot_round_course(uuid) to authenticated;

grant select on public.round_course_snapshot, public.round_hole_snapshot to authenticated, anon;
-- service_role access for controlled tests/admin operations.
grant select, insert, update on public.round_course_snapshot, public.round_hole_snapshot to service_role;
