-- Phase 5C: secure single-claim player invitation lifecycle.
-- Only token hashes enter PostgreSQL. Raw invitation tokens are generated and hashed server-side.

create or replace function public.create_invitation(
  p_tour_player_id uuid,
  p_token_hash text,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tour_id uuid;
  v_invitation_id uuid;
begin
  if p_token_hash is null or length(p_token_hash) < 43 then
    raise exception 'Invitation token hash is invalid';
  end if;
  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'Invitation expiry must be in the future';
  end if;

  select tp.tour_id into v_tour_id
  from public.tour_players tp
  where tp.id = p_tour_player_id;
  if not found then raise exception 'Tour player not found'; end if;
  if not public.is_tour_organiser(v_tour_id) then
    raise exception 'Only the Tour organiser may create invitations';
  end if;
  if exists (select 1 from public.tour_players where id=p_tour_player_id and user_id is not null) then
    raise exception 'Tour player is already claimed';
  end if;

  -- Regeneration semantics: any previous pending invitation becomes unusable.
  update public.invitations
  set status='revoked'
  where tour_player_id=p_tour_player_id and status='pending';

  insert into public.invitations(tour_id,tour_player_id,token_hash,status,expires_at)
  values(v_tour_id,p_tour_player_id,p_token_hash,'pending',p_expires_at)
  returning id into v_invitation_id;

  return v_invitation_id;
end;
$$;

create or replace function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tour_id uuid;
begin
  select i.tour_id into v_tour_id
  from public.invitations i
  where i.id=p_invitation_id;
  if not found then raise exception 'Invitation not found'; end if;
  if not public.is_tour_organiser(v_tour_id) then
    raise exception 'Only the Tour organiser may revoke invitations';
  end if;

  update public.invitations
  set status='revoked'
  where id=p_invitation_id and status='pending';

  if not found then raise exception 'Only pending invitations may be revoked'; end if;
end;
$$;

create or replace function public.claim_invitation(p_token_hash text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_inv public.invitations%rowtype;
  v_existing_user uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then raise exception 'Authentication is required to claim an invitation'; end if;
  if not exists(select 1 from public.profiles where id=v_user_id) then
    raise exception 'Authenticated user profile is required';
  end if;
  if p_token_hash is null or length(p_token_hash) < 43 then
    raise exception 'Invitation token hash is invalid';
  end if;

  select * into v_inv
  from public.invitations
  where token_hash=p_token_hash
  for update;
  if not found then raise exception 'Invitation is invalid'; end if;
  if v_inv.status='revoked' then raise exception 'Invitation has been revoked'; end if;
  if v_inv.status='claimed' then raise exception 'Invitation has already been claimed'; end if;
  if v_inv.status='expired' or (v_inv.expires_at is not null and v_inv.expires_at <= now()) then
    if v_inv.status='pending' then
      update public.invitations set status='expired' where id=v_inv.id;
    end if;
    raise exception 'Invitation has expired';
  end if;
  if v_inv.status<>'pending' then raise exception 'Invitation is not claimable'; end if;

  select tp.user_id into v_existing_user
  from public.tour_players tp
  where tp.id=v_inv.tour_player_id and tp.tour_id=v_inv.tour_id
  for update;
  if not found then raise exception 'Intended Tour player no longer exists'; end if;
  if v_existing_user is not null then raise exception 'Tour player is already claimed'; end if;
  if exists (
    select 1 from public.tour_players tp
    where tp.tour_id=v_inv.tour_id and tp.user_id=v_user_id
  ) then raise exception 'Authenticated user is already attached to this Tour'; end if;

  update public.tour_players
  set user_id=v_user_id,
      status='active'
  where id=v_inv.tour_player_id and tour_id=v_inv.tour_id and user_id is null;
  if not found then raise exception 'Tour player claim failed'; end if;

  update public.invitations
  set status='claimed', claimed_by_user_id=v_user_id, claimed_at=now()
  where id=v_inv.id and status='pending';
  if not found then raise exception 'Invitation claim failed'; end if;

  return v_inv.tour_player_id;
end;
$$;

revoke all on function public.create_invitation(uuid,text,timestamptz) from public;
revoke all on function public.revoke_invitation(uuid) from public;
revoke all on function public.claim_invitation(text) from public;
grant execute on function public.create_invitation(uuid,text,timestamptz) to authenticated;
grant execute on function public.revoke_invitation(uuid) to authenticated;
grant execute on function public.claim_invitation(text) to authenticated;
