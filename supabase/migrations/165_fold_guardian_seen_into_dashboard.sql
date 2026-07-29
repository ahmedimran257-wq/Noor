-- Reading the dashboard and acknowledging a ward's unread messages belong to
-- one checked operation. Keep the old worker implementations internal and
-- expose only the auth-bound projection with an optional acknowledgement.

CREATE OR REPLACE FUNCTION public.get_guardian_dashboard(
  p_mark_seen_ward_id uuid DEFAULT NULL
)
RETURNS TABLE(
  ward_name text,
  ward_profile_id uuid,
  ward_user_id uuid,
  match_id uuid,
  other_party_name text,
  other_party_photo text,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint,
  guardian_mode text,
  match_status text,
  guardian_approved boolean,
  match_created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
BEGIN
  IF p_mark_seen_ward_id IS NOT NULL
    AND NOT public.is_current_guardian_for_ward(
      p_mark_seen_ward_id,
      NULL
    ) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;

  -- Materialize the unread counts before advancing last_seen.
  RETURN QUERY
  SELECT dashboard.*
  FROM public.get_guardian_dashboard() dashboard;

  IF p_mark_seen_ward_id IS NOT NULL THEN
    INSERT INTO public.guardian_sessions(
      guardian_id, ward_id, last_seen_at, is_active
    )
    VALUES (v_guardian_id, p_mark_seen_ward_id, now(), true)
    ON CONFLICT (guardian_id, ward_id) DO UPDATE
    SET last_seen_at = EXCLUDED.last_seen_at,
        is_active = true;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_guardian_dashboard()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_guardian_dashboard(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_guardian_dashboard(uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.update_guardian_last_seen(uuid)
  FROM PUBLIC, anon, authenticated;
