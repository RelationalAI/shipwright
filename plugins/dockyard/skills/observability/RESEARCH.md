# Observability Skill — Research Notes

This document captures all research gathered from Confluence documentation, Observe knowledge graph exploration, and live querying during the design of the observability skill. It serves as the source of truth for playbook design.

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
- Flow: SQL procedure → SPCS Control Plane → rai-server engine → results

### CDC Transactions
- Background data sync triggered by `process_batches` task (runs every 1 minute)
- Always run on `CDC_MANAGED_ENGINE` (a single app-managed engine)
- Flow: Source SF Table → SF Stream → Data Stream Task (1min) → CSV to Stage → process_batches → CDC_MANAGED_ENGINE → RAI Database
- One transaction per target DB at a time; next queued item starts immediately after completion
- Generated Rel transactions avoid stdlib dependencies

### Graph Index Transactions
- Automated resource management triggered by `use_index` (called internally by PyRel)
- Flow: use_index (sql-lib) → prepareIndex (ERP) → transaction execution
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

**Escalation:**
- Julia runtime segfaults → Julia team
- Storage/network stack segfaults → Storage team
- Stack overflows in metadata layer → Backend team

### Pattern B: Out of Memory (OOM)

**Signals:**
- "Engine last termination reason" card: constant value of 1 with label `FailedWithOOM`
- "Engine container restarts" card: shows restart
- Jemalloc profile dumps near OOM time:
  - `"[Jemalloc] absolute profile"` — total allocations per function
  - `"[Jemalloc] relative profile"` — delta between successive dumps
- If no Jemalloc dump: use CPU profile

**Escalation:** Determined by Jemalloc/CPU profile analysis

### Pattern C: Brownout (Interactive Thread Blocking)

**Definition:** Engine's interactive threads blocked or executing non-yielding task. Engine can't accept new transactions, progress existing ones, or emit heartbeats.

**Signals:**
- "Server heartbeats per second" card: bars drop below 1 for extended period
- "ERP: Transaction heartbeats received" card: missing bars (when brownout > 30s)
- "Julia GC time" card: high values → long GC cycles
- "Julia compilation time" card: high values → compilation on interactive threads

**Special case — PyRel XS engine brownouts:**
- Continuous brownout of 20+ minutes on XS engines named `pyrel_test_*` in spcs-int
- Engine stops emitting metrics entirely
- OTEL collector metrics show: increased blocked threads, increased CPU wait time, increased pending disk operations, increased close_wait connections
- When engine recovers, logs `"heartbeat was lost for XXXX seconds"`
- Tracked in NCDNTS-4522, RAI-28970

**Escalation:**
- Julia GC/compilation → Julia team
- External function calls (Solver/HiGHS) → respective library team
- All other → ERP team

### Pattern D: Long Transaction Heartbeat Requests to the ERP

**Signals:**
- "Transaction logs overview" card: thin purple vertical lines stop
- Trace span `bot_keepalive_write_to_kvs`: abnormally long duration (can take up to 1 hour, tracked in RAI-29423)
- When a periodic task hasn't finished within its scheduled period, no subsequent task runs — one slow heartbeat blocks all future heartbeats

**Additional checks:**
- Non-transaction-specific logs from interactive tasks with long durations (project on `thread_id` attribute)
- "Inflight/queued transactions" card for concurrent transactions
- CPU profile from "Engine CPU continuous profiling" section

**Escalation:** ERP team

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

---

## 4. Diagnostic Lookup Table (Card → Root Cause)

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

## 6. Key Observe Dashboards

| Dashboard | ID | Purpose |
|---|---|---|
| Engine Failures | 41949642 | Primary oncall dashboard for transaction aborts |
| CPU Profiling | 41782266 | Continuous CPU profiling |
| Performance Triage | 41786648 | Performance investigation |
| Distributed Workload Indicators | 41946298 | Workload distribution |
| Optimizer Dashboard | 41882895 | Optimizer analysis |
| SPCS Environments | 41872510 | Environment overview |
| O4S Pipeline Health | 42090551 | Telemetry pipeline health |
| CDC Investigations | 42469929 | Data stream/CDC issues |
| Telemetry Outages | Telemetry-Outages-42760073 | Telemetry pipeline outages |
| Account Health | SPCS-Account-Health-42358249 | Per-account health |

All in workspace `41759331` at `https://171608476159.observeinc.com/`.

