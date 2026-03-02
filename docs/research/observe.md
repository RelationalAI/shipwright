# Observability Skill — Observe Platform Research

This document captures all Observe-specific knowledge: datasets, dashboards, metrics, correlation tags, MCP tool capabilities, telemetry filter patterns, monitor inventory, and sample query patterns. Sourced from the Observe knowledge graph via `mcp__observe__generate-knowledge-graph-context`, live querying via `mcp__observe__generate-query-card`, and manual exploration.

Last updated: 2026-02-27

---

## 1. Dashboard Catalog

All dashboards are in workspace `41759331` at `https://171608476159.observeinc.com/`.

| Dashboard | ID | Purpose | When to Use |
|---|---|---|---|
| Engine Failures | 41949642 | Primary oncall dashboard for transaction aborts | First stop for any engine crash or transaction failure investigation |
| CPU Profiling | 41782266 | Continuous CPU profiling | Performance hotspot analysis, slow transaction root cause |
| Performance Triage | 41786648 | Performance investigation | Latency regressions, slow query triage |
| Distributed Workload Indicators | 41946298 | Workload distribution across engines | Load balancing issues, capacity planning |
| Optimizer Dashboard | 41882895 | Optimizer analysis | Query plan issues, optimizer regressions |
| SPCS Environments | 41872510 | Environment overview | Environment health comparison, deployment verification |
| O4S Pipeline Health | 42090551 | Telemetry pipeline health | Missing telemetry, pipeline lag, data gaps |
| CDC Investigations | 42469929 | Data stream/CDC issues | Failed data streams, batch processing errors |
| Telemetry Outages | Telemetry-Outages-42760073 | Telemetry pipeline outages | When telemetry data stops flowing for a region/account |
| Account Health | SPCS-Account-Health-42358249 | Per-account health | Customer-specific issues, account-level SLA tracking |

**Fallback:** DataDog "Engine failures (SPCS version)" at `https://app.datadoghq.com/dashboard/5u7-367-vkv`

---

## 2. Complete Dataset Catalog

Full inventory of all datasets discovered via `mcp__observe__generate-knowledge-graph-context`. Organized by tier for skill configuration.

### Tier 1 — Core Data (every investigation touches these)

| Dataset | ID | Kind | Key Fields | Description |
|---|---|---|---|---|
| **RelationalAI/Snowflake Logs** | 41832558 | Event | timestamp, content, service_name, environment, snowflake_region, account_alias, org_alias, level, attributes, rai_engine_name, rai_transaction_id, trace_id, span_id, sf_query_id | Primary log dataset. All service logs with severity, content, and rich attributes. Supports distributed tracing via trace_id/span_id. |
| **RelationalAI/Spans** | 41867217 | Interval | start_time, end_time, duration, service_name, account_alias, org_alias, kind, span_name, parent_span_id, span_id, trace_id, error_message, response_status, error, environment, attributes, rai_engine_name, transaction_id, sf_query_id, span_type, service_namespace, service_instance_id, service_version, status_code, schema_url, instrumentation_library, non_otlp_span | Distributed tracing spans. Duration in nanoseconds. Supports parent/child hierarchy via parent_span_id. `span_type` categorizes as "Internal operation", "Service entry point", or "Unknown". |
| **Transaction Info** | 42728011 | Resource | rai_transaction_id, account_alias, cloud, duration (FLOAT64), engine_size, engine_version, environment, language, snowflake_region, rai_commit, rai_database_name, readonly, org_alias, abort_reason, **status** | **Extended transaction metadata.** Has `status` (success/failure) and `abort_reason` that the base Transaction dataset lacks. Duration is FLOAT64 (seconds), not DURATION. Duration of -1 indicates engine crashed before completion. |

### Tier 2 — Investigation-Specific

