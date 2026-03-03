# Observe Platform Reference

## Datasets

### Tier 1 — Primary Investigation

| Dataset | ID | Kind | Key Fields | Use When |
|---|---|---|---|---|
| **Snowflake Logs** | 41832558 | Event | timestamp, content, service_name, environment, level, rai_engine_name, rai_transaction_id, trace_id, span_id, sf_query_id, account_alias, org_alias | Log search, error investigation, keyword search in log content |
| **Spans** | 41867217 | Interval | start_time, end_time, duration, service_name, span_name, error_message, response_status, trace_id, span_id, parent_span_id, rai_engine_name, transaction_id, account_alias, org_alias | Distributed tracing, latency analysis, error spans. Duration in nanoseconds. |
| **Transaction Info** | 42728011 | Resource | rai_transaction_id, account_alias, duration (FLOAT64 seconds), engine_size, engine_version, environment, status, abort_reason, org_alias, cloud, snowflake_region | Transaction status/failure queries. Has `status` and `abort_reason` that base Transaction lacks. Duration -1 = engine crashed. |

### Tier 2 — Investigation-Specific

| Dataset | ID | Kind | Key Fields | Use When |
|---|---|---|---|---|
| **Transaction** | 41838769 | Interval | rai_transaction_id, rai_engine_name, account_alias, org_alias, environment, duration (DURATION ns), maxlevel | Transaction lifecycle. `maxlevel` is highest log severity, NOT status. Use Transaction Info for status. |
| **Traces** | 41838766 | Interval | trace_id, rai_transaction_id, duration, trace_name, num_spans, error | Trace-level aggregates. `trace_name` = root operation. |
| **Long Running Spans** | 42001379 | Interval | Same as Spans, pre-filtered | Pre-filtered slow spans. Performance investigations. |
| **Metrics** | 41861990 | Metric | metric_name, metric_type, metric_value, rai_engine_name, account_alias, environment, service_name, le | OTel metrics. See Metrics Catalog below. |
| **Span Event** | 42206250 | Event | event_name, attributes, span_id, trace_id, timestamp | Events within a span (exceptions, state transitions). |
| **Diagnostic Profiles v2** | 42394246 | Event | PROFILE_START, PROFILE_END, rai_engine_name, ACCOUNT_ALIAS | CPU profiling data. Links to CPU Profiling dashboard. |

### Tier 3 — Resource/Dimension

| Dataset | ID | Kind | Use When |
|---|---|---|---|
| **Engine** | 41838774 | Resource | Engine metadata, instance families, versions |
| **Environment** | 41838780 | Resource | Environment lifecycle |
| **Service** | 41853352 | Resource | Service lifecycle |
| **Region** | 41854129 | Resource | Region lookup |
| **Account Alias** | 41854125 | Resource | Customer account lookup |
| **Org Alias** | 41854127 | Resource | Organization lookup |
| **SF Query ID** | 41861926 | Resource | Snowflake query ID bridge |

### Tier 4 — Monitor/Alerting

| Dataset | ID | Kind | Use When |
|---|---|---|---|
| **Monitor** | 41759358 | Table | Monitor definitions (name, rule_kind) |
| **Monitor Detections** | 41832993 | Event | Alarm events (NewAlarm, AlarmConditionEnded). Threshold severities: Error, Critical, Informational. |
| **Monitor Notifications** | 41759342 | Interval | v1 notification history |
| **Monitor Messages** | 41832992 | Event | v2 notification logs with recipients |

### Tier 5+ — Specialized

| Dataset | ID | Use When |
|---|---|---|
| **Event Table OTEL Metrics** | 42399252 | Only if RelationalAI/Metrics has gaps. Prefer 41861990. |
| **snowflake/Service** | 41833043 | Snowflake compute service mapping |
| **OpenTelemetry/Span** | 41766875 | Non-RAI OTel services only (e.g., dev-review-agent) |
| **ServiceExplorer/Service Metrics** | 41862479 | Derived metrics: `exception_count_5m` |
| **AI Agents - Metrics** | 42910805 | AI agent platform metrics |
| **RAI CI Build Metrics** | 42587371 | CI build observations |

### Dataset Comparison Notes

**Transaction vs Transaction Info:** Use Transaction Info (42728011) for status/abort_reason. Use Transaction (41838769) for maxlevel and host-level correlation. `maxlevel` is NOT status.

