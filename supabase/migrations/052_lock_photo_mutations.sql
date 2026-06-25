-- Only trusted Edge Functions may reserve, activate, or approve photos.
-- Clients use get-signed-url and validate-photo-upload instead of direct DB writes.
DROP POLICY IF EXISTS photos_insert ON public.photos;
DROP POLICY IF EXISTS photos_update ON public.photos;