| Dataset | ID | Kind | Key Fields | Description |
|---|---|---|---|---|
| **RelationalAI/Transaction** | 41838769 | Interval | rai_transaction_id, rai_engine_name, account_alias, org_alias, environment, service_name, host, language, duration (DURATION), maxlevel | Transaction lifecycle with nanosecond duration. `maxlevel` is highest log severity (NOT status). Links to Engine and Environment datasets. |
| **RelationalAI/Traces** | 41838766 | Interval | trace_id, rai_transaction_id, start_time, duration, trace_name, num_spans, error, end_time | Trace-level aggregates. Each trace groups related spans. `trace_name` shows the root operation (e.g., handle_generic_request, POST /api/v1/transactionEvents). |
| **RelationalAI/Long Running Spans** | 42001379 | Interval | Same schema as Spans but pre-filtered | Pre-filtered slow spans exceeding duration thresholds. Same foreign keys as Spans. Use for performance investigations. |
| **RelationalAI/Metrics** | 41861990 | Metric | metric_name, metric_type, metric_value + rai_engine_name, account_alias, org_alias, snowflake_region, environment, cloud, service_name, le | OTel metrics dataset. Primary source for all RAI platform metrics. See Section 6 for full metric catalog. |
| **RelationalAI/Span Event** | 42206250 | Event | event_name, attributes, span_id, trace_id, timestamp | Span-associated events. Captures discrete events within a span's lifetime (e.g., exceptions, state transitions). |
| **RelationalAI/Diagnostic Profiles v2** | 42394246 | Event | PROFILE_START, PROFILE_END, PROFILE_ID, PROFILE_TAGS, rai_engine_name, NUM_CHUNKS, PROFILE_DATA, ACCOUNT_ID, ACCOUNT_ALIAS | CPU profiling data. Links to CPU Profiling dashboard (41782266). Use for deep performance analysis. |

### Tier 3 — Resource/Dimension Datasets (filtering and joins)

| Dataset | ID | Kind | Key Fields | Description |
|---|---|---|---|---|
| **RelationalAI/Engine** | 41838774 | Resource | engine, service_name, environment, snowflake_region, account_alias, org_alias, host, snowflake_database, snowflake_instance_family, version, rai_engine_id | Engine metadata. Instance families: CPU_X64_XS, HIGHMEM_X64_S, CPU_X64_M, CPU_X64_S, HIGHMEM_X64_M. |
| **RelationalAI/Environment** | 41838780 | Resource | environment | Environment lifecycle. Values: spcs-prod, spcs-int, spcs-latest, spcs-staging, spcs-expt, spcs-ea, None, unknown. |
| **RelationalAI/Service** | 41853352 | Resource | service | Service lifecycle. See Section 7 for full service list. |
| **RelationalAI/Region** | 41854129 | Resource | region | 12 regions. See Section 7 for full list. |
| **RelationalAI/Account Alias** | 41854125 | Resource | Account Alias | Customer account aliases. Multi-tenant identifier for scoping investigations. |
| **RelationalAI/Org Alias** | 41854127 | Resource | Org Alias | Organization aliases: rai, ey, imcd, obeikan, blueyonder, bnym, snowflake, att, block, ericsson, sparknz, novartis, etc. |
| **SF Query ID** | 41861926 | Resource | sf_query_id | Snowflake query ID lookup. Bridges Observe data to Snowflake query history. |

### Tier 4 — Monitor/Alerting Datasets

| Dataset | ID | Kind | Key Fields | Description |
|---|---|---|---|---|
| **usage/Observe Monitor** | 41759358 | Table | monitor_id, name, package, rule_kind, customer_id, created_by, updated_by | Monitor definitions. Rule kinds: Threshold, Count, Promote, Log. Links to Package, Account, User datasets. |
| **usage/Monitor Detections** | 41832993 | Event | Timestamp, AlarmId, MonitorId, MonitorVersion, AlarmStart, AlarmEnd, Threshold, Type, CapturedValues, GroupingHash, MonitorName | v2 alarm events. Types: NewAlarm, AlarmConditionEnded, AlarmBackdated, AlarmInvalidated, AlarmStartedFromSplit, AlarmSplit. Threshold severities: Error, Critical, Informational. |
| **usage/Monitor Notifications** | 41759342 | Interval | Notification Signature, MonitorId, Start Time, Monitor Name, Kind, Description, Importance | v1 notification history. Links to Monitor dataset via MonitorId. |
| **usage/Monitor Messages** | 41832992 | Event | MonitorId, Timestamp, Severity, Message, FIELDS (includes kvs.recipients, kvs.alarmId, kvs.eventType) | v2 notification logs. **Recipients field** contains raw webhook URLs (Slack), JIRA API endpoints, or email addresses. No friendly names for webhooks. |

