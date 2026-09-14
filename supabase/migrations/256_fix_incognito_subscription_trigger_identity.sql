-- Fix subscription updates rejected by the shared premium-incognito trigger.
-- public.users identifies a member with `id`; promotional/test grant rows use
-- `user_id`. The original generic trigger assumed every attached table used
-- `user_id`, so RevenueCat state changes failed before they could commit.

CREATE OR REPLACE FUNCTION private.sync_incognito_entitlement_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF TG_TABLE_SCHEMA = 'public' AND TG_TABLE_NAME = 'users' THEN
    -- This trigger is UPDATE-only on public.users, whose member key is `id`.
    v_user_id := NEW.id;
  ELSE
    -- Promotional grants and private device-test grants use `user_id` and can
    -- fire for INSERT, UPDATE, or DELETE.
    v_user_id := CASE
      WHEN TG_OP = 'DELETE' THEN OLD.user_id
      ELSE NEW.user_id
    END;
  END IF;

  PERFORM private.sync_incognito_entitlement(v_user_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_incognito_entitlement_trigger()
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.sync_incognito_entitlement_trigger() IS
  'Keeps premium incognito entitlement synchronized across public.users and grant tables using the correct row identity column.';

NOTIFY pgrst, 'reload schema';