**RelationalAI/Spans vs OpenTelemetry/Span:** Use RelationalAI/Spans (41867217) for RAI investigations. OTel/Span (41766875) lacks RAI-specific enrichment.

**RelationalAI/Metrics vs Event Table OTEL Metrics:** Prefer RelationalAI/Metrics (41861990). Event Table (42399252) has different tag structure, partial overlap.

## Dataset Relationships

```
Transaction Info ────→ Environment, Account Alias, Org Alias, Region, Transaction
Transaction ─────────→ Environment, Engine, Account Alias, Org Alias, Service
Snowflake Logs ──────→ Environment, Engine, Account Alias, Org Alias, Region, Service, Transaction, SF Query ID
Spans ───────────────→ Environment, Account Alias, Org Alias, Region, Service, Trace, Engine, Transaction, SF Query ID
Span Event ──────────→ Spans (via span_id, trace_id)
Traces ──────────────→ Transaction (via rai_transaction_id)
Engine ──────────────→ Environment, Account Alias, Org Alias, Region, Service
Diagnostic Profiles ─→ Account Alias, Engine (via rai_engine_name)
Monitor Detections ──→ Monitor (via MonitorId)
Monitor Messages ────→ Monitor (via MonitorId)
```

### Key Join Paths

```
Transaction failure:  Transaction Info (status=failure) → Logs (rai_transaction_id) → Spans (rai_transaction_id)
Trace drill-down:     Traces (trace_id) → Spans (trace_id) → Span Events (span_id) → Logs (trace_id)
Engine crash:         Logs (content CONTAINS "segmentation fault") → Engine (rai_engine_name) → Transaction Info
Cross-account:        Account Alias → Transaction Info / Logs / Spans / Metrics (account_alias)
Snowflake query:      SF Query ID → Logs (sf_query_id) → Spans (sf_query_id)
```

## Correlation Tags

| Tag | Found In | Purpose |
|---|---|---|
| `rai_transaction_id` | Logs, Spans, Transaction, Transaction Info, Traces | Primary transaction anchor |
| `rai_engine_name` | Logs, Spans, Transaction, Transaction Info, Engine, Metrics | Engine-scoped queries |
| `account_alias` | All datasets | Customer-scoped queries |
| `org_alias` | All datasets | Organization-scoped queries |
| `trace_id` | Spans, Logs, Traces, Span Events | Distributed trace correlation |
| `span_id` | Spans, Logs, Span Events | Span-level correlation |
| `sf_query_id` | Logs, Spans, SF Query ID | Snowflake query bridge |
| `pyrel_program_id` | Spans | SQL ↔ ERP layer cross-correlation |
| `host` | Logs, Transaction, Engine | Host-level correlation |
| `environment` | All RAI datasets | Environment scoping |
| `service_name` | Logs, Spans, Transaction, Engine, Metrics | Service filtering |

## Monitors

### SEV2 Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| SEV2: SPCS: An engine crashed due to a segmentation fault | Threshold | Engine segfault crashes |

### SEV3 Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| SEV3: SPCS: Failure during metadata node consolidation | Threshold | Metadata consolidation failures |
| SEV3: Possible deadlock detected in Destructors | Threshold | Potential deadlock in destructor threads |
| SEV3: The server's heartbeat was lost for more than... | Threshold | Engine brownout / unresponsive engine |
| SEV3: Snowflake Billing: Consumption tasks are not... | Threshold | Billing pipeline failures |

### Engine/Transaction Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| SPCS: Large number of allocations in the last 5 minutes | Threshold | Memory allocation spikes |
| Copy of RAIServer Error on SPCS Int environment | Threshold | RAI server errors on integration env |
| X-prod Intermediate With CPVO | Count | Cross-prod intermediate CPVO events |
| Warm engine recreation failed - compcache outdated | Threshold | Stale computation cache |
| CompCache Memory usage too high | Threshold | Computation cache memory pressure |
| Internal Julia Exception without owner | Threshold | Unhandled Julia exceptions |
| Duplicate eager invalidation events in recomputation | Threshold | Recomputation anomalies |

### ERP/Control Plane Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| ERP: Panics in server handler - migrated | Threshold | ERP handler panics |
| ERP restarts | Threshold | ERP service restarts |

