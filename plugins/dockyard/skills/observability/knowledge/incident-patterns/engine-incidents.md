# Engine Incident Patterns

## Pattern: Snowflake Maintenance (False Positive)

| Field | Value |
|---|---|
| **Frequency** | Very High — 33% of ALL engine incidents |
| **Severity** | Noise — non-actionable |
| **Signature** | Engine state = PENDING around alert time. Container status `running -> pending (~25min) -> running` in Engine failures dashboard. Multiple "engine failed" transaction aborts on same engine within minutes. |
| **Root Cause** | Snowflake-initiated container restart during maintenance window. Heartbeat cache evicts in-flight transactions, causing "engine failed" abort. |
| **Diagnostic Steps** | 1. CHECK FIRST: Before investigating ANY "engine failed" incident, check SF maintenance status 2. Open Engine failures dashboard, look for engine state = PENDING 3. If container shows 25-min pending gap -> SF maintenance, not a RAI crash 4. Confirm timing against known SF maintenance windows (typically weekends) |
| **Resolution** | Close immediately after confirming maintenance timing. No RAI action needed. |
| **Recurring Accounts** | `ritchie_brothers_oob38648` (most affected — weekend CDC workloads), any account with always-on engines |

---

## Pattern: Engine Crash (SPCS)

| Field | Value |
|---|---|
| **Frequency** | Very high — dozens per week across all accounts. Most common incident type by volume. |
| **Severity** | Typically Medium |
| **Signature** | Alert: "SPCS: The engine X crashed in the account Y". Error logs matching "segmentation fault" and "signal". Container restart via `spcs.container.restarts.total` metric. |
| **Root Cause** | Segfault (Julia runtime, storage/network stack), stack overflow (metadata layer), abort signal |
| **Diagnostic Steps** | 1. Check error logs for "segmentation fault" 2. Identify crash component from stack trace in error logs (core dumps unavailable on SPCS since 2025-09-17) 3. Identify crash component from logs 4. Check `spcs.container.state.last.finished.reason` = `Failed` or `Done` |
| **Resolution** | Engine auto-restarts and resumes. Most are transient. Route to owning team based on crash component. |
| **Recurring Accounts** | `rai_studio_sac08949` (daily crashes, multiple engine types: LD_SF100, MD_SF100 — appears to be stress testing) |
| **Related Monitors** | [Engine crash detection (42938640)](https://171608476159.observeinc.com/workspace/41759331/threshold-monitor/42938640) |

### Escalation by Crash Type

| Component | Team | Channel |
|---|---|---|
| Julia runtime segfault | Julia team | #team-prod-engine-resource-providers-spcs |
| Storage/network stack | Storage team | #team-prod-engine-resource-providers-spcs |
| Stack overflow in metadata | Backend team | #team-prod-engine-resource-providers-spcs |

---

## Pattern: Transaction Aborts with Reason "Engine Failed"

| Field | Value |
|---|---|
| **Frequency** | High — multiple per week |
| **Severity** | Typically Medium |
| **Signature** | Alert: "Transactions were aborted with reason 'engine failed' on the engine X". Multiple transactions may be affected simultaneously. |
| **Root Cause** | ERP didn't receive heartbeat for 20 minutes. Sub-causes: crash, OOM, brownout, Snowflake maintenance, long heartbeat requests, lifecycle events. |
| **Diagnostic Steps** | 1. Open [Engine failures dashboard (41949642)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Engine-failures-41949642) with transaction ID, engine name, account ID 2. Check "Engine last termination reason" card 3. Check "Server heartbeats per second" for brownout 4. Check "Service lifecycle events" for user-initiated operations 5. Check timing for Snowflake maintenance (Mon-Thu 11PM-5AM local) 6. Check ERP logs for engine deletion/replacement events — user may have deleted or resized engine during transaction (user explicitly deleted engine NCDNTS-10953 -> close as false positive; user resized engine = delete old + create new NCDNTS-10059 -> `container.state.last.finished.reason` increments on deletion, triggering false crash alert) |
| **Resolution** | Depends on sub-cause — see diagnostic lookup table below |
| **Recurring Accounts** | Various — high volume across production |
| **Related Monitors** | [Transaction abort detection (42297913)](https://171608476159.observeinc.com/workspace/41759331/count-monitor/42297913) |

### Diagnostic Lookup Table

See `engine-failures.md` — Diagnostic Lookup Table section for full "What You See → Root Cause → Next Step" reference.

---

## Pattern: OOM Brake Transaction Cancellations

| Field | Value |
|---|---|
| **Frequency** | Moderate — several per month across different accounts |
| **Severity** | Typically Medium |
| **Signature** | Alert: "Repeated transaction cancellations by the OOM brake on the engine X". Multiple transactions cancelled in sequence. Engine remains running (unlike full OOM kill). |
| **Root Cause** | OOM brake proactively cancels transactions when memory pressure is detected, before the OS would kill the engine process. |
| **Diagnostic Steps** | 1. Identify cancelled transactions and concurrent transactions 2. Note the stage at which transactions were cancelled 3. Note the queries being evaluated 4. Inspect metrics on [OOM Investigations dashboard (41777956)](https://171608476159.observeinc.com/workspace/41759331/dashboard/OOM-Investigations-41777956) 5. Check Jemalloc absolute and relative profiles near OOM events 6. Check CPU profiles to identify hot code paths |
| **Resolution** | Identify memory-intensive workloads. May require engine upsizing or query optimization. |
| **Recurring Accounts** | `by_dev_ov40102` (most frequent), `rai_studio_sac08949`, `att_cdononprod_cdononprod`, `rai_mirror_x_aqb71127`, `ey_fabric233_rua08657` |
| **Related Monitors** | [OOM brake detection (42445898)](https://171608476159.observeinc.com/workspace/41759331/threshold-monitor/42445898) |

---

## Pattern: Engine Brownout (PyRel XS)

| Field | Value |
|---|---|
| **Frequency** | Intermittent |
| **Severity** | Medium |
| **Signature** | Continuous brownout of 20+ minutes on XS engines named `pyrel_test_*` in spcs-int. Engine stops emitting metrics entirely. On recovery, logs "heartbeat was lost for XXXX seconds". |
| **Root Cause** | Unknown — specific to XS instance type. Increased blocked threads, CPU wait time, pending disk operations, close_wait connections observed. |
| **Diagnostic Steps** | 1. Check OTEL collector metrics: blocked threads, CPU wait, pending disk ops, close_wait connections 2. Check if engine recovered (heartbeat lost log) |
| **Resolution** | Mitigation: move to S engines. Open investigation tracked in NCDNTS-4522, RAI-28970. |
| **Recurring Accounts** | Internal test accounts (spcs-int) |
| **Related Monitors** | Transaction abort detection (via heartbeat timeout) |

## Cross-References

- OOM brake incidents may escalate to full engine crashes → see engine crash pattern above
- Engine failures on CDC engines → see [pipeline-incidents.md](pipeline-incidents.md)
- Brownouts affecting heartbeats → triggers "engine failed" abort pattern
