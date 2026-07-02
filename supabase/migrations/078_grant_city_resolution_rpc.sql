-- Allow authenticated onboarding/profile writes to resolve selected cities.
-- Basic Identity references profiles.city_id and profiles.country_code by FK,
-- so the client must be able to call this SECURITY DEFINER resolver before
-- writing the profile row.

GRANT EXECUTE ON FUNCTION public.get_or_create_city(
  character varying,
  character varying,
  character varying,
  character varying,
  numeric,
  numeric
) TO authenticated;