### Telemetry Pipeline Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| Event table heartbeat of type METRIC is missing | Threshold | Missing metric heartbeats |
| NA Logs Outage | Threshold | North America log pipeline outage |
| Diagnostic Profiles - 60 Minute Gap Detection | Threshold | CPU profiling data gaps |
| O4S Pipeline Health (various) | Threshold | Telemetry forwarding health |

### Billing Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| Snowflake billing: Nonbillable engines are reported | Threshold | Billing anomalies |
| Snowflake Billing: idle engine - Running Engines w... | Threshold | Idle engines still running |

### Integration/CDC Monitors

| Name | Rule Kind | Triggers On |
|---|---|---|
| SPCS Integration native app async request p99 increase | Threshold | Integration latency spikes |
| Missing scheduled workflow executions | Threshold | Scheduled workflow failures |

## Dashboards

| Name | ID | URL | Use When |
|---|---|---|---|
| Engine Failures | 41949642 | Observe workspace | First stop for engine crash / transaction failure |
| CPU Profiling | 41782266 | Observe workspace | Performance hotspot analysis |
| Performance Triage | 41786648 | Observe workspace | Latency regressions, slow query triage |
| Distributed Workload Indicators | 41946298 | Observe workspace | Load balancing, capacity planning |
| Optimizer Dashboard | 41882895 | Observe workspace | Query plan issues, optimizer regressions |
| SPCS Environments | 41872510 | Observe workspace | Environment health comparison |
| O4S Pipeline Health | 42090551 | Observe workspace | Missing telemetry, pipeline lag |
| OOM Investigations | 41777956 | Observe workspace | Engine OOM diagnosis, Jemalloc profiles |
| BlobGC | 42245311 | Observe workspace | BlobGC health, pass status, storage cleanup |
| CDC Investigations | 42469929 | Observe workspace | Failed data streams, batch processing errors |
| Telemetry Outages | 42760073 | Observe workspace | Telemetry pipeline outages |
| Account Health | 42358249 | Observe workspace | Customer-specific issues, account SLA |
| Telemetry Heartbeats | 42384426 | Observe workspace | Heartbeat monitoring for telemetry pipeline |
| Pager | 42313242 | Observe workspace | OOM pager activity and memory pressure |
| Memory Breakdown | Memory-Breakdown-42602551 | Observe workspace | Detailed engine memory analysis |
| Continuous CPU Profiling | RelationalAI-Continuous-CPU-Profiling-41782266 | Observe workspace | CPU hotspot analysis (linked from Diagnostic Profiles) |
| Engine Overview | RelationalAI-Engine-Overview-MR-WIP-41925747 | Observe workspace | Multi-region engine health overview |
| ERP Restart | ERP-Restart-42156070 | Observe workspace | ERP service restart tracking |
| ERP Actionable Monitor V2 | ERP-actionable-monitor-v2-42488209 | Observe workspace | ERP error monitoring dashboard |
| Product SLOs | Product-SLOs-42733752 | Observe workspace | Product-level SLO tracking |
| Engineering SLOs | Engineering-SLOs-42723876 | Observe workspace | Engineering-level SLO tracking |
| SPCS Versions | SPCS-Versions-42021302 | Observe workspace | SPCS version deployment tracking |
| Synthetic Tests Insights | Synthetic-Tests-Insights-42313552 | Observe workspace | Synthetic test pass rates by region |

**Fallback:** DataDog "Engine failures (SPCS version)" at `https://app.datadoghq.com/dashboard/5u7-367-vkv`

## Metrics Catalog

### Transaction Metrics (RelationalAI/Metrics — 41861990)

| Metric | Type | Description |
|---|---|---|
| `transactions_total` | delta | Total transaction count |
| `transactions_succeeded_total` | delta | Successful transactions (success rate = succeeded / total) |
| `transactions_duration_total` | delta | Cumulative transaction duration (avg = duration_total / total) |
| `transactions_inflight` | gauge | Currently in-flight transactions |

### Commit Metrics

| Metric | Type | Description |
|---|---|---|
| `commit_duration_ms` | delta | Commit latency in milliseconds |
| `commit_txns_failure` | delta | Failed commit count |
| `commit_txns_start_commit` | delta | Commit throughput |

