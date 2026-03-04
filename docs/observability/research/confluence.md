# Observability Skill — Confluence Research Notes

This document captures domain knowledge gathered from Confluence documentation across the ES (Engineering System) and SPCS (RAI on SPCS) spaces. It covers all actionable runbooks, debugging procedures, mitigation guides, dashboards, log patterns, escalation paths, and architecture context relevant to production incident investigation.

**Sources read:**
- ES space: Engine Oncall Runbook (parent page 573898765) and all 33 child pages
- SPCS space: Observability section (Runbooks, Guides and Runbooks, Architecture), SPCS on-call Guide, deployment/upgrade runbooks, billing incident handling

---

## 1. Transaction Terminal States

Transaction status is NOT determined by `maxlevel`. The ERP sets terminal states explicitly:

- **COMPLETED** — transaction succeeded
- **ABORTED** — transaction failed, with a specific abort reason

`maxlevel` only indicates the highest severity log event within the transaction (info, warning, error). A transaction can have `maxlevel = error` but still COMPLETE, or `maxlevel = info` and be ABORTED (e.g., engine failed before logs were emitted).

### Abort Reasons

- `engine failed` — ERP didn't receive heartbeat for 20 minutes
- `engine is in DELETING state` — user deleted engine during transaction
- `engine is in SUSPENDING state` — engine was suspended during transaction
- `engine is in UPGRADING state` — engine was being upgraded
- `internal server error` — gracefully handled error (e.g., stack overflow)

---

## 2. Transaction Types

There are three distinct transaction contexts:

### User-Initiated Transactions
- Triggered via `api.exec()` or `api.exec_into()` SQL procedures
- Run on user-created named engines
- Flow: SQL procedure -> SPCS Control Plane -> rai-server engine -> results

### CDC Transactions
- Background data sync triggered by `process_batches` task (runs every 1 minute)
- Always run on `CDC_MANAGED_ENGINE` (a single app-managed engine)
- Flow: Source SF Table -> SF Stream -> Data Stream Task (1min) -> CSV to Stage -> process_batches -> CDC_MANAGED_ENGINE -> RAI Database
- One transaction per target DB at a time; next queued item starts immediately after completion
- Generated Rel transactions avoid stdlib dependencies

### Graph Index Transactions
- Automated resource management triggered by `use_index` (called internally by PyRel)
- Flow: use_index (sql-lib) -> prepareIndex (ERP) -> transaction execution
- Important: NO end-to-end trace propagation between sql-lib and ERP due to Snowflake constraints
- Must manually correlate via `pyrel_program_id`, `sf.query_id`/`request_id`, or hashed DB name

---

## 3. Six Engine Failure Patterns

From the Engine Oncall Runbook (Confluence page 806748161).

### Pattern A: Engine Crash (Segfault, Abort, Stack Overflow)

**Signals:**
- "Engine last termination reason" card: constant value of 1 with label `Failed` or `Done`
- "Engine container restarts" card: shows restart via `spcs.container.restarts.total`
- Log messages containing `"segmentation fault"` at error level
- Core dumps generated on segfaults

**Segfault-specific:**
- Detected via monitor alerting on messages containing "segmentation fault" at error level
- Core dumps can be retrieved and inspected (documented at ES page 385253381)
- Core dump is created only if engine segfaults (UNIX signal 11, 11.1, 11.2, or 11.128)

**Stack overflow-specific:**
- Do not always cause a crash; can be handled gracefully resulting in abort reason "internal server error" (NCDNTS-5203)
- No monitoring set up specifically for them
- If they crash, a corresponding log message will be at error level

**Escalation:**
- Julia runtime segfaults -> Julia team
- Storage/network stack segfaults -> Storage team
- Stack overflows in metadata layer -> Backend team

### Pattern B: Out of Memory (OOM)

**Signals:**
- "Engine last termination reason" card: constant value of 1 with label `FailedWithOOM`
- "Engine container restarts" card: shows restart
- Jemalloc profile dumps near OOM time:
  - `"[Jemalloc] absolute profile"` — total allocations per function (bytes + percentage)
  - `"[Jemalloc] relative profile"` — delta between successive dumps
- If no Jemalloc dump: use CPU profile from "Engine CPU continuous profiling" section
- Metric: `spcs.container.state.last.finished.reason` = `FailedWithOOM`

**Escalation:** Determined by Jemalloc/CPU profile analysis — hardest to attribute to a team.

**Additional resource:** A dedicated OOM runbook exists at Google Doc `1X798g5PSkoZdrm_eUSaiRJKCOW-IyfrkSR38JpgyZRs`.

### Pattern C: Brownout (Interactive Thread Blocking)

**Definition:** Engine's interactive threads blocked or executing non-yielding task. Engine can't accept new transactions, progress existing ones, or emit heartbeats.

**Signals:**
- "Server heartbeats per second" card: bars drop below 1 for extended period
- "ERP: Transaction heartbeats received" card: missing bars (when brownout > 30s)
- "Julia GC time" card: high values -> long GC cycles
- "Julia compilation time" card: high values -> compilation on interactive threads

**Special case — PyRel XS engine brownouts:**
- Continuous brownout of 20+ minutes on XS engines named `pyrel_test_*` in spcs-int
- Engine stops emitting metrics entirely
- OTEL collector metrics show: increased blocked threads, increased CPU wait time, increased pending disk operations, increased close_wait connections
- When engine recovers, logs `"heartbeat was lost for XXXX seconds"`
- Tracked in NCDNTS-4522, RAI-28970
- Mitigation: PyRel tests moved to S engines to verify XS instance type theory

**Escalation:**
- Julia GC/compilation -> Julia team
- External function calls (Solver/HiGHS) -> respective library team
- All other -> ERP team

### Pattern D: Long Transaction Heartbeat Requests to the ERP

**Signals:**
- "Transaction logs overview" card: thin purple vertical lines stop
- Trace span `bot_keepalive_write_to_kvs`: abnormally long duration (can take up to 1 hour, tracked in RAI-29423)
- When a periodic task hasn't finished within its scheduled period, no subsequent task runs — one slow heartbeat blocks all future heartbeats

**Additional checks:**
- Non-transaction-specific logs from interactive tasks with long durations (project on `thread_id` attribute)
- "Inflight/queued transactions" card for concurrent transactions
- CPU profile from "Engine CPU continuous profiling" section
- Check if brownouts are ongoing

**Escalation:** ERP team (known unknown)

### Pattern E: Engine Lifecycle Events (False Positives)

