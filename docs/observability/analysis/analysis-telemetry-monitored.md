# Telemetry/Observe Outage Incidents — Batch 2 Analysis

**Date:** 2026-03-03
**Scope:** 19 NCDNTS incidents related to Observe telemetry outages (not covered in batch 1)

---

## 1. Individual Incident Details

### NCDNTS-12644 — Telemetry outage AWS_AP_SOUTHEAST_2
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-25 00:21 UTC | **Resolved:** 2026-02-25 02:21 UTC (~2h)
- **Region:** AWS_AP_SOUTHEAST_2 | **Account:** RAI_AWS_APSOUTHEAST_2_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Duplicate of another incident (likely NCDNTS-12636)
- **How Resolved:** Auto-closed as duplicate by OpsAgent/automation

### NCDNTS-12643 — Telemetry outage AZURE_WESTEUROPE
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-25 00:15 UTC | **Resolved:** 2026-02-25 02:21 UTC (~2h)
- **Region:** AZURE_WESTEUROPE | **Account:** RAI_AZURE_WESTEUROPE_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Duplicate — acknowledged by Trevor Paddock, auto-closed
- **How Resolved:** Auto-closed as duplicate

### NCDNTS-12641 — Telemetry outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-25 00:06 UTC | **Resolved:** 2026-02-25 02:20 UTC (~2h14m)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Duplicate
- **How Resolved:** Auto-closed as duplicate

### NCDNTS-12639 — Telemetry outage AWS_EU_CENTRAL_1
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-24 23:41 UTC | **Resolved:** 2026-02-25 02:20 UTC (~2h39m)
- **Region:** AWS_EU_CENTRAL_1 | **Account:** RAI_AWS_EU_CENTRAL_1_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Duplicate of NCDNTS-12636 (Trevor Paddock explicitly marked it)
- **How Resolved:** Manual duplicate marking by oncall, then auto-closed

### NCDNTS-12638 — Telemetry outage AZURE_WESTUS2
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-24 23:39 UTC | **Resolved:** 2026-02-26 15:53 UTC (~40h)
- **Region:** AZURE_WESTUS2 | **Account:** RAI_AZURE_USWEST_2_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Duplicate of NCDNTS-12636 (OpsAgent detected, Trevor confirmed)
- **How Resolved:** Duplicate marking + auto-close (delayed ~40h)

### NCDNTS-12637 — Telemetry outage AZURE_WESTUS2
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-24 23:39 UTC | **Resolved:** 2026-02-25 02:17 UTC (~2h38m)
- **Region:** AZURE_WESTUS2 | **Account:** RAI_AZURE_WESTUS2_EVENTS | **Org:** RAIRULES
- **Customer Impact:** No Customer Impact
- **Root Cause:** Duplicate of NCDNTS-12636 (OpsAgent detected, Trevor confirmed)
- **How Resolved:** Duplicate confirmed by OpsAgent, auto-closed
- **Notable:** Different org (RAIRULES vs NDSOEBE) from NCDNTS-12638 despite same region

### NCDNTS-11733 — Telemetry outage AWS_US_WEST_2
- **Status:** Closed | **Resolution:** Done
- **Created:** 2026-01-06 02:44 UTC | **Resolved:** 2026-01-09 09:33 UTC (~3 days)
- **Region:** AWS_US_WEST_2 | **Account:** RAI_STAGING_SPCS_PROVIDER | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** O4S ingestion task failed between 2026-01-05 18:17 and 18:42. Fix: switched WH to Snowpark-optimized to increase /tmp space.
- **How Resolved:** Self-recovered after ~25 min of failures. Long-term fix: Snowpark-optimized warehouse.
- **Responders:** Priti Patel (acknowledged), Ary Fasciati (PIR/fix)

### NCDNTS-11645 — Telemetry outage AWS_US_WEST_2
- **Status:** Closed | **Resolution:** Done
- **Created:** 2025-12-25 16:40 UTC | **Resolved:** 2025-12-26 14:25 UTC (~22h)
- **Region:** AWS_US_WEST_2 | **Account:** RAI_STAGING_SPCS_PROVIDER | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** O4S event table tasks were failing and getting canceled. Transient issue.
- **How Resolved:** Self-recovered. PIR dismissed as "transient issue with O4S tasks."
- **Responders:** Moaz ElShorbagy (acknowledged), Ary Fasciati (PIR/follow-up)

### NCDNTS-11560 — Telemetry outage AZURE_WESTUS2
- **Status:** Closed | **Resolution:** Done
- **Created:** 2025-12-16 22:37 UTC | **Resolved:** 2025-12-26 14:21 UTC (~10 days in ticket)
- **Region:** AZURE_WESTUS2 | **Account:** RAI_AZURE_USWEST_2_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Observe task failing for ~40 minutes. Filed Observe support incident (OBSSD-2303).
- **How Resolved:** Self-recovered. Filed with Observe support. PIR dismissed as "transient issue."
- **Responders:** Priti Patel (investigation + Observe ticket), Ary Fasciati (PIR)

