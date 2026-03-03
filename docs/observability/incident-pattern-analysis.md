# NCDNTS Incident Pattern Analysis — Comprehensive 974-Incident Study

**Period:** September 2025 — March 2026 (6 months)
**Total incidents analyzed:** 974 closed non-duplicate incidents
**Data sources:** JIRA (full ticket body + comments for ~120 tickets across 6 categories), Observe aggregate queries, Slack (20+ channels searched for tribal knowledge and RCA details not in JIRA)
**Analysis date:** 2026-03-02

---

## Executive Summary

974 incidents were closed as non-duplicates over 6 months. Key findings:

- **82% of CI/CD incidents (215/261) have zero investigation comments** — the single largest opportunity for `/investigate`
- **~48 "other" incidents per 6 months are auto-closeable** (25% of the "other" category) based on pattern matching alone
- **33% of ERP incidents are auto-detected duplicates** — OpsAgent already handles a third of ERP volume
- **Ritchie Brothers** is the most engine-incident-prone external customer (5 of 15 sampled engine tickets)
- **EY** drives 26% of "other" incidents, almost all from running old engine versions
- **Snowflake maintenance windows** are the #1 false-positive pattern for engine incidents (33% of sampled engine tickets)
- **UAE North account** generates 38% of ALL telemetry incidents (20/53)
- **Core dumps are DEAD on SPCS** since 2025-09-17 (Snowflake confirmed intentional removal) — segfault investigation severely limited
- **6+ ERP error codes are missing from the Actionable ERP Runbook** — oncallers repeatedly flag gaps in Slack
- **BlobGC has an undocumented OOM death loop** on XL engines — purely tribal knowledge in Slack
- **Zekai Huang (prod lead) explicitly wants AI as "third oncaller"** — organizational buy-in exists
- **PIR/5-Whys fields remain dead** — 0% fill rate across all categories

---

## 1. Incident Volume by Category

| Category | Count | % of Total |
|----------|------:|----------:|
| CI/CD & Deployment | 261 | 26.8% |
| Engine Crashes / OOM / Aborts | 208 | 21.4% |
| Other / Uncategorized | 191 | 19.6% |
| ERP Errors | 167 | 17.1% |
| Monitored Account Errors | 94 | 9.7% |
| Telemetry / Observability | 53 | 5.4% |

---

## 2. Engine Crashes, OOM, and Transaction Aborts (208 incidents)

### Root Cause Distribution (from 15-ticket deep dive)

| Root Cause | Frequency | Tickets |
|-----------|-----------|---------|
| SF maintenance window / false positive | 33% (5/15) | 11862, 11299, 11224, 10953, 10059 |
| OOM / memory pressure | 27% (4/15) | 11928, 11504, 10495, 9943 |
| Stuck/deadlocked transactions | 20% (3/15) | 11925, 11435, 11980 |
| BlobGC OOM (metadata deserialization) | 13% (2/15) | 10495, 10381 |
| Segfault (core dump needed) | 7% (1/15) | 12025 |

### Key Patterns

**Pattern 1: SF Maintenance Window (most common, non-actionable)**
- Engine goes PENDING during SF weekend maintenance
- Heartbeat cache evicts in-flight transactions → "engine failed" abort
- Ritchie Brothers most affected (weekend CDC workloads)
- **Signal:** Engine state = PENDING around alert time in Engine failures dashboard
- **Action:** Close immediately after confirming maintenance timing

**Pattern 2: OOM — Three Subtypes**
- *GC brownout false alarm:* GC pause prevents pager eviction → OOM monitor fires but no real OOM. Signal: GC pause coincides with pager warning.
- *Rapid Julia memory spike:* Julia poolmem spikes faster than pager can evict (11→33GB in 20s). Signal: High cost warning in logs before crash, QE scan activity.
- *Undersized engine:* OOM brake cancels repeatedly on same engine. Signal: same transaction type failing repeatedly on HIGHMEM_X64_S. Fix: larger engine.

**Pattern 3: Stuck Transactions — Three Subtypes**
- *Pager deadlock:* CPU 100% on 1-2 cores, zero IO after 30min. Stack: `unsafe_get_page_no_transition -> lock`. Requires bug fix.
- *Long structural recursion:* QE materialization 100K+ seconds, 2B+ tuples. CPU 100% with normal IO initially. Usually completes — wait it out.
- *Stuck CANCELLING:* `aborting active transaction ... in state CANCELLING` for hours with no TransactionEnd. Resolution: engine deletion.