**Signals:**
- "Service lifecycle events" or "ERP-initiated lifecycle events" cards show deletion/creation/suspension/upgrade
- "Engine uptime" card: metric drops steeply then slowly recovers
- Newer ERP versions use specific abort reasons; older versions still report `engine failed`

**Action:** Reach out to account owners to upgrade native app

### Pattern F: Scheduled Snowflake Maintenance

**Signals:**
- "Engine container status" card: "running" line drops and comes back up
- Timing: Monday-Thursday, 11 PM to 5 AM local time in the deployment region
- Gauge host metrics: `spcs.container.state.running` drops, `spcs.container.state.pending.reason` increases
- Two lines for "running" state indicate container migration

**Action:** No escalation needed; announce in `#team-prod-snowflake-integration`. Linked repairs: SFRAI-139, RAI-29329.
- Time zone converter: https://www.worldtimebuddy.com/?pl=1&lid=100,8,2643743,5&h=100&hf=1

---

## 4. Diagnostic Lookup Table (Card -> Root Cause)

Quick-reference after filtering the Engine Failures dashboard by transaction ID, engine name, and account:

| What You See | Root Cause |
|---|---|
| "Engine last termination reason" = `Failed` or `Done` | Engine crash (segfault, abort, stack overflow) |
| "Engine last termination reason" = `FailedWithOOM` | OOM |
| "Server heartbeats per second" bars don't reach 1 | Brownout |
| Above + missing bars in "ERP: Transaction heartbeats received" | Brownout affecting the transaction |
| Above + high "Julia GC time" or "Julia compilation time" | Memory pressure or compilation warmup |
| "Transaction logs overview" stops showing thin purple vertical lines | Long heartbeat requests to ERP |
| "Engine uptime" drops + events in lifecycle cards | Engine lifecycle event (likely false positive) |
| "Engine container status" running drops Mon-Thu 11PM-5AM local | Scheduled Snowflake maintenance |

---

## 5. Heartbeat Mechanism

- Periodic task `TxnKeepAlive - id: <transaction_id>` runs every **30 seconds** on the engine
- Communicates with ERP endpoint `/api/v1/transactionHeartbeat`
- Code: started in `Server.jl` line ~1894, implemented in `packages/RAI_KVStore/src/spcs.jl` line ~487
- If ERP doesn't receive heartbeat for **20 minutes**, it aborts with "engine failed"

---

## 6. Engine Failures Dashboard — Step-by-Step Usage