Fallback: DataDog "Engine failures (SPCS version)" at `https://app.datadoghq.com/dashboard/5u7-367-vkv`

---

## 7. Key Datasets in Observe

| Dataset | ID | Type | Description |
|---|---|---|---|
| RelationalAI/Snowflake Logs | 41832558 | Event | Log events with content, severity, attributes |
| RelationalAI/Spans | 41867217 | Interval | Operation timing with parent/child traces |
| Long Running Spans | 42001379 | Interval | Spans exceeding 3 hours (separate for performance) |
| RelationalAI/Metrics | 41861990 | Metric | Time series metrics |
| RelationalAI/Transaction | 41838769 | Interval | Transaction overview (duration, engine, maxlevel) |
| RelationalAI/Engine | 41838774 | Resource | Engine metadata (version, instance family) |
| RelationalAI/Service | 41853352 | Resource | Service lifecycle tracking |
| ServiceExplorer/Service Metrics | 41862479 | Metric | Metrics derived from OTel spans |
| OpenTelemetry/Span | 41766875 | Interval | Generic OTel spans |

---

## 8. Key Correlation Tags and Lookup Keys

| Key | Description | Links to |
|---|---|---|
| `rai_transaction_id` | Transaction identifier | Logs, spans, transaction dataset |
| `rai_engine_name` | Engine name | All datasets |
| `account_alias` | Customer Snowflake account | All datasets |
| `org_alias` | Customer organization | All datasets |
| `sf.query.id` / `sf_query_id` | Snowflake query ID | Logs, spans |
| `trace_id` / `span_id` | Distributed tracing IDs | Spans, logs |
| `host` | Snowflake host FQDN | Logs |
| `phase` | Compiler phase (PhaseInlining, CompilePhase, etc.) | Logs |
| `rai.commit` | Engine commit hash | Logs |
| `pyrel_program_id` | Links use_index and prepareIndex spans | Cross-layer correlation |

---

## 9. Key Metrics

| Metric | Type | Description |
|---|---|---|
| `commit_duration_ms` | delta | How long commits take |
| `transactions_duration_total` | delta | Total transaction duration |
| `commit_txns_failure` | delta | Failed commit count |
| `commit_txns_start_commit` | delta | Commit start count |
| `exception_count_5m` | — | Exception rate (5-minute window, from ServiceExplorer) |
| `jm_local_threads_available` | gauge | Thread availability |

---

## 10. Environments, Services, and Languages

### Environments
`spcs-prod`, `spcs-int`, `spcs-latest`, `spcs-staging`, `spcs-expt`, `spcs-ea`

### Services
- `rai-server` — RAI engine (executes Rel queries)
- `spcs-control-plane` — ERP (orchestrates engine lifecycle, handles API requests)
- `spcs-integration` — SQL integration layer (procedures, data stream tasks)
- `gnn-engine` — Graph Neural Network engine
- `observe-for-snowflake` — O4S telemetry forwarding
- `rai-solver` — Solver service
- `spcs-log-heartbeat` — Log pipeline heartbeat
- `spcs-event-sharing-heartbeat` — Event sharing heartbeat
- `provider-account-monitoring` — Provider account monitoring

### Transaction Languages
- `rel` — RAI's internal query language (being deprecated)
- `lqp` — Logical Query Plan (replacing rel)
- Users write PyRel (Python DSL) which compiles to rel/lqp

### Log Severity Levels
`info`, `warning`, `warn`, `error`, `fatal`

### Transaction maxlevel Values
`info`, `warning`, `error`

---

## 11. SPCS Architecture

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
Int → Staging → Prod Ring 0 → Prod Ring 1 (approval required) → Prod Ring 2 (approval required)

---

## 12. Telemetry Pipeline

```
SPCS Services (rai-server, spcs-control-plane, etc.)
    → Consumer OTel Collector (consumer-otelcol)
    → Event Table (TELEMETRY.TELEMETRY.SHARED_EVENTS)
    → Event Sharing (to Events Account)
    → O4S Native App tasks
    → Observe
    → Datadog (via configured pipelines)
```

**Telemetry latency threshold:** If > 30 minutes, post in `#ext-relationalai-observe`