**Pattern 4: User-Initiated Engine Deletion (false positive)**
- User deletes engine or resizes (delete old + create new) → crash alert fires
- Check ERP logs for deletion events before treating as real crash

**Pattern 5: BlobGC OOM (Ritchie Brothers recurring)**
- BlobGC engine crashes during metadata deserialization
- Engine auto-restarts and usually stabilizes
- GapKeyWithoutJuliaValError = engine version mismatch marker

### Key Dashboards

| Dashboard | Purpose |
|-----------|---------|
| Engine failures | First stop for all engine_failed and crash incidents |
| OOM Investigations | Julia GC live bytes, pager metrics, eviction rounds |
| Pager dashboard | Buffer pool health, pinned pages |
| DWI | In-flight transactions, engine activity |

### Top Affected Accounts

| Account | Engine Incidents | Primary Pattern |
|---------|-----------------|----------------|
| ritchie_brothers_oob38648 | 5 | Maintenance windows + BlobGC OOM |
| ey-production | 2 | Stuck transactions (recursion + pager deadlock) |
| rai_studio_sac08949 | 2 | Internal test — fast close as known error |

---

## 3. ERP Errors (167 incidents)

### Summary Statistics

| Metric | Value |
|--------|-------|
| Auto-detected duplicates (OpsAgent) | ~55 (33%) |
| Resolved as Done | ~90 (54%) |
| Known Error | ~25 (15%) |
| Won't Do | ~20 (12%) |

### ERP Error Taxonomy

| ERP Code | Meaning | First Check |
|----------|---------|-------------|
| `txnevent/internal` broken pipe | Client disconnected | Close if no txn failure |
| `blobgc/sf_sql compute_pool_suspended` | SF compute pool suspended | Check for manual account changes |
| `blobgc/internal circuit_breaker_open` | BlobGC can't reach engine | Find upstream engine incident |
| `txnmgr/sf txn_commit_error` | Snowflake platform issue | Check status.snowflake.com |
| `txnrp/awss3 next_page_error` | S3 rate limiting | Check if internal GC span |
| `unknown/engine send_rai_request_error` | Engine briefly unreachable | Check Julia GC brownout |

### Three Dominant Subsystems

1. **BlobGC** (6/15 sampled): storage threshold, circuit breaker, PROVISION_FAILED engines, data loss alerts, type mismatch, storage migration
2. **Transactions** (3/15): SF commit errors, stream write errors, S3 paging errors
3. **CompCache** (2/15): coordinator failures (auto-retry every 2h), cost/runaway engine alerts

### Cascading Failure Pattern (Critical)

Engine failure → BlobGC cannot run → storage threshold exceeded. This 3-step chain appears repeatedly. The AI investigator MUST recognize BlobGC storage alerts as downstream symptoms and look for a parent engine incident.

### Repeat Offender Accounts

| Account | Incidents | Notes |
|---------|-----------|-------|
| rai_studio_sac08949 | 25+ | Internal testing — bulk noise |
| by_dev_ov40102 | 20+ | BY dev account — high ERP error rate |
| rai_int_sqllib | 12+ | Integration testing |

### Key Runbooks

- ERP Runbook: `https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425/Actionable+ERP+monitoring+Run+book`
- BlobGC/CompCache: `https://relationalai.atlassian.net/wiki/spaces/ES/pages/890929153/Julia+Compilations+Cache`
- BlobGC Dashboard: `https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311`

---

## 4. CI/CD & Deployment (261 incidents)

### The "No Investigation" Problem

**82.4% of CI/CD incidents (215/261) are closed with zero investigation comments.** The predominant pattern: auto-generated ticket → check if next run passed → close.

### Workflow Failure Breakdown

| Category | Count | % |
|----------|------:|--:|
| SPCS-INT deployment | 92 | 35.2% |
| Test Ring 3 | 44 | 16.9% |
| Deployment (prod/expt/ring) | 30 | 11.5% |
| Poison commits | 10 | 3.8% |
| Test Ring 1 | 9 | 3.4% |
| SPCS-staging | 10 | 3.8% |
| Synthetic tests | 11 | 4.2% |
| Security/CVE | 22 | 8.4% |
| ArgoCD sync | 5 | 1.9% |
| Other (CosmosDB, Dependabot, etc.) | 18 | 6.9% |