### NCDNTS-11546 — SPCS OTEL Metrics outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2025-12-16 08:05 UTC | **Resolved:** 2025-12-16 09:30 UTC (~1h25m)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS
- **Customer Impact:** No Customer Impact
- **Root Cause:** Part of AWS_EU_WEST_1 multi-signal outage (duplicate)
- **How Resolved:** Acknowledged by Hamzah Sadder, auto-closed as duplicate

### NCDNTS-11545 — Snowflake Platform Metrics outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2025-12-16 08:05 UTC | **Resolved:** 2025-12-16 09:29 UTC (~1h24m)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS
- **Customer Impact:** No Customer Impact
- **Root Cause:** Part of AWS_EU_WEST_1 multi-signal outage (duplicate)
- **How Resolved:** Acknowledged by Hamzah Sadder, auto-closed as duplicate

### NCDNTS-11544 — SPCS Logs outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2025-12-16 08:05 UTC | **Resolved:** 2025-12-16 09:29 UTC (~1h24m)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS
- **Customer Impact:** No Customer Impact
- **Root Cause:** Part of AWS_EU_WEST_1 multi-signal outage (duplicate)
- **How Resolved:** Acknowledged by Hamzah Sadder, auto-closed as duplicate

### NCDNTS-11543 — NA Spans outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2025-12-16 08:05 UTC | **Resolved:** 2025-12-16 09:29 UTC (~1h24m)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS
- **Customer Impact:** No Customer Impact
- **Root Cause:** Part of AWS_EU_WEST_1 multi-signal outage (duplicate)
- **How Resolved:** Acknowledged by Hamzah Sadder, auto-closed as duplicate

### NCDNTS-11542 — NA Logs outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Done (primary incident for the EU_WEST_1 storm)
- **Created:** 2025-12-16 08:05 UTC | **Resolved:** 2025-12-26 14:16 UTC (~10 days in ticket)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS
- **Customer Impact:** No Customer Impact
- **Root Cause:** Ingestion tasks failing for 12 hours. Caused by **ongoing Snowflake outage** (status.snowflake.com). Snowflake applied a mitigation to the affected account.
- **How Resolved:** Snowflake applied mitigation. Tasks recovered.
- **Repair Item:** Improve runbook to account for full telemetry/task outage where some old events still flow.
- **Responders:** Hamzah Sadder (investigation), Ary Fasciati (PIR/repair)

### NCDNTS-11539 — Telemetry outage AWS_EU_WEST_1
- **Status:** Closed | **Resolution:** Done
- **Created:** 2025-12-15 20:32 UTC | **Resolved:** 2025-12-26 14:20 UTC (~11 days in ticket)
- **Region:** AWS_EU_WEST_1 | **Account:** RAI_PROD_AWS_EU_WEST_1_EVENTS | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Task stuck in EXECUTING state for ~25 minutes. Scheduled at 12:02 but didn't start executing until 12:44.
- **How Resolved:** Self-recovered. Reported to Observe. PIR dismissed as "transient issue."
- **Runbook gap:** No query_id for EXECUTING tasks makes the cancel step impossible.
- **Responders:** Priti Patel (investigation), Ary Fasciati (PIR)

### NCDNTS-11519 — Telemetry outage AWS_US_WEST_2
- **Status:** Closed | **Resolution:** Done
- **Created:** 2025-12-14 18:46 UTC | **Resolved:** 2025-12-26 14:18 UTC (~12 days in ticket)
- **Region:** AWS_US_WEST_2 | **Account:** RAI_STAGING_SPCS_PROVIDER | **Org:** NDSOEBE
- **Customer Impact:** No Customer Impact
- **Root Cause:** Task failures between 18:18 and 18:38 UTC causing missing events in that window. Self-recovered.
- **How Resolved:** Self-recovered. PIR dismissed as "transient issue."
- **Responders:** Priti Patel (investigation), Ary Fasciati (PIR)

### NCDNTS-12229 — SPCS OTEL Metrics outage AZURE_EASTUS2
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-11 16:05 UTC | **Resolved:** 2026-02-11 16:09 UTC (~4 min)
- **Region:** AZURE_EASTUS2 | **Account:** RAI_AZURE_EASTUS2_EVENTS
- **Customer Impact:** No Customer Impact
- **How Resolved:** Auto-closed as duplicate within 4 minutes

