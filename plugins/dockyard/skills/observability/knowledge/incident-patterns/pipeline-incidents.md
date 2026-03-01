# Pipeline Incident Patterns

## Pattern: Telemetry Outage (Observe)

| Field | Value |
|---|---|
| **Frequency** | Moderate — roughly weekly occurrences, often clusters of multiple regions |
| **Severity** | Typically High |
| **Signature** | Alert: "[Observe] Telemetry outage in REGION_NAME". No data flowing into Observe dashboards for affected region. Multiple monitors across the region may trigger simultaneously. |
| **Root Cause** | Snowflake event table issues, O4S task problems, or Observe platform issues. Clusters suggest platform-level rather than region-specific problems. |
| **Diagnostic Steps** | 1. Check [Observe Status Page](https://status.observeinc.com/) 2. Verify event table has recent telemetry (< 20 min) 3. If no telemetry → Snowflake pipeline issue → file Sev-1 support case 4. If telemetry exists → check O4S task status 5. If task stuck (EXECUTING > 20 min) → cancel with `SYSTEM$CANCEL_QUERY` 6. If no scheduled tasks → check O4S app installed → raise Observe incident |
| **Resolution** | Varies: Snowflake Sev-1 ticket, O4S task cancellation, Observe incident, or warehouse upsizing |
| **Recurring Accounts** | N/A — affects regions, not accounts |
| **Related Monitors** | [Event Table Telemetry Outage (42741161)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42741161), [SPCS Logs Outage (42750468)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42750468), [NA Logs Outage (42750481)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42750481), [OTEL Metrics Outage (42750529)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42750529), [NA Spans Outage (42750527)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42750527) |

### Affected Regions (observed)

AWS_US_WEST_2 (most frequent), AWS_US_EAST_1, AWS_EU_WEST_1, AWS_EU_CENTRAL_1, AWS_AP_SOUTHEAST_2, AZURE_WESTUS2, AZURE_WESTEUROPE, AZURE_EASTUS2

### Verification Dashboard

[Telemetry Outages (42760073)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-Outages-42760073)

### Escalation

| Step | Channel |
|---|---|
| Notify reliability | `#helpdesk-observability` (tag `@reliability`) |
| Snowflake issue | File Sev-1 via https://app.snowflake.com/us-west-2/esb29457/#/support |
| Observe issue | File incident via https://customer.support.observeinc.com/servicedesk/customer/portal/7/group/26/create/109 |
| Telemetry latency > 30 min | `#ext-relationalai-observe` |

---

## Pattern: Snowflake Platform Metrics Outage

| Field | Value |
|---|---|
| **Frequency** | Low — approximately 3 in 6 months |
| **Severity** | Typically High |
| **Signature** | Alert: "[Observe] Snowflake Platform Metrics outage in REGION_NAME". Platform metrics missing for 4+ hours while other telemetry may still work. |
| **Root Cause** | Snowflake platform metrics pipeline specific failure |
| **Diagnostic Steps** | 1. Check Observe status page 2. Log into O4S account and verify platform metrics (filter `RECORD_TYPE = 'METRIC'`, `SCOPE['name'] = 'snow.spcs.platform'`) 3. If missing → file Sev-1 Snowflake support case |
| **Resolution** | Snowflake Sev-1 ticket |
| **Recurring Accounts** | N/A — affects regions |
| **Related Monitors** | [Snowflake Platform Metrics Outage (42750530)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42750530) |

---

## Pattern: CDC Long-Running Transactions

| Field | Value |
|---|---|
| **Frequency** | Moderate — recurring weekly for specific accounts |
| **Severity** | Typically Medium |
| **Signature** | "SPCS: A transaction has been running for 20h on the engine `CDC_MANAGED_ENGINE`". Transaction aborts with "engine failed" on CDC engine. |
| **Root Cause** | CDC_MANAGED_ENGINE transactions running 20+ hours. May be due to large data volumes, engine contention, or engine failures. |
| **Diagnostic Steps** | 1. Check transaction status on CDC_MANAGED_ENGINE for the account 2. Check process_batches span durations 3. Check for quarantined or stale streams 4. Check engine health (crash, OOM) |
| **Resolution** | Usually auto-resolves. Data mismatches require engineering investigation (High severity). |
| **Recurring Accounts** | `ritchie_brothers_oob38648` (most frequent, weekly), `rai_studio_sac08949` |
| **Related Monitors** | Transaction abort detection (general) |

---

## Pattern: Observe Ingestion Lag

| Field | Value |
|---|---|
| **Frequency** | Low |
| **Severity** | Medium |
| **Signature** | Telemetry latency exceeds 30 minutes. Dashboards show stale data. |
| **Root Cause** | O4S task processing slower than event rate. Warehouse undersized. |
| **Diagnostic Steps** | 1. Check [O4S Pipeline Health dashboard](https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-O4S-Pipeline-Health-42090551) for task durations 2. Check warehouse utilization |
| **Resolution** | Upsize `observability_wh` warehouse to next tier |
| **Recurring Accounts** | N/A |
| **Related Monitors** | O4S Pipeline Health dashboard |

### Escalation

Thread in `#ext-relationalai-observe` tagging @Austin Nixon @Arthur Dayton. Notify `@reliability` in `#helpdesk-observability`.

## Cross-References

- Telemetry outages can trigger false positives in other monitors (engine crash, ERP errors) due to missing data
- CDC engine failures → see [engine-incidents.md](engine-incidents.md)
- CDC pipeline architecture details → see [data-pipeline.md](../data-pipeline.md)
