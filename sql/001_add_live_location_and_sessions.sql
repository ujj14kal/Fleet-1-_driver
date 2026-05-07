-- 001_add_live_location_and_sessions.sql
-- Adds tables and helper functions to support live driver location sharing
-- Run this in the Supabase SQL editor or via a service-role connection.

-- 1) Make sure pgcrypto is available for UUID generation
create extension if not exists pgcrypto;

-- 2) Transporter companies (optional, additive)
create table if not exists transporter_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact jsonb,
  created_at timestamptz default now()
);

-- 3) Driver locations (append-only time series of geo points)
create table if not exists driver_locations (
  id bigserial primary key,
  driver_id uuid not null,
  latitude double precision not null,
  longitude double precision not null,
  heading double precision,
  speed double precision,
  recorded_at timestamptz default now(),
  is_active boolean default true
);
create index if not exists idx_driver_locations_driver_time on driver_locations(driver_id, recorded_at desc);

-- 4) Delivery sessions: represents an active delivery/ride that can be shared
create table if not exists delivery_sessions (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid references shipments(id),
  driver_id uuid references drivers(id),
  receiver_phone text,
  otp text,
  otp_required boolean default true,
  started_at timestamptz,
  completed_at timestamptz,
  is_active boolean default true,
  created_at timestamptz default now()
);
create index if not exists idx_delivery_sessions_shipment on delivery_sessions(shipment_id);

-- 5) Convenience view to join shipment_assignments -> shipments (if those tables exist)
create or replace view driver_assignments_view as
select
  sa.*,
  s.id as shipment_id,
  s.tracking_number,
  s.pickup_location,
  s.drop_location,
  s.transporter_company_id
from
  shipment_assignments sa
left join shipments s on s.id = sa.shipment_id;

-- 6) Haversine distance helper (returns kilometers)
create or replace function haversine_km(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(least(1, pow(sin(radians(($1-$3)/2)),2) + cos(radians($1))*cos(radians($3))*pow(sin(radians(($2-$4)/2)),2))));
$$;

-- 7) RPC: get live locations for a receiver phone + otp (security definer)
-- This returns recent location points for drivers associated with active sessions
-- Call via PostgREST RPC: rpc_get_live_locations_by_phone?p_receiver_phone=...&p_otp=...
create or replace function rpc_get_live_locations_by_phone(p_receiver_phone text, p_otp text)
returns table(
  driver_id uuid,
  latitude double precision,
  longitude double precision,
  recorded_at timestamptz,
  shipment_id uuid
)
language sql
stable
security definer
as $$
  select dl.driver_id, dl.latitude, dl.longitude, dl.recorded_at, ds.shipment_id
  from driver_locations dl
  join delivery_sessions ds on ds.driver_id = dl.driver_id
  where ds.receiver_phone = p_receiver_phone
    and ds.is_active = true
    and (ds.otp_required = false or ds.otp = p_otp)
  order by dl.recorded_at desc;
$$;

-- 8) Notes / recommendations (do not run automatically):
-- - The RPC is declared SECURITY DEFINER so that callers who know the receiver phone + OTP
--   can read location points without needing additional DB privileges. Review and restrict
--   the function's behavior in your environment if necessary.
-- - Consider adding Row Level Security (RLS) policies for `driver_locations` and
--   `delivery_sessions` to restrict inserts/selects to authenticated drivers or
--   authorized viewers. RLS policies typically require knowledge of how you map
--   auth users to `profiles` (phone numbers, roles). Example RLS snippets are provided
--   below for guidance (commented out):

/*
-- Example RLS (guidance only):
alter table driver_locations enable row level security;
create policy insert_own_location on driver_locations for insert using (auth.uid() = driver_id) with check (auth.uid() = driver_id);
create policy select_driver_locations on driver_locations for select using (
  exists (select 1 from delivery_sessions ds where ds.driver_id = driver_locations.driver_id and ds.is_active = true and (ds.receiver_phone = (select phone from profiles where id = auth.uid()) or auth.role = 'manufacturer'))
);

alter table delivery_sessions enable row level security;
create policy insert_session on delivery_sessions for insert using (auth.role = 'manufacturer');
create policy select_session on delivery_sessions for select using (auth.uid() = driver_id or auth.role = 'manufacturer');
*/

-- End of migration