### Tier 5 — Snowflake and OpenTelemetry Generic Datasets

| Dataset | ID | Kind | Key Fields | Description |
|---|---|---|---|---|
| **snowflake/Event Table OTEL Metrics** | 42399252 | Metric | SNOWFLAKE_ACCOUNT, SNOWFLAKE_REGION, resource_attributes, metric_name | Duplicate of some metrics from RelationalAI/Metrics but sourced directly from Snowflake event tables. Different tag structure. **Prefer RelationalAI/Metrics (41861990) for consistency.** |
| **snowflake/Service** | 41833043 | Resource | service_name, compute_pool, dns_name, min_instances, max_instances | Snowflake compute services from ACCOUNT_USAGE.SERVICES view. Maps service containers to compute pools. |
| **OpenTelemetry/Span** | 41766875 | Interval | Standard OTel span fields | Generic OTel spans. Currently used by dev-review-agent. RAI data uses RelationalAI/Spans instead. |
| **OpenTelemetry/Span Event** | 41766877 | Event | Standard OTel span event fields | OTel span events (generic layer). |
| **OpenTelemetry/Operation** | 41766878 | Resource | operation_name | Operation catalog derived from spans. |
| **OpenTelemetry/Trace** | 41766879 | Interval | Standard OTel trace fields | OTel trace summaries (generic layer). |
| **ServiceExplorer/Service Metrics** | 41862479 | Metric | exception_count_5m, service_name | Derived metrics from OTel span data. Source for `exception_count_5m`. |

### Tier 6 — CI and AI Agent Datasets

| Dataset | ID | Kind | Key Fields | Description |
|---|---|---|---|---|
| **AI Agents - Metrics** | 42910805 | Event | model, tool, agent, queue, timestamp | AI agent platform metrics. Tracks model usage, tool invocations, and agent activity. |
| **RAI CI Build Metrics** | 42587371 | Event | build_id, status, duration, branch | CI build observations. Raw build data from CI pipeline. |
| **RAI CI Build Metrics / Metrics RAICode** | 42707328 | Event | Derived fields from build metrics | Derived CI metrics specific to the RAICode repository. |

---

## 3. Foreign Key Relationships

How datasets connect to each other. These relationships define valid join paths for cross-dataset queries.

```
Snowflake Logs ──────→ Environment, Engine, Account Alias, Org Alias, Region, Service, Transaction, SF Query ID
Spans ───────────────→ Environment, Account Alias, Org Alias, Region, Service, Trace, Parent Span (self-ref), Engine, Transaction, SF Query ID
Span Event ──────────→ Spans (via span_id, trace_id)
Long Running Spans ──→ Same as Spans
Transaction ─────────→ Environment, Engine, Account Alias, Org Alias, Service
Transaction Info ────→ Environment, Account Alias, Org Alias, Region, Transaction
Traces ──────────────→ Transaction (via rai_transaction_id)
Engine ──────────────→ Environment, Account Alias, Org Alias, Region, Service
Diagnostic Profiles ─→ Account Alias, Engine (via rai_engine_name)
Monitor Notifications → Monitor (via MonitorId)
Monitor Detections ──→ Monitor (via MonitorId)
Monitor Messages ────→ Monitor (via MonitorId)
```

### Key Join Paths for Common Investigations

```
Transaction failure investigation:
  Transaction Info (status=failure) → Logs (rai_transaction_id) → Spans (rai_transaction_id)

Trace drill-down:
  Traces (trace_id) → Spans (trace_id) → Span Events (span_id) → Logs (trace_id)

Engine crash investigation:
  Logs (content CONTAINS "segmentation fault") → Engine (rai_engine_name) → Transaction Info (rai_engine_name)

Cross-account comparison:
  Account Alias → Transaction Info / Logs / Spans / Metrics (account_alias)

Snowflake query correlation:
  SF Query ID → Logs (sf_query_id) → Spans (sf_query_id)
```

---

## 4. Dataset Comparisons

### Transaction vs Transaction Info