### SPCS-INT (92 incidents, 35.2%)

87% closed without root cause. The workflow has 5+ parallel sub-jobs; a single SF platform issue generates 3-6 tickets simultaneously.

### Poison Commits (10 incidents)

| Repository | Count |
|-----------|------:|
| raicode | 6 (60%) |
| spcs-control-plane | 3 (30%) |
| spcs-sql-lib | 1 (10%) |

**Recurring pattern:** NCDNTS-10686 and NCDNTS-11242 are the same root cause (BlobGC/normalized padding) filed 2 months apart — the test gap was never fixed.

**Resolution:** Revert (preferred) or antidote workflow (forward-fix).

### External Outages

- GitHub outages cause cascading failures across ArgoCD sync + synthetic tests + CI workflows
- **Always check githubstatus.com FIRST** before internal investigation
- Alert latency means outages may already be over when the ticket arrives

### CI/CD Decision Tree

```
New CI/CD incident
├─ Title: "Poison commit <sha>"? → Revert or antidote workflow
├─ Multiple systems failing? → Check githubstatus.com first
├─ ArgoCD out-of-sync? → Check GH outage; if resolved <20min = transient
├─ Setup step fails? → Find recent PR that modified go.mod/workflow YAML, revert
├─ "EnginePending" in logs? → Check auto_suspend_mins, recreate engine
├─ SF API/syntax error? → Vendor regression; check SF release notes
├─ "/sys/fs/cgroup/" not found? → Revert commit that added cgroup access
├─ "CVE-" in title? → Route via code-ownership.yaml; batch concurrent CVEs
└─ Account matches *_cicd_validation_*? → Intentional test run; close
```

---

## 5. Monitored Account Errors (94 incidents)

### How They're Generated

Bot (`untracked.automation@relational.ai`) auto-creates NCDNTS ticket when a known RAI bug (RAI-XXXXX) fires in a "monitored account" (customer production). The ticket body contains: affected accounts, engine versions, databases, environment, and transaction log link.

### Key Statistics

- 19 unique RAI bugs generated 59% of all monitored account incidents
- All were SEV3 (Moderate - 1 Business Day ACK)
- None were customer-impacting (all `customfield_10077` = "No")

### Resolution Pattern (Standard — nearly identical across all tickets)

1. Acknowledge incident (same-day for Engine oncall)
2. Read the linked RAI bug ticket
3. If known + repair exists → close: "Known issue, tracked in RAI-XXXXX"
4. If new → investigate via transaction logs (Observe for SPCS, Datadog for non-SPCS), create repair, link it
5. If customer impact → contact customer team via Slack
6. Wait 3 business days for response; close if no reply

### Log Investigation Tools

- **SPCS (spcs-prod):** Observe log explorer filtered by transaction ID
- **Non-SPCS (prod):** Datadog logs filtered by `@rai.transaction_id`

---

## 6. Telemetry / Observability (53 incidents)

### Pattern Distribution

| Pattern | Count | % |
|---------|------:|--:|
| Transient platform issue (self-healing) | ~35 | 66% |
| RAI-side code/config bug | ~5 | 9% |
| Monitor misconfiguration / false alert | ~5 | 9% |
| UAE North account noise | ~20 | 38% |

### UAE North Account Problem

UAE North generates 38% of ALL telemetry incidents (20/53). An alert storm on Oct 16, 2025 generated 11 tickets in one day for the same account. Template variable leak (`{{webhookData.SNOWFLAKE_REGION}}`) reveals webhook configuration bugs.

### Three Telemetry Outage Patterns

**Pattern A: Transient (most common)** — Alert fires, telemetry missing 20-40min. No RAI change caused it. Root cause: SF task failures, Observe outage, Azure networking, or AWS outage. Self-heals; oncaller verifies via Observe dashboard and closes.

**Pattern B: RAI-side bug** — Sustained outage (hours). Caused by bad feature flag logic or data format bug. Requires code fix. PIR filed.

**Pattern C: Monitor misconfiguration** — Alert fires for inactive org/account. Not a real outage. Fix: adjust monitor exclusions.

### Key Dashboards

| Dashboard | URL |
|-----------|-----|
| Telemetry Outages | `https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-Outages-42760073` |
| Telemetry Heartbeats | `https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-heartbeats-42384426` |
| Observe Log Explorer | `https://171608476159.observeinc.com/workspace/41759331/log-explorer?datasetId=41832558` |

