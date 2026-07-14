-- Forward-only production rebrand from Mithaq to Silarah.
-- Historical migrations and immutable infrastructure IDs remain unchanged.

ALTER TABLE public.profile_nudge_rules
  DROP CONSTRAINT IF EXISTS profile_nudge_rules_deep_link_check;

UPDATE public.profile_nudge_rules
SET title_template = replace(title_template, 'Mithaq', 'Silarah'),
    body_template = replace(body_template, 'Mithaq', 'Silarah'),
    deep_link = replace(replace(deep_link, 'mithaq://', 'silarah://'), 'mithaq.app', 'silarah.com'),
    updated_at = now();

ALTER TABLE public.profile_nudge_rules
  ADD CONSTRAINT profile_nudge_rules_deep_link_check
  CHECK (deep_link LIKE 'silarah://%');

UPDATE public.notifications
SET title = replace(title, 'Mithaq', 'Silarah'),
    body = replace(body, 'Mithaq', 'Silarah'),
    deep_link = replace(replace(deep_link, 'mithaq://', 'silarah://'), 'mithaq.app', 'silarah.com')
WHERE title LIKE '%Mithaq%'
   OR body LIKE '%Mithaq%'
   OR deep_link LIKE 'mithaq://%'
   OR deep_link LIKE '%mithaq.app%';

UPDATE public.admin_notifications
SET message = replace(message, 'Mithaq', 'Silarah')
WHERE message LIKE '%Mithaq%';

UPDATE public.admin_push_campaigns
SET title = replace(title, 'Mithaq', 'Silarah'),
    body = replace(body, 'Mithaq', 'Silarah'),
    deep_link = replace(replace(deep_link, 'mithaq://', 'silarah://'), 'mithaq.app', 'silarah.com')
WHERE title LIKE '%Mithaq%'
   OR body LIKE '%Mithaq%'
   OR deep_link LIKE 'mithaq://%'
   OR deep_link LIKE '%mithaq.app%';

UPDATE public.app_content_pages
SET title = replace(title, 'Mithaq', 'Silarah'),
    body = replace(replace(body, 'Mithaq', 'Silarah'), 'mithaq.app', 'silarah.com'),
    updated_at = now()
WHERE title LIKE '%Mithaq%'
   OR body LIKE '%Mithaq%'
   OR body LIKE '%mithaq.app%';

-- Update every installed public function that still generates old brand copy
-- or links. pg_get_functiondef preserves the function's security attributes.
DO $$
DECLARE
  v_function record;
  v_definition text;
BEGIN
  FOR v_function IN
    SELECT p.oid, pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND (
        pg_get_functiondef(p.oid) LIKE '%Mithaq%'
        OR pg_get_functiondef(p.oid) LIKE '%mithaq://%'
        OR pg_get_functiondef(p.oid) LIKE '%mithaq.app%'
      )
  LOOP
    v_definition := replace(v_function.definition, 'Mithaq', 'Silarah');
    v_definition := replace(v_definition, 'mithaq://', 'silarah://');
    v_definition := replace(v_definition, 'mithaq.app', 'silarah.com');
    EXECUTE v_definition;
  END LOOP;
END;
$$;

COMMENT ON TABLE public.profile_nudge_rules IS
  'Configurable Silarah profile-completion notification copy and priority.';