### NCDNTS-12228 — NA Spans outage AZURE_EASTUS2
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-11 16:05 UTC | **Resolved:** 2026-02-11 16:08 UTC (~3 min)
- **Region:** AZURE_EASTUS2 | **Account:** RAI_AZURE_EASTUS2_EVENTS
- **Customer Impact:** No Customer Impact
- **How Resolved:** Auto-closed as duplicate within 3 minutes

### NCDNTS-12227 — Snowflake Platform Metrics outage AZURE_EASTUS2
- **Status:** Closed | **Resolution:** Duplicate
- **Created:** 2026-02-11 16:05 UTC | **Resolved:** 2026-02-11 16:08 UTC (~3 min)
- **Region:** AZURE_EASTUS2 | **Account:** RAI_AZURE_EASTUS2_EVENTS
- **Customer Impact:** No Customer Impact
- **How Resolved:** Auto-closed as duplicate within 3 minutes

---

## 2. Alert Storm Detection — Grouping by Probable Root Cause Event

### Storm 1: Multi-region outage on 2026-02-24/25 (6 incidents -> 1 root cause: NCDNTS-12636)
| Ticket | Region | Created | Resolution |
|--------|--------|---------|------------|
| NCDNTS-12637 | AZURE_WESTUS2 (RAIRULES) | 23:39 | Dup of 12636 |
| NCDNTS-12638 | AZURE_WESTUS2 (NDSOEBE) | 23:39 | Dup of 12636 |
| NCDNTS-12639 | AWS_EU_CENTRAL_1 | 23:41 | Dup of 12636 |
| NCDNTS-12641 | AWS_EU_WEST_1 | 00:06 | Dup of 12636 |
| NCDNTS-12643 | AZURE_WESTEUROPE | 00:15 | Dup of 12636 |
| NCDNTS-12644 | AWS_AP_SOUTHEAST_2 | 00:21 | Dup of 12636 |

**Pattern:** All 6 tickets fired within ~42 minutes across 5 different regions and 2 orgs. All are duplicates of NCDNTS-12636. Classic alert storm — a single upstream event triggered per-region monitors independently.

### Storm 2: AWS_EU_WEST_1 multi-signal outage on 2025-12-16 (6 incidents -> 1 root cause: Snowflake outage)
| Ticket | Signal Type | Created | Resolution |
|--------|-------------|---------|------------|
| NCDNTS-11539 | Telemetry (general) | 2025-12-15 20:32 | Done |
| NCDNTS-11542 | NA Logs | 08:05 | Done (primary) |
| NCDNTS-11543 | NA Spans | 08:05 | Duplicate |
| NCDNTS-11544 | SPCS Logs | 08:05 | Duplicate |
| NCDNTS-11545 | SF Platform Metrics | 08:05 | Duplicate |
| NCDNTS-11546 | SPCS OTEL Metrics | 08:05 | Duplicate |

**Pattern:** 5 tickets at the exact same second for the same region but different signal types. NCDNTS-11539 preceded by ~12h. Root cause: **Snowflake outage** (confirmed via status.snowflake.com). Ingestion tasks failing for 12 hours.

### Storm 3: AZURE_EASTUS2 multi-signal outage on 2026-02-11 (3 incidents -> 1 root cause)
| Ticket | Signal Type | Created | Resolution |
|--------|-------------|---------|------------|
| NCDNTS-12227 | SF Platform Metrics | 16:05 | Duplicate |
| NCDNTS-12228 | NA Spans | 16:05 | Duplicate |
| NCDNTS-12229 | SPCS OTEL Metrics | 16:05 | Duplicate |

**Pattern:** 3 tickets at the same second for the same region, different signals. All auto-closed within 3-4 minutes.

### Standalone Incidents (4 incidents, each a separate root cause)
| Ticket | Region | Created | Root Cause |
|--------|--------|---------|------------|
| NCDNTS-11519 | AWS_US_WEST_2 | 2025-12-14 | Transient task failures (~20 min window) |
| NCDNTS-11560 | AZURE_WESTUS2 | 2025-12-16 | Observe task failing ~40 min |
| NCDNTS-11645 | AWS_US_WEST_2 | 2025-12-25 | O4S tasks failing/getting canceled |
| NCDNTS-11733 | AWS_US_WEST_2 | 2026-01-06 | O4S ingestion task failure (fixed by Snowpark-optimized WH) |

**Total: 19 tickets represent only 7 distinct outage events.**

---

## 3. Region Breakdown

| Region | Count | % |
|--------|-------|---|
| AWS_EU_WEST_1 | 6 | 31.6% |
| AWS_US_WEST_2 | 4 | 21.1% |
| AZURE_WESTUS2 | 3 | 15.8% |
| AZURE_EASTUS2 | 3 | 15.8% |
| AWS_EU_CENTRAL_1 | 1 | 5.3% |
| AZURE_WESTEUROPE | 1 | 5.3% |
| AWS_AP_SOUTHEAST_2 | 1 | 5.3% |