| Field | Transaction (41838769) | Transaction Info (42728011) |
|---|---|---|
| Kind | Interval | Resource |
| duration type | DURATION (nanoseconds) | FLOAT64 (seconds); -1 means engine crashed |
| status | NOT available (use maxlevel as proxy) | `status`: "success" or "failure" |
| abort_reason | NOT available | `abort_reason`: "None", "engine failed", "system internal error" |
| engine_size | NOT available | `engine_size`: XS, S, M, HIGHMEM_X64_S, HIGHMEM_X64_M |
| engine_version | NOT available | `engine_version`: build version strings |
| rai_database_name | NOT available | Available |
| readonly | NOT available | `readonly`: true/false |
| rai_commit | NOT available | `rai_commit`: code commit hash |
| cloud | NOT available | `cloud`: sf-aws, sf-azure |
| maxlevel | Available (info, warning, error) | NOT available |
| host | Available | NOT available |

**Recommendation:** Use Transaction Info for status/abort_reason queries. Use Transaction for maxlevel and host-level correlation.

### RelationalAI/Spans vs OpenTelemetry/Span

| Aspect | RelationalAI/Spans (41867217) | OpenTelemetry/Span (41766875) |
|---|---|---|
| Scope | RAI platform services only | All OTel-emitting services (including dev-review-agent) |
| Enrichment | Flattened RAI fields (rai_engine_name, account_alias, etc.) | Raw OTel fields, nested resource_attributes |
| Use for RAI investigations | YES — preferred | No — lacks RAI-specific enrichment |
| Foreign keys | Full linkage to RAI dimension datasets | Limited |

### RelationalAI/Metrics vs snowflake/Event Table OTEL Metrics

| Aspect | RelationalAI/Metrics (41861990) | Event Table OTEL Metrics (42399252) |
|---|---|---|
| Source | OTel collector pipeline | Snowflake event tables (ACCOUNT_USAGE) |
| Tag structure | Flattened columns (account_alias, org_alias, etc.) | Nested (SNOWFLAKE_ACCOUNT, resource_attributes) |
| Preferred | YES | No — use only if RelationalAI/Metrics has gaps |
| Metric overlap | Full set | Partial (e.g., transactions_duration_total) |

---

## 5. Correlation Tags and Lookup Keys

### Primary Correlation Keys (cross-dataset)

| Key | Column Name(s) | Present In | Description |
|---|---|---|---|
| `rai_transaction_id` | rai_transaction_id, transaction_id | Logs, Spans, Transaction, Transaction Info, Traces | Primary transaction identifier. Use to trace a single transaction across all datasets. |
| `rai_engine_name` | rai_engine_name | Logs, Spans, Transaction, Transaction Info, Engine, Metrics, Diagnostic Profiles | Engine name. Use to scope all data to a specific engine instance. |
| `account_alias` | account_alias, Account Alias | All datasets | Customer Snowflake account alias. Primary multi-tenant scoping key. |
| `org_alias` | org_alias, Org Alias | All datasets | Customer organization. Groups multiple accounts under one org. |
| `trace_id` | trace_id, trace.id | Spans, Logs, Traces, Span Events | Distributed tracing ID. Links all spans and logs in a single trace. |
| `span_id` | span_id, span.id | Spans, Logs, Span Events | Individual span identifier. Links span events and logs to a specific span. |
| `sf_query_id` | sf_query_id, sf.query.id, sf.query_id | Logs, Spans, SF Query ID | Snowflake query ID. Bridges Observe data to Snowflake query history. |

### Secondary Correlation Keys (within specific datasets)

| Key | Present In | Description |
|---|---|---|
| `host` | Logs, Transaction, Engine | Snowflake host FQDN. Use for host-level correlation. |
| `phase` | Logs | Compiler phase (PhaseInlining, CompilePhase, etc.). Filter compilation logs. |
| `rai.commit` / `rai_commit` | Logs, Transaction Info | Engine commit hash. Correlate issues to specific code versions. |
| `pyrel_program_id` | Spans | Links `use_index` and `prepareIndex` spans for cross-layer correlation. |
| `parent_span_id` | Spans | Parent span reference. Build span hierarchy trees. |
| `environment` | All RAI datasets | Environment filter. Critical for scoping to prod vs staging. |
| `snowflake_region` | Logs, Spans, Engine, Metrics, Transaction Info | Region filter. Scope to specific cloud regions. |
| `service_name` | Logs, Spans, Transaction, Engine, Metrics | Service filter. Scope to rai-server, spcs-control-plane, etc. |