Dashboard: [Engine failures](https://171608476159.observeinc.com/workspace/41759331/dashboard/41949642)

### Step 1: Set Parameters
Copy from the "Affected transactions" card:
- **Transaction ID** — filters logs and heartbeats to that transaction
- **Engine name** — filters logs and metrics to that engine
- **SF account alias** or **account id** — filters to the ERP instance for that account

### Step 2: Zoom Into Transaction Activity
Use "Transaction logs overview (set transaction id)" card. Zoom to the timeframe where logs indicate activity. Always include the failure timestamp from "Affected transactions" card.

### Step 3: Inspect Diagnostic Cards
Walk through the diagnostic lookup table. Check transaction logs, engine-wide logs, ERP logs, and "Other engine metrics" section. For crashes, look for error-level log messages about segfault or stack overflow.

### Troubleshooting Missing Dashboard Data
When a card has no data, check the DataDog fallback: [Engine failures (SPCS version)](https://app.datadoghq.com/dashboard/5u7-367-vkv). Both dashboards share design principles but differ in metric breadth.

---

## 7. SPCS Architecture

### Three Major Components
1. **Native App Package** — installable artifact with SQL scripts, SPCS container images, Streamlit UI, manifest
2. **SQL Integration Layer (sql-lib / spcs-sql-lib)** — SQL objects exposing RAI functionality (procedures, UDFs, tasks, streams)
3. **Engine Resource Provider (ERP)** — single-tenant coordinator service in SPCS for metadata and resource management

### Two Service Layers (NO end-to-end tracing between them)
- `spcs-integration` (SQL layer) — procedures, data stream tasks
- `spcs-control-plane` (ERP) — engine/DB management, transaction coordination
- Correlation: `pyrel_program_id`, `sf.query_id`/`request_id`, or hashed DB name

### Provider vs Consumer Account
- **Provider**: Hosts App Package, image repos, billing config. No running app code.
- **Consumer**: Where Native App is installed. All RAI services run here.
- **Events Account**: Dedicated per region for telemetry forwarding.

### Compute Pool Instance Types
| Pattern | Instance | Purpose |
|---|---|---|
| `*_COMPUTE` | STANDARD_2 | Control plane |
| `*_COMPUTE_XS` | HIGH_MEMORY_1 | XS engines |
| `*_COMPUTE_S` | HIGH_MEMORY_2 | S engines |
| `*_COMPUTE_XL` | HIGH_MEMORY_5 | XL engines |

### Deployment Ring Order
Int -> Staging -> Prod Ring 0 -> Prod Ring 1 (approval required) -> Prod Ring 2 (approval required)

### Mapping Consumer Account to Provider Account
- Provider account details: SPCS CI/CD Accounts doc (Confluence page 1169260556)
- One provider per environment
- Observe query to find mapping:
```opal
make_col PROVIDER_ACCOUNT_NAME:string(attributes.PROVIDER_ACCOUNT_NAME)
make_col PROVIDER_ACCOUNT_LOCATOR:string(attributes.PROVIDER_ACCOUNT_LOCATOR)
make_col CONSUMER_ACCOUNT_LOCATOR:string(attributes.CONSUMER_ACCOUNT_LOCATOR)
make_col CONSUMER_ACCOUNT_ORG:string(attributes.CONSUMER_ORGANIZATION_NAME)
filter metric = "telemetry.spcs.consumer_application_state"
pick_col timestamp, account_alias, org_alias, PROVIDER_ACCOUNT_NAME, PROVIDER_ACCOUNT_LOCATOR, CONSUMER_ACCOUNT_LOCATOR, CONSUMER_ACCOUNT_ORG
dedup account_alias
```

---

## 8. Telemetry Pipeline

```
SPCS Services (rai-server, spcs-control-plane, etc.)
    -> Consumer OTel Collector (consumer-otelcol)
    -> Event Table (TELEMETRY.TELEMETRY.SHARED_EVENTS)
    -> Event Sharing (to Events Account)
    -> O4S Native App tasks
    -> Observe
    -> Datadog (via configured pipelines)
```

### Telemetry Types
- **Continuous logs**: Services -> stdout -> OTel collector -> event table -> Observe
- **On-demand logs** (sensitive): Services -> OTel collector -> private stage file on consumer account (not sent to Observe by default)
- **Traces**: Services -> OTel tracing library -> OTel collector -> stdout -> event table
- **Metrics**: Services -> Prometheus -> OTel collector scrapes -> stdout -> event table
- **NA SQL logs/traces**: Stored procedures/UDFs emit directly to event table

### Telemetry Latency
- Threshold: If > 30 minutes, post in `#ext-relationalai-observe`
- Check O4S task durations: [O4S Pipeline Health dashboard](https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-O4S-Pipeline-Health-42090551)
- If latency increasing, upsize the `observability_wh` warehouse:
```sql
ALTER WAREHOUSE observability_wh SET warehouse_size=MEDIUM;
```

---

## 9. Telemetry Outage Runbooks (SPCS Observability)

From Confluence page 1697054722 (SPCS space Observability > Runbooks).

### Event Table Telemetry Outage
Monitor: [Event Table Telemetry Outage](https://171608476159.observeinc.com/workspace/41759331/count-monitor/Event-Table-Telemetry-Outage-42741161)

**Decision tree:**
1. Check Observe status page: https://status.observeinc.com/
2. Check if event table has recent telemetry (< 20 min):
```sql
SELECT * FROM TELEMETRY.TELEMETRY.SHARED_EVENTS
WHERE TIMESTAMP > DATEADD(minute, -20, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC LIMIT 100;
```
3. If no telemetry -> Snowflake pipeline issue -> File Sev-1 support case
4. If telemetry present -> Check O4S tasks:
```sql
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE DATABASE_NAME = 'OBSERVE_FOR_SNOWFLAKE'
AND NAME LIKE 'O4S_TASK_SEND_EVENT%'
AND SCHEDULED_TIME >= DATEADD('hour', -12, current_timestamp())
ORDER BY COMPLETED_TIME DESC;
```
5. If task stuck (STATE=EXECUTING for > 20 min) -> Cancel it:
```sql
SELECT SYSTEM$CANCEL_QUERY('<QUERY_ID>');
```
6. If no scheduled tasks -> Check O4S app installed -> If yes, raise Observe incident
7. Notify `@reliability` in `#helpdesk-observability`

### SPCS Logs Outage / NA Logs Outage / OTEL Metrics Outage / Platform Metrics Outage / NA Spans Outage
All follow the same pattern:
1. Check Observe status page
2. Verify specific telemetry type in event table (filter by RECORD_TYPE = 'LOG'/'METRIC'/'SPAN')
3. If missing -> Sev-1 to Snowflake
4. Notify `@reliability` in `#helpdesk-observability`

### Observe Ingestion Lag
1. Upsize `observability_wh` warehouse to next tier
2. Thread in `#ext-relationalai-observe` tagging @Austin Nixon @Arthur Dayton
3. Notify `@reliability` in `#helpdesk-observability`

---

## 10. Investigate Missing Telemetry (Detailed Runbook)

From Confluence page 1339392001.

### Step 1: Find Events Account for Consumer
Use [Consumer-Forwarder mapping worksheet](https://171608476159.observeinc.com/workspace/41759331/worksheet/-MONITOR-RUNBOOK-Consumer-Account-Forwarder-Account-Mapping-42409423)

### Step 2: Observe Investigations — Check O4S Tasks
- Check task history in the events account
- Look for errors from O4S tasks:
```sql
SELECT * FROM TELEMETRY.TELEMETRY.SHARED_EVENTS
WHERE RECORD_TYPE = 'LOG'
AND RESOURCE_ATTRIBUTES['snow.application.name'] = 'OBSERVE_FOR_SNOWFLAKE'
AND RESOURCE_ATTRIBUTES['snow.executable.name'] LIKE '%SEND_EVENT_TABLE%'
AND TIMESTAMP > '<start_time>'
ORDER BY timestamp DESC;
```

### Step 3: Events Account — Check Event Table Directly
- Query for logs: filter `VALUE LIKE '%resourceLogs%'` with env, engine_name, service
- Query for traces: filter `VALUE LIKE '%resourceSpans%'`
- Query for metrics: use LATERAL FLATTEN on OTLP JSON structure

### Step 4: Consumer Side (internal accounts only)
- Verify event sharing enabled: `DESC APPLICATION <APP_NAME>;` check `share_events_with_provider = TRUE`
- If FALSE: `ALTER APPLICATION <APP_NAME> SET SHARE_EVENTS_WITH_PROVIDER = TRUE;`
- Check consumer event table directly
- Check consumer stage files (on-demand logs)

---

## 11. ERP Actionable Monitoring

From Confluence pages 655491086 and 658407425.

### How It Works
ERP defines `AlertingError` with upstream component, error, and reason code. Error codes follow pattern: `erp_{component}_{reason}`.

### Components
```
InternalComp, DBRPComp, EngineRPComp, MetadataComp, TxnRPComp,
BlobGCComp, SnowflakeComp, AWSS3Comp, EngineComp, ServerComp,
CPUProfilerComp, TxnEventComp, UnknownComp
```

### Alert Channel
`#erp-observe-monitor` — receives alerts from [ERP Actionable Monitor v2](https://171608476159.observeinc.com/workspace/41759331/promote-monitor/ERP-actionable-monitor-v2-42488209)

### Diagnostic Steps (for any ERP alert)
1. **Check alert**: Click "View Notification" in Slack
2. **Check trace**: Click "View Trace" for flame chart view
3. **Check logs**: Navigate via trace -> logs -> transaction (or filter by request_id/sf.query_id in OPAL)
4. **Check stack trace**: Expand root span for error stack
5. **Take action by error code**: See below

### Error Code Reference and Actions

#### `erp_engine_enginepending`
- Check engine status via OPAL: `filter ((string(attributes['rai.engine_name']) = "<engine>"))`
- If engine just created: transaction may have been sent before engine was ready (transient)
- If engine long-running: check for maintenance window, OOM, or Snowflake network issues

#### `erp_enginerp_engine_provision_timeout`
- Check logs for engine polling status (PENDING messages)
- If engine stuck PENDING: may be bad code or Snowflake compute pool issue
- File Snowflake ticket with account name, service name, provision period

#### `erp_sf_unknown`
- SQL client error querying Snowflake
- Get `sf.query_id` from trace, filter logs by it
- Determine if client-side (e.g., invalid compute pool) or server-side issue

#### `erp_txnevent_internal_stream_write_error`
- Usually S3/blob throttling (transient)
- No customer impact or SLO impact typically
- If encounter count >= 2, raise to `#team-prod-engine-resource-providers-spcs`

#### `erp_blobgc_sf_unknown`
- BlobGC Snowflake query error (usually transient)
- If not continuously happening, mark as transient (retry handles it)
- Otherwise escalate to `#team-prod-engine-resource-providers-spcs`

#### `erp_spcs_internal_request_reading_error`
- Check if endpoint is `/api/v1/transactionHeartbeat`
- If heartbeat and only once: transient, mitigate
- If > 2 times: escalate to `#team-prod-engine-resource-providers-spcs`

#### `erp_spcs_awss3_txn_get_txn_artifacts_error`
- Check transaction logs for unexpected status (e.g., already aborted)
- Often client-side wrong behavior (downloading artifacts from aborted transaction)

#### `erp_enginerp_internal_engine_provision_timeout`
- Check engine provision logs for PENDING status
- File Snowflake ticket if not engine-side issue

#### `erp_txnrp_internal_db_init_failed`
- Get transaction ID and database name from trace
- Check for race condition: database deleted before transaction commit
- If delete-before-commit pattern: transient, safe to mitigate

#### `erp_raiclient_engine_send_rai_request_error`
- ERP cannot reach engine. Possible causes:
  1. Engine in brownout (check CPU, memory, heartbeat)
  2. Engine doing blocking operation (e.g., loading compile cache)
  3. Snowflake network issue (timeouts/connection errors)
- If due to blobgc and not continuously failing > 1 hour: ignore

#### `erp_enginerp_sf_oauth_token_expired`
- Check if reconnect succeeded: filter `content ~"reconnect success"`
- Check customer-side response: filter `content ~"end-user request"`
- If both OK: transient, mitigate

#### `erp_txnrp_awss3_get_object_error`
- S3 throttling due to new bucket repartitioning
- ERP and engine have retry logic
- If retries failing or customer impact: escalate

#### `*_transaction_cache_not_found_error`
- Usually ERP restart: mapping cache lost
- If no field/customer concern: safe to close

#### `erp_jobrp_engine_send_rai_request_error`
- Open trace, find `rai.job_id`, filter logs by it
- If retry happening and final response 200: transient

#### `erp_internallogicrp_sf_invalid_image_in_spec`
- After NA upgrade, image temporarily unavailable
- If no transaction failures within 1 hour: duplicate of NCDNTS-10633
- Repair tracked in RAI-43310

#### `erp_logicrp_sf_unknown` / `erp_graphindex_sf_unknown`
- If error contains "Processing aborted due to error 300002": internal Snowflake error
- File Snowflake ticket via https://app.snowflake.com/us-west-2/esb29457/#/support
- Often transient; check trace for broad user impact

#### `erp_blobgc_internal_blobgc_circuit_breaker_open`
- Circuit breaker opened after 3 consecutive BlobGC failures (blocks for 12 hours)
- Search logs for `"[blobgc] circuit breaker is open due to error"` to find root cause
- Investigate the underlying error

### How to Mute an Alert
**Option 1**: Create a mute window on the monitor
**Option 2**: Edit the monitored dataset OPAL to add a `filter` exclusion (annotated with reason + incident link)

---

## 12. ERP Diagnostic 101

From Confluence page 756023297.

### Key Concept: Snowflake batch ID -> sf.queryId -> rai transaction ID
- ERP uses the first passed-in query ID as `sf.queryId` and creates the transaction with it
- Batch ID may be a set of Snowflake query IDs — may need to truncate last 2 chars and use contains filter

### Finding Logs for a Transaction
Portal: https://171608476159.observeinc.com/workspace/41759331/log-explorer?datasetId=41832558
```opal
filter label(^Service) = "spcs-control-plane"
filter label(^Environment) = "spcs-int"
filter ((string(attributes['sf.query_id']) = "<batch_id>")) OR (attributes['rai.transaction_id'] = "<batch_id>")
```

### Finding Traces for a Transaction
Portal: https://171608476159.observeinc.com/workspace/41759331/trace-explorer?spanDatasetId=41867217
```opal
filter span_type = "Service entry point"
filter ((string(attributes['sf.query_id']) = "<batch_id>")))
```

### Finding Metrics
Portal: https://171608476159.observeinc.com/workspace/41759331/metric-explorer
Search ERP code for metric names: https://github.com/search?q=repo%3ARelationalAI%2Fspcs-control-plane%20prometheus&type=code

---

## 13. Common Debugging Techniques

From Confluence page 573603858.

### Transaction Logs
- DataDog: `@rai.transaction_id:<txn_id>` in service `rai-server`
- Observe: filter by `rai_transaction_id`
- View engine-wide logs via "view in context" or filter by engine name

### Traces
- DataDog: `@rai.transaction_id:<my_txn_id>` in APM traces
- Observe: filter in trace explorer

### Key Dashboards (DataDog — mostly Azure)
- [DWI](https://app.datadoghq.com/dashboard/az9-6ez-5jc/distributed-workload-indicators) — CPU, pager, blob storage, Julia
- [Engine Health](https://app.datadoghq.com/dashboard/bk4-9nq-6gt) — process lifetime, Julia runtime
- [Pager Metrics](https://app.datadoghq.com/dashboard/83g-cwc-75y)
- [Performance Triage](https://app.datadoghq.com/dashboard/75z-4wj-tw9)
- [Transaction Details](https://app.datadoghq.com/dashboard/nt6-ze5-6a4)
- [Optimizer Dashboard](https://app.datadoghq.com/dashboard/bed-fje-kia)
- [Compilation Times](https://app.datadoghq.com/dashboard/r8d-2aq-a62)
- [Cancellation Dashboard (Azure)](https://app.datadoghq.com/dashboard/cj9-2wy-mui)
- [Cancellation Dashboard (SPCS)](https://app.datadoghq.com/dashboard/egm-2bn-xwz)

### OOM Checks
- [Engine Health](https://app.datadoghq.com/dashboard/bk4-9nq-6gt) — Process Lifetime section

### Wall-time Profiles
- Useful for identifying root cause when rule evaluation gets stuck
- SPCS tooling: https://github.com/RelationalAI/spcs-sql-lib/pull/329 (engines created after end of Dec 2024)

---

## 14. Getting Signals from a Running Engine

From Confluence page 573767695.

### SPCS: On-Demand Profiling
See [on-demand profiling page](https://relationalai.atlassian.net/wiki/spaces/ES/pages/515637250)

### RAICloud (Azure): Profiling via kubectl

**Julia Task Stacktraces (preferred):**
```bash
./julia-debug-engine <account_name> <engine_name> task_backtraces
```
Uses ProfileEndpoints.jl. Much faster than GDB. Fails if engine is stuck (brownout) — fall back to GDB.

**GDB Thread Backtraces (fallback for brownouts):**
```bash
./julia-stacktrace-k8s <account_name> <engine_name>
```

**CPU Profile:**
```bash
./julia-debug-engine <account> <engine_name> profile "duration=5.0&n=1e8&delay=0.1" [out_file]
```
View with: `pprof -http localhost:57599 <out_file>.pb.gz`

**Wall-time Profile:**
Same as CPU but use `profile_wall` instead of `profile`

**Allocation Profile:**
```bash
./julia-debug-engine <account> <engine_name> allocs_profile "duration=30&sample_rate=0.0001"
```

**Jemalloc Heap Profile:**
NOTE: Jemalloc profiling has been disabled.

**Heap Snapshot:**
```bash
./julia-debug-engine <account-name> <engine-name>
```
Saves profile streamed in parts. Recombine with Julia: `Profile.HeapSnapshot.assemble_snapshot("./tmp/julia.heapsnapshot")`

---

## 15. Long Cancellation Investigation

From Confluence page 605257729. Informal threshold: 5 seconds.

### Key Log Messages (chronological)
1. `"V2: User requested to cancel transaction"` — `txn_duration` = time since transaction began
2. `"V2: Signaling transaction cancellation"` — `txn_duration` = time to send CancelledException
3. `"V2: Marking transaction aborted due to user-requested Cancellation"` — end of cancellation

### Investigation Steps
1. Check transaction AND engine logs for internal errors
2. Check DataDog trace — use `txn_duration` offsets to find position in control flow
3. Check if other transactions were running during cancellation (inflight transaction count)
4. Check if engine restarted during cancellation (raiserver uptime drop)
5. Check continuous profiling between "User requested" and "Signaling" logs

### Typical Root Causes
- **Missing cancellation checks**: Long time between "User requested" and "Signaling"
- **Deep recursion**: Long time between "Signaling" and "Marking" — look for `"Recursion status"` log
- **During compilation**: Log `"INFO: Transaction cancelled while compiling"`
- **Flooding with short transactions**: >400 short transactions during cancellation
- **Concurrent transactions**: Even trivial transactions can take >10s to cancel
- **Internal error**: e.g., keep alive task failure delays cancellation
- **Opening a database concurrently**: Can produce long or incorrect cancellation

---

## 16. BlobGC Runbook

From Confluence page 1686241283.

### Background
BlobGC garbage collects blob storage — identifies and deletes unreachable blobs. Runs in background of idle engines. If no successful pass in a week, a dedicated BlobGC engine is started.

Dashboard: [BlobGC Dashboard](https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311)
Slack: `#component-blobgc`

### Blob States
- **Reachable**: in databases or in use by running engines
- **Unreachable**: eligible for deletion after grace period (2+ days)
- **Stray**: discovered through listings, labeled in next pass

### Cause: Long Running Transaction
- Generates high data volumes
- Prevents blob deletion while engine runs
- **Action**: Cancel transaction, suspend/delete engine

### Cause: No BlobGC Pass Completed
Key log messages:
- `BlobGC: pass complete pager` — last successful pass
- `BlobGC: progress update` — running pass progress
- `starting gc pass on engine` — pass started

**Create dedicated BlobGC engine:**
```sql
CALL relationalai.api.create_engine(
    'blobgc', 'HIGHMEM_X64_S',
    {'auto_suspend_mins': 60, 'await_storage_vacuum': true}, null
);
```
Wait for `"[blobgc] finished a blobgc run successfully..."` then delete: `CALL api.delete_engine('blobgc');`

### Cause: BlobGC Running But Not Deleting
Grace period hasn't expired. Reduce to minimum (2 days):
```sql
CALL relationalai.api.set_storage_vacuum_grace_period(172800, 'CONFIRM_GRACE_PERIOD_UPDATE');
```

### Cause: BlobGC Failing
Check logs for `BlobGC: pass failed`. If state corrupted, trigger full BlobGC:
```sql
CALL relationalai.api.create_engine(
    'full_blobgc', 'HIGHMEM_X64_S',
    {'auto_suspend_mins': 60, 'await_storage_vacuum': true}, null
);
```
WARNING: Full BlobGC resets grace period — deletion delayed significantly.

### Cause: BlobGC OOM'ing
For large data, BlobGC is memory intensive. May need bigger engine size until successful pass reduces storage.

---

## 17. Julia Compilations Cache (JCC) Runbook

From Confluence page 890929153.

### How It Works
- Engine loads cache packages on startup from customer SF stage
- ERP checks every 10 minutes if cache build needed
- Build triggers: version change, > 24h since last build, previous failure (up to 3 retries)
- Max build time: 2 hours

### Cache Loading Failed
**Should not crash the engine** — only log error and trigger incident.
If it causes crashes or high `program_rss`:
1. Disable compilations cache on the account
2. Reprovision affected engines:
```sql
USE DATABASE <NATIVE_APP_NAME>;
CALL api.suspend_engine(<ENGINE_NAME>);
CALL api.resume_engine(<ENGINE_NAME>);
```
Or for many engines:
```sql
CALL app.deactivate();
CALL app.activate();
```

### Enable/Disable Compilations Cache
```sql
USE DATABASE RAI_INT_APP_PKG; -- replace with provider package
CALL CONFIG.enable_comp_cache('ESB29457'); -- UPPERCASE account locator
-- OR
CALL CONFIG.disable_comp_cache('ESB29457');
```
Takes up to 6 hours to take effect.

### Cache Hit Rate Diagnosis
Use [compilations cache dashboard](https://app.datadoghq.com/dashboard/t8r-m5t-tv6/compilationscache-dashboard). If hit rate drops after application logic change, cache takes time to recover.

### Common ERP Errors
- `[compcache] [trigger] failed to start compilation run: failed to provision...` -> `#team-prod-engine-resource-provider`
- `Warehouse 'RELATIONAL_AI_ERP_WAREHOUSE' is suspended` -> User misconfiguration
- `found compilations cache run in provisioning state` -> ERP restart during provisioning (usually ignore single occurrence)

### Monitors
- ERP: [DD](https://app.datadoghq.com/monitors/158815508), [Observe](https://171608476159.observeinc.com/workspace/41759331/threshold-monitor/Compilations-Cache-ERP-Monitor-42287441)
- RAICode: [DD](https://app.datadoghq.com/monitors/156953732), [Observe](https://171608476159.observeinc.com/workspace/41759331/count-monitor/SEV3-CompCache-Coordinator-job-failed-42312891)

---

## 18. Auto Engine Upgrade Failed Runbook

From Confluence page 828669967.

### Context
Engine upgrades enforced every Monday 10am UTC. Users can reschedule.

### Monitor
[Auto engine upgrade monitor](https://171608476159.observeinc.com/workspace/41759331/monitor/Auto-engine-upgrade-failed-42026258)

### Investigation Steps
1. Open alert detail from Jira ticket
2. Click "View Logs" to find account, region, failure message
3. In DataDog: filter `"upgrade failed" status:error` for the time period
4. Get `sf.query_id` from error log for detailed query
5. Contact Fields for affected accounts to recreate engines

---

## 19. Deployment Failure Runbook

From Confluence page 1500184577.

### General Pattern
1. Open failed GitHub workflow run
2. Identify failure type (test vs infra/tooling)
3. Take action based on type

### For Test Failures
- **Transient**: Re-run failed jobs. If succeeds, mitigate and assign to owning component.
- **Code change**: Add poison commit, deploy patch/antidote, trigger rollback.
- **Unclear**: Assign to owning component.

### Incident Routing
| Failure Type | Rotation | Channel |
|---|---|---|
| Pipeline failures (not test) | Engineering - Infrastructure, NA Deployments | #project-prod-continuous-delivery |
| SmokeTests / NativeAppTests | Engineering - Infrastructure, NA Integration | #team-prod-snowflake-integration |
| Pre/Post-Upgrade (SQLLIB) | Engineering - Infrastructure, NA Integration | #team-prod-snowflake-integration |
| Pre/Post-Upgrade (ERP) | Engine & Rel compiler, Engine Resource Providers | #team-prod-engine-resource-providers-spcs |
| PyRel tests | UX, PyRel | #team-prod-experience |

### 10k DBs Limit
Error: `Bad Request - database count has reached the 10k limit. Please clean up and retry. (RAIERR:1000)`
- Clean databases older than 7 days using: https://github.com/RelationalAI/relationalai-python/blob/main/src/relationalai/util/clean_up_databases.py
- List existing DBs: `select * from rai_prod_app.api.databases;`

---

## 20. Billing Incident Handling

From Confluence page 745799681.

### Triage
- **Over-billing**: Always high priority. Discuss in `#project-snowflake-billing`.
- **Under-billing**: Categorized by severity:
  - Sporadic recoverable: Low severity
  - Continuous failures: Medium severity (activities may expire)
  - Unrecoverable: High severity

### Consumption Component Issues
- Task: `RELATIONALAI.CONSUMPTION.CAPTURE_5_MINUTES_ENGINE_USAGE`
- If task unhealthy: regression or Snowflake issue
- If `list_engine` API unhealthy: known ERP issue (ERP down, warehouse down)
- Recovery: `CALL App.Recover()` to restart tasks

### Billing Component Issues
- Task: `RELATIONALAI.BILLING.BILL_NEW_USAGE_SINCE`
- If SF API unhealthy: file Sev-2 with Snowflake
- Recovery: `CALL App.Recover()` to restart tasks
- 7-day window to correct billing before Snowflake refuses corrected invoices

### Billing Dashboards
- [Snowflake Billing Support](https://171608476159.observeinc.com/workspace/41759331/dashboard/42073498)
- [Per-customer Billing Insights](https://171608476159.observeinc.com/workspace/41759331/dashboard/-Deprecated-Snowflake-Per-customer-Billing-Insights-42208826)

---

## 21. Assessing Incident Impact

From Confluence page 700710913.

### Which User Submitted a Transaction?
Each transaction emits a `new transaction` log with `CreatedBy` attribute.
- **Observe**: `rai_transaction_id = '<id>' content = 'new transaction'`
- **DataDog**: `@rai.transaction_id:<id> "new transaction"`

### How Old Is a Database? Was It Cloned?
- **Observe**: `attributes["rai.database_name"] = '<name>' content ~ 'created database'`
- Clone indicated by additional text with source database name

### Which Accounts/Engines Are Affected?
- **Observe**: `content ~ '<error_string>' Environment = '<environment>'`
- Group by engine name or account name

### Which Engines Run a Specific Version?
**Observe OPAL** (timeframe: last 4 hours):
```opal
@running <- @ { filter ((content ~ '[SERVER] Server is still running.' or content ~ '[SERVER] Enter event loop') and string(attributes["rai.engine_version"]) = "<version>")}
filter content ~ 'has been deleted successfully' or content ~ 'received engine suspension request for'
follow_not (rai_engine_name = @running.rai_engine_name)
statsby Count:count(1), group_by(rai_engine_name)
sort desc(Count)
```

**Suspended engines** (timeframe: version release date to now):
```opal
@engines_on_version <- @ { filter string(attributes["rai.engine_version"]) = "<version>"}
filter content ~ 'received engine suspension request for'
follow rai_engine_name = @engines_on_version.rai_engine_name
statsby Count:count(1), group_by(rai_engine_name)
sort desc(Count)
```

---

## 22. Error Categorization (Graph Index)

All errors follow a consistent structure:

### Expected Errors (user-actionable, `expected_error: true`)
| Error | Source | Resolution |
|---|---|---|
| Change Tracking Not Enabled | Table name | Enable change tracking on source table |
| CDC Task Suspended | cdc | Investigate root cause, run `CALL app.resume_cdc()` |
| Data Stream Quarantined >15 min | Table name | Review quarantine reason |
| Invalid Object Type | Table name | Reference only tables or views |

### Unexpected Errors (system failures, `expected_error: false`)
| Error | Source |
|---|---|
| Engine Failures | engine name |
| API Normalization Errors | api.normalize_fq_ids |
| Reference Validation Errors | Table name |
| Index Preparation Errors | prepareIndex |

### SLO Calculation
```
success_rate = (successful_unique_use_index_ids / total_unique_use_index_ids) * 100
```
"Successful" = no unexpected errors. Expected errors do NOT reduce SLO.

---

## 23. CDC Pipeline Details

### Data Stream Task (runs every 1 minute, serverless)
- Implementation: `api.base_write_changes` in `spcs-sql-lib/lib/integration/rai_cdc.sql`
- WHEN condition: `SYSTEM$STREAM_HAS_DATA(<stream>)` — only runs if changes exist
- Uses SF transactions for atomic metadata + CSV export
- Serverless pool is bursty at top of hour/day (can cause timeouts)

### process_batches Task (singleton, runs every 1 minute)
- Implementation: `api.process_batches()` in `spcs-sql-lib/lib/integration/rai_cdc.sql`
- Two work item types: DB Preparation (model installation) and Batch Loading (data import)
- Transactions via CDC_MANAGED_ENGINE
- One transaction per target DB at a time
- Generated Rel avoids stdlib dependencies

### Stream Stale State
- SF Stream holds an offset timestamp for last consumed position
- If stream falls behind data retention window -> **stale** (unrecoverable)
- Data stream must be recreated

---

## 24. Escalation Channels

| Issue Type | Slack Channel |
|---|---|
| Engine failures (oncall) | #team-prod-engine-resource-providers-spcs |
| Native App integration | #team-prod-snowflake-integration |
| PyRel/UX issues | #team-prod-experience |
| Observability issues | #helpdesk-observability |
| Slow queries | #helpdesk-slow-queries |
| CI/CD failures | #project-prod-continuous-delivery |
| Observe vendor issues | #ext-relationalai-observe |
| Snowflake support | #ext_rai-snowflake |
| Billing | #project-prod-snowflake-billing |
| ERP monitor alerts | #erp-observe-monitor |
| BlobGC issues | #component-blobgc |
| Compilations cache alerts | #feed-alerts-compcache |
| Compilations cache team | #project-compilations-cache |
| Release notes | #team-prod-release |

### Escalation by Failure Type
| Failure | Team |
|---|---|
| Julia runtime segfault | Julia team |
| Storage/network segfault | Storage team |
| Stack overflow in metadata | Backend team |
| OOM | Determine from Jemalloc/CPU profiles |
| Brownout from GC/compilation | Julia team |
| Brownout from external calls (Solver/HiGHS) | Respective library team |
| Brownout (other) | ERP team |
| Long heartbeat requests | ERP team |
| Snowflake maintenance | No escalation, announce in #team-prod-snowflake-integration |
| Engine provision timeout | ERP team + potentially Snowflake ticket |

### How to Route an Incident to Another Loop
Edit the "Affected Services" field in the incident: remove Engine, add the target loop (e.g., Infra, Compiler). Add a comment explaining why. Find oncallers at https://relationalai.atlassian.net/jira/ops/who-is-on-call (view "All schedules").

### How to Rechannel an Incident
Use "Rechanneled" status when incident needs dedicated team investigation. Create new Slack channel for it (e.g., `#ncdnts-1232`).

---

## 25. Error 404 in Metadata

From Confluence page 575176706.

HTTP 404 when accessing metadata indicates the transaction failed before metadata could be committed (possible OOM). The workflow tries to pull metadata in a subsequent step, which fails because there is none.

---

## 26. Hotfix vs Patch Process

From Confluence page 1411842085.

- **Patch**: Fix for issues in releases NOT YET in production. Deploys to staging only.
- **Hotfix**: Fix for issues ALREADY in production. Full ring deployment: staging -> ring-0 -> ring-1 (approval) -> ring-2 (approval).

### When to Use Which
- Release hasn't reached ring-1: **Patch**
- Release has reached ring-1 or later: **Hotfix**

### Targeted Hotfix (specific customer)
- Skips staging and internal ring-0
- Tests in pre-release app in spcs-prod consumer account
- Limited to one account per workflow run

---

## 27. Network Access Policies

From Confluence page 745996289.

### Emergency: Drop Network Policy
```sql
ALTER ACCOUNT SET NETWORK_POLICY = null;
SHOW PARAMETERS LIKE 'network_policy' IN ACCOUNT;
```

### If Tailscale Down
1. Use `SPCS_CICD_USER` (any-IP whitelisted) via GitHub workflow
2. George Nalmpantis and Thomas Weber are whitelisted from any IP
3. Use Azure deployment VM public IPs (also whitelisted)

---

## 28. Key Dashboard References

### Observe Dashboards
| Dashboard | URL | Purpose |
|---|---|---|
| Engine failures | https://171608476159.observeinc.com/workspace/41759331/dashboard/41949642 | Transaction abort investigation |
| BlobGC | https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311 | BlobGC health |
| ERP Actionable Monitor | https://171608476159.observeinc.com/workspace/41759331/promote-monitor/ERP-actionable-monitor-v2-42488209 | ERP error monitoring |
| CPU Profiling | https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-Continuous-CPU-Profiling-41782266 | CPU continuous profiling |
| Telemetry Outages | https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-Outages-42760073 | Telemetry health |
| O4S Pipeline Health | https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-O4S-Pipeline-Health-42090551 | O4S task durations/latency |
| Billing Support | https://171608476159.observeinc.com/workspace/41759331/dashboard/42073498 | Billing health |
| Log Explorer | https://171608476159.observeinc.com/workspace/41759331/log-explorer?datasetId=41832558 | Log search |
| Trace Explorer | https://171608476159.observeinc.com/workspace/41759331/trace-explorer?spanDatasetId=41867217 | Trace search |
| Metric Explorer | https://171608476159.observeinc.com/workspace/41759331/metric-explorer | Metric search |

### DataDog Dashboards (primarily Azure, some SPCS)
| Dashboard | URL | Purpose |
|---|---|---|
| Engine failures (SPCS) | https://app.datadoghq.com/dashboard/5u7-367-vkv | Fallback for Observe |
| DWI | https://app.datadoghq.com/dashboard/az9-6ez-5jc | CPU, pager, blob, Julia |
| Engine Health | https://app.datadoghq.com/dashboard/bk4-9nq-6gt | Process lifetime, Julia |
| Performance Triage | https://app.datadoghq.com/dashboard/75z-4wj-tw9 | Performance investigation |
| Transaction Details | https://app.datadoghq.com/dashboard/nt6-ze5-6a4 | Transaction drill-down |
| Optimizer | https://app.datadoghq.com/dashboard/bed-fje-kia | Backend optimization |
| Compilation Times | https://app.datadoghq.com/dashboard/r8d-2aq-a62 | Julia compilation |
| Compilations Cache | https://app.datadoghq.com/dashboard/t8r-m5t-tv6 | Cache hit rate |
| Cancellation (Azure) | https://app.datadoghq.com/dashboard/cj9-2wy-mui | Cancel duration |
| Cancellation (SPCS) | https://app.datadoghq.com/dashboard/egm-2bn-xwz | Cancel duration |

---

## 29. Key Log Patterns and Span Names

### Transaction Lifecycle Logs
- `"transaction request has been prepared"` — transaction accepted
- `"[SERVER] Transaction request received"` — server received
- `"TransactionBegin"` — transaction started
- `"[TransactionQueue] Transaction enqueued"` / `"dequeued"` — queue events
- `"rel profiler root"` — Rel execution started
- `"Estimated cardinality of the output relation: N"` — query result size
- `"[COMMIT] Wrote tip for X => Y"` — database version advancement
- `"transaction X marked as COMPLETED"` / `"ABORTED"` — terminal state
- `"TransactionEnd"` — transaction finished
- `"[service review] Transaction finished without internal error"` — clean completion
- `"new transaction"` — contains `CreatedBy` attribute for user identification

### Engine Failure Logs
- `"segmentation fault"` at error level — segfault
- `"[Jemalloc] absolute profile"` — OOM investigation (allocations per function)
- `"[Jemalloc] relative profile"` — OOM investigation (delta between dumps)
- `"heartbeat was lost for XXXX seconds"` — engine recovered from brownout
- `"[SERVER] Server is still running."` — periodic heartbeat (every 4 hours)
- `"[SERVER] Enter event loop"` — server started

### Cancellation Logs
- `"V2: User requested to cancel transaction"` — cancellation initiated
- `"V2: Signaling transaction cancellation"` — CancelledException thrown
- `"V2: Marking transaction aborted due to user-requested Cancellation"` — cancellation complete
- `"INFO: Transaction cancelled while compiling"` — cancelled during Julia compilation
- `"Recursion status"` — deep recursion indicator

### BlobGC Logs
- `"BlobGC: pass complete pager"` — successful pass summary
- `"BlobGC: progress update"` — running pass progress
- `"starting gc pass on engine"` — pass started
- `"BlobGC: pass failed"` — pass failed
- `"[blobgc] finished a blobgc run successfully..."` — run complete
- `"[blobgc] circuit breaker is open due to error"` — circuit breaker triggered

### Compilations Cache Logs
- `"[CompCache]"` — all cache-related messages
- `"[compcache] [trigger] failed to start compilation run"` — build failed to start
- `"Warehouse 'RELATIONAL_AI_ERP_WAREHOUSE' is suspended"` — warehouse down

### ERP Error Codes
Format: `erp_{component}_{reason}` — searchable in traces via `attributes.error_code`

### Key Span Names
- `bot_keepalive_write_to_kvs` — heartbeat task (abnormal duration indicates Pattern D)
- `group_commit` — database commit phase
- `post_to_erp` — posting results to ERP
- `service.CompleteTransactions` — ERP completing transaction
- `eot_tip_write` — end-of-transaction tip write
- `spcscp.spcsHeaderHandler` — ERP header handler (for job request errors)

---

## 30. Key Metrics

### Snowflake Host Metrics
- `spcs.container.state.last.finished.reason` — engine termination reason (`Failed`, `Done`, `FailedWithOOM`)
- `spcs.container.restarts.total` — container restart count
- `spcs.container.state.running` — container running state
- `spcs.container.state.pending.reason` — why container is pending

### Engine Metrics
- Server heartbeats per second (bars should reach 1)
- Julia GC time
- Julia compilation time
- Engine uptime
- Inflight/queued transactions
- CPU utilization

### ERP Metrics
- Transaction heartbeats received
- Engine lifecycle events
- HTTP request counts/durations

---

## 31. Environment-Specific Notes

### Environments
- `spcs-int` — Integration (development/testing)
- `spcs-staging` — Staging
- `spcs-prod` — Production (rings 0, 1, 2)
- `spcs-latest` — Latest (acts as both consumer and provider for telemetry)

### Snowflake Maintenance Windows
Monday-Thursday, 11 PM to 5 AM local time in the deployment region (6-hour window).

### Key Internal Accounts
- `esb29457` — Snowflake support portal account for filing tickets
- Provider accounts require VPN + MFA (Duo only)
- On-callers get `rai-on-caller` role with elevated privileges

### Snowflake Ticket Filing
Portal: https://app.snowflake.com/us-west-2/esb29457/#/support
Provide: account name/locator, error time, query ID if available.

---

## 32. Playbook Design (Agreed Structure for AI Skill)

### Playbook 1: Transaction Investigation (Entry Point)
- **Input:** transaction ID
- **Goal:** Status, customer, what it did (high-level), duration
- **Steps:**
  1. Query transaction dataset -> status, customer (org + account), engine, duration, maxlevel, language
  2. Determine transaction type: CDC (CDC_MANAGED_ENGINE) vs user vs Graph Index
  3. If COMPLETED -> summarize (query spans + logs in parallel for detail)
  4. If ABORTED -> report abort reason, route to Playbook 2 or 3
- **Customer identification:** `org_alias` + `account_alias` (e.g., "Western Union (account: wudev_wudatadev)")

### Playbook 2: Engine Failure Investigation
- **Input:** engine name + transaction ID (from Playbook 1 or alert)
- **Goal:** Root cause classification + escalation path
- **Steps:** Walk diagnostic lookup table:
  1. Check termination reason -> crash or OOM?
  2. Check heartbeats -> brownout?
  3. Check heartbeat span duration -> long heartbeat requests?
  4. Check lifecycle events -> user-initiated?
  5. Check container status timing -> Snowflake maintenance?

### Playbook 3: Data Pipeline Investigation
- **Input:** "data isn't loading" or slow CDC, or data stream errors
- **Goal:** Root cause + remediation
- **Steps:**
  1. Check CDC dashboard for the data stream / account
  2. Check process_batches spans for errors or slow execution
  3. Check for stale streams, quarantined streams, suspended tasks
  4. If slow: debug via slow data loading procedure

---

## 33. Observed Transaction Example

Transaction `6f6d1441-ef58-4986-9c15-3edb74a75a42` was investigated live:

| Field | Value |
|---|---|
| Engine | CDC_MANAGED_ENGINE |
| Account | wudev_wudatadev |
| Org | western_union |
| Environment | spcs-prod |
| Service | spcs-control-plane |
| Language | rel |
| Duration | ~30.27 seconds |
| Max Log Level | info |

### Timeline
| Phase | Duration | Notes |
|---|---|---|
| Queue wait | ~17s | Enqueued -> dequeued |
| Execution | ~5s | Rel query, output cardinality = 0 |
| Commit | ~4.3s | group_commit, DB version 28->29 |
| Completion | ~4s | Cache/metrics, event stream close, auto-suspend |

### Key Spans (heaviest)
| Span | Service | Duration |
|---|---|---|
| group_commit | rai-server | 4.3s |
| post_to_erp | rai-server | 4.07s |
| service.CompleteTransactions | spcs-control-plane | 4.07s |
| eot_tip_write | rai-server | 134ms |
| eot_tip_write_to_blob | rai-server | 101ms |
