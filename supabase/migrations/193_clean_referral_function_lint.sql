-- Qualify referral columns so database lint cannot confuse the PL/pgSQL
-- variable with the table column.
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_generated_code text;
  v_attempt integer := 0;
BEGIN
  SELECT rc.code INTO v_generated_code
  FROM public.referral_codes AS rc
  WHERE rc.owner_id = v_user_id;
  IF v_generated_code IS NOT NULL THEN
    RETURN v_generated_code;
  END IF;

  LOOP
    v_attempt := v_attempt + 1;
    EXIT WHEN v_attempt > 32;
    v_generated_code := upper(substr(
      md5(gen_random_uuid()::text || clock_timestamp()::text || v_attempt::text),
      1,
      6
    ));
    INSERT INTO public.referral_codes AS rc(code, owner_id)
    VALUES (v_generated_code, v_user_id)
    ON CONFLICT DO NOTHING;

    SELECT rc.code INTO v_generated_code
    FROM public.referral_codes AS rc
    WHERE rc.owner_id = v_user_id;
    IF v_generated_code IS NOT NULL THEN
      RETURN v_generated_code;
    END IF;
  END LOOP;

  RAISE EXCEPTION 'referral_code_generation_failed' USING ERRCODE = 'P0001';
END;
$$;

REVOKE ALL ON FUNCTION public.generate_referral_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO authenticated;
