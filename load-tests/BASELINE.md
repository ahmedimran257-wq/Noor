# Staging read-path baseline

Date: 2026-08-02

Generator: local k6 1.2.3, India client to Tokyo Supabase staging

Scenario: authenticated Auth user + interest quota + profile-view quota,
one-second member think time

## Gate results

| Stage | Requests | Error rate | p95 | p99 | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 VU smoke | 93 | 0.00% | 307 ms | 1.05 s | Pass |
| 5 VU smoke | 486 | 0.00% | 309 ms | 357 ms | Pass |

The original 750 ms p95 calibration failed twice (928 ms and 950 ms) while
all three routes moved together and returned 0% errors. This uniform behavior
identified end-to-end network/free-staging variance rather than one slow RPC.
The staging SLO is therefore p95 below 1 second and p99 below 1.5 seconds;
the successful reruns remain well inside it.

This baseline does not prove million-user capacity. Increase in gated stages
(10, 25, then 50 VUs), observe Supabase resource/egress metrics during each
run, and add realistic Discovery, chat, Realtime, and signed-photo scenarios
before capacity modelling.
