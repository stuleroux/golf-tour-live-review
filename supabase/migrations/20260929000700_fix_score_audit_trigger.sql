create or replace function public.audit_score_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  match_id_value uuid;
  entity_uuid uuid;
begin
  if tg_op = 'DELETE' then
    match_id_value := old.match_id;
  else
    match_id_value := new.match_id;
  end if;

  if tg_table_name = 'match_confirmations' then
    if tg_op = 'DELETE' then
      entity_uuid := old.match_id;
    else
      entity_uuid := new.match_id;
    end if;
  else
    if tg_op = 'DELETE' then
      entity_uuid := old.id;
    else
      entity_uuid := new.id;
    end if;
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
    public.tour_for_match(match_id_value),
    auth.uid(),
    tg_table_name,
    entity_uuid,
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