### Span-Specific Correlation Tags (from knowledge graph)

| Tag | Description |
|---|---|
| `attributes.relation` | Rel relation being evaluated |
| `dd.span.Resource` | DataDog-compatible span resource name |
| `faq_relation` | Frequently accessed relation |
| `path` | Request path |
| `recursion_type` | Recursion strategy used |
| `relation` | Relation name |
| `response_status` | Span response status (Ok, Error) |
| `span_name` | Span operation name |
| `test.url` / `http.url` | HTTP URL for the request |

### Log-Specific Correlation Tags (from knowledge graph)

| Tag | Description |
|---|---|
| `decl_id` | Declaration identifier |
| `evaluation_id` | Evaluation identifier |
| `faq_relation` | Frequently accessed relation |
| `multipart_id` | Multipart request identifier |
| `scc_id` | SCC (strongly connected component) identifier |

---

## 6. Key Metrics

### Transaction Metrics (RelationalAI/Metrics — 41861990)

| Metric | Type | Description | Oncall Use |
|---|---|---|---|
| `transactions_total` | delta | Total transaction count | Transaction volume, rate of change |
| `transactions_succeeded_total` | delta | Successful transaction count | Success rate = succeeded / total |
| `transactions_duration_total` | delta | Total transaction duration (cumulative) | Average duration = duration_total / total |
| `transactions_inflight` | gauge | Currently in-flight transactions | Queue depth, capacity saturation |

### Commit Metrics (RelationalAI/Metrics — 41861990)

| Metric | Type | Description | Oncall Use |
|---|---|---|---|
| `commit_duration_ms` | delta | How long commits take (milliseconds) | Commit latency monitoring |
| `commit_txns_failure` | delta | Failed commit count | Commit failure rate |
| `commit_txns_start_commit` | delta | Commit start count | Commit throughput |

### Runtime Metrics (RelationalAI/Metrics — 41861990)

| Metric | Type | Description | Oncall Use |
|---|---|---|---|
| `jm_local_threads_available` | gauge | Available threads in thread pool | Thread exhaustion detection |
| `julia_gc_num_poolalloc` | delta | Julia GC pool allocations | Memory pressure indicators |
| `julia_gc_num_total_allocd` | delta | Julia GC total allocations | Memory pressure indicators |
| `julia_gc_num_malloc` | delta | Julia GC malloc count (also in 42399252) | Memory allocation rate |

### HTTP Metrics (RelationalAI/Metrics — 41861990)

| Metric | Type | Description | Oncall Use |
|---|---|---|---|
| `http.server.request.duration.count` | histogram | HTTP request count | Request rate by endpoint |
| `http.server.request.duration.bucket` | histogram | HTTP request duration distribution | Latency percentiles (p50, p95, p99) |
| `http.server.request.duration.sum` | histogram | HTTP request duration sum | Average latency |
| `otelcol_http_server_duration_bucket` | delta | OTel collector HTTP duration | Collector performance |

### Derived Metrics (ServiceExplorer/Service Metrics — 41862479)

| Metric | Type | Description | Oncall Use |
|---|---|---|---|
| `exception_count_5m` | derived | Exception rate over 5-minute window | Error spike detection |

### Metric Filter Dimensions

All metrics in RelationalAI/Metrics can be filtered by:
- `rai_engine_name` — scope to specific engine
- `account_alias` — scope to specific customer
- `org_alias` — scope to specific organization
- `snowflake_region` — scope to specific region
- `environment` — scope to specific environment (spcs-prod, spcs-int, etc.)
- `cloud` — scope to cloud provider (sf-aws, sf-azure)
- `service_name` — scope to specific service
- `le` — histogram bucket boundary (for histogram metrics)

---

## 7. Enumerated Values

### Environments
`spcs-prod`, `spcs-int`, `spcs-latest`, `spcs-staging`, `spcs-expt`, `spcs-ea`, `None`, `unknown`