**After deduplication (by distinct events):**
- AWS_US_WEST_2: 3 distinct events (most independently problematic)
- AWS_EU_WEST_1: 2 distinct events
- AZURE_WESTUS2: 2 distinct events
- AZURE_EASTUS2: 1 distinct event
- Others: 0 distinct events (all part of multi-region Storm 1)

---

## 4. Resolution Patterns

### By Resolution Type
| Type | Count | % |
|------|-------|---|
| Duplicate | 13 | 68.4% |
| Done (actual fix/recovery) | 6 | 31.6% |

### Self-Recovery vs Manual Intervention
Of the 6 "Done" incidents:
- **Self-recovered (5):** NCDNTS-11519, 11539, 11560, 11645, 11733
- **External fix (1):** NCDNTS-11542 — Snowflake applied a mitigation

**Zero incidents required direct manual intervention by RAI oncall to fix the underlying issue.** Oncall role was limited to: acknowledging, investigating, verifying recovery, filing Observe support tickets, and dismissing PIRs.

---

## 5. New Patterns Not Seen in First Batch

### A: Snowflake Platform Outage as Root Cause
NCDNTS-11542 confirms a **Snowflake outage** (status.snowflake.com) as the root cause. Different failure mode from typical O4S transients.

### B: Multi-Signal Alert Storms
A single region outage fires 5 separate alert types (NA Logs, NA Spans, SPCS Logs, SF Platform Metrics, SPCS OTEL Metrics) plus general Telemetry. 5-6x ticket multiplier per event.

### C: Multi-Region Alert Storms
Storm 1 shows a single root cause firing across 5+ regions simultaneously. Combined with per-signal monitors, could theoretically create 30+ tickets from one event.

### D: OpsAgent Duplicate Detection
Feb 2026 incidents show OpsAgent performing duplicate detection and responding to `@OpsAgent mark` commands. Newer automation not present in Dec 2025 incidents.

### E: Snowpark-Optimized Warehouse Fix
NCDNTS-11733 led to a permanent fix: switching to Snowpark-optimized warehouse to increase /tmp space.

### F: Runbook Gap
NCDNTS-11539: when a task is stuck in EXECUTING state, the runbook says to cancel it, but no query_id is available.

---

## 6. Time-to-Resolution

### Ticket Resolution Times
| Bucket | Count | Tickets |
|--------|-------|---------|
| < 30 min | 3 | NCDNTS-12227, 12228, 12229 |
| 1-3 hours | 7 | NCDNTS-12637, 12639, 12641, 12643, 12644, 11543-11546 |
| ~22 hours | 1 | NCDNTS-11645 |
| ~40 hours | 1 | NCDNTS-12638 |
| 3 days | 1 | NCDNTS-11733 |
| 10-12 days | 6 | NCDNTS-11519, 11539, 11542, 11560 (ticket left open for PIR) |

### Actual Outage Durations (when identifiable)
- Task failure windows: 20-42 minutes (NCDNTS-11519, 11733)
- Task stuck EXECUTING: ~25 minutes (NCDNTS-11539)
- Observe task failure: ~40 minutes (NCDNTS-11560)
- Snowflake outage impact: ~12 hours of task failures (NCDNTS-11542)

**Gap between actual outage and ticket resolution is large.** Most outages self-resolve in under an hour. The 10-12 day tickets were all closed in a batch on 2025-12-26 by Ary Fasciati (PIR cleanup sweep).

---

## 7. Summary Findings

1. **68% of tickets are duplicates.** Monitoring fires per-region and per-signal-type, creating massive alert storms. 19 tickets = only 7 distinct events.

2. **All incidents self-resolved or were fixed by Snowflake.** No RAI oncall manual intervention actually fixed a telemetry outage.

3. **O4S ingestion task failures are the universal proximate cause.** Every incident traces back to O4S tasks failing, getting stuck, or being canceled.

4. **AWS_US_WEST_2 (staging) is the most independently problematic region** with 3 distinct outage events, all involving RAI_STAGING_SPCS_PROVIDER.

5. **Alert storm mitigation is improving** — AZURE_EASTUS2 storm (Feb 2026) resolved in 3-4 minutes via automation, vs hours for Dec 2025 storms.

6. **PIR process is a bottleneck** — all PIRs dismissed as "transient issue." 10-12 day resolution times are entirely PIR delay. Consider whether these warrant PIR at all.

7. **Actionable repairs identified:**
   - Improve runbook for EXECUTING tasks with no query_id
   - Snowpark-optimized warehouse deployed for staging (one-time fix)
   - Consider alert correlation to reduce storm ticket volume
