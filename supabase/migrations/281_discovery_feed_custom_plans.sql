-- Silarah — keep the Discovery feed on per-call query plans
--
-- get_discovery_feed is one PL/pgSQL query with ~25 optional filters written
-- as "(filter absent) OR (condition)". After five calls on a connection,
-- Postgres switches the cached statement to a generic plan that cannot drop
-- the absent filters. A rolled-back staging load test with 3,500 candidates
-- (October 2026) measured:
--   calls 1-5 ~330 ms, call 6 onwards ~5,000 ms, age filter ~3,400 ms;
--   with force_custom_plan every call ~275 ms, age filter ~255 ms.
-- PostgREST keeps connections open, so without this nearly every request
-- would take the slow path once the member base grows. Planning each call
-- costs a few milliseconds.

ALTER FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) SET plan_cache_mode = force_custom_plan;