---

## 7. Other / Uncategorized (191 incidents)

### Sub-Category Breakdown

| Category | Count | % | Dominant Root Cause |
|----------|------:|--:|---------------------|
| Azure DB Failed to Open | 37 | 19% | Old engine version (EY) |
| Mixed other | 70 | 37% | Varies |
| StorageIntegration failures | 18 | 9% | EAI misconfiguration, transient |
| Heartbeat lost | 9 | 5% | Dev engines, provider gaps |
| Long-running transactions | 8 | 4% | Memory issues, customer logic |
| Engine provisioning failures | 8 | 4% | Azure US East capacity |
| Blob storage access errors | 7 | 4% | Transient SF storage |
| ERP upgrade failures | 6 | 3% | Disk space, account state |
| Trust Center ingestion | 6 | 3% | Snowflake-side bug |
| AWS key detection | 5 | 3% | False positives (CI) |
| Julia compilation >20 min | 4 | 2% | Customer logic (EY) |
| Cost alerts | 3 | 2% | Runaway costs |
| Engine suspended issues | 3 | 2% | CDC propagation |
| Others | 7 | 4% | Various |

### EY Account Analysis (49 incidents, 26% of "other")

EY runs pinned old engine versions → `CancelledException` during metadata deserialization → 20+ "database failed to open" tickets that are pure monitoring noise. Oncallers consistently note: "Old engine version, nothing we can do."

### Auto-Close Candidates (~48 tickets per 6 months)

| Pattern | Detection Rule | Saved |
|---------|---------------|------:|
| Test incidents | Summary matches /test incident\|testing.*oncall\|please ignore/i | ~12 |
| EY old engine DB failures | "database failed to open" + EY + old engine + CancelledException | ~20 |
| Trust Center ingestion | "Trust Center ingestion task failed" | ~6 |
| AWS key false positives | "AWS Keys ID is detected" + internal account | ~5 |
| Dev engine heartbeat | "heartbeat was lost" + engine name = person name | ~5 |

### Customer-Specific Investigation Shortcuts

| Customer | Shortcut |
|----------|----------|
| EY | Check engine version first. If old → known error. If new → Metadata team |
| BY | Check reference limits, stream table sync |
| Ritchie Brothers | Check CDC engine state, quarantined streams, compute pool costs |
| CashApp/Block | Check engine provisioning logs, blob storage access |
| ATT | Check PrivateLink and OpenID Connect config |
| IMCD | Check stream table sync, external function config |

---

## 8. Cross-Cutting Findings

### Finding 1: Investigation Quality is Poor

| Category | % with zero investigation comments |
|----------|--:|
| CI/CD | 82.4% |
| Poison commits | 100% (0/10 documented) |
| Prod deployments | 100% (0/30 documented) |
| Telemetry | ~60% (transients closed without analysis) |

### Finding 2: Cascading Duplicates Inflate Volume

A single Snowflake issue generates 3-6 CI/CD tickets (parallel sub-jobs). A single RAI bug generates multiple monitored account tickets. OpsAgent catches 33% of ERP duplicates but misses CI/CD cascades.

### Finding 3: Known Noise Patterns (~150+ tickets per 6 months)

| Source | Est. Tickets/6mo |
|--------|--:|
| CI/CD zero-investigation closures | ~215 |
| ERP auto-detected duplicates | ~55 |
| "Other" auto-close candidates | ~48 |
| Telemetry transients | ~35 |
| Internal test account incidents | ~30 |
| **Total noise** | **~383 (39% of all incidents)** |

### Finding 4: External Customer Risk Concentration

| Customer | Categories Affected | Severity |
|----------|-------------------|----------|
| Ritchie Brothers | Engine crashes, BlobGC OOM, CDC issues, transactions | High (2 SEV1s) |
| EY | Stuck transactions, Azure DB failures, compilation time | Medium (bulk noise) |
| BY | Compiler errors, provisioning, stream sync | Moderate |
| CashApp/Block | Engine provisioning, blob storage | Moderate |

### Finding 5: Snowflake is the #1 External Dependency Risk

- SF maintenance windows → 33% of engine incident false positives
- SF platform issues → 6-10% of CI/CD failures (confirmed)
- SF breaking changes → multi-day CI disruptions (SF 10.5 Iceberg)
- SF support response time: days not hours
- SF intentionally removed core dump support on SPCS (2025-09-17), severely limiting segfault investigation