### Runtime Metrics

| Metric | Type | Description |
|---|---|---|
| `jm_local_threads_available` | gauge | Available threads (thread exhaustion detection) |
| `julia_gc_num_poolalloc` | delta | Julia GC pool allocations |
| `julia_gc_num_total_allocd` | delta | Julia GC total allocations |
| `julia_gc_num_malloc` | delta | Julia GC malloc count |

### HTTP Metrics

| Metric | Type | Description |
|---|---|---|
| `http.server.request.duration.count` | histogram | Request count by endpoint |
| `http.server.request.duration.bucket` | histogram | Request duration distribution (p50, p95, p99) |
| `http.server.request.duration.sum` | histogram | Request duration sum (average latency) |

### Derived Metrics (ServiceExplorer — 41862479)

| Metric | Type | Description |
|---|---|---|
| `exception_count_5m` | derived | Exception rate over 5-minute window |

## Enumerated Values

### Environments
`spcs-prod`, `spcs-int`, `spcs-latest`, `spcs-staging`, `spcs-expt`, `spcs-ea`, `None`, `unknown`

### Services
`rai-server`, `spcs-control-plane`, `spcs-integration`, `gnn-engine`, `observe-for-snowflake`, `rai-solver`, `spcs-log-heartbeat`, `spcs-event-sharing-heartbeat`, `provider-account-monitoring`, `provider-account-monitoring-heartbeats`, `pyrel`, `spcs-trace-heartbeat`, `unknown`

### Clouds
`sf-aws`, `sf-azure`

### Regions (12)
`aws_us_west_2`, `aws_us_east_1`, `azure_eastus2`, `azure_westus2`, `aws_eu_central_1`, `aws_ap_southeast_2`, `azure_uaenorth`, `aws_us_east_2`, `aws_eu_west_1`, `azure_westeurope`, `azure_southcentralus`, `azure_uscentral`

### Transaction Status (Transaction Info)
`success`, `failure`

### Abort Reasons (Transaction Info)
`None`, `engine failed`, `system internal error`

> See `engine-failures.md` for additional abort reasons from ERP logs and Confluence runbooks.

### Log Severity Levels
`info`, `warning`, `warn`, `error`, `fatal`

### Transaction maxlevel (Transaction dataset)
`info`, `warning`, `error`

### Engine Instance Families
`CPU_X64_XS`, `CPU_X64_S`, `CPU_X64_M`, `HIGHMEM_X64_S`, `HIGHMEM_X64_M`

### Engine Sizes (Transaction Info)
`XS`, `S`, `M` (map to CPU_X64_* families; HIGHMEM variants appear as-is)

### Span Types
`Internal operation`, `Service entry point`, `Unknown`

### Span Response Status
`Ok`, `Error`

## ERP Error Codes

Format: `erp_{component}_{upstream}_{reason}`

Components: `InternalComp`, `DBRPComp`, `EngineRPComp`, `MetadataComp`, `TxnRPComp`, `BlobGCComp`, `SnowflakeComp`, `AWSS3Comp`, `EngineComp`, `ServerComp`, `CPUProfilerComp`, `TxnEventComp`, `UnknownComp`

