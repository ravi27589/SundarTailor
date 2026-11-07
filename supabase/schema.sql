-- Run once in a new Supabase project's SQL editor.
begin;

create sequence public.sync_version_seq;

create table public.customers (
  shop_id uuid not null references auth.users(id),
  id uuid not null,
  customer_number text not null,
  name text not null,
  phone text not null,
  shirt_measurements jsonb not null default '{}',
  trouser_measurements jsonb not null default '{}',
  pajama_measurements jsonb not null default '{}',
  suit_measurements jsonb not null default '{}',
  shorts_measurements jsonb not null default '{}',
  kurta_measurements jsonb not null default '{}',
  safari_measurements jsonb not null default '{}',
  notes text not null default '',
  created_date timestamptz not null,
  updated_date timestamptz not null,
  deleted_date timestamptz,
  sync_version bigint not null,
  primary key (shop_id, id),
  unique (shop_id, customer_number)
);

create table public.orders (
  shop_id uuid not null references auth.users(id),
  id uuid not null,
  order_number text not null,
  customer_id uuid not null,
  booking_date timestamptz not null,
  delivery_date timestamptz not null,
  order_details text not null,
  comments text not null default '',
  quantity integer not null check (quantity > 0),
  amount double precision not null,
  advance_paid double precision not null,
  status text not null check (status in (
    'booked', 'drying', 'cutting', 'stitching', 'finishing', 'ironing',
    'trial', 'ready', 'delivered', 'cancelled'
  )),
  created_date timestamptz not null,
  updated_date timestamptz not null,
  deleted_date timestamptz,
  sync_version bigint not null,
  primary key (shop_id, id),
  unique (shop_id, order_number),
  foreign key (shop_id, customer_id) references public.customers(shop_id, id)
);

create table public.sync_devices (
  shop_id uuid not null references auth.users(id),
  id uuid not null,
  device_number integer not null check (device_number between 1 and 46655),
  primary key (shop_id, id),
  unique (shop_id, device_number)
);

create index customers_sync on public.customers(shop_id, sync_version);
create index orders_sync on public.orders(shop_id, sync_version);
create index orders_customer on public.orders(shop_id, customer_id);
create index orders_delivery on public.orders(shop_id, delivery_date);
create index orders_status on public.orders(shop_id, status);

alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.sync_devices enable row level security;

create policy shop_customers on public.customers
  for select to authenticated using (shop_id = (select auth.uid()));
create policy shop_orders on public.orders
  for select to authenticated using (shop_id = (select auth.uid()));

revoke all on public.customers, public.orders, public.sync_devices
  from anon, authenticated;
grant select on public.customers, public.orders to authenticated;
revoke all on sequence public.sync_version_seq from public, anon, authenticated;

-- Serialize version allocation through commit, so incremental pulls cannot skip
-- an earlier version whose writing transaction has not committed yet.
create function public.stamp_sync_version() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(72841926);
  new.sync_version := pg_catalog.nextval('public.sync_version_seq');
  return new;
end;
$$;

create trigger customers_sync_version before insert or update on public.customers
  for each row execute function public.stamp_sync_version();
create trigger orders_sync_version before insert or update on public.orders
  for each row execute function public.stamp_sync_version();

create function public.register_sync_device(device_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  shop uuid := auth.uid();
  n integer;
  alphabet constant text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
begin
  if shop is null then raise exception 'Sign in before syncing'; end if;
  if device_id is null then raise exception 'Device ID is required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(72841926);
  select device_number into n from public.sync_devices
    where shop_id = shop and id = device_id;
  if n is null then
    select coalesce(max(device_number), 0) + 1 into n
      from public.sync_devices where shop_id = shop;
    insert into public.sync_devices values (shop, device_id, n);
  end if;
  return substr(alphabet, n / 1296 + 1, 1)
    || substr(alphabet, (n / 36) % 36 + 1, 1)
    || substr(alphabet, n % 36 + 1, 1);
end;
$$;

create function public.sync_upsert_customer(payload jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  shop uuid := auth.uid();
  row_data public.customers;
begin
  if shop is null then raise exception 'Sign in before syncing'; end if;
  perform pg_catalog.pg_advisory_xact_lock(72841926);
  row_data := jsonb_populate_record(
    null::public.customers,
    payload || jsonb_build_object('shop_id', shop, 'sync_version', null)
  );
  insert into public.customers as existing select (row_data).*
  on conflict (shop_id, id) do update set
    customer_number = excluded.customer_number,
    name = excluded.name,
    phone = excluded.phone,
    shirt_measurements = excluded.shirt_measurements,
    trouser_measurements = excluded.trouser_measurements,
    pajama_measurements = excluded.pajama_measurements,
    suit_measurements = excluded.suit_measurements,
    shorts_measurements = excluded.shorts_measurements,
    kurta_measurements = excluded.kurta_measurements,
    safari_measurements = excluded.safari_measurements,
    notes = excluded.notes,
    created_date = excluded.created_date,
    updated_date = excluded.updated_date,
    deleted_date = excluded.deleted_date
  where existing.updated_date <= excluded.updated_date;
end;
$$;

create function public.sync_upsert_order(payload jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  shop uuid := auth.uid();
  row_data public.orders;
begin
  if shop is null then raise exception 'Sign in before syncing'; end if;
  perform pg_catalog.pg_advisory_xact_lock(72841926);
  row_data := jsonb_populate_record(
    null::public.orders,
    payload || jsonb_build_object('shop_id', shop, 'sync_version', null)
  );
  insert into public.orders as existing select (row_data).*
  on conflict (shop_id, id) do update set
    order_number = excluded.order_number,
    customer_id = excluded.customer_id,
    booking_date = excluded.booking_date,
    delivery_date = excluded.delivery_date,
    order_details = excluded.order_details,
    comments = excluded.comments,
    quantity = excluded.quantity,
    amount = excluded.amount,
    advance_paid = excluded.advance_paid,
    status = excluded.status,
    created_date = excluded.created_date,
    updated_date = excluded.updated_date,
    deleted_date = excluded.deleted_date
  where existing.updated_date <= excluded.updated_date;
end;
$$;

revoke all on function public.stamp_sync_version() from public, anon, authenticated;
revoke all on function public.register_sync_device(uuid) from public, anon;
revoke all on function public.sync_upsert_customer(jsonb) from public, anon;
revoke all on function public.sync_upsert_order(jsonb) from public, anon;
grant execute on function public.register_sync_device(uuid) to authenticated;
grant execute on function public.sync_upsert_customer(jsonb) to authenticated;
grant execute on function public.sync_upsert_order(jsonb) to authenticated;

commit;
