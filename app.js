-- Esquema inicial de referência para migrar a demonstração para Supabase/PostgreSQL.
create extension if not exists pgcrypto;

create type public.store_kind as enum ('restaurant','snacks');
create type public.order_status as enum ('aguardando_whatsapp','recebido','confirmado','em_preparo','pronto','saiu_para_entrega','entregue','cancelado');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  role text not null default 'customer' check (role in ('customer','admin','operator')),
  created_at timestamptz not null default now()
);

create table public.stores (
  id store_kind primary key,
  label text not null,
  subtitle text,
  status_mode text not null default 'auto' check (status_mode in ('open','closed','auto')),
  schedule jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store store_kind not null references public.stores(id),
  category text not null,
  name text not null,
  description text not null default '',
  price_cents integer not null check (price_cents >= 0),
  old_price_cents integer check (old_price_cents is null or old_price_cents >= 0),
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.option_groups (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  title text not null,
  min_choices integer not null default 0,
  max_choices integer not null default 1,
  position integer not null default 0,
  check (min_choices >= 0 and max_choices >= min_choices)
);

create table public.product_options (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.option_groups(id) on delete cascade,
  label text not null,
  price_cents integer not null default 0 check (price_cents >= 0),
  description text not null default '',
  exclusive boolean not null default false,
  active boolean not null default true,
  position integer not null default 0
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  store store_kind not null references public.stores(id),
  customer_id uuid references public.profiles(id),
  customer_name text not null,
  customer_phone text not null,
  customer_address text,
  fulfillment text not null check (fulfillment in ('pickup','delivery')),
  payment_method text not null,
  status order_status not null default 'aguardando_whatsapp',
  subtotal_cents integer not null,
  delivery_fee_cents integer not null default 0,
  total_cents integer not null,
  idempotency_key text unique not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id),
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price_cents integer not null,
  unit_extras_cents integer not null default 0,
  total_cents integer not null,
  selections jsonb not null default '{}'::jsonb,
  note text not null default ''
);

create table public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status order_status not null,
  actor_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.option_groups enable row level security;
alter table public.product_options enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create policy "public reads active products" on public.products for select using (active = true);
create policy "public reads option groups" on public.option_groups for select using (true);
create policy "public reads active options" on public.product_options for select using (active = true);
create policy "customer reads own orders" on public.orders for select using (auth.uid() = customer_id);
create policy "customer reads own order items" on public.order_items for select using (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid()));

-- Criação de pedidos, cálculo, baixa de estoque e alterações administrativas devem ocorrer
-- em Edge Functions/RPCs protegidas. Não permita que o navegador defina preço ou total.
