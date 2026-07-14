-- Let authenticated users permanently remove only their own notification rows.
-- Select/update policies already enforce the same ownership boundary.

DROP POLICY IF EXISTS notifs_delete ON public.notifications;
CREATE POLICY notifs_delete
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