| Error Code | Meaning | Typical Action | Transient? |
|---|---|---|---|
| `erp_engine_enginepending` | Engine not ready for transaction | Transient if engine just created | Yes |
| `erp_enginerp_engine_provision_timeout` | Engine stuck in PENDING | File Snowflake ticket | No |
| `erp_enginerp_internal_engine_provision_timeout` | Engine provisioning timeout (internal) | Not in runbook. File Snowflake ticket if persistent. | No |
| `erp_spcs_awss3_txn_get_txn_artifacts_error` | Downloading artifacts from aborted txn | Often client-side wrong behavior | Varies |
| `erp_jobrp_engine_send_rai_request_error` | Job RP can't reach engine | Transient if retry succeeds (final 200) | Usually |
| `erp_txnrp_awss3_get_object_error` | S3 throttling (bucket repartitioning) | ERP/engine have retry logic | Yes |
| `erp_logicrp_sf_unknown` / `erp_graphindex_sf_unknown` | Snowflake internal error (300002) | File Snowflake ticket | Varies |
| `erp_txnevent_internal_stream_write_error` | S3/blob throttling | No customer impact | Yes |
| `erp_blobgc_sf_unknown` | BlobGC Snowflake query error | Retry handles it | Yes |
| `erp_spcs_internal_request_reading_error` | Request reading failure | Transient if single occurrence | Yes |
| `erp_enginerp_sf_oauth_token_expired` | OAuth token expiry | Check if reconnect succeeded | Yes |
| `erp_logicrp_sf_invalid_image_in_spec` | Post-upgrade image unavailable | Duplicate of NCDNTS-10633 if no txn failures in 1h | Yes |
| `erp_internallogicrp_sf_invalid_image_in_spec` | Post-upgrade image unavailable (internal) | Same as above | Yes |
| `erp_txnrp_internal_db_init_failed` | DB init race condition | Transient if delete-before-commit pattern | Yes |
| `erp_raiclient_engine_send_rai_request_error` | ERP can't reach engine | Check brownout, blocking ops, network | Varies |
| `erp_sf_unknown` | Generic Snowflake SQL error | Get sf.query_id, check logs | Varies |
| `erp_blobgc_internal_blobgc_circuit_breaker_open` | 3 consecutive BlobGC failures, 12h block | Search logs for root cause error | No |
| `*_transaction_cache_not_found_error` | ERP restart lost mapping cache | Safe to close if no customer concern | Yes |
| `erp_unknown_internal_middlewarepanic` | ERP middleware panic | Not in runbook. Rare — investigate. | No |
| `erp_blobgc_sf_sql_compute_pool_suspended` | BlobGC compute pool suspended | Not in runbook. Check for manual account changes. | No |
| `erp_blobgc_engine_blobgc_engine_response_error` | BlobGC engine response error | Incident creation disabled (jian.fang). | Yes |
| `erp_txnevent_internal_request_reading_error` | TxnEvent request reading error | Not in runbook. Safe to close if not repeating. | Yes |

**Transient detection:** encounter count < 2 → likely transient, safe to mitigate. Count >= 2 or persistent → escalate to `#team-prod-engine-resource-providers-spcs`.

## ArgoCD URLs

- ArgoCD prod: `https://argocd.prod.internal.relational.ai:8443/`
- ArgoCD staging: `https://argocd.staging.internal.relational.ai:8443/`

## Query Patterns

| # | Scenario | Query for generate-query-card |
|---|---|---|
| 1 | Failed transactions (last 24h) | "Query Transaction Info (42728011) for status = failure in last 24 hours. Show rai_transaction_id, account_alias, abort_reason, duration, engine_version. Sort by timestamp desc. Limit 50." |
| 2 | Failure rate by account | "Query Transaction Info (42728011) last 24 hours. Group by account_alias, status. Count per group. Sort by count desc." |
| 3 | Active alarms | "Query Monitor Detections (41832993) last 24 hours. Filter Type = NewAlarm. Group by MonitorName. Count per monitor. Sort desc. Limit 20." |
| 4 | Error logs for transaction | "Query Snowflake Logs (41832558) where rai_transaction_id = '<TXN_ID>' and level IN (error, fatal). Show timestamp, content, service_name. Sort by timestamp asc." |
| 5 | Spans for trace | "Query Spans (41867217) where trace_id = '<TRACE_ID>'. Show span_name, duration, service_name, response_status, error_message. Sort by start_time asc." |
| 6 | Engine crash logs | "Query Snowflake Logs (41832558) last 24 hours where content contains 'segmentation fault' and environment = 'spcs-prod'. Show timestamp, rai_engine_name, account_alias, content." |
| 7 | Monitor inventory | "Query Monitor (41759358). Show monitor_id, name, rule_kind. Sort by name asc." |
| 8 | Transaction rate by env | "Query Metrics (41861990) for metric_name = 'transactions_total' last 1 hour. Group by environment. Show rate of change." |
| 9 | Long running spans | "Query Long Running Spans (42001379) last 24 hours where environment = 'spcs-prod'. Show span_name, duration, service_name, rai_engine_name. Sort by duration desc. Limit 20." |
| 10 | Cross-dataset investigation | "Step 1: Transaction Info (42728011) for failed txn → get rai_transaction_id. Step 2: Logs (41832558) for that ID, level = error. Step 3: Spans (41867217) for that ID, error = true." |
