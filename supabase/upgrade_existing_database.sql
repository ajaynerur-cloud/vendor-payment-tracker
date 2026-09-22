-- VendorPay additive multi-user upgrade
-- Designed to preserve the existing public.payments table and all rows.
-- Run once in Supabase SQL Editor. Do not run the earlier fresh-project replacement schema.

begin;
create extension if not exists pgcrypto;

create table if not exists public.vp_workspaces(
 id uuid primary key default gen_random_uuid(),
 name text not null,
 owner_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now()
);
create table if not exists public.vp_members(
 workspace_id uuid not null references public.vp_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check(role in('owner','admin','editor','viewer')),
 created_at timestamptz not null default now(),
 primary key(workspace_id,user_id)
);
create table if not exists public.vp_invitations(
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.vp_workspaces(id) on delete cascade,
 email text not null,
 role text not null check(role in('admin','editor','viewer')),
 status text not null default 'pending' check(status in('pending','accepted','revoked')),
 invited_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 unique(workspace_id,email)
);

alter table public.payments add column if not exists workspace_id uuid references public.vp_workspaces(id) on delete cascade;

-- Create one personal workspace per existing payment owner, then attach existing rows.
insert into public.vp_workspaces(name,owner_id)
select coalesce(nullif(split_part(u.email,'@',1),''),'Personal')||'''s Payments', p.user_id
from (select distinct user_id from public.payments where user_id is not null) p
join auth.users u on u.id=p.user_id
where not exists(select 1 from public.vp_workspaces w where w.owner_id=p.user_id);

insert into public.vp_members(workspace_id,user_id,role)
select w.id,w.owner_id,'owner' from public.vp_workspaces w
on conflict(workspace_id,user_id) do nothing;

update public.payments p set workspace_id=w.id
from public.vp_workspaces w
where p.workspace_id is null and w.owner_id=p.user_id;

create index if not exists vp_payments_workspace_idx on public.payments(workspace_id,payment_date desc);
create index if not exists vp_invitation_email_idx on public.vp_invitations(lower(email),status);

create or replace function public.vp_has_role(p_workspace uuid,p_roles text[])
returns boolean language sql stable security definer set search_path=public
as $$select exists(select 1 from vp_members where workspace_id=p_workspace and user_id=auth.uid() and role=any(p_roles))$$;

create or replace function public.vp_get_context()
returns jsonb language plpgsql stable security definer set search_path=public,auth
as $$declare r record;begin
 select w.id,w.name,m.role into r from vp_members m join vp_workspaces w on w.id=m.workspace_id where m.user_id=auth.uid() order by m.created_at limit 1;
 if found then return jsonb_build_object('workspace_id',r.id,'workspace_name',r.name,'role',r.role);end if;
 return null;
end$$;

create or replace function public.vp_invite_user(p_email text,p_role text)
returns uuid language plpgsql security definer set search_path=public
as $$declare w uuid;i uuid;begin
 if p_role not in('admin','editor','viewer') then raise exception 'Invalid role';end if;
 select workspace_id into w from vp_members where user_id=auth.uid() and role in('owner','admin') order by created_at limit 1;
 if w is null then raise exception 'Not authorized';end if;
 insert into vp_invitations(workspace_id,email,role,invited_by) values(w,lower(trim(p_email)),p_role,auth.uid())
 on conflict(workspace_id,email) do update set role=excluded.role,status='pending',invited_by=auth.uid(),created_at=now() returning id into i;
 return i;
end$$;

create or replace function public.vp_my_pending_invitations()
returns jsonb language sql stable security definer set search_path=public,auth
as $$select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'workspace_name',w.name,'role',i.role)),'[]'::jsonb)
from vp_invitations i join vp_workspaces w on w.id=i.workspace_id
where lower(i.email)=lower(coalesce(auth.jwt()->>'email','')) and i.status='pending'$$;

create or replace function public.vp_accept_invitation(p_invitation uuid)
returns void language plpgsql security definer set search_path=public,auth
as $$declare i vp_invitations;begin
 select * into i from vp_invitations where id=p_invitation and lower(email)=lower(coalesce(auth.jwt()->>'email','')) and status='pending' for update;
 if not found then raise exception 'Invitation not found for this email';end if;
 insert into vp_members(workspace_id,user_id,role) values(i.workspace_id,auth.uid(),i.role) on conflict(workspace_id,user_id) do update set role=excluded.role;
 update vp_invitations set status='accepted' where id=i.id;
end$$;

create or replace function public.vp_admin_list()
returns jsonb language plpgsql stable security definer set search_path=public,auth
as $$declare w uuid;result jsonb;begin
 select workspace_id into w from vp_members where user_id=auth.uid() and role in('owner','admin') order by created_at limit 1;
 if w is null then raise exception 'Not authorized';end if;
 select jsonb_build_object(
  'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'email',u.email,'role',m.role)),'[]'::jsonb) from vp_members m join auth.users u on u.id=m.user_id where m.workspace_id=w),
  'invitations',(select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'role',i.role,'status',i.status)),'[]'::jsonb) from vp_invitations i where i.workspace_id=w)
 ) into result;return result;
end$$;

create or replace function public.vp_change_role(p_user uuid,p_role text)
returns void language plpgsql security definer set search_path=public
as $$declare w uuid;begin
 if p_role not in('admin','editor','viewer') then raise exception 'Invalid role';end if;
 select workspace_id into w from vp_members where user_id=auth.uid() and role in('owner','admin') order by created_at limit 1;
 update vp_members set role=p_role where workspace_id=w and user_id=p_user and role<>'owner';
end$$;
create or replace function public.vp_remove_member(p_user uuid)
returns void language plpgsql security definer set search_path=public
as $$declare w uuid;begin select workspace_id into w from vp_members where user_id=auth.uid() and role in('owner','admin') order by created_at limit 1;delete from vp_members where workspace_id=w and user_id=p_user and role<>'owner';end$$;
create or replace function public.vp_revoke_invitation(p_invitation uuid)
returns void language plpgsql security definer set search_path=public
as $$declare w uuid;begin select workspace_id into w from vp_members where user_id=auth.uid() and role in('owner','admin') order by created_at limit 1;update vp_invitations set status='revoked' where id=p_invitation and workspace_id=w;end$$;

-- Replace only policies on payments. No payment rows are deleted or recreated.
alter table public.payments enable row level security;
drop policy if exists "Users read own payments" on public.payments;
drop policy if exists "Users insert own payments" on public.payments;
drop policy if exists "Users update own payments" on public.payments;
drop policy if exists "Users delete own payments" on public.payments;
drop policy if exists vp_payment_select on public.payments;
drop policy if exists vp_payment_insert on public.payments;
drop policy if exists vp_payment_update on public.payments;
drop policy if exists vp_payment_delete on public.payments;
create policy vp_payment_select on public.payments for select using(user_id=auth.uid() or vp_has_role(workspace_id,array['owner','admin','editor','viewer']));
create policy vp_payment_insert on public.payments for insert with check(user_id=auth.uid() and (workspace_id is null or vp_has_role(workspace_id,array['owner','admin','editor'])));
create policy vp_payment_update on public.payments for update using(user_id=auth.uid() or vp_has_role(workspace_id,array['owner','admin','editor'])) with check(vp_has_role(workspace_id,array['owner','admin','editor']) or user_id=auth.uid());
create policy vp_payment_delete on public.payments for delete using(user_id=auth.uid() or vp_has_role(workspace_id,array['owner','admin','editor']));

alter table public.vp_workspaces enable row level security;alter table public.vp_members enable row level security;alter table public.vp_invitations enable row level security;
drop policy if exists vp_workspace_read on public.vp_workspaces;create policy vp_workspace_read on public.vp_workspaces for select using(vp_has_role(id,array['owner','admin','editor','viewer']));
drop policy if exists vp_member_read on public.vp_members;create policy vp_member_read on public.vp_members for select using(user_id=auth.uid() or vp_has_role(workspace_id,array['owner','admin']));
drop policy if exists vp_invite_read on public.vp_invitations;create policy vp_invite_read on public.vp_invitations for select using(lower(email)=lower(coalesce(auth.jwt()->>'email','')) or vp_has_role(workspace_id,array['owner','admin']));

grant execute on function public.vp_get_context() to authenticated;grant execute on function public.vp_invite_user(text,text) to authenticated;grant execute on function public.vp_my_pending_invitations() to authenticated;grant execute on function public.vp_accept_invitation(uuid) to authenticated;grant execute on function public.vp_admin_list() to authenticated;grant execute on function public.vp_change_role(uuid,text) to authenticated;grant execute on function public.vp_remove_member(uuid) to authenticated;grant execute on function public.vp_revoke_invitation(uuid) to authenticated;
commit;
