-- Phase 3: admin push campaigns, content pages, and marriage success stories.
-- Uses the existing notifications queue/FCM dispatcher; no parallel push stack.

CREATE TABLE IF NOT EXISTS public.admin_push_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (length(trim(title)) BETWEEN 3 AND 80),
  body text NOT NULL CHECK (length(trim(body)) BETWEEN 3 AND 220),
  deep_link text,
  audience text NOT NULL DEFAULT 'all'
    CHECK (audience IN ('all', 'active_7d', 'subscribers', 'country')),
  country_code text,
  scheduled_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'queued', 'cancelled')),
  queued_count integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES auth.users(id),
  queued_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  queued_at timestamptz,
  CONSTRAINT admin_push_campaign_country_required
    CHECK (audience <> 'country' OR country_code IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_admin_push_campaigns_status
  ON public.admin_push_campaigns(status, scheduled_at DESC);

CREATE TABLE IF NOT EXISTS public.admin_push_campaign_recipients (
  campaign_id uuid NOT NULL REFERENCES public.admin_push_campaigns(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  notification_id uuid REFERENCES public.notifications(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (campaign_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.app_content_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,80}$'),
  locale text NOT NULL DEFAULT 'en' CHECK (locale ~ '^[a-z]{2}(-[a-z]{2})?$'),
  title text NOT NULL CHECK (length(trim(title)) BETWEEN 3 AND 120),
  body text NOT NULL CHECK (length(trim(body)) >= 20),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  updated_by uuid REFERENCES auth.users(id),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (slug, locale)
);

CREATE INDEX IF NOT EXISTS idx_app_content_pages_status
  ON public.app_content_pages(status, slug, locale);

CREATE TABLE IF NOT EXISTS public.marriage_success_stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_name text NOT NULL CHECK (length(trim(couple_name)) BETWEEN 2 AND 120),
  country_code text,
  story text NOT NULL CHECK (length(trim(story)) >= 20),
  photo_path text,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'published', 'rejected', 'archived')),
  submitted_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_marriage_success_stories_status
  ON public.marriage_success_stories(status, created_at DESC);

ALTER TABLE public.admin_push_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_push_campaign_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_content_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marriage_success_stories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_push_campaigns_staff_read ON public.admin_push_campaigns;
CREATE POLICY admin_push_campaigns_staff_read
  ON public.admin_push_campaigns FOR SELECT
  USING (public.is_active_admin());

DROP POLICY IF EXISTS admin_push_campaign_recipients_staff_read ON public.admin_push_campaign_recipients;
CREATE POLICY admin_push_campaign_recipients_staff_read
  ON public.admin_push_campaign_recipients FOR SELECT
  USING (public.is_active_admin());

DROP POLICY IF EXISTS app_content_pages_staff_read ON public.app_content_pages;
CREATE POLICY app_content_pages_staff_read
  ON public.app_content_pages FOR SELECT
  USING (public.is_active_admin() OR status = 'published');

DROP POLICY IF EXISTS marriage_success_stories_staff_read ON public.marriage_success_stories;
CREATE POLICY marriage_success_stories_staff_read
  ON public.marriage_success_stories FOR SELECT
  USING (public.is_active_admin() OR status = 'published');

CREATE OR REPLACE FUNCTION public.admin_push_campaigns(p_limit integer DEFAULT 50)
RETURNS TABLE(
  campaign_id uuid, title text, body text, deep_link text, audience text,
  country_code text, scheduled_at timestamptz, status text, queued_count integer,
  created_at timestamptz, queued_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.title, c.body, c.deep_link, c.audience, c.country_code,
    c.scheduled_at, c.status, c.queued_count, c.created_at, c.queued_at
  FROM admin_push_campaigns c
  WHERE public.is_active_admin(ARRAY['super_admin','support'])
  ORDER BY c.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_create_push_campaign(
  p_title text,
  p_body text,
  p_deep_link text DEFAULT NULL,
  p_audience text DEFAULT 'all',
  p_country_code text DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT now()
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO admin_push_campaigns(
    title, body, deep_link, audience, country_code, scheduled_at, created_by
  )
  VALUES (
    trim(p_title), trim(p_body), nullif(trim(coalesce(p_deep_link, '')), ''),
    p_audience, nullif(upper(trim(coalesce(p_country_code, ''))), ''),
    coalesce(p_scheduled_at, now()), auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'campaign_created',
    jsonb_build_object('campaign_id', v_id, 'audience', p_audience));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_queue_push_campaign(p_campaign_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_campaign admin_push_campaigns%ROWTYPE;
  v_count integer := 0;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  SELECT * INTO v_campaign
  FROM admin_push_campaigns
  WHERE id = p_campaign_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  IF v_campaign.status <> 'draft' THEN
    RAISE EXCEPTION 'Campaign is already %', v_campaign.status;
  END IF;

  WITH eligible AS (
    SELECT DISTINCT u.id AS user_id
    FROM users u
    JOIN profiles p ON p.user_id = u.id
    WHERE coalesce(u.is_banned, false) = false
      AND p.visibility = 'visible'
      AND (
        v_campaign.audience = 'all'
        OR (v_campaign.audience = 'active_7d' AND p.last_active_at >= now() - interval '7 days')
        OR (v_campaign.audience = 'subscribers' AND u.subscription_status IN ('active','grace_period'))
        OR (v_campaign.audience = 'country' AND p.country_code = v_campaign.country_code)
      )
  ),
  recipients AS (
    INSERT INTO admin_push_campaign_recipients(campaign_id, user_id)
    SELECT v_campaign.id, e.user_id
    FROM eligible e
    ON CONFLICT (campaign_id, user_id) DO NOTHING
    RETURNING user_id
  ),
  queued AS (
    INSERT INTO notifications(user_id, type, title, body, deep_link, scheduled_at)
    SELECT r.user_id, 'admin_campaign', v_campaign.title, v_campaign.body,
      v_campaign.deep_link, greatest(v_campaign.scheduled_at, now())
    FROM recipients r
    RETURNING id, user_id
  )
  UPDATE admin_push_campaign_recipients r
  SET notification_id = q.id
  FROM queued q
  WHERE r.campaign_id = v_campaign.id
    AND r.user_id = q.user_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE admin_push_campaigns
  SET status = 'queued',
      queued_count = v_count,
      queued_by = auth.uid(),
      queued_at = now()
  WHERE id = v_campaign.id;

  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'campaign_queued',
    jsonb_build_object('campaign_id', v_campaign.id, 'queued_count', v_count));

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_content_pages(p_limit integer DEFAULT 100)
RETURNS TABLE(
  page_id uuid, slug text, locale text, title text, body text, status text,
  updated_at timestamptz, published_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.slug, p.locale, p.title, p.body, p.status, p.updated_at, p.published_at
  FROM app_content_pages p
  WHERE public.is_active_admin(ARRAY['super_admin','support'])
  ORDER BY p.updated_at DESC
  LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_content_page(
  p_slug text,
  p_locale text,
  p_title text,
  p_body text
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO app_content_pages(slug, locale, title, body, updated_by, updated_at)
  VALUES (lower(trim(p_slug)), lower(trim(p_locale)), trim(p_title), trim(p_body), auth.uid(), now())
  ON CONFLICT (slug, locale) DO UPDATE
  SET title = excluded.title,
      body = excluded.body,
      updated_by = auth.uid(),
      updated_at = now(),
      status = CASE WHEN app_content_pages.status = 'archived' THEN 'draft' ELSE app_content_pages.status END
  RETURNING id INTO v_id;

  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'content_upserted',
    jsonb_build_object('page_id', v_id, 'slug', lower(trim(p_slug)), 'locale', lower(trim(p_locale))));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_content_status(p_page_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;
  IF p_status NOT IN ('draft','published','archived') THEN
    RAISE EXCEPTION 'Unsupported content status';
  END IF;

  UPDATE app_content_pages
  SET status = p_status,
      published_at = CASE WHEN p_status = 'published' THEN now() ELSE published_at END,
      updated_by = auth.uid(),
      updated_at = now()
  WHERE id = p_page_id;

  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'content_' || p_status,
    jsonb_build_object('page_id', p_page_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_success_stories(p_limit integer DEFAULT 100)
RETURNS TABLE(
  story_id uuid, couple_name text, country_code text, story text, photo_path text,
  status text, created_at timestamptz, published_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT s.id, s.couple_name, s.country_code, s.story, s.photo_path,
    s.status, s.created_at, s.published_at
  FROM marriage_success_stories s
  WHERE public.is_active_admin(ARRAY['super_admin','support'])
  ORDER BY s.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_add_success_story(
  p_couple_name text,
  p_country_code text,
  p_story text,
  p_photo_path text DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO marriage_success_stories(
    couple_name, country_code, story, photo_path, status, reviewed_by, reviewed_at, published_at
  )
  VALUES (
    trim(p_couple_name), nullif(upper(trim(coalesce(p_country_code, ''))), ''),
    trim(p_story), nullif(trim(coalesce(p_photo_path, '')), ''),
    'published', auth.uid(), now(), now()
  )
  RETURNING id INTO v_id;

  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'success_story_added',
    jsonb_build_object('story_id', v_id));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_success_story(p_story_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;
  IF p_status NOT IN ('published','rejected','archived') THEN
    RAISE EXCEPTION 'Unsupported story status';
  END IF;

  UPDATE marriage_success_stories
  SET status = p_status,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      published_at = CASE WHEN p_status = 'published' THEN now() ELSE published_at END
  WHERE id = p_story_id;

  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'success_story_' || p_status,
    jsonb_build_object('story_id', p_story_id));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_push_campaigns(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_create_push_campaign(text, text, text, text, text, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_queue_push_campaign(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_content_pages(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_content_page(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_content_status(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_success_stories(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_add_success_story(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_success_story(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_push_campaigns(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_push_campaign(text, text, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_queue_push_campaign(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_content_pages(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_content_page(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_content_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_success_stories(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_success_story(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_success_story(uuid, text) TO authenticated;