### Services
| Service | Description |
|---|---|
| `rai-server` | RAI engine (executes Rel queries) |
| `spcs-control-plane` | ERP (orchestrates engine lifecycle, handles API requests) |
| `spcs-integration` | SQL integration layer (procedures, data stream tasks) |
| `gnn-engine` | Graph Neural Network engine |
| `observe-for-snowflake` | O4S telemetry forwarding |
| `rai-solver` | Solver service |
| `spcs-log-heartbeat` | Log pipeline heartbeat |
| `spcs-event-sharing-heartbeat` | Event sharing heartbeat |
| `provider-account-monitoring` | Provider account monitoring |
| `provider-account-monitoring-heartbeats` | Provider account monitoring heartbeats |
| `pyrel` | Python-Rel integration layer |
| `spcs-trace-heartbeat` | Trace pipeline heartbeat |
| `unknown` | Unidentified service |

### Transaction Languages
- `rel` — RAI's internal query language (being deprecated)
- `lqp` — Logical Query Plan (replacing rel)

### Log Severity Levels
`info`, `warning`, `warn`, `error`, `fatal`

### Transaction maxlevel Values (Transaction dataset)
`info`, `warning`, `error`

### Transaction Status Values (Transaction Info dataset)
`success`, `failure`

### Abort Reason Values (Transaction Info dataset)
`None`, `engine failed`, `system internal error`

### Engine Instance Families
`CPU_X64_XS`, `CPU_X64_S`, `CPU_X64_M`, `HIGHMEM_X64_S`, `HIGHMEM_X64_M`

### Engine Sizes (Transaction Info dataset)
`XS`, `S`, `M`

Note: Engine sizes in Transaction Info (XS, S, M) map to instance families in Engine dataset (CPU_X64_XS, CPU_X64_S, CPU_X64_M). HIGHMEM variants appear as-is in both.

### Snowflake Regions (12 active)
`aws_us_west_2`, `aws_us_east_1`, `azure_eastus2`, `azure_westus2`, `aws_eu_central_1`, `aws_ap_southeast_2`, `azure_uaenorth`, `aws_us_east_2`, `aws_eu_west_1`, `azure_westeurope`, `azure_southcentralus`, `azure_uscentral`

### Cloud Values
`sf-aws`, `sf-azure`

### Span Kind Values
`INTERNAL`, `SERVER`

### Span Response Status Values
`Ok`, `Error`

### Span Type Values
`Internal operation`, `Service entry point`, `Unknown`

### Monitor Rule Kinds
`Threshold`, `Count`, `Promote`, `Log`

### Monitor Detection Types
`NewAlarm`, `AlarmConditionEnded`, `AlarmBackdated`, `AlarmInvalidated`, `AlarmStartedFromSplit`, `AlarmSplit`

### Monitor Threshold Severities
`Error`, `Critical`, `Informational`

---

## 8. Telemetry Filter Patterns

### Service Filters
| Filter | Purpose |
|---|---|
| `service_name = "rai-server"` | RAI engine telemetry |
| `service_name = "spcs-control-plane"` | ERP telemetry |
| `service_name = "spcs-integration"` | SQL integration layer telemetry |
| `service_name = "gnn-engine"` | GNN engine telemetry |
| `response_status = "Error"` | Failed operations (spans) |
| `status_code = "Error"` | Failed operations (alternative field in spans) |
| `error = true` | Error spans/traces |
| `attributes['error.class'] = "user"` | User-caused failures |

### Key Span Name Filters
| Filter | Purpose |
|---|---|
| `span_name = "process_batches"` | CDC batch processing |
| `span_name = "use_index"` | Graph Index operations |
| `span_name = "prepareIndex"` | Index preparation (link via pyrel_program_id) |
| `span_name = "emit_trace"` | Periodic app telemetry (every 6 hours) |
| `span_name = "app_trace"` | App activity telemetry (every 12 minutes) |
| `span_name = "handle_generic_request"` | Generic request handler (common root span) |

### Key Log Search Patterns
| Pattern | What it indicates |
|---|---|
| `"segmentation fault"` | Engine segfault (error level) — triggers SEV2 monitor |
| `"[Jemalloc] absolute profile"` | Memory allocation profile |
| `"[Jemalloc] relative profile"` | Differential memory profile |
| `"heartbeat was lost for"` | Brownout recovery indicator — triggers SEV3 monitor |
| `"TransactionBegin"` | Transaction start |
| `"TransactionEnd"` | Transaction end |
| `"transaction X marked as COMPLETED"` | Transaction completion |
| `"KVStoreCommitWriteTransactions"` | DB version advancement (write transaction) |
| `"Estimated cardinality of the output relation"` | Query output size |
| `"metadata node consolidation"` | Metadata node consolidation failure — triggers SEV3 |
| `"deadlock detected in Destructors"` | Possible deadlock — triggers SEV3 |
| `"Panics in server handler"` | ERP handler panic |

