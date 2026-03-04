# Slack-Sourced Investigation Patterns & Tribal Knowledge

**Date:** 2026-03-02
**Sources:** Slack channels searched via MCP (public channels only)
**Purpose:** Augment JIRA-based incident analysis with investigation patterns, tribal knowledge, and RCA details that oncallers use but don't document in tickets.

---

## 1. Key Slack Channels for Incident Investigation

| Channel | Purpose | Why It Matters |
|---------|---------|----------------|
| `#team-prod-engine-oncall` (C04NAKBMP4Y) | Engine incident triage; daily bot-driven syncs | Primary source of engine RCA discussion |
| `#team-prod-oncall` (C028U514FQV) | Broader production oncall | Cross-team incident coordination |
| `#team-prod-infrastructure-oncall` (C0AHUNB7B99) | Infra oncall (new, 2026-03-02) | CI/CD and infra incident triage |
| `#feed-alerts-oom` (C05R4EFBH8V) | Dedicated OOM alerts | Deep OOM investigation discussions |
| `#feed-alert-segfault` (C05U6559VMF) | Segfault alert feed | Segfault triage |
| `#helpdesk-segfaults` (C07BF5UDD8F) | Segfault investigation requests | Core dump retrieval coordination |
| `#feed-alert-erp` (C07818TN2TH) | ERP alert feed | ERP error triage |
| `#erp-observe-monitor` (C07JZ03HU4R) | ERP + Observe monitoring | ERP actionable monitor tuning |
| `#component-blobgc` (C051N4QBPRB) | BlobGC discussions | BlobGC failure mode analysis |
| `#helpdesk-observability` (C063VTB7FCJ) | Observability helpdesk | Telemetry outage investigation |
| `#team-prod-engine-resource-providers-spcs` (C063KNGN6FL) | ERP/SPCS engine issues | ERP failure patterns |
| `#team-prod-post-incident-review` (C05T8AP4MBQ) | PIR tracking | PIR dismissal rationales (contain root cause insights) |
| `#customer-ritchie-bros` (C05FQPCR69F) | Ritchie Brothers customer | RB-specific incident coordination |
| `#customer-ey` (C04K4BV1RM4) | EY customer | EY incident coordination |
| `#team-customer-support` (C06PK9GBDCJ) | Customer comms coordination | Outage notification templates |
| `#team-field` (C857W2738) | Field team | Core dump retrieval, customer access |
| `#feed-highsev-incidents` (C051XNDC7QX) | High-sev incident feed | SEV1/SEV2 alert subscription |
| `#project-prod-continuous-delivery` | CI/CD deployment | Deployment failure discussions |
| `#project-compilation-cache` | CompCache | CompCache failure patterns |

---

## 2. Engine Incident Investigation — Slack-Only Knowledge

### Daily Oncall Bot Sync

The engine oncall channel has an **automated daily bot** (8:00 CST) that posts:
- Open SEV1/SEV2 incidents without activity in past 24h
- Open SEV3 incidents without activity in past 3 days
- Mitigated incidents without activity in past 5 days

The bot prompts: "Engine Oncallers, for the engine incident sync today, please call out anything that needs to be discussed in this thread."

**Why this matters for /investigate:** The bot's sync cadence defines the real SLA oncallers operate under — not the JIRA severity SLAs. Incidents without bot attention for 3+ days are effectively abandoned.

### Core Dump Retrieval — DEAD on SPCS

**Critical finding:** Core dumps are NO LONGER AVAILABLE on SPCS as of 2025-09-17.

- Tracked in **RAI-42503**
- Snowflake confirmed: "our Engineering team has confirmed that we do not currently support access to coredumps... the previous core dump functionality in container directories was unintentional and occurred due to an earlier kernel configuration."
- Impact: Max Schleich: "we don't have the ability to get core dumps on SPCS anymore, so it's very hard to investigate them further"
- Dean De Leo lowered segfault monitor priority to medium for ALL accounts because "there is very limited action that can be done for seg faults nowadays"
- The Confluence runbook (`https://relationalai.atlassian.net/wiki/spaces/ES/pages/385253381`) is outdated — it still describes the retrieval process

**When core dumps WERE available:**
```sql
SELECT get_presigned_url(@relationalai.APP_STATE.CLIENT_LOG_STAGE, 'coredumps/core.zst') AS presigned_url;
```
Required customer admin access. Common failure: presigned URL returns 404 (no core dump written).

