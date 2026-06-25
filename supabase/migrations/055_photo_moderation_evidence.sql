-- Record the evidence used by the server-controlled photo activation path.
ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS nsfw_score numeric(5,4),
  ADD COLUMN IF NOT EXISTS nsfw_category text,
  ADD COLUMN IF NOT EXISTS nsfw_scanned_at timestamptz,
  ADD COLUMN IF NOT EXISTS moderation_source text;

ALTER TABLE public.photos
  DROP CONSTRAINT IF EXISTS photos_nsfw_score_range;
ALTER TABLE public.photos
  ADD CONSTRAINT photos_nsfw_score_range
  CHECK (nsfw_score IS NULL OR (nsfw_score >= 0 AND nsfw_score <= 1));

COMMENT ON COLUMN public.photos.moderation_source IS
  'Moderation implementation that supplied the server activation evidence.';
