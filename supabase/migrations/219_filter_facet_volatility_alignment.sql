-- The base facet RPC is read-only. Marking it STABLE keeps its India wrapper
-- honest and removes an avoidable planner/linter pessimization.
ALTER FUNCTION public.get_discovery_filter_facets(uuid) STABLE;

NOTIFY pgrst, 'reload schema';
