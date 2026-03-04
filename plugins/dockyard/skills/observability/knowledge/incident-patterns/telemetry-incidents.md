# Telemetry Incident Patterns

## Pattern: Transient O4S Task Failure

| Field | Value |
|---|---|
| **Frequency** | High — 66% of telemetry incidents, weekly occurrences |
| **Severity** | Typically SEV2 but usually self-resolves |
| **Signature** | Telemetry missing 20-40 min, then returns. O4S tasks show failed/canceled runs. |
| **Root Causes** | SF task failures, Observe outage, Azure networking, AWS outage |
| **Action** | Verify return via [Telemetry Outages dashboard (42760073)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-Outages-42760073). Close if recovered. |
| **Key Stat** | ~50% self-recover within 30 minutes. Wait, then check. |

---

## Pattern: Snowflake Platform Outage

| Field | Value |
|---|---|
| **Frequency** | Low — ~2-3 per 6 months, but high impact |
| **Severity** | High |
| **Signature** | Multi-region telemetry outages, 12+ hours of task failures. Confirmed via status.snowflake.com. |
| **Example** | Dec 16, 2025 — AWS_EU_WEST_1, 12h outage, 6 tickets for one event |
| **Action** | Check status.snowflake.com. File Sev-1 SF support ticket. Snowflake must apply mitigation. |
| **Key Insight** | RAI oncall cannot fix this. Resolution requires Snowflake-side mitigation. |

---

## Pattern: RAI-Induced Outage

| Field | Value |
|---|---|
| **Frequency** | Low — ~9% of telemetry incidents |
| **Severity** | High |
| **Signature** | Sustained outage (hours), recent RAI deploy/config change |
| **Example** | Flag logic error disabled telemetry |
| **Action** | Check recent deployments, O4S task logs, escalate to #helpdesk-observability |

---

## Pattern: Monitor Misconfiguration

| Field | Value |
|---|---|
| **Frequency** | Low — ~9% of telemetry incidents |
| **Severity** | Low |
| **Signature** | Alert fires for specific account/region while others are healthy. Template variable leaks (`{{webhookData.SNOWFLAKE_REGION}}`). |
| **Action** | Check O4S app installed, warehouse status, event sharing config. Fix monitor exclusions. |

---

## Alert Storm Handling (CRITICAL)

A single pipeline failure triggers 2-6 monitors per region:
- Telemetry outage (general)
- NA Logs outage
- SPCS Logs outage
- OTEL Metrics outage
- SF Platform Metrics outage
- NA Spans outage

Multi-region outages multiply further: 5 regions x 5 signals = 25+ tickets.

**Rule:** If multiple telemetry tickets fire within 30 min for same region or across regions, treat as single event. Investigate the first ticket only. Close rest as duplicates.

---

## O4S Task Diagnostics

```sql
SELECT *, DATEDIFF('minute', QUERY_START_TIME, COMPLETED_TIME) AS DURATION_MINUTES
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, current_timestamp()),
    RESULT_LIMIT => 100,
    TASK_NAME => '<O4S_TASK_NAME>'
));
```

- If task stuck EXECUTING with no query_id: the documented "cancel task with SYSTEM$CANCEL_QUERY" step is impossible. Alternative: suspend and restart the task.
- If task latency increasing: upsize warehouse (M -> L). Consider Snowpark-optimized warehouse for /tmp space (NCDNTS-11733 fix).

---

## Three-Tier Monitoring Architecture

Source: Ruba Doleh, Nov 2025.

| Tier | Monitor | Threshold | Action |
|---|---|---|---|
| 1 | Event Table heartbeat (42741161) | 20 min no data | Immediate: check O4S task status |
| 2 | Observe Ingestion Lag | 1 hour latency | Resize warehouse |
| 3 | Telemetry-type monitors (4h) | 4 hours specific type missing | Evaluated every 4h |

Investigation order: check Tier 1 first. If event table has data but Observe doesn't, problem is Tier 2/3.

**Gap:** No suppression logic between tiers — Tier 1 and Tier 2 fire independently, causing alert storms.

---

## UAE North Specifics

- 38% of ALL telemetry incidents (20/53 in 6mo) come from `rai_azure_uaenorth_events_ye96117`
- Oct 16, 2025: single outage generated 11 tickets in one day
- Alert storm handling: investigate one ticket, close the rest as duplicates
- Access blocker: `rai_oncaller` workflow doesn't work for UAE North. Manual IT/ACCOUNTADMIN intervention required.
- Muting is error-prone: oncaller muted one monitor but not another -> re-fire
- Limited SF support coverage for UAE region

---

## Escalation

| Step | Channel |
|---|---|
| Notify reliability | `#helpdesk-observability` (tag `@reliability`) |
| Snowflake issue | File Sev-1 via https://app.snowflake.com/support/case/ |
| Observe issue | File incident via https://customer.support.observeinc.com/servicedesk/customer/portal/7 |
| Telemetry latency > 30 min | `#ext-relationalai-observe` |

## Cross-References

- Pipeline-level patterns: [pipeline-incidents.md](pipeline-incidents.md)
- Monitor IDs: `platform-extended.md` monitors section
- Observe dashboards: [Telemetry Outages (42760073)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-Outages-42760073), [Telemetry Heartbeats (42384426)](https://171608476159.observeinc.com/workspace/41759331/dashboard/42384426)