### Finding 6: JIRA Captures <30% of RCA — Real Investigation Happens in Slack

Slack channel analysis reveals a massive gap between what's documented in JIRA and what oncallers actually know:

| Knowledge Area | In JIRA | In Slack Only |
|---------------|---------|---------------|
| OOM investigation methodology (5-step process) | No | Max Schleich's full workflow in #feed-alerts-oom |
| BlobGC OOM death loop on XL engines | No | Todd Veldhuizen's analysis in #component-blobgc |
| Core dumps permanently unavailable on SPCS | No | Kiran Pamnany confirmed in #ext_rai-snowflake |
| 6+ ERP error codes missing from runbook | No | Alexandre Bergel, Richard Gankema flagged in #erp-observe-monitor |
| Auto-suspender warnings are noise during engine crashes | No | George Kollias clarified in #team-prod-engine-oncall |
| Poison commit antidote must be explicitly registered | No | Thiago Tonelli's lesson in #project-prod-continuous-delivery |
| UAE North access issues blocking investigation | No | Multiple oncallers blocked in #helpdesk-observability |
| CompCache three-strike shutdown rule | No | jian.fang in #project-compilation-cache |
| Customer notification template and flow | No | Genevieve's template in #team-customer-support |
| Telemetry O4S task SQL for investigation | No | Zekai Huang in #helpdesk-observability |

### Finding 7: Core Dumps Are Dead — Segfault Investigation Severely Limited

**RAI-42503**: Snowflake confirmed core dump access was "unintentional and occurred due to an earlier kernel configuration." Removed 2025-09-17. Dean De Leo lowered segfault monitor to medium priority for ALL accounts because "there is very limited action that can be done for seg faults nowadays." The Confluence runbook is outdated and still describes the retrieval process.

### Finding 8: Organizational Buy-In for AI Oncaller Exists

Zekai Huang (prod lead): "We should leverage AI a lot more in our incident response. Potentially have AI agent as our third oncaller." This is explicit leadership endorsement for the `/investigate` command's mission.

---

## 9. Recommendations for /investigate

### New Classifications Needed

Current: `crash / OOM / brownout / pipeline / cross-service / unknown`

Add:
- **erp-error** — ERP subsystem error with established taxonomy
- **cascade** — downstream symptom of an upstream failure (BlobGC after engine crash)
- **noise** — known false positive or auto-closeable pattern
- **cicd** — CI/CD workflow failure
- **telemetry** — telemetry pipeline outage
- **customer-impact** — modifier flag, not a standalone classification

### Account-Aware Triage

The AI should recognize these account patterns immediately:

| Pattern | Action |
|---------|--------|
| `rai_studio_*`, `rai_int_*`, `rai_latest_*` | Internal — lower priority |
| `*_cicd_validation_*` | CI test account — likely intentional |
| `ey_fabric233_*` + old engine | Known error — check engine version |
| `ritchie_brothers_*` + weekend | Check SF maintenance window first |
| Engine name = person's name | Dev engine — auto-close heartbeat alerts |

### ERP Error Decision Tree

```
ERP error arrives
├─ BlobGC error? → Check for upstream engine incident (cascade pattern)
├─ broken_pipe/stream error? → Transient; close if single occurrence
├─ compute_pool_suspended? → Check for manual account changes
├─ circuit_breaker_open? → Find the failing upstream engine
├─ txn_commit_error? → Check status.snowflake.com
├─ S3/storage error? → Check for throttling; transient if single occurrence
└─ Account in repeat-offender list? → Check if known pattern for that account
```

### Cascade Detection

When a BlobGC storage alert fires:
1. Check if an engine failure occurred in the same account within the last 2 hours
2. If yes → this is a cascade. Link to the engine incident and close as downstream symptom.
3. If no → investigate BlobGC independently

### CI/CD Automation Opportunities

1. **Auto-check next run:** If subsequent pipeline run passed → classify as transient
2. **Duplicate grouping:** Group spcs-int sub-job failures within 30min window
3. **Poison commit template:** Auto-populate the 5 standard questions
4. **GitHub outage detection:** Check githubstatus.com before any CI investigation
5. **Recurring root cause surfacing:** Flag when a root cause matches a prior incident

---

## 10. Key Runbooks and Dashboards