### Environment Scoping Patterns
| Filter | Purpose |
|---|---|
| `environment = "spcs-prod"` | Production environment only |
| `environment IN ("spcs-prod", "spcs-ea")` | Production + early access |
| `environment NOT IN ("spcs-int", "spcs-latest", "spcs-staging")` | Exclude non-production |

### Time-Based Patterns
| Pattern | Purpose |
|---|---|
| Last 1 hour | Active incident investigation |
| Last 24 hours | Recent alarm review, failure trending |
| Last 7 days | Regression detection, pattern analysis |
| Last 30 days | Capacity planning, long-term trends |

---

## 9. Observe MCP Tool Capabilities and Limitations

### Two tools available:

1. **`mcp__observe__generate-query-card`** — primary tool. Generates and executes OPAL queries against Observe datasets. Auto-fetches knowledge graph context internally. Use for all data retrieval.
2. **`mcp__observe__generate-knowledge-graph-context`** — exploration only. Searches for datasets, metrics, correlation tags. Use to discover what is available. Do NOT call this before generate-query-card (it fetches its own context).

### What generate-query-card CAN do:
- Query any dataset by ID or name (logs, spans, metrics, monitor data)
- Filter by any column or tag value
- Aggregate with groupby, count, sum, avg, min, max
- Time-range scoping
- Join across datasets via foreign keys
- Generate visualizations (bar charts, line charts, tables)
- Return tabular results with column headers

### What generate-query-card CANNOT do:
- Access monitor configuration (webhook action bodies/templates)
- Map friendly webhook names (e.g., "SPCS Incident Infrastructure High") to webhook URLs
- Access Observe REST API or control plane settings
- Create, update, or delete monitors
- Modify any data or configuration
- Access datasets outside the workspace

### Query Tips:
- Always specify the dataset ID when possible (more reliable than name)
- Use `environment = "spcs-prod"` for production-scoped queries
- For metrics, specify the metric_name in the filter
- For large result sets, add LIMIT or use aggregation
- Time ranges are auto-scoped but can be overridden in the prompt
- For Transaction Info, duration is FLOAT64 seconds (not DURATION type)

---

## 10. Monitor Inventory

### SEV2 Monitors (Critical — immediate oncall response)

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| SEV2: SPCS: An engine crashed due to a segmentation fault | Threshold | Engine segfault crashes |

### SEV3 Monitors (High — oncall investigation required)

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| SEV3: SPCS: Failure during metadata node consolidation | Threshold | Metadata consolidation failures |
| SEV3: Possible deadlock detected in Destructors | Threshold | Potential deadlock in destructor threads |
| SEV3: The server's heartbeat was lost for more than... | Threshold | Engine brownout / unresponsive engine |
| SEV3: Snowflake Billing: Consumption tasks are not... | Threshold | Billing pipeline failures |

### Engine and Transaction Monitors

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| SPCS: Large number of allocations in the last 5 minutes | Threshold | Memory allocation spikes |
| Copy of RAIServer Error on SPCS Int environment | Threshold | RAI server errors on integration env |
| X-prod Intermediate With CPVO | Count | Cross-prod intermediate CPVO events |
| Warm engine recreation failed - compcache outdated | Threshold | Stale computation cache |
| CompCache Memory usage too high | Threshold | Computation cache memory pressure |
| Internal Julia Exception without owner | Threshold | Unhandled Julia exceptions |
| Duplicate eager invalidation events in recomputation | Threshold | Recomputation anomalies |

### ERP/Control Plane Monitors

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| ERP: Panics in server handler - migrated | Threshold | ERP handler panics |
| ERP restarts | Threshold | ERP service restarts |