### Key Telemetry Filters
| Filter | Purpose |
|---|---|
| `service = "spcs-integration"` | SQL layer telemetry |
| `service = "spcs-control-plane"` | ERP telemetry |
| `response_status = "Error"` | Failed procedures |
| `attributes['error.class'] = "user"` | User-caused failures |
| `span_name = "process_batches"` | CDC batch processing |
| `span_name = "use_index"` | Graph Index operations |
| `span_name = "emit_trace"` | Periodic app telemetry (every 6 hours) |
| `span_name = "app_trace"` | App activity telemetry (every 12 minutes) |

### Key Log Search Patterns
| Pattern | What it indicates |
|---|---|
| `"segmentation fault"` | Engine segfault (error level) |
| `"[Jemalloc] absolute profile"` | Memory allocation profile |
| `"[Jemalloc] relative profile"` | Differential memory profile |
| `"heartbeat was lost for"` | Brownout recovery indicator |
| `"TransactionBegin"` | Transaction start |
| `"TransactionEnd"` | Transaction end |
| `"transaction X marked as COMPLETED"` | Transaction completion |
| `"KVStoreCommitWriteTransactions"` | DB version advancement (write transaction) |
| `"Estimated cardinality of the output relation"` | Query output size |

---

## 13. Error Categorization (Graph Index)

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

## 14. CDC Pipeline Details

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
- If stream falls behind data retention window → **stale** (unrecoverable)
- Data stream must be recreated

---

## 15. Escalation Channels

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

---

## 16. Playbook Design (Agreed Structure)

### Playbook 1: Transaction Investigation (Entry Point)
- **Input:** transaction ID
- **Goal:** Status, customer, what it did (high-level), duration
- **Steps:**
  1. Query transaction dataset → status, customer (org + account), engine, duration, maxlevel, language
  2. Determine transaction type: CDC (CDC_MANAGED_ENGINE) vs user vs Graph Index
  3. If COMPLETED → summarize (query spans + logs in parallel for detail)
  4. If ABORTED → report abort reason, route to Playbook 2 or 3
- **Customer identification:** `org_alias` + `account_alias` (e.g., "Western Union (account: wudev_wudatadev)")
- **"What it did" level:** Inference from language, DB version changes, span names. Business intent is future work.
- **User-level drill down:** Not MVP, future consideration.

### Playbook 2: Engine Failure Investigation
- **Input:** engine name + transaction ID (from Playbook 1 or alert)
- **Goal:** Root cause classification + escalation path
- **Steps:** Walk diagnostic lookup table:
  1. Check termination reason → crash or OOM?
  2. Check heartbeats → brownout?
  3. Check heartbeat span duration → long heartbeat requests?
  4. Check lifecycle events → user-initiated?
  5. Check container status timing → Snowflake maintenance?

### Playbook 3: Data Pipeline Investigation
- **Input:** "data isn't loading" or slow CDC, or data stream errors
- **Goal:** Root cause + remediation
- **Steps:**
  1. Check CDC dashboard for the data stream / account
  2. Check process_batches spans for errors or slow execution
  3. Check for stale streams, quarantined streams, suspended tasks
  4. If slow: debug via slow data loading procedure

---

## 17. Observed Transaction Example

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
| Queue wait | ~17s | Enqueued → dequeued |
| Execution | ~5s | Rel query, output cardinality = 0 |
| Commit | ~4.3s | group_commit, DB version 28→29 |
| Completion | ~4s | Cache/metrics, event stream close, auto-suspend |

### Key Spans (heaviest)
| Span | Service | Duration |
|---|---|---|
| group_commit | rai-server | 4.3s |
| post_to_erp | rai-server | 4.07s |
| service.CompleteTransactions | spcs-control-plane | 4.07s |
| eot_tip_write | rai-server | 134ms |
| eot_tip_write_to_blob | rai-server | 101ms |

### Key Log Messages (chronological)
- `"transaction request has been prepared"`
- `"[SERVER] Transaction request received"`
- `"TransactionBegin"`
- `"[TransactionQueue] Transaction enqueued"`
- `"[TransactionQueue] Transaction dequeued"`
- `"rel profiler root"`
- `"Estimated cardinality of the output relation: 0"`
- `"[COMMIT] Wrote tip for 28 => 29"`
- `"transaction X marked as COMPLETED"`
- `"TransactionEnd"`
- `"[service review] Transaction finished without internal error"`

This was a CDC transaction (CDC_MANAGED_ENGINE, rel language, write transaction with DB version advancement).