### Runbooks

| Topic | URL | Notes |
|-------|-----|-------|
| Engine failed investigation (SPCS) | `https://relationalai.atlassian.net/wiki/spaces/ES/pages/806748161` | |
| Core dump access | `https://relationalai.atlassian.net/wiki/x/BYD2Fg` | **OUTDATED** — core dumps unavailable on SPCS since 2025-09-17 |
| Debugging segfaults with core dumps | `https://relationalai.atlassian.net/wiki/spaces/ES/pages/385253381` | **OUTDATED** — same issue |
| ERP monitoring runbook | `https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425` | Missing 6+ error codes (see Slack findings) |
| Compilations Cache | `https://relationalai.atlassian.net/wiki/spaces/ES/pages/890929153` | |
| Deployment failure incidents | `https://relationalai.atlassian.net/wiki/x/AQBrWQ` | |
| SPCS Runbooks (telemetry) | `https://relationalai.atlassian.net/wiki/spaces/SPCS/pages/1697054722/Runbooks` | |
| Event Table Heartbeat Monitors | `https://relationalai.atlassian.net/wiki/spaces/SPCS/pages/380370945/Monitors#Event-Table-Heartbeat-Monitors` | |
| Investigate Missing Telemetry | `https://relationalai.atlassian.net/wiki/spaces/SPCS/pages/1339392001` | Step-by-step telemetry investigation (from Slack) |
| Observability Architecture | `https://relationalai.atlassian.net/wiki/spaces/SPCS/pages/1328840706` | Partially outdated (from Slack) |
| PIR process | `https://relationalai.atlassian.net/wiki/spaces/ES/pages/366542860` | |

### Observe Dashboards

| Dashboard | ID/URL | Source |
|-----------|--------|--------|
| Engine failures | `Engine-failures-41949642` | JIRA |
| OOM Investigations | `OOM-Investigations-41777956` | JIRA |
| Memory Breakdown | `Memory-Breakdown-42602551` | Slack |
| Continuous CPU Profiling | `RelationalAI-Continuous-CPU-Profiling-41782266` | Slack |
| Engine Overview | `RelationalAI-Engine-Overview-MR-WIP-41925747` | Slack |
| Pager dashboard | `42313242` | JIRA |
| DWI | `41946298` | JIRA |
| BlobGC | `42245311` | JIRA |
| ERP Restart | `ERP-Restart-42156070` | Slack |
| ERP Actionable Monitor V2 | `ERP-actionable-monitor-v2-42488209` | Slack |
| Product SLOs | `Product-SLOs-42733752` | Slack |
| Engineering SLOs | `Engineering-SLOs-42723876` | Slack |
| SPCS Versions | `SPCS-Versions-42021302` | Slack |
| Telemetry Outages | `Telemetry-Outages-42760073` | JIRA |
| Telemetry Heartbeats | `Telemetry-heartbeats-42384426` | JIRA |
| Synthetic Tests | `Synthetic-Tests-Insights-42313552` | JIRA |

### Datadog (Legacy — migrating to Observe)

| Dashboard | URL |
|-----------|-----|
| OOM Investigations (legacy) | `https://app.datadoghq.com/dashboard/hhw-p5u-btj/oom-investigations` |
| RAICloud DWI | `https://app.datadoghq.com/dashboard/az9-6ez-5jc/distributed-workload-indicators` |
| Datadog Logs | `https://app.datadoghq.com/logs` (filter by `@rai.transaction_id`) |

### External Support Portals

| Service | URL |
|---------|-----|
| GitHub Status | `https://www.githubstatus.com` |
| Snowflake Status | `https://status.snowflake.com` |
| Observe Support | `https://customer.support.observeinc.com/servicedesk/customer/portal/7` |
| Snowflake Support | `https://app.snowflake.com/support/case/` |

---

## 11. Slack-Sourced Tribal Knowledge (Not in JIRA)

This section captures critical investigation knowledge that exists only in Slack channels.

### Engine Investigation

- **Auto-suspender warnings are noise** during engine failure investigation (George Kollias) — they fire because the engine is already failing
- **Container status `running → pending (~25min) → running`** = Snowflake-initiated container restart, not a RAI crash
- **Segfault monitor lowered to medium priority** for ALL accounts (Dean De Leo) because core dumps are unavailable
- **OOM Investigation 5-step method** (Max Schleich): OOM dashboard → Julia GC live bytes → Datadog/Observe logs with txn ID → CPU profile → transaction log correlation

