-- 003_driver_delivery_otp_and_documents.sql
-- Supports driver-side camera document uploads and receiver OTP delivery completion.
-- Run in the Supabase SQL editor as project owner.

grant select, update on public.shipments to authenticated;
grant insert on public.shipment_status_updates to authenticated;
grant select, insert, update on public.delivery_sessions to authenticated;
grant select, update on public.drivers to authenticated;

alter table public.drivers
  add column if not exists profile_last_edited_at timestamptz;

create or replace function public.enforce_driver_profile_edit_window()
returns trigger
language plpgsql
as $$
begin
  if (
    old.full_name is distinct from new.full_name
    or old.phone is distinct from new.phone
    or old.age is distinct from new.age
  ) then
    if old.profile_last_edited_at is not null
       and old.profile_last_edited_at > now() - interval '24 hours' then
      raise exception 'Driver profile can only be edited once every 24 hours.';
    end if;
    new.profile_last_edited_at = now();
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_driver_profile_edit_window on public.drivers;
create trigger enforce_driver_profile_edit_window
  before update on public.drivers
  for each row
  execute function public.enforce_driver_profile_edit_window();

alter table public.delivery_sessions enable row level security;

drop policy if exists delivery_sessions_driver_select_own on public.delivery_sessions;
create policy delivery_sessions_driver_select_own
  on public.delivery_sessions
  for select
  to authenticated
  using (driver_id = auth.uid());

drop policy if exists delivery_sessions_driver_insert_own on public.delivery_sessions;
create policy delivery_sessions_driver_insert_own
  on public.delivery_sessions
  for insert
  to authenticated
  with check (driver_id = auth.uid());

drop policy if exists delivery_sessions_driver_update_own on public.delivery_sessions;
create policy delivery_sessions_driver_update_own
  on public.delivery_sessions
  for update
  to authenticated
  using (driver_id = auth.uid())
  with check (driver_id = auth.uid());

drop policy if exists shipments_driver_update_assigned on public.shipments;
create policy shipments_driver_update_assigned
  on public.shipments
  for update
  to authenticated
  using (driver_id = auth.uid())
  with check (driver_id = auth.uid());

drop policy if exists shipment_status_updates_driver_insert on public.shipment_status_updates;
create policy shipment_status_updates_driver_insert
  on public.shipment_status_updates
  for insert
  to authenticated
  with check (updated_by = auth.uid());

drop policy if exists drivers_update_own_with_daily_profile_edit on public.drivers;
create policy drivers_update_own_with_daily_profile_edit
  on public.drivers
  for update
  to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and (
      profile_last_edited_at is null
      or profile_last_edited_at <= now()
      or profile_last_edited_at >= now() - interval '1 minute'
    )
  );

insert into storage.buckets (id, name, public)
values ('driver_documents', 'driver_documents', true)
on conflict (id) do nothing;

drop policy if exists driver_documents_upload_own_folder on storage.objects;
create policy driver_documents_upload_own_folder
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'driver_documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists driver_documents_read_public on storage.objects;
create policy driver_documents_read_public
  on storage.objects
  for select
  to public
  using (bucket_id = 'driver_documents');
