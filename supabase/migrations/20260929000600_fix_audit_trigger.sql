create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tour uuid;
  v_entity_id uuid;
begin
  if tg_table_name = 'tours' then
    if tg_op = 'DELETE' then
      v_tour := old.id;
      v_entity_id := old.id;
    else
      v_tour := new.id;
      v_entity_id := new.id;
    end if;

  elsif tg_table_name = 'teams' then
    if tg_op = 'DELETE' then
      v_tour := old.tour_id;
      v_entity_id := old.id;
    else
      v_tour := new.tour_id;
      v_entity_id := new.id;
    end if;

  elsif tg_table_name = 'tour_players' then
    if tg_op = 'DELETE' then
      v_tour := old.tour_id;
      v_entity_id := old.id;
    else
      v_tour := new.tour_id;
      v_entity_id := new.id;
    end if;

  elsif tg_table_name = 'rounds' then
    if tg_op = 'DELETE' then
      v_tour := old.tour_id;
      v_entity_id := old.id;
    else
      v_tour := new.tour_id;
      v_entity_id := new.id;
    end if;

  else
    raise exception 'Unsupported audit table: %', tg_table_name;
  end if;

  insert into public.audit_log (
    tour_id,
    actor_user_id,
    entity_type,
    entity_id,
    action,
    old_data,
    new_data
  )
  values (
    v_tour,
    auth.uid(),
    tg_table_name,
    v_entity_id,
    tg_op,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;