### BlobGC

- **OOM death loop on XL engines**: XL selected for BlobGC → gc interval >250G → OOMGuardian can't keep up → container killed → restarted → re-selected → loop (Todd Veldhuizen)
- **Storage upgrade resets BlobGC state**: `resetBlobGCState()` called during upgrades — not in any runbook (jian.fang)
- **Multiple ERP race condition**: Multiple ERPs on same account cause BlobGC to trigger twice/minute instead of hourly (Irfan Bunjaku)
- **Dedicated vs Background BlobGC engines**: BG engine requires `LastCompleted` to be non-zero; if never had a successful pass, BG engine never starts
- **Creating dedicated BlobGC engine**: `CALL relationalai.api.create_engine('full_blobgc', 'HIGHMEM_X64_S', {'auto_suspend_mins': 60, 'await_storage_vacuum': true})`

### ERP

- **6+ error codes missing from runbook**: `erp_enginerp_internal_engine_provision_timeout`, `erp_unknown_internal_middlewarepanic`, `erp_txnevent_internal_request_reading_error`, `erp_blobgc_sf_sql_compute_pool_suspended`, `erp_blobgc_engine_blobgc_engine_response_error` (disabled), `erp_logicrp_sf_unknown`
- **Noise vs signal debate**: "Monitors will always have noise" (Sagar Patel) vs oncallers wanting less noise
- **`erp_txnevent_*` errors**: "If not happening repeatedly, safe to close" (Wei He)

### CI/CD

- **Poison commit antidote must be explicitly registered** in `raicloud-deployment/cicd/poison` — forgotten at least once (Thiago Tonelli)
- **Staging does NOT fail on poison commits** — it finds the latest non-poisoned INT deployment
- **Single poison commit impact**: 14/18 INT deployments failed, P75 inflated to 22h 41m (vs 9h target)
- **SF 10.5 communication gap**: Heads-up shared in Slack but not acted upon until CI broke

### Telemetry

- **O4S task investigation SQL**: Query `SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY` with scheduled time range and task name
- **Three-tier monitoring system** (Ruba Doleh, Nov 2025): Event Table (20min), Ingestion Lag (1h), Telemetry-type (4h)
- **UAE North access blocker**: `rai_oncaller` workflow doesn't work for that account. Manual IT/ACCOUNTADMIN intervention required.
- **Muting is error-prone**: Oncaller muted trace monitor but not log monitor → re-fire

### CompCache

- **Three-strike shutdown rule**: CompCache stops after 3 consecutive failures (jian.fang)
- **Race condition in raicloud (EY)**: Cache loading and writing happen simultaneously with same name, corrupting cache. Fixed in raicode/SPCS but still recurring on raicloud (maintenance mode).

### Customer Communication

- **Large-scale outage flow**: Identify impacted accounts → Google Doc with paid customer list → draft notification → review in Slack → ship to customers
- **CashApp storage explosion**: BlobGC failures → 0.2PB storage → ~$3k/month → customer "understandably unwilling to reinstall"
- **Monitor-to-customer-action**: Nathan Daly's threshold monitor (42899672) files High Priority engine incidents where "someone should take action by immediately reaching out to support"

### Key People for Escalation

| Person | Expertise | Channel |
|--------|-----------|---------|
| Babis Nikolaou | Engine oncall lead, monitor config | #team-prod-engine-oncall |
| Max Schleich | OOM investigation | #feed-alerts-oom |
| Todd Veldhuizen | Deep memory/pager/BlobGC analysis | #component-blobgc |
| Ary Fasciati | Observability/telemetry lead | #helpdesk-observability |
| Ruba Doleh | Three-tier monitoring architect | #helpdesk-observability |
| George Kollias | ERP expertise | #team-prod-engine-resource-providers-spcs |
| jian.fang | BlobGC/CompCache log analysis | #component-blobgc |
| Nathan Daly | Customer-facing monitors | #team-prod |

---

*Generated 2026-03-02 from comprehensive analysis of 974 JIRA incidents + 20+ Slack channels.*
*Analysis files: analysis-engine-incidents.md, analysis-erp-incidents.md, analysis-cicd-incidents.md, analysis-telemetry-monitored.md, analysis-other-incidents.md, analysis-slack-findings.md*
