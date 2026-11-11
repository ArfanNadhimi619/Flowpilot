-- FlowPilot multi-tenant enterprise schema for Supabase / PostgreSQL
-- Run in Supabase SQL Editor. UUID PKs, FK relationships, timestamps, tenant isolation, and RLS.
create extension if not exists pgcrypto;

create type public.member_role as enum ('owner','admin','operator','viewer');
create type public.order_status as enum ('draft','pending','confirmed','processing','shipped','delivered','cancelled','refunded');
create type public.shipment_status as enum ('label_created','picked_up','in_transit','out_for_delivery','delivered','delayed','exception','returned');
create type public.agent_status as enum ('draft','active','paused','disabled','error');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'viewer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);
create index organization_members_user_idx on public.organization_members(user_id);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  contact_name text,
  email text,
  phone text,
  address jsonb not null default '{}'::jsonb,
  lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
  payment_terms text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);
create index suppliers_org_idx on public.suppliers(organization_id);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_id uuid references public.suppliers(id) on delete set null,
  sku text not null,
  name text not null,
  description text,
  category text,
  unit text not null default 'unit',
  unit_cost numeric(14,2) not null default 0 check (unit_cost >= 0),
  unit_price numeric(14,2) not null default 0 check (unit_price >= 0),
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  reorder_level integer not null default 0 check (reorder_level >= 0),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, sku)
);
create index products_org_name_idx on public.products(organization_id, name);
create index products_supplier_idx on public.products(supplier_id);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  customer_type text not null default 'individual',
  billing_address jsonb not null default '{}'::jsonb,
  shipping_address jsonb not null default '{}'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, email)
);
create index customers_org_name_idx on public.customers(organization_id, name);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete restrict,
  order_number text not null,
  status public.order_status not null default 'pending',
  currency char(3) not null default 'INR',
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  shipping_amount numeric(14,2) not null default 0 check (shipping_amount >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  billing_address jsonb not null default '{}'::jsonb,
  shipping_address jsonb not null default '{}'::jsonb,
  notes text,
  placed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, order_number)
);
create index orders_org_status_idx on public.orders(organization_id, status);
create index orders_customer_idx on public.orders(customer_id);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  line_total numeric(14,2) not null check (line_total >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, product_id)
);
create index order_items_product_idx on public.order_items(product_id);

create table public.shipments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete restrict,
  carrier text,
  tracking_number text,
  status public.shipment_status not null default 'label_created',
  origin jsonb not null default '{}'::jsonb,
  destination jsonb not null default '{}'::jsonb,
  estimated_delivery_at timestamptz,
  shipped_at timestamptz,
  delivered_at timestamptz,
  last_event text,
  last_event_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, tracking_number)
);
create index shipments_org_status_idx on public.shipments(organization_id, status);
create index shipments_order_idx on public.shipments(order_id);

create table public.ai_agents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  agent_type text not null,
  status public.agent_status not null default 'draft',
  model text,
  system_prompt text,
  configuration jsonb not null default '{}'::jsonb,
  last_run_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);
create index ai_agents_org_status_idx on public.ai_agents(organization_id, status);

-- Store a vault/secret-manager reference, NEVER a raw provider API key.
create table public.ai_agent_keys (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  agent_id uuid references public.ai_agents(id) on delete cascade,
  provider text not null,
  key_name text not null,
  secret_ref text not null,
  key_prefix_hint text,
  scopes text[] not null default '{}',
  is_active boolean not null default true,
  expires_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, key_name)
);
create index ai_agent_keys_agent_idx on public.ai_agent_keys(agent_id);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_org_created_idx on public.audit_logs(organization_id, created_at desc);

-- Generic updated_at trigger.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

do $$
declare t text;
begin
  foreach t in array array['organizations','organization_members','suppliers','products','customers','orders','order_items','shipments','ai_agents','ai_agent_keys'] loop
    execute format('create trigger set_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

-- Membership helper: SECURITY DEFINER avoids recursive RLS checks on organization_members.
create or replace function public.is_org_member(target_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.organization_members m
    where m.organization_id = target_org and m.user_id = auth.uid());
$$;
create or replace function public.has_org_role(target_org uuid, allowed public.member_role[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.organization_members m
    where m.organization_id = target_org and m.user_id = auth.uid() and m.role = any(allowed));
$$;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.suppliers enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.shipments enable row level security;
alter table public.ai_agents enable row level security;
alter table public.ai_agent_keys enable row level security;
alter table public.audit_logs enable row level security;

create policy "members can view own organizations" on public.organizations for select using (public.is_org_member(id));
create policy "owners can update organizations" on public.organizations for update using (public.has_org_role(id, array['owner','admin']::public.member_role[])) with check (public.has_org_role(id, array['owner','admin']::public.member_role[]));
create policy "members can view memberships" on public.organization_members for select using (public.is_org_member(organization_id));
create policy "admins manage memberships" on public.organization_members for all using (public.has_org_role(organization_id, array['owner','admin']::public.member_role[])) with check (public.has_org_role(organization_id, array['owner','admin']::public.member_role[]));

-- Operational users can read; owners/admins/operators can write. Viewers are read-only.
do $$
declare t text;
begin
  foreach t in array array['suppliers','products','customers','orders','shipments','ai_agents'] loop
    execute format('create policy %I on public.%I for select using (public.is_org_member(organization_id))', t||'_read_members', t);
    execute format('create policy %I on public.%I for insert with check (public.has_org_role(organization_id, array[''owner'',''admin'',''operator'']::public.member_role[]))', t||'_insert_ops', t);
    execute format('create policy %I on public.%I for update using (public.has_org_role(organization_id, array[''owner'',''admin'',''operator'']::public.member_role[])) with check (public.has_org_role(organization_id, array[''owner'',''admin'',''operator'']::public.member_role[]))', t||'_update_ops', t);
    execute format('create policy %I on public.%I for delete using (public.has_org_role(organization_id, array[''owner'',''admin'']::public.member_role[]))', t||'_delete_admin', t);
  end loop;
end $$;

-- order_items inherit tenant access through their parent order.
create policy "members read order items" on public.order_items for select using (
  exists (select 1 from public.orders o where o.id = order_id and public.is_org_member(o.organization_id)));
create policy "operators manage order items" on public.order_items for all using (
  exists (select 1 from public.orders o where o.id = order_id and public.has_org_role(o.organization_id, array['owner','admin','operator']::public.member_role[])))
with check (
  exists (select 1 from public.orders o where o.id = order_id and public.has_org_role(o.organization_id, array['owner','admin','operator']::public.member_role[])));

-- Secret references are admin-only. No raw key material belongs in this table.
create policy "admins manage agent key references" on public.ai_agent_keys for all
using (public.has_org_role(organization_id, array['owner','admin']::public.member_role[]))
with check (public.has_org_role(organization_id, array['owner','admin']::public.member_role[]));
create policy "admins read audit logs" on public.audit_logs for select
using (public.has_org_role(organization_id, array['owner','admin']::public.member_role[]));
create policy "members create audit logs" on public.audit_logs for insert
with check (public.is_org_member(organization_id) and (actor_user_id is null or actor_user_id = auth.uid()));

-- Relationship summary:
-- organizations 1—N organization_members, products, customers, suppliers, orders, shipments, agents, key refs, audit_logs
-- suppliers 1—N products
-- customers 1—N orders
-- orders 1—N order_items and shipments
-- products 1—N order_items
-- ai_agents 1—N ai_agent_keys
