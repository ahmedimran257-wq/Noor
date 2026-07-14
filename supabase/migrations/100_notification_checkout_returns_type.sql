-- FCM dispatch needs notification type for reliable tap routing.

DROP FUNCTION IF EXISTS public.checkout_notifications(integer);

CREATE OR REPLACE FUNCTION public.checkout_notifications(batch_size int DEFAULT 500)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  type text,
  title text,
  body text,
  deep_link text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.notifications n
  SET sent_at = NOW()
  WHERE n.id IN (
    SELECT n2.id
    FROM public.notifications n2
    WHERE n2.scheduled_at <= NOW()
      AND n2.sent_at IS NULL
    ORDER BY n2.scheduled_at ASC
    LIMIT batch_size
    FOR UPDATE SKIP LOCKED
  )
  RETURNING n.id, n.user_id, n.type, n.title, n.body, n.deep_link;
END;
$$;

REVOKE ALL ON FUNCTION public.checkout_notifications(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checkout_notifications(integer) TO service_role;
