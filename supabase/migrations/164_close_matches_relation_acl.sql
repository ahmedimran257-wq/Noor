-- Member and guardian match reads use checked RPC projections. The obsolete
-- direct guardian join was removed from the app, so the base relation no
-- longer needs to be exposed through the Data API.
REVOKE SELECT ON TABLE public.matches
  FROM PUBLIC, anon, authenticated;