### Telemetry Pipeline Monitors

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| Event table heartbeat of type METRIC is missing | Threshold | Missing metric heartbeats |
| NA Logs Outage | Threshold | North America log pipeline outage |
| Diagnostic Profiles - 60 Minute Gap Detection | Threshold | CPU profiling data gaps |
| O4S Pipeline Health (various) | Threshold | Telemetry forwarding health |

### Billing Monitors

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| Snowflake billing: Nonbillable engines are reported | Threshold | Billing anomalies |
| Snowflake Billing: idle engine - Running Engines w... | Threshold | Idle engines still running |

### Integration/CDC Monitors

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| SPCS Integration native app async request p99 increase | Threshold | Integration latency spikes |
| Missing scheduled workflow executions | Threshold | Scheduled workflow failures |

### CI Monitors

| Monitor Name | Rule Kind | What it Detects |
|---|---|---|
| Success Jobs Threshold | Threshold | CI job success rate drops |
| Count Monitor test | Count | Test/development monitor |

### Recent Alarm Activity (24-hour sample, 2026-02-27)

| Monitor | Alarm Count | Notes |
|---|---|---|
| Copy of RAIServer Error on SPCS Int environment | 173 | Most active — integration env noise |
| SPCS: Large number of allocations in the last 5 minutes | 144 | Memory allocation spikes |
| X-prod Intermediate With CPVO | 47 | Cross-prod events |
| SEV3: Engine crashed (segfault) | 27 | Production engine crashes |

---

## 11. Sample Query Patterns

These are proven query patterns for the `mcp__observe__generate-query-card` tool. Use these as templates when constructing investigation queries.

### Failed Transactions (last 24 hours)

```
Query the Transaction Info dataset (42728011) for transactions where status = "failure"
in the last 24 hours. Show rai_transaction_id, account_alias, org_alias, environment,
abort_reason, engine_size, duration, and engine_version. Sort by timestamp descending.
Limit to 50 results.
```

**Expected columns:** rai_transaction_id, account_alias, org_alias, environment, abort_reason, engine_size, duration, engine_version
**Key insight:** duration = -1 means engine crashed before transaction completed.

### Transaction Failure Rate by Account

```
Query the Transaction Info dataset (42728011) for the last 24 hours.
Group by account_alias and status. Count transactions per group.
Show account_alias, status, and count. Sort by count descending.
```

### Active Alarms by Monitor

```
Query the Monitor Detections dataset (41832993) for the last 24 hours.
Filter to Type = "NewAlarm". Group by MonitorName. Count alarms per monitor.
Sort by count descending. Limit to 20.
```

### Error Logs for a Specific Transaction

```
Query the Snowflake Logs dataset (41832558) where rai_transaction_id = "<TXN_ID>"
and level IN ("error", "fatal"). Show timestamp, content, service_name, level.
Sort by timestamp ascending.
```

### Spans for a Specific Trace

```
Query the Spans dataset (41867217) where trace_id = "<TRACE_ID>".
Show span_name, duration, service_name, response_status, error_message,
parent_span_id, span_id. Sort by start_time ascending.
```

### Engine Crash Logs

```
Query the Snowflake Logs dataset (41832558) for the last 24 hours where
content contains "segmentation fault" and environment = "spcs-prod".
Show timestamp, rai_engine_name, account_alias, content. Sort by timestamp descending.
```

### Monitor Inventory

```
Query the usage/Observe Monitor dataset (41759358). Show monitor_id, name,
rule_kind, package. Sort by name ascending.
```

### Metric Query: Transaction Rate by Environment

```
Query the RelationalAI/Metrics dataset (41861990) for metric_name = "transactions_total"
in the last 1 hour. Group by environment. Show the rate of change over time.
```

### Long Running Spans

```
Query the Long Running Spans dataset (42001379) for the last 24 hours
where environment = "spcs-prod". Show span_name, duration, service_name,
rai_engine_name, account_alias. Sort by duration descending. Limit to 20.
```

### Cross-Dataset: Transaction with Error Logs and Spans

```
Step 1: Query Transaction Info (42728011) for a failed transaction to get rai_transaction_id
Step 2: Query Snowflake Logs (41832558) filtering by that rai_transaction_id, level = "error"
Step 3: Query Spans (41867217) filtering by that rai_transaction_id, error = true
```

This multi-step pattern is the standard workflow for investigating a specific transaction failure end-to-end.
