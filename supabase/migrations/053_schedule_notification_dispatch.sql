-- Dispatch queued FCM notifications every minute through the deployed Edge Function.
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'dispatch_notifications_minutely';

SELECT cron.schedule(
  'dispatch_notifications_minutely',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'https://jukpscfxzwttgtxvrbmj.supabase.co/functions/v1/dispatch-notifications',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
        'Content-Type', 'application/json'
      )
    );
  $$
);
