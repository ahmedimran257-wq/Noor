-- Silarah — one round trip for a Discovery page and its revision token
--
-- Discovery read the revision token, then requested the feed: two network
-- round trips in series on every cold start and filter change (0.5-1 s each
-- on Indian mobile networks to the Tokyo project). This wrapper does both in
-- one call. The token is read in its own statement before the feed, so under
-- READ COMMITTED it can only be older than the rows: a change that lands in
-- between still makes the next revision check refresh, exactly as before.
--
-- SECURITY INVOKER: both inner functions keep their own auth.uid() checks,
-- entitlement checks and per-call plans (plan_cache_mode on the feed).

CREATE OR REPLACE FUNCTION public.get_discovery_feed_page(
  p_viewer_id uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_page_size integer DEFAULT 20,
  p_filters jsonb DEFAULT '{}'::jsonb,
  p_include_revision boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_token text;
  v_rows jsonb;
BEGIN
  IF p_include_revision THEN
    SELECT revision.revision_token
    INTO v_token
    FROM public.get_my_discovery_revision(coalesce(p_filters, '{}'::jsonb))
      revision
    LIMIT 1;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(feed) ORDER BY feed.ordinality), '[]'::jsonb)
  INTO v_rows
  FROM public.get_discovery_feed(
    p_viewer_id,
    p_cursor_score,
    p_cursor_id,
    p_page_size,
    coalesce(p_filters, '{}'::jsonb)
  ) WITH ORDINALITY AS feed;

  -- to_jsonb(feed) includes the ordinality column; drop it from every row.
  SELECT coalesce(jsonb_agg(row_value - 'ordinality' ORDER BY position), '[]'::jsonb)
  INTO v_rows
  FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS item(row_value, position);

  RETURN jsonb_build_object('revision_token', v_token, 'rows', v_rows);
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_feed_page(
  uuid, double precision, uuid, integer, jsonb, boolean
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed_page(
  uuid, double precision, uuid, integer, jsonb, boolean
) TO authenticated, service_role;

COMMENT ON FUNCTION public.get_discovery_feed_page(
  uuid, double precision, uuid, integer, jsonb, boolean
) IS 'Discovery page plus optional revision token (read first) in one call.';
