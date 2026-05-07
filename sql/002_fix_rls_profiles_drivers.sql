-- 002_fix_rls_profiles_drivers.sql
-- Purpose: Enable/repair Row-Level Security policies for `profiles` and `drivers`.
-- Run this in Supabase SQL editor as the project owner (service_role) or ask an admin to run it.

-- === Profiles table policies ===
-- Enable RLS on profiles (no-op if already enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Insert: authenticated users may insert a profile only for themselves
DROP POLICY IF EXISTS insert_own_profile ON public.profiles;
CREATE POLICY insert_own_profile
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (new.id = auth.uid());

-- Update: authenticated users may update only their own profile
DROP POLICY IF EXISTS update_own_profile ON public.profiles;
CREATE POLICY update_own_profile
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (old.id = auth.uid())
  WITH CHECK (new.id = auth.uid());

-- Select: allow authenticated users to read profiles (adjust if you want stricter access)
DROP POLICY IF EXISTS select_profiles_authenticated ON public.profiles;
CREATE POLICY select_profiles_authenticated
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- === Drivers table policies ===
-- Enable RLS on drivers (no-op if already enabled)
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

-- Insert: allow authenticated users to insert driver rows when the row's id
-- or profile_id matches their auth.uid(). Adjust column names if your schema
-- uses different identifiers (e.g., driver_id, user_id).
DROP POLICY IF EXISTS insert_own_driver ON public.drivers;
CREATE POLICY insert_own_driver
  ON public.drivers
  FOR INSERT
  TO authenticated
  WITH CHECK (
    coalesce(new.id::text, '') = auth.uid()
    OR coalesce(new.profile_id::text, '') = auth.uid()
  );

-- Update: allow authenticated users to update driver rows they own
DROP POLICY IF EXISTS update_own_driver ON public.drivers;
CREATE POLICY update_own_driver
  ON public.drivers
  FOR UPDATE
  TO authenticated
  USING (
    coalesce(old.id::text, '') = auth.uid()
    OR coalesce(old.profile_id::text, '') = auth.uid()
  )
  WITH CHECK (
    coalesce(new.id::text, '') = auth.uid()
    OR coalesce(new.profile_id::text, '') = auth.uid()
  );

-- Select: allow authenticated users to select drivers (adjust as needed)
DROP POLICY IF EXISTS select_drivers_authenticated ON public.drivers;
CREATE POLICY select_drivers_authenticated
  ON public.drivers
  FOR SELECT
  TO authenticated
  USING (true);

-- === Notes ===
-- 1) These policies assume `profiles.id` is the authenticated user's UUID (auth.uid()).
-- 2) If your `drivers` table uses a different ownership column name, replace `profile_id` above.
-- 3) Review the SELECT policies: currently they allow authenticated users to read all rows.
--    If you want stricter access, change the USING clause to only allow owned rows.
-- 4) Run the SELECT queries from `pg_policy` to verify what policies are installed after running this.

-- Helpful verification queries (run after applying):
-- List policies:
-- SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expression,
--        pg_get_expr(polwithcheck, polrelid) AS with_check, polroles
-- FROM pg_policy
-- WHERE polrelid IN ('profiles'::regclass, 'drivers'::regclass);

-- Check RLS enabled:
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname IN ('profiles','drivers');