**Implication for /investigate:** Don't suggest core dump retrieval for SPCS segfaults. Instead, check logs/Observe for stack traces and recommend filing a bug with available evidence.

### Monitor Tuning (Babis Nikolaou, Feb 2026)

- Disabled the old log-based monitor for segfaults
- Introduced a **general crash monitor** (excludes OOMs, excludes segfaults during shutdown)
- Made the **OOM monitor** specific to OOM-only crashes
- All set to SEV3; `rai_studio_sac08949` (Tolga's experiments) filtered out

### "Expected" Errors to Ignore

George Kollias (engine team): "the auto-suspender log is a warning irrelevant to the engine failure"
- Auto-suspender errors in logs are **noise** during engine failure investigation — they fire because the engine is already failing, not as a cause.

### Engine State Transitions (Snowflake Restarts)

Container status: `running → pending (~25min gap) → running` indicates a **Snowflake-initiated container restart**, not a RAI-side crash. This is how oncallers distinguish SF maintenance from real crashes using the Engine Failures dashboard.

---

## 3. OOM Investigation — Slack-Only Techniques

### Max Schleich's OOM Investigation Methodology

1. Open OOM dashboard with engine name and time range
2. Check **Julia GC live bytes** — look for spikes (e.g., "from ~9 GiB to 40 GiB")
3. Check **Datadog/Observe logs** with transaction ID to identify what was being computed
4. Check **continuous CPU profile** (`/profiling/explorer`) to identify hotspots
5. Correlate with transaction logs filtered by `@rai.transaction_id`

### OOM Patterns Found in Slack (NOT in JIRA)

| Pattern | Signal | Example |
|---------|--------|---------|
| Large Julia heap with no transactions | Memory leak — Julia heap grows even idle | Similar to EY SAM OOMs |
| Quick spike outside 10s reporting period | OOM happens too fast for Datadog to capture | Spike falls between metric samples |
| Large metadata on XS engines | XS too small for metadata operations | ATT case — recommend S or M |
| Large ASTs in optimizer | Julia heap spikes from ~7GiB to 52GiB | Type inference + optimizer interaction |
| Two concurrent transactions both hitting type inference | Compound memory pressure | Observed in multi-tenant engines |
| OOM during result serialization | After "Estimated cardinality of output relation" log | Large result set serialization |
| OOM brake cancellation | `OOMGuardian triggered full collection` | Proactive cancellation, not a crash |
| BlobGC OOM during metadata deserialization | Julia GC slowdown + page buffer eviction not responding | Todd Veldhuizen's deep analysis |

### Key Dashboards (with URLs)

| Dashboard | URL | Migration Status |
|-----------|-----|-----------------|
| OOM Investigations (Datadog, legacy) | `https://app.datadoghq.com/dashboard/hhw-p5u-btj/oom-investigations` | Being replaced by Observe |
| Memory Breakdown (Observe) | `https://171608476159.observeinc.com/workspace/41759331/dashboard/Memory-Breakdown-42602551` | Current |
| BlobGC Dashboard (Observe) | `https://171608476159.observeinc.com/workspace/41759331/dashboard/BlobGC-Dashboard-42245311` | Current |
| Continuous CPU Profiling (Observe) | `https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-Continuous-CPU-Profiling-41782266` | Current |
| Engine Overview (Observe) | `https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-Engine-Overview-MR-WIP-41925747` | Current |

### Negative Pager Limit Investigation (NCDNTS-11928 Slack Thread)

From `C02A1VBSH19/p1769610756190849`:
- Engine was using memory from the safety margin
- A 5-minute GC pause caused a brownout-like event
- Kiran Pamnany: "A 14GB heap could have a really long collection." Even LLVM compilation caused >30 second stop-the-world GC pauses
- **Fix:** PR #27072 — subtract GC time from elapsed time check before triggering the pager exception

---

## 4. BlobGC — Slack-Only Failure Modes

### BlobGC OOM Death Loop (Todd Veldhuizen, NCDNTS-4515)

XL engines in SPCS get selected for BlobGC → gc interval set >250G → OOMGuardian can't keep up (>50% wall time on gc) → container OOM killed → restarted → re-selected for BlobGC → **infinite death loop**.

Recognition: purely tribal knowledge. Not in any runbook.

### Storage Upgrade Resets BlobGC State

jian.fang found via Observe trace analysis that storage upgrades call `resetBlobGCState()`, which was the root cause of a specific incident. Not documented in any runbook.

### Multiple ERP Race Condition

Irfan Bunjaku found that multiple ERPs on the same account (`rai_latest_idb96670`) cause BlobGC to trigger twice within a minute instead of every hour. Visible only through log frequency analysis in Observe.

### Dedicated vs Background BlobGC Engine

Two types exist:
- **Background (BG) engine**: Requires `LastCompleted` to be a valid non-zero value. If blobgc state was created before recent changes AND the account never had a successful pass, the BG engine never starts.
- **Dedicated `full_blobgc` engine**: Manually created by users. Creating one:
```sql
CALL relationalai.api.create_engine('full_blobgc', 'HIGHMEM_X64_S', {'auto_suspend_mins': 60, 'await_storage_vacuum': true})
```

### Inode/Leaf Reporting Bug

Todd Veldhuizen: If an inode points to a leaf page destroyed but evicted from `recently_deleted_pages`, BlobGC wrongly reports it as a root. Found via code analysis of `report_roots.jl`.

---

## 5. ERP Error Taxonomy — Runbook Gaps Found in Slack

### Error Codes MISSING from the Actionable ERP Runbook

| Error Code | Flagged By | Status |
|-----------|-----------|--------|
| `erp_enginerp_internal_engine_provision_timeout` | Alexandre Bergel | NOT in runbook |
| `erp_unknown_internal_middlewarepanic` | Alexandre Bergel | NOT in runbook |
| `erp_txnevent_internal_request_reading_error` | Alexandre Bergel | NOT in runbook |
| `erp_blobgc_sf_sql_compute_pool_suspended` | Richard Gankema | NOT in runbook |
| `erp_blobgc_engine_blobgc_engine_response_error` | jian.fang | Known bug; incident creation disabled |
| `erp_logicrp_sf_unknown` | Documented | SF internal issue |

### ERP Monitor Noise Discussion

- jian.fang disabled incident creation for `erp_blobgc_engine_blobgc_engine_response_error` due to high volume
- Sagar Patel: "Monitors will always have noise. We've been so hesitant to roll out monitors that file incidents."
- Zekai Huang: "Individual customer monitors are volatile. Often if the all-up is good and only the individual customer one is red, it's usually not very actionable."
- Wei He: "If not happening repeatedly, safe to close." (for `erp_txnevent_*` errors)

### ERP Investigation Tools

| Tool | URL | Purpose |
|------|-----|---------|
| ERP Actionable Monitor V2 | `https://171608476159.observeinc.com/workspace/41759331/promote-monitor/ERP-actionable-monitor-v2-42488209` | Monitor configuration |
| ERP Restart Dashboard | `https://171608476159.observeinc.com/workspace/41759331/dashboard/ERP-Restart-42156070` | Correlate ERP restarts with cache misses |
| Actionable ERP Runbook | `https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425` | Central ERP reference |

---

## 6. CI/CD — Slack-Only Patterns

### Poison Commit Process (Detailed)

1. **Detection:** Oncallers spot regressions in INT via upgrade failures in SPCS-INT logs
2. **Filing:** Must explicitly file a poison commit to block the release
3. **Poison/Antidote system:** Located at `github.com/RelationalAI/raicloud-deployment/tree/main/cicd/poison`
4. **Antidotes must be explicitly registered.** Thiago Tonelli noted they once forgot to register a revert as an antidote.
5. **Ring behavior:**
   - Staging deployment does NOT fail on poison commits — it finds the latest non-poisoned INT deployment instead
   - Only prod-ring deployments fail on poison commits
   - Ring 3 failures block deployment to INT

### Impact Measurement

Owais Mohamed tracks weekly P75 deploy-to-INT times. One poison commit in spcs-sql-lib over a long weekend caused:
- 14 of 18 INT deployments to fail
- raicode deployment P75 inflated to 22h 41m (vs 9h target)
- TR3 success rate dropped from usual 80%+ to 26%

### Babis Nikolaou's Taxonomy Clarification

"Livesite issue is any failure in a production environment. Nowadays, incidents can track failures as early as ring 3."

### SF 10.5 Breaking Change (NCDNTS-12478 Slack Thread)

From `C04T0R0GLR5/p1771536760126739`:
- `CREATE ICEBERG TABLE` syntax broke — `external_volume` and `catalog` clauses documented as "optional" but were actually mandatory
- `SNOWFLAKE_DEFAULT_VOLUME` silently dropped, causing INSERT failures
- Feature flags for `TRANSIENT ICEBERG` not enabled on dev accounts
- Communication: RAI team worked with SF PM (Randy Pettus) and engineer (Shannon Chen) directly via Slack and Zoom
- Prior precedent: Wei He previously "asked the Snowflake team to roll back the breaking change"

---

## 7. Telemetry Investigation — Slack-Only Knowledge

### Standard Investigation Workflow

**Step 1:** Verify telemetry is actually missing via Telemetry Outages dashboard

**Step 2:** Check O4S task status:
```sql
SELECT *, DATEDIFF('minute', QUERY_START_TIME, COMPLETED_TIME) AS DURATION_MINUTES
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, current_timestamp()),
    RESULT_LIMIT => 100,
    TASK_NAME => '<O4S_TASK_NAME>'
));
```

**Step 3:** Mitigation:
- If task stuck: suspend and restart the O4S task
- If latency increasing: upsize warehouse (M → L)
- If Snowflake issue: file support tickets with Observe AND Snowflake

**Step 4:** File external tickets:
- Observe support: `https://customer.support.observeinc.com/servicedesk/customer/portal/7`
- Snowflake support: `https://app.snowflake.com/support/case/`

### Three-Tier Monitoring System (Ruba Doleh, Nov 2025)

1. **Event Table Telemetry Outage Monitor**: Fires after 20 min of no data. Immediate action.
2. **Observe Ingestion Lag Monitor**: Fires when latency >1 hour. Resize warehouse.
3. **Telemetry-type Monitors**: Fire if specific type (logs/metrics/traces) missing >4 hours. Evaluated every 4 hours.

### UAE North — The Full Story

- **Root cause**: O4S task latency steadily increases, triggering outage incidents
- **Standard mitigation**: Upsize warehouse (M → L)
- **Recurring muting problem**: Murilo muted the trace monitor but not the log one, causing re-fire
- **Access issue**: `rai_oncaller` workflow doesn't work for UAE North account. Multiple oncallers blocked from investigating because they lacked ACCOUNTADMIN. Manual IT intervention required.
- **Cost concern**: Running on Large warehouse for observability is expensive; Ruba asked about cost reduction
- **Snowflake bug (Feb 2026)**: Telemetry was forwarded to centralized events account, but due to SF bug, some telemetry still flowed through the old account. SF deployed a fix; old account can be retired.
- **Oct 23 2025**: Filed Observe incident OBSSD-1771 for steadily increasing task latency
- **Sep 15 2025**: O4S procedure getting 504 from Observe's collect endpoint. Nobody had account access.

### Ary Fasciati's Investigation Philosophy

"I think this some temporary SF task issue that auto-resolved" and "Might be a temporary hiccup... fine to mitigate if we can't observe any telemetry loss."

Consistently advocates for mitigating without deep investigation when telemetry recovers quickly.

### Event Table Heartbeat — How It Works

Moaz Elshorbagy's technical explanation:
- Heartbeat service emits a single event to event table in OTLP format
- Same log event processed twice: by `LOGS_TO_STAGE` task and `NA_LOGS_TO_STAGE` task (intentional duplication)
- Goes to Datadog in two formats
- Monitor fires after 20 min of missing heartbeat

Babis raised 3 heartbeat incidents that Ary confirmed were false alarms: "I did a cursory check... these are false alarms. We might need to tune the alerts a bit more."

---

## 8. Customer Communication Patterns

### Large-Scale Outage Notification Template (Feb 24 2026 SF Marketplace Incident)

Flow:
1. Adeel identified impacted accounts → posted growing list in #team-prod
2. Manish compiled Google Doc with impacted accounts and paid customer identification
3. Customer support team tagged for comms
4. Genevieve drafted notification template in Slack for review
5. Andrew Goetz approved: "Ship it"
6. Genevieve informed all active customers on affected list

Template structure:
- What happened (upstream Snowflake marketplace issue)
- Start time
- Visible symptoms
- What NOT to do (don't drop/recreate the app)
- Resolution expectations
- Follow-up commitment

### CashApp/Block Storage Cost Explosion (NCDNTS-9881)

- BlobGC failures → 0.2PB storage in dev account → ~$3k/month
- CashApp response: "understandably unwilling to reinstall the app until we can provide a confident statement that the issue will not recur"
- Nathan Daly's comms: cleared 200TB garbage, retained 30TB real data, queued product repairs
- Treated as independent SEV2 (customer install blocked)

### Monitor-to-Customer-Action Pattern

Nathan Daly set up a threshold monitor (Monitor-42899672) in Observe that files Engine service incidents at High Priority, where "someone should take action on this by immediately reaching out to support to talk to the customer."

### EY Monitoring Approach

- Custom monitors for EY and ATT accounts for top-level SLOs
- Sagar Patel: "These monitors were never actionable themselves, so we never upgraded them to file incidents."
- Shifted to collective customer success rate monitoring reviewed weekly

---

## 9. Ritchie Brothers — Complete Slack Picture

### Performance Regression from Normalization (NCDNTS-9887)

Dedicated channel: `#ncdnts-9887-rb-performance-regression`
- Root cause: CSI iterators performing orders of magnitude worse with string-heavy workloads and short-distance backtracking in trees
- Mitigation: switched S → L engines (barely enough), rewriting rules to avoid joins on string keys
- Fix: Richard Gankema's PR #25905 for CSI iterator regression

### Multi-Engine Simultaneous Failure (July 2025)

7 engines failed simultaneously. Investigation (Grigoris/George):
- Engines showed 25-minute gap in heartbeats
- Container status: running → pending → running
- **Snowflake-initiated container restart** — some transactions survived, others didn't

### BlobGC OOM Deep Investigation (Sept 2025)

Todd Veldhuizen, Gerald Berger, genevieve.lalonde:
- OOM during blob listing phase (not under heavy load)
- Julia heap spike from ~48GB
- Page buffer eviction stuck: "MemCache maintenance: took too long" (145s, 152s)
- Julia GC time ramped from 2% to 48.9% wall time
- Root cause hypothesis: eviction tasks stuck (not starved) due to metadata deserialization + Julia GC interference

### What's NOT in JIRA for RB

- Cross-team coordination patterns (engine oncall → field team → customer admin for core dumps)
- Specific Observe dashboard configurations and OPAL queries used for debugging
- Knowledge that SF container restarts cause selective transaction failures
- Relationship between normalization, CSI iterators, and string performance
- BlobGC eviction stuck-task hypothesis

---

## 10. Stuck Transaction Investigation — Slack-Only Patterns

### Arroyo Deadlock

Log pattern: "Arroyo periodic deadlock check: took too long"
- Mitigation (Babis): use a different database on the same engine, or same database on different engine
- Alexandre Bergel identified a specific raicode commit (`bfe0a993b00`) causing deadlocks during transaction cancellation

### Lock Contention

Josh's example: engine hung on single small transaction, zero CPU. Diagnosed as deadlock in raidocs parser.

### OPAL Queries for Stuck Transaction Detection

Vukasin Stefanovic wrote custom Observe worksheets using OPAL to match TransactionBegin/TransactionEnd events to find transactions that started but never ended.

### EY Stuck Transactions (Jan 27 2026, 34-reply thread)

- Recursion didn't converge — ran 2+ days
- Dung Nguyen: "EY has nested loops; that's why sometimes it works, sometimes it doesn't. And we need to fix that in Loopy."
- Inner-loop2 evaluation not converging
- Large security group with >20K input sublots generating potentially over 100K splits
- Jeff from EY: "wants to let it run and see"

---

## 11. CompCache — Slack-Only Patterns

### Race Condition on raicloud (EY)

Irfan Bunjaku: Compilation cache loading and writing happen simultaneously with the same name, corrupting the cache. Fixed in raicode/SPCS but still recurring on raicloud (maintenance mode).

### Three-Strike Rule

CompCache stops running after 3 consecutive failures. jian.fang: "the cache loading aborted after exceeding 60 seconds. Finally, the compilation cache stopped running after 3 failures in a row."

### Security Concern with Debug API

`debug_export_compcache` and `debug_export_juliatrace` procedures removed due to IP/security concerns (allowing admin users to download proprietary engine binaries). Irfan requesting reinstatement with safeguards.

---

## 12. Process Insights

### Moaz Elshorbagy's Incident Response Feedback

1. Some incidents close without a single update — worst practice
2. First update is critical: should include impact, current root cause assumption, next action
3. Mitigation documentation should detail manual steps taken

### Zekai Huang's AI Vision

"We should leverage AI a lot more in our incident response. Potentially have AI agent as our third oncaller."

### PIR Compliance Gap

Zekai: "we have to connect problem reporting, tracking, working, and resolving all the way to lessoning (postmortems). Auditors are meticulous." Many incidents require postmortems but have none linked.

---

## 13. Additional Dashboards & Runbooks Found in Slack

### Dashboards NOT Previously Catalogued

| Dashboard | URL | Purpose |
|-----------|-----|---------|
| Memory Breakdown | `observeinc.com/.../Memory-Breakdown-42602551` | Memory analysis per engine |
| Continuous CPU Profiling | `observeinc.com/.../RelationalAI-Continuous-CPU-Profiling-41782266` | CPU profile analysis |
| Engine Overview | `observeinc.com/.../RelationalAI-Engine-Overview-MR-WIP-41925747` | Engine resource overview |
| ERP Restart | `observeinc.com/.../ERP-Restart-42156070` | ERP restart correlation |
| Product SLOs | `observeinc.com/.../Product-SLOs-42733752` | Product SLO tracking |
| Engineering SLOs | `observeinc.com/.../Engineering-SLOs-42723876` | Engineering SLO tracking |
| SPCS Versions | `observeinc.com/.../SPCS-Versions-42021302` | Version tracking |
| ERP Actionable Monitor V2 | `observeinc.com/.../ERP-actionable-monitor-v2-42488209` | Monitor config |

### Runbooks NOT Previously Catalogued

| Runbook | URL | Purpose |
|---------|-----|---------|
| Investigate Missing Telemetry | `relationalai.atlassian.net/wiki/spaces/SPCS/pages/1339392001` | Step-by-step telemetry investigation |
| Observability Architecture | `relationalai.atlassian.net/wiki/spaces/SPCS/pages/1328840706` | Architecture diagram (partially outdated) |
| Debugging Segfaults with Core Dumps | `relationalai.atlassian.net/wiki/spaces/ES/pages/385253381` | **OUTDATED** — core dumps no longer available on SPCS |

### External Support Portals

| Service | URL |
|---------|-----|
| Observe Support | `https://customer.support.observeinc.com/servicedesk/customer/portal/7` |
| Snowflake Support | `https://app.snowflake.com/support/case/` |
| GitHub Status | `https://www.githubstatus.com` |

---

## 14. Key People in RCA Discussions

| Person | Role in Investigations |
|--------|----------------------|
| Charalampos (Babis) Nikolaou | Engine oncall lead, monitor configuration, investigation methodology |
| Maximilian Schleich (Max) | OOM investigation expert, performance analysis |
| Dean De Leo | Segfault monitor tuning, oncall policy decisions |
| Todd Veldhuizen | Deep memory/pager analysis (BlobGC), code-level root causes |
| Kiran Pamnany | SPCS infrastructure, core dump status |
| George Kollias | ERP/engine resource provider expertise |
| Richard Gankema | Performance engineering, CSI iterator fixes |
| Ary Fasciati | Observability lead, telemetry outage triage philosophy |
| Ruba Doleh | Three-tier monitoring system architect |
| Moaz Elshorbagy | Event table heartbeat, incident response quality |
| Zekai Huang | Process improvement, AI oncaller vision, compliance |
| jian.fang | BlobGC/CompCache log analysis, race condition discovery |
| Irfan Bunjaku | ERP race conditions, dedicated BlobGC engine expertise |
| Nathan Daly | Monitor-to-customer-action patterns, CashApp escalation |
| Sagar Patel | Monitor philosophy, customer SLO monitoring approach |
| Genevieve Lalonde | Customer notification drafting, BlobGC analysis |
| Vukasin Stefanovic | OPAL query patterns for stuck transaction detection |

---

*Generated 2026-03-02 from Slack channel search across 20+ channels.*
