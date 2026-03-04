# SPCS Architecture Reference

## Components

| Component | Role | Where |
|---|---|---|
| Native App Package | Installable artifact: SQL scripts, SPCS container images, Streamlit UI, manifest | Provider account |
| SQL Integration Layer (sql-lib) | SQL objects exposing RAI functionality: procedures, UDFs, tasks, streams | Consumer account |
| Engine Resource Provider (ERP) | Single-tenant coordinator for metadata and resource management | Consumer account (SPCS) |

## Service Layers

**NO end-to-end tracing between SQL layer and ERP.** Must correlate manually.

### SQL Layer (`spcs-integration`)

- Stored procedures: `api.exec()`, `api.exec_into()`, `api.process_batches()`
- Data stream tasks, UDFs
- Emits telemetry directly to event table (NA SQL logs/traces)

### ERP Layer (`spcs-control-plane`)

- Engine/database management
- Transaction coordination and heartbeat monitoring
- BlobGC, compilations cache management
- Emits telemetry via OTel collector → event table

## Cross-Service Correlation

| Correlation Key | Found In | Links |
|---|---|---|
| `pyrel_program_id` | Spans | SQL layer ↔ ERP layer (primary) |
| `sf.query_id` / `request_id` | Spans, Logs | Snowflake query context |
| Hashed DB name | Both layers | Last resort matching |
| `rai_transaction_id` | All datasets | Transaction ↔ Spans ↔ Logs (within same layer) |
| `trace_id` / `span_id` | Spans | Distributed trace within a single service layer |

## Provider vs Consumer Account

| Account Type | Purpose | Telemetry |
|---|---|---|
| **Provider** | Hosts App Package, image repos, billing config | No running app code, no telemetry |
| **Consumer** | Where Native App is installed, all RAI services run | All service telemetry originates here |
| **Events Account** | Dedicated per region for telemetry forwarding | Receives event table shares, forwards to Observe |

### Mapping Consumer to Provider

Query in Observe:
```opal
make_col PROVIDER_ACCOUNT_NAME:string(attributes.PROVIDER_ACCOUNT_NAME)
make_col CONSUMER_ACCOUNT_LOCATOR:string(attributes.CONSUMER_ACCOUNT_LOCATOR)
filter metric = "telemetry.spcs.consumer_application_state"
pick_col timestamp, account_alias, org_alias, PROVIDER_ACCOUNT_NAME, CONSUMER_ACCOUNT_LOCATOR
dedup account_alias
```

## Compute Pool Instance Types

| Pattern | Instance | Purpose |
|---|---|---|
| `*_COMPUTE` | STANDARD_2 | Control plane |
| `*_COMPUTE_XS` | HIGH_MEMORY_1 | XS engines |
| `*_COMPUTE_S` | HIGH_MEMORY_2 | S engines |
| `*_COMPUTE_XL` | HIGH_MEMORY_5 | XL engines |

## Environments

| Environment | Description |
|---|---|
| `spcs-int` | Integration — development and testing |
| `spcs-staging` | Staging |
| `spcs-prod` | Production (rings 0, 1, 2) |
| `spcs-latest` | Latest — acts as both consumer and provider for telemetry |
| `spcs-expt` | Experimental |
| `spcs-ea` | Early access |

### Deployment Ring Order

Int → Staging → Prod Ring 0 → Prod Ring 1 (approval required) → Prod Ring 2 (approval required)

## Telemetry Pipeline

```
SPCS Services (rai-server, spcs-control-plane, etc.)
    → Consumer OTel Collector (consumer-otelcol)
    → Event Table (TELEMETRY.TELEMETRY.SHARED_EVENTS)
    → Event Sharing (to Events Account)
    → O4S Native App tasks
    → Observe
    → Datadog (via configured pipelines)
```

### Telemetry Types

| Type | Path | Notes |
|---|---|---|
| Continuous logs | Services → stdout → OTel collector → event table → Observe | Default telemetry |
| On-demand logs | Services → OTel collector → private stage file on consumer | Sensitive, NOT sent to Observe |
| Traces | Services → OTel tracing library → OTel collector → stdout → event table | |
| Metrics | Services → Prometheus → OTel collector scrapes → stdout → event table | |
| NA SQL logs/traces | Stored procedures/UDFs → event table directly | No OTel collector |

### Telemetry Latency

- Threshold: > 30 minutes → post in `#ext-relationalai-observe`
- Check: [O4S Pipeline Health dashboard](https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-O4S-Pipeline-Health-42090551)
- Mitigation: upsize `observability_wh` warehouse

## ERP Error Codes

ERP error codes are defined in `platform-extended.md`.

## Escalation

| Issue Type | Team | Slack Channel |
|---|---|---|
| Engine failures (oncall) | ERP / Julia / Storage | #team-prod-engine-resource-providers-spcs |
| Native App integration | Integration team | #team-prod-snowflake-integration |
| PyRel/UX issues | UX team | #team-prod-experience |
| Observability issues | Reliability | #helpdesk-observability |
| Slow queries | Performance | #helpdesk-slow-queries |
| CI/CD failures | Infrastructure | #project-prod-continuous-delivery |
| Observe vendor issues | Observe support | #ext-relationalai-observe |
| Snowflake support | Snowflake | #ext_rai-snowflake |
| Billing | Billing team | #project-prod-snowflake-billing |
| ERP monitor alerts | ERP team | #erp-observe-monitor |
| BlobGC issues | BlobGC team | #component-blobgc |
| Compilations cache | Cache team | #project-compilations-cache |
