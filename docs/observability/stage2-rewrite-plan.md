# Stage 2 Rewrite & Knowledge File Update Plan (v2)

**Date:** 2026-03-03
**Status:** Pending review
**Scope:** Fix "jump at first error" problem in `/investigate` + update all knowledge files with 1374-incident research findings
**Research base:** 974 cross-rotation incidents + 400 Infrastructure-rotation incidents + 20-channel Slack research

---

## Problem Statement

The `/investigate` command's AI jumps at the first error it finds instead of collecting all signals, evaluating each, and eliminating alternatives before declaring root cause. Three root causes:

1. **Stage 1 line 115** explicitly says "earliest signal in the chain is more likely the root cause"
2. **Stage 2** has only 4 vague investigation steps with no instruction to collect all errors before classifying
3. **Knowledge files** use "what you see → root cause" lookup tables that reward first-match behavior

Additionally:
- Two referenced knowledge files don't exist (`telemetry-incidents.md`, `erp-incidents.md`) — Stage 2 breaks for those classifications
- Knowledge files contain factual errors (core dump retrieval — dead since 2025-09-17)
- Critical patterns from the 1374-incident analysis and Slack tribal knowledge are missing
- Infrastructure rotation incidents reveal massive alert storm patterns (94 tickets from 1 pod, 13 from 1 AWS key detection) that Stage 1 doesn't handle

**Design constraint:** Stage 1 stays quick (seconds). Stage 2 can take time (background agent).

---

## Research Grounding

Every change is grounded in the combined analysis of 1374 JIRA incidents and 20-channel Slack research:

| Change | Research Source | Incidents Backing It |
|--------|---------------|---------------------|
| Stage 1 "earliest signal" fix | Cross-cutting Finding 1 (82% CI/CD zero investigation) | 974+400 total |
| Stage 2 "collect then eliminate" methodology | Finding 6 (JIRA <30% of RCA) + Infrastructure analysis (85% noise) | All |
| Stage 1 alert storm check | Infrastructure analysis: 94 pod memory, 13 AWS key, 6+ telemetry per event | 400 infra incidents |
| SF maintenance as #1 false positive | Engine deep dive (5/15 = 33%) + Slack #team-prod-engine-oncall | 208 engine incidents |
| OOM 5-step methodology | Slack Section 3 — Max Schleich's workflow | ~56 OOM incidents |
| OOM 3 subtypes | Engine Pattern 2 + Slack OOM patterns table | ~56 OOM incidents |
| Stuck transaction 3 subtypes | Engine Pattern 3 + Slack Section 10 | ~42 stuck txn incidents |
| Core dump removal | Slack Section 2 — RAI-42503, Kiran Pamnany | All segfault investigation |
| BlobGC death loop | Slack Section 4 — Todd Veldhuizen (NCDNTS-4515) | Recurring BlobGC incidents |
| CompCache 3-strike | Slack Section 11 — jian.fang | CompCache failure incidents |
| Cascade detection | ERP deep dive Section 3 (6/15 BlobGC sampled) | 167 ERP incidents |
| ERP error taxonomy + missing codes | Slack Section 5 — Alexandre Bergel, Richard Gankema, Wei He | 167 ERP incidents |
| Multiple-ERP race condition | Slack Section 4 — Irfan Bunjaku | Edge case |
| githubstatus.com first-check | CI/CD deep dive + Infra analysis (70% GH transient) | 261+80 CI/CD incidents |
| Subsequent-run auto-close (87%) | CI/CD + SPCS-INT analysis | 92 SPCS-INT incidents |
| Docker image not-found pattern | Infra analysis: Feb 14-15 cluster (13 tickets) | 400 infra incidents |
| Synthetic test multi-region = upstream | Infra analysis: 100% upstream-caused, 3+ regions within 60s | 17 synthetic incidents |
| Test Ring 1 = noise | Infra analysis + Wien Leung quote | 11 test ring incidents |
| On-demand logs = flaky test | Infra analysis: 13 incidents, zero signal | 13 on-demand incidents |
| Pod memory persistent alert escalation | Infra analysis: 94 tickets, 1 event, zero investigation | 94 pod memory incidents |
| Deployment test-run detection | Infra analysis: 7 prod-uswest = all test runs | 14 deployment incidents |
| Engine provisioning Azure upstream | Infra analysis: webhook timeouts, disk mount, etcd leader | 20 provisioning incidents |
| ArgoCD multi-env = bad config | Infra analysis: simultaneous multi-env = config commit | 3 ArgoCD incidents |
| Alert storm dedup guidance | Infra analysis: 94/1, 13/1, 6+/event multipliers | 400 infra incidents |
| SF Billing patterns | Infra analysis: 9 billing incidents, 4 distinct types | 9 billing incidents |
| Customer Azure instability (ATT/EY) | Infra analysis: every customer incident = Azure | 8 customer incidents |
| Three-tier telemetry monitoring | Slack Section 7 — Ruba Doleh + Infra analysis confirmation | 53+44 telemetry incidents |
| O4S task SQL + diagnostics | Slack Section 7 + telemetry batch 2 analysis | Telemetry investigation |
| UAE North specifics | Telemetry deep dive (20/53 = 38%) + Infra analysis | 20 UAE North incidents |
| O4S task EXECUTING with no query_id | Telemetry batch 2: NCDNTS-11539 runbook gap | Telemetry investigation |
| Antidote registration | Slack Section 6 — Thiago Tonelli | 10 poison commit incidents |
| Missing dashboards (9) | Slack Section 13 + Infra analysis | Reference data |
| Repeat-offender accounts | ERP deep dive + monitored account analysis | ~57 ERP + 94 monitored |
| User-initiated engine deletion | Engine Pattern 4 + Infra analysis (ATT/EY) | Engine false positives |
| Auto-suspender noise | Slack Section 2 — George Kollias | Engine investigation |
| Docker version regression (GH runners) | Infra deep dive NCDNTS-12322 | CI/CD incidents |
| SF OAuth token transient (390303) | Infra deep dive NCDNTS-12877 | CI/CD incidents |
| Telemetry multi-signal alert storms | Telemetry batch 2: 5-6 tickets per region per event | 19 telemetry batch 2 |
| Snowpark-optimized WH fix | Telemetry batch 2: NCDNTS-11733 | Telemetry fix |

---

## Changes Summary

| # | File | Action | Lines Now → Est. After |
|---|---|---|---|
| 1 | `commands/investigate.md` | Fix Stage 1 + rewrite Stage 2 + add alert storm check | 369 → ~440 |
| 2 | `knowledge/engine-failures.md` | Remove core dumps, add OOM methodology + subtypes, stuck txn subtypes | 107 → ~150 |
| 3 | `knowledge/incident-patterns/engine-incidents.md` | Remove core dump step, add SF maintenance, deletion check | 78 → ~110 |
| 4 | `knowledge/incident-patterns/control-plane-incidents.md` | Add BlobGC death loop, CompCache 3-strike, cascade, ERP race | 84 → ~130 |
| 5 | `knowledge/incident-patterns/infrastructure-incidents.md` | Major expansion: GH status, auto-close, Docker, synthetics, Ring 1, provisioning, ArgoCD, billing, alert storms | 107 → ~175 |
| 6 | `knowledge/incident-patterns/pipeline-incidents.md` | Add 3-tier monitoring, O4S diagnostics, UAE North, alert storm handling, runbook gap | 87 → ~130 |
| 7 | `knowledge/platform.md` | Add ~9 dashboards, missing ERP error codes, ArgoCD URLs, billing patterns | 308 → ~330 |
| 8 | `knowledge/incident-patterns/erp-incidents.md` | **NEW** — ERP taxonomy, BlobGC cascade, repeat offenders, signal vs noise | 0 → ~90 |
| 9 | `knowledge/incident-patterns/telemetry-incidents.md` | **NEW** — 4 outage patterns, O4S diagnostics, UAE North, alert storm handling, runbook gaps | 0 → ~100 |

**Token budget:** Base load ~9050 → ~9800 (+750). Typical classification: ~12,000 → ~13,800. Worst case (Unknown): ~14,350 → ~17,500. All within acceptable range.

---

## Detailed Changes

### 1. `commands/investigate.md` — Core Behavioral Fix

#### 1a. Fix Stage 1 "earliest signal" (line 115)

**Current:**
> If multiple anchor-correlated signals exist, determine causal ordering: which came first? The earliest signal in the chain is more likely the root cause

**Replace with:**
> If multiple anchor-correlated signals exist, record ALL of them on the triage card. Do not determine root cause in Stage 1 — only classify the incident type and set confidence. Root cause determination happens in Stage 2.

#### 1b. Add Alert Storm Check to Stage 1 (new section after "Parallel Queries", before "Classification")

Insert a new "Alert Storm / Duplicate Check" section (~15 lines):

**Before running classification, check for alert storms:**
1. If the incident is from an automated monitor, search JIRA for other open incidents with the same monitor name or entity (engine name, pod name, account, region) in the last 24h
2. If an existing open incident exists for the same entity → classify as **noise**, recommend closing as duplicate, link to the root incident
3. Known alert storm patterns:
   - Pod memory alerts: same pod_name with existing open incident → auto-close
   - AWS Key/Token detection: same detection event within 24h → auto-close all but first
   - Telemetry outages: same region, multiple signal types (NA Logs, SPCS Logs, OTEL Metrics, SF Platform Metrics, NA Spans) within 30 min → single event, close extras
   - Telemetry multi-region: 3+ regions within 60 min → single upstream event, investigate one, close rest
   - Synthetic tests: 3+ regions failing within 60 seconds → upstream outage, check status pages
   - SPCS-INT sub-jobs: same GitHub Actions run ID → same failure, close extras
   - Engine provisioning: same Datadog monitor re-firing at SEV2 and SEV3 → single event

#### 1c. Rewrite Stage 2 Investigation Steps (lines 206-210)

Replace the 4-line section with a 5-phase "Collect Then Eliminate" methodology (~60 lines):

**Phase A — Comprehensive Error Inventory:**
- Dispatch Stage 2 log agent (unconstrained) with full anchor set
- Query ALL failed transactions on this engine/account in the incident window (not just the reported one)
- Query ALL error spans on this engine/account in the incident window
- Query ALL monitor detections for this account/engine in ±2h window
- If Confluence runbook linked in JIRA, read it and add its diagnostic queries
- Produce an **error inventory**: flat list of every error/failure/anomaly, each tagged with:
  - Timestamp
  - Source (logs/spans/metrics/monitors)
  - Anchor-correlated vs temporally-adjacent
  - Description

**Phase B — Classification Re-evaluation:**
- Compare error inventory against Stage 1 classification
- If inventory reveals contradicting signals (e.g., Stage 1 said OOM but inventory shows preceding segfault), update classification and load the correct knowledge file
- If inventory reveals the incident is part of a broader alert storm not caught in Stage 1, reclassify as noise/cascade
- If classification holds, proceed with already-loaded knowledge file

**Phase C — Grouping:**
- Group inventory into **candidate causes** (not a flat timeline)
- Errors sharing component, error code prefix, or causal proximity = one group
- Use knowledge file patterns to recognize known cascades:
  - Engine crash → BlobGC errors within 2h = cascade
  - SF maintenance → multiple "engine failed" aborts = single event
  - GitHub outage → ArgoCD + synthetic + CI/CD failures = single event
  - Azure outage → provisioning + disk mount + webhook failures = single event

**Phase D — Evaluation and Elimination:**
For each candidate cause, check:
1. **Causal chain:** Can you trace candidate → intermediate effects → observed symptom?
2. **Timing:** Did candidate occur BEFORE symptom?
3. **Scope:** Does candidate affect the investigated entity (not a different engine/account)?
4. **Knowledge match:** Does a pattern in the knowledge file explain this candidate?
5. **Upstream check:** Is this a known downstream symptom? (BlobGC after engine crash, "engine failed" after SF maintenance, CI failure after GH outage)

Eliminate candidates that fail checks. Note WHY each was eliminated (one line per elimination).

**Phase E — Root Cause Declaration:**

| Situation | Action |
|---|---|
| One candidate, clear causal chain | Root cause, High confidence |
| One candidate, gap in chain | "Suspected root cause," Medium confidence, explain gap |
| Multiple candidates survive | "Multiple potential causes" — list each with evidence and what would distinguish them |
| No candidates survive | "Root cause undetermined" — list what was checked and what's missing |
| Upstream/external cause identified | "External root cause" — name the upstream system (SF, GitHub, Azure) and link to status page |

Explicit rule: **"Never declare root cause by picking the earliest error. The earliest error is often a symptom of a deeper cause (e.g., SF maintenance triggers engine restart which triggers transaction abort which triggers BlobGC failure)."**

#### 1d. Update knowledge loading table

Add the two new files:
- `erp-incidents.md` for ERP-error classification
- `telemetry-incidents.md` for Telemetry classification
- Update Unknown to load all 6 incident pattern files

#### 1e. Add known transient patterns to CI/CD decision tree

Add to the existing CI/CD decision tree:
```
├─ Docker pull/push with "connection reset by peer" across repos?
│   → GitHub runner Docker version change. Check if self-hosted runners work.
│   → If GH-hosted fails but self-hosted passes: pin Docker version.
│
├─ Snowflake error 390303 (Invalid OAuth access token)?
│   → Transient. Check if next run passes. Auto-close if resolved.
│
├─ "Copy Image X failed" / Docker image not found?
│   → Check if image tag exists in source registry.
│   → Feb 14-15 pattern: consumer-otelcol image missing.
│
├─ Test Ring 1 failure?
│   → Deprioritize. Ring 1 is ~100% noise (confirmed by data).
│   → Only investigate if 3+ repos show the same specific failure.
│
├─ "On-demand logs workflow tests are failing"?
│   → Chronic flaky test. Auto-close.
│
├─ "Deployment failed" for *prod-uswest* + hotfix-specific-customer workflow?
│   → Intentional test run. Close as noise.
│
├─ Synthetic tests failing for 3+ regions within 60 seconds?
│   → Upstream outage. Check status.snowflake.com AND githubstatus.com.
│   → If upstream active: close all as single event.
```

#### 1f. Add ArgoCD refinement to CI/CD decision tree

Update the existing ArgoCD entry:
```
├─ ArgoCD out-of-sync?
│   → Simultaneous multi-environment sync failure? → Bad config commit. Investigate. Revert.
│   → Single-environment? → GitHub transient. Self-resolved <20 min? Close.
```

---

### 2. NEW `knowledge/incident-patterns/erp-incidents.md` (~90 lines)

**ERP Error Taxonomy table:**

| Category | Error Prefix | Typical Severity | Cascade Risk |
|---|---|---|---|
| BlobGC | `erp_blobgc_*` | Medium | High — often cascades from engine crash |
| CompCache | `erp_compcache_*` | Low | Low — auto-retries every 2h |
| TxnMgr | `erp_txnevent_*`, `erp_txnrp_*` | Medium | Medium |
| EngineRP | `erp_enginerp_*` | Medium | Low |
| SF Platform | `erp_logicrp_sf_*` | Medium | Low — SF-side |
| S3/Storage | `erp_txnrp_awss3_*` | Low | Low — transient |

**Pattern: BlobGC Cascade** (most common ERP pattern):
- Frequency: High — appears in ~6/15 sampled ERP incidents
- Signature: BlobGC errors following engine crash in same account within 2h
- Chain: engine crash/OOM → BlobGC cannot run → `circuit_breaker_open` → storage threshold exceeded
- Diagnostic: check for upstream engine crash FIRST
- Key insight: "Do NOT investigate BlobGC independently if engine crash preceded it"
- Special case: `GapKeyWithoutJuliaValError` = engine version mismatch marker, not primary cause

**Pattern: BlobGC Death Loop (XL engines):**
- XL engines selected for BlobGC → gc interval >250G → OOMGuardian can't keep up (>50% wall time on gc) → container OOM killed → restarted → re-selected → infinite loop
- Recognition: BlobGC engine crashes repeatedly on same XL engine, always during gc
- Key: "Do NOT investigate each BlobGC OOM independently — they are symptoms of the same loop"
- Source: Todd Veldhuizen (NCDNTS-4515), purely tribal knowledge

**Pattern: CompCache Three-Strike:**
- CompCache stops running after 3 consecutive failures (jian.fang)
- If CompCache suddenly stops working, check for 3 prior failures in logs
- CompCache auto-retries every 2h; single failure is not actionable

**Pattern: Multiple-ERP Race Condition:**
- Multiple ERPs on same account cause BlobGC to trigger twice/minute instead of hourly (Irfan Bunjaku)
- Two ERP errors within seconds for same account = same failure from two components. Investigate only the first.

**Pattern: Repeat-offender accounts:**

| Account | Incidents (6mo) | Known Pattern |
|---|---|---|
| `rai_studio_sac08949` | 25+ | Internal testing — bulk noise. Fast-close as known error. |
| `by_dev_ov40102` | 20+ | BY dev — high ERP error rate, transient. |
| `rai_int_sqllib` | 12+ | Integration testing — noise unless new error type. |

Rule: verify error is a NEW pattern before deep investigation on repeat-offender accounts.

**Signal vs Noise Decision Table:**

| Signal | Action |
|---|---|
| ERP error + transaction failure in same account | Investigate — real impact |
| ERP error + no transaction failure within 1h | Likely transient — close |
| `broken_pipe` / `request_reading_error` single occurrence | Noise — close |
| `circuit_breaker_open` | Find upstream engine failure — this is a cascade |
| `compute_pool_suspended` | Check for user-initiated suspension |
| `erp_txnevent_*` not repeating | "Safe to close" (Wei He) |
| `middlewarepanic` | Rare — investigate |
| `blobgc_engine_response_error` | Incident creation disabled (jian.fang) — noise |

**Cross-references:**
- Cascade detection: `commands/investigate.md` Cascade Detection section
- ERP error codes: `knowledge/platform.md` ERP codes section
- Engine incidents: `knowledge/incident-patterns/engine-incidents.md`

---

### 3. NEW `knowledge/incident-patterns/telemetry-incidents.md` (~100 lines)

**Pattern: Transient O4S Task Failure (most common — 66% of telemetry incidents):**
- Frequency: High — weekly occurrences
- Severity: Typically SEV2 but usually self-resolves
- Signature: Telemetry missing 20-40min, then returns. O4S tasks show failed/canceled runs.
- Root causes: SF task failures, Observe outage, Azure networking, AWS outage
- Action: Verify return via Telemetry Outages dashboard, close if recovered
- ~50% self-recover within 30 minutes. Wait, then check.

**Pattern: Snowflake Platform Outage:**
- Frequency: Low — ~2-3 per 6 months, but high impact
- Signature: Multi-region telemetry outages, 12+ hours of task failures. Confirmed via status.snowflake.com.
- Example: Dec 16, 2025 — 12h outage, 6 tickets for one event
- Action: Check status.snowflake.com. File Sev-1 SF support ticket. Snowflake must apply mitigation.
- Resolution: Snowflake applies mitigation to affected account.

**Pattern: RAI-Induced Outage:**
- Frequency: Low — ~9% of telemetry incidents
- Signature: Sustained outage (hours), recent RAI deploy/config change
- Example: Flag logic error disabled telemetry
- Action: Check recent deployments, O4S task logs, escalate to #helpdesk-observability

**Pattern: Monitor Misconfiguration:**
- Frequency: Low — ~9% of telemetry incidents
- Signature: Alert fires for specific account/region, others healthy. Template variable leaks (`{{webhookData.SNOWFLAKE_REGION}}`).
- Action: Check O4S app installed, warehouse status, event sharing config. Fix monitor exclusions.

**Alert Storm Handling (CRITICAL for Infrastructure oncall):**
- A single pipeline failure triggers 2-6 monitors per region:
  - Telemetry outage (general)
  - NA Logs outage
  - SPCS Logs outage
  - OTEL Metrics outage
  - SF Platform Metrics outage
  - NA Spans outage
- Multi-region outages multiply further: 5 regions × 5 signals = 25+ tickets
- Rule: If multiple telemetry tickets fire within 30 min for same region or across regions, treat as single event. Investigate the first ticket only. Close rest as duplicates.

**O4S Task Diagnostics:**
```sql
SELECT *, DATEDIFF('minute', QUERY_START_TIME, COMPLETED_TIME) AS DURATION_MINUTES
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, current_timestamp()),
    RESULT_LIMIT => 100,
    TASK_NAME => '<O4S_TASK_NAME>'
));
```
- If task stuck EXECUTING with no query_id: the documented "cancel task with SYSTEM$CANCEL_QUERY" step is impossible. Alternative: suspend and restart the task.
- If task latency increasing: upsize warehouse (M → L). Consider Snowpark-optimized warehouse for /tmp space (NCDNTS-11733 fix).

**Three-Tier Monitoring Architecture (Ruba Doleh, Nov 2025):**

| Tier | Monitor | Threshold | Action |
|---|---|---|---|
| 1 | Event Table heartbeat (42741161) | 20 min no data | Immediate: check O4S tasks |
| 2 | Observe Ingestion Lag | 1 hour | Resize warehouse |
| 3 | Telemetry-type monitors (4h) | 4 hours specific type missing | Evaluated every 4h |

Investigation order: check Tier 1 first. If event table has data but Observe doesn't, problem is Tier 2/3.

**Gap:** No suppression logic between tiers — Tier 1 and Tier 2 fire independently, causing alert storms.

**UAE North Specifics:**
- 38% of ALL telemetry incidents (20/53 in 6mo) come from `rai_azure_uaenorth_events_ye96117`
- Oct 16, 2025: single outage generated 11 tickets in one day
- Alert storm handling: investigate one ticket, close the rest as duplicates
- Access blocker: `rai_oncaller` workflow doesn't work for UAE North. Manual IT/ACCOUNTADMIN intervention required.
- Muting is error-prone: oncaller muted one monitor but not another → re-fire
- Limited SF support coverage for UAE region

**Escalation:**

| Step | Channel |
|---|---|
| Notify reliability | `#helpdesk-observability` (tag `@reliability`) |
| Snowflake issue | File Sev-1 via https://app.snowflake.com/support/case/ |
| Observe issue | File incident via https://customer.support.observeinc.com/servicedesk/customer/portal/7 |
| Telemetry latency > 30 min | `#ext-relationalai-observe` |

**Cross-references:**
- Pipeline-level patterns: `knowledge/incident-patterns/pipeline-incidents.md`
- Monitor IDs: `knowledge/platform.md` monitors section
- Observe dashboards: Telemetry Outages (42760073), Telemetry Heartbeats (42384426)

---

### 4. `knowledge/engine-failures.md`

**4a. Remove core dump references:**
- Line 7 Pattern A: remove "core dumps" from Key Signals
- Add: "Core dumps unavailable on SPCS since 2025-09-17 (RAI-42503). Snowflake confirmed: 'the previous core dump functionality was unintentional.' For segfaults, check error logs for stack traces. Segfault monitor lowered to medium priority for ALL accounts (Dean De Leo) because 'there is very limited action that can be done for seg faults nowadays.'"

**4b. Replace OOM section (lines 92-95) with Max Schleich's 5-step methodology:**
1. Open OOM dashboard with engine name + time range
2. Check **Julia GC live bytes** — look for spikes (e.g., 9GB → 40GB)
3. Check logs filtered by transaction ID — what was being computed
4. Check **continuous CPU profile** for hotspots
5. **Correlate with ALL concurrent transactions** — the aborted transaction is often the victim, not the cause. Two concurrent transactions both hitting type inference = compound memory pressure.

**4c. Add OOM 3 subtypes (after methodology):**

| Subtype | Signal | Action |
|---|---|---|
| GC brownout (false alarm) | GC pause + pager warning, no termination. Pager couldn't evict during GC pause. 5-min monitor window missed actual recovery. | Close — not a real OOM |
| Rapid Julia spike | Julia poolmem spikes faster than pager can react (11GB→33GB in 20s). High cost warning in logs before crash. QE scan activity. | Julia team — pager couldn't react |
| Undersized engine (OOM brake) | Same txn type failing repeatedly on HIGHMEM_X64_S. `OOMGuardian triggered full collection`. | Recommend larger engine — not a bug |

Additional OOM patterns from Slack (for recognition, not investigation):
- Large metadata on XS engines → recommend S or M
- OOM during result serialization → after "Estimated cardinality of output relation" log
- Large ASTs in optimizer → Julia heap 7GB → 52GB

**4d. Add stuck transaction 3 subtypes (after Long Cancellation):**

| Subtype | Signal | Action |
|---|---|---|
| Long recursion | QE materialization 100K+ sec, 2B+ tuples, CPU 100% + IO normal initially. Structural recursion not converging. | Wait it out — it's progressing, just slow |
| Stuck cancel | "aborting active transaction ... in state CANCELLING" for hours with no TransactionEnd | Engine deletion is the only fix |
| Pager deadlock | CPU 100% on 1-2 cores, zero IO after 30min. Stack: `unsafe_get_page_no_transition -> lock` | Storage team — requires bug fix |

Key Observe query for stuck cancellation: find transactions with TransactionBegin but no TransactionEnd on the engine.

**4e. Add auto-suspender noise note:**
"Auto-suspender warnings during engine failures are noise — they fire because the engine is already failing, not as a cause (George Kollias)."

**4f. Add benign signal note:**
"`DerivedMetadataVersionError: Found derived metadata version X; expected Y` is ALWAYS benign and expected after engine version upgrade. Never treat as root cause."

---

### 5. `knowledge/incident-patterns/engine-incidents.md`

**5a. Remove core dump step:**
Line 11 diagnostic step 2: replace "retrieve core dump (ES page 385253381)" with "Identify crash component from stack trace in error logs (core dumps unavailable on SPCS since 2025-09-17)"

**5b. Add SF Maintenance pattern (insert BEFORE existing patterns — this is the most common):**

| Field | Value |
|---|---|
| **Frequency** | Very High — 33% of ALL engine incidents |
| **Severity** | Noise — non-actionable |
| **Signature** | Engine state = PENDING around alert time. Container status `running → pending (~25min) → running` in Engine failures dashboard. Multiple "engine failed" transaction aborts on same engine within minutes. |
| **Root Cause** | Snowflake-initiated container restart during maintenance window. Heartbeat cache evicts in-flight transactions → "engine failed" abort. |
| **Diagnostic Steps** | 1. CHECK FIRST: Before investigating ANY 'engine failed' incident, check SF maintenance status 2. Open Engine failures dashboard, look for engine state = PENDING 3. If container shows 25-min pending gap → SF maintenance, not a RAI crash 4. Confirm timing against known SF maintenance windows (typically weekends) |
| **Resolution** | Close immediately after confirming maintenance timing. No RAI action needed. |
| **Recurring Accounts** | `ritchie_brothers_oob38648` (most affected — weekend CDC workloads), any account with always-on engines |

**5c. Add user-initiated deletion check:**
Add to "Transaction Aborts" pattern diagnostic steps:
- "Check ERP logs for engine deletion/replacement events — user may have deleted or resized engine during transaction"
- Two subtypes:
  - User explicitly deleted engine (NCDNTS-10953) → close as false positive
  - User resized engine (delete old + create new, NCDNTS-10059) → `container.state.last.finished.reason` increments on deletion, triggering false crash alert

---

### 6. `knowledge/incident-patterns/control-plane-incidents.md`

**6a. Add BlobGC Death Loop pattern:**
New pattern section:
- XL engines selected for BlobGC → gc interval >250G → OOMGuardian can't keep up → container OOM killed → restarted → re-selected → infinite loop
- Recognition: BlobGC engine crashes repeatedly on same account, always during gc operations
- Key insight: "Do NOT investigate each BlobGC OOM independently — they are symptoms of the same loop"
- Source: Todd Veldhuizen (NCDNTS-4515)

**6b. Add CompCache three-strike rule:**
- "CompCache stops after 3 consecutive failures. If CompCache suddenly stops working, check for 3 prior failures in logs."
- CompCache auto-retries every 2h; single failure is not actionable.
- Race condition on raicloud (EY): cache loading and writing happen simultaneously with same name, corrupting cache. Fixed in raicode/SPCS but still recurring on raicloud (maintenance mode).

**6c. Add cascade detection pattern:**
- When multiple ERP errors fire for same account within 2h, check for cascade chain:
  - Engine crash → BlobGC → storage threshold
  - SF maintenance → engine restart → transaction abort → BlobGC failure
- Rule: find earliest error in account within 2h; later errors are likely cascading downstream symptoms.

**6d. Add multiple-ERP race condition note:**
"When two ERP errors fire within seconds for same account, they're usually the same failure reported by two components. Investigate only the first."

---

### 7. `knowledge/incident-patterns/infrastructure-incidents.md` — Major Expansion

This file gets the largest expansion because Infrastructure-rotation incidents were deeply analyzed (400 incidents).

**7a. Add githubstatus.com first-check:**
Insert as step 1 of CI/CD Workflow Failures diagnostic steps:
"**FIRST**: Check https://www.githubstatus.com — if GitHub outage active, stop. External outages cause cascading internal CI failures. ~70% of NA Deployment failures are GitHub transient connectivity issues."

**7b. Add subsequent-run auto-close:**
Add subsection to CI/CD pattern:
"For SPCS-INT failures: check if subsequent run of same workflow passed. If yes → transient, close. **87% resolve this way** (confirmed by 400-incident analysis). This is the single highest-value triage rule for Infrastructure incidents."

**7c. Add Docker image not-found pattern:**
New subsection:
- Signature: `Copy Image X failed` or Docker image not found in CI logs
- Root cause: CI pipeline references image tags that don't exist yet at deploy time
- Example: Feb 14-15 cluster — 13 tickets from one root cause (consumer-otelcol image missing)
- Action: Check if image tag exists in source registry. If not → pipeline timing issue, not a bug.

**7d. Add Docker version regression pattern:**
New subsection:
- Signature: `connection reset by peer` during Docker pull/push, affecting GH-hosted runners but not self-hosted
- Root cause: GitHub runner image Docker version upgrade (e.g., v28→v29, containerd image store change)
- Action: Check GH runner image changelog. Pin Docker version. Switch to self-hosted runners as workaround.
- Source: NCDNTS-12322 investigation (10 comments, tcpdump analysis)

**7e. Add synthetic test multi-region pattern:**
New subsection:
- Signature: `Synthetic tests are failing for [Region] Prod Consumer Account` across 3+ regions within 60 seconds
- Root cause: 100% upstream-caused (Snowflake or GitHub outage). Zero required RAI action.
- Action: If 3+ regions fail within 60s → single upstream event. Check status.snowflake.com AND githubstatus.com. Close all as single event.

**7f. Add Test Ring 1 = noise:**
New subsection:
- Ring 1 failures are ~100% noise. Wien Leung: "I don't think having the infra on-call try to make sense of a pile of TR1 failures is productive."
- Only investigate if 3+ repos show the same specific failure pattern.
- Ring 3 failures from dev branches should also be excluded (NCDNTS-12197).

**7g. Add On-demand logs = chronic flaky test:**
One-liner: "`On-demand logs workflow tests are failing` — chronic flaky test. 13 incidents in 3 months, zero genuine signal. Auto-close."

**7h. Strengthen engine provisioning pattern:**
Add to existing section:
- Check Azure status for active incidents. If correlated → auto-classify as upstream.
- Known transient signatures: Linkerd webhook timeouts (`context deadline exceeded`), disk mount failures (`failed to find disk on lun 17`), etcd leader changes
- Multi-account same region = cloud infrastructure issue (SF or Azure), not RAI bug. File SF support ticket.
- SEV2 for provisioning errors is overclassified when Azure has active incidents.
- The monitor fires at both SEV2 and SEV3 thresholds simultaneously, and re-fires every cycle. One event → many tickets.

**7i. Strengthen ArgoCD decision tree:**
Update existing pattern:
- Simultaneous multi-environment sync failure = bad config commit pushed. Signal. Fix: revert.
- Single-environment transient = GitHub connectivity. Noise. Self-resolved <20 min.

**7j. Add antidote registration detail:**
Add to Poison Commits pattern resolution:
"Antidotes must be explicitly registered in `raicloud-deployment/cicd/poison`. Forgetting registration has caused missed antidotes (Thiago Tonelli). Staging does NOT fail on poison commits — it finds the latest non-poisoned INT deployment."

**7k. Add pod memory persistent alert pattern:**
New subsection:
- If a pod memory alert has >5 duplicates and the root ticket is unassigned → the underlying issue needs engineering attention
- Example: engine-operator pod — 94 tickets, 1 event, zero investigation
- OpsAgent correctly deduplicates but nobody investigates the root cause

**7l. Add SF Billing patterns:**
New subsection (brief):
- Missing Credit Cost / Engine Type Config → transient propagation delays. Close.
- Incorrect Charge Type → config bug. Investigate. (NCDNTS-12314)
- Billing Component failure → sporadic, self-resolving. Close.
- Unreported engine activities → SF outage caused billing tasks to suspend. Check SF status.
- "The runbook seems very outdated" (oncaller quote) — do not rely on billing runbook.

**7m. Add deployment test-run detection:**
One-liner: "Deployment failures for `spcs-prod-uswest` from `hotfix-specific-customer` workflow are 100% intentional test runs. Close as noise."

**7n. Add customer-specific Azure instability note:**
"ATT and EY customer-impacting incidents all trace to Azure infrastructure instability (SIGTERM, disk mount, storage provisioning, unidentified deletions). AWS customers are not represented in infrastructure incidents. For ATT/EY engine lifecycle failures on Azure, check Azure status first."

---

### 8. `knowledge/incident-patterns/pipeline-incidents.md`

**8a. Add three-tier monitoring architecture:**
New section explaining Ruba Doleh's system:

| Tier | Monitor | Threshold | Action |
|---|---|---|---|
| 1 | Event Table heartbeat (42741161) | 20min no data | Immediate: check O4S task status |
| 2 | Observe Ingestion Lag | 1 hour latency | Resize warehouse (M → L) |
| 3 | Telemetry-type monitors | 4h specific type missing | Evaluated every 4h |

Investigation order: check Tier 1 first. If event table has data but Observe doesn't, problem is Tier 2/3.

**8b. Add O4S task diagnostics:**
Query pattern for checking task status (SQL from Zekai Huang) + stuck task guidance:
- If task stuck EXECUTING with no query_id: cannot use `SYSTEM$CANCEL_QUERY`. Alternative: suspend + restart the task.
- If task latency increasing steadily: upsize warehouse. Consider Snowpark-optimized warehouse for /tmp space.

**8c. Add UAE North specifics:**
- 38% of telemetry incidents. Alert storm handling: investigate one, close rest as duplicates.
- Access blocker: `rai_oncaller` workflow doesn't work. Manual IT/ACCOUNTADMIN intervention required.
- Muting is error-prone (muted one monitor but not another → re-fire).
- Limited Snowflake support coverage.

**8d. Add alert storm handling note:**
"A single outage event triggers 2-6 monitors per region (Telemetry outage, NA Logs, SPCS Logs, OTEL Metrics, SF Platform Metrics, NA Spans). Multi-region outages generate 10-30+ tickets from one event. No suppression logic exists between tiers."

**8e. Add Snowflake outage as distinct pattern:**
- Distinct from transient O4S failures. 12+ hours of impact.
- Confirmed via status.snowflake.com.
- Resolution: SF applies mitigation. RAI oncall cannot fix.
- Example: Dec 16, 2025 — AWS_EU_WEST_1, 12h outage.

---

### 9. `knowledge/platform.md` — Reference Data Additions

**9a. Add missing dashboards to dashboards table:**

| Dashboard | ID |
|---|---|
| Pager | 42313242 |
| Memory Breakdown | Memory-Breakdown-42602551 |
| Continuous CPU Profiling | RelationalAI-Continuous-CPU-Profiling-41782266 |
| Engine Overview | RelationalAI-Engine-Overview-MR-WIP-41925747 |
| ERP Restart | ERP-Restart-42156070 |
| ERP Actionable Monitor V2 | ERP-actionable-monitor-v2-42488209 |
| Product SLOs | Product-SLOs-42733752 |
| Engineering SLOs | Engineering-SLOs-42723876 |
| SPCS Versions | SPCS-Versions-42021302 |

**9b. Add missing ERP error codes:**

| Code | Notes |
|---|---|
| `erp_unknown_internal_middlewarepanic` | Not in runbook. Rare — investigate. |
| `erp_blobgc_sf_sql_compute_pool_suspended` | Not in runbook. Check for manual account changes. |
| `erp_blobgc_engine_blobgc_engine_response_error` | Incident creation disabled (jian.fang). |
| `erp_enginerp_internal_engine_provision_timeout` | Not in runbook (Alexandre Bergel). |
| `erp_txnevent_internal_request_reading_error` | Not in runbook. "If not repeating, safe to close" (Wei He). |
| `erp_logicrp_sf_unknown` | SF internal issue. |

**9c. Add ArgoCD URLs:**
- ArgoCD prod: `https://argocd.prod.internal.relational.ai:8443/`
- ArgoCD staging: `https://argocd.staging.internal.relational.ai:8443/`

---

## Implementation Order

1. **`investigate.md`** — Stage 1 fix + alert storm check + Stage 2 rewrite + CI/CD tree additions (core behavioral change, everything depends on this)
2. **`erp-incidents.md`** (NEW) — unblocks control-plane-incidents.md references
3. **`telemetry-incidents.md`** (NEW) — unblocks pipeline-incidents.md references
4. **`engine-failures.md`** — OOM methodology, stuck transactions, core dump removal (highest-impact knowledge)
5. **`engine-incidents.md`** — SF maintenance pattern, core dump removal, deletion check
6. **`control-plane-incidents.md`** — BlobGC death loop, cascade, CompCache
7. **`infrastructure-incidents.md`** — Major expansion (GH status, auto-close, Docker, synthetics, Ring 1, provisioning, ArgoCD, billing, alert storms, customer Azure)
8. **`pipeline-incidents.md`** — 3-tier monitoring, O4S diagnostics, UAE North, alert storms
9. **`platform.md`** — dashboards, ERP codes, ArgoCD URLs (reference data, last)

---

## Verification

1. `wc -l` each file — no knowledge file >175 lines, investigate.md <450 lines
2. `bash plugins/dockyard/tests/smoke/run-all.sh` — pass
3. Cross-reference check: every file in investigate.md's knowledge loading table exists
4. Anti-pattern grep: zero hits for `"earliest signal"`, `"first error"`, `"most likely cause"`, `"retrieve core dump"` (except the explicit "Never declare root cause by picking the earliest error" rule)
5. Mental simulation — OOM incident: Does Phase A collect all concurrent txn data? Does Phase D eliminate GC brownout before declaring OOM? Does Phase E handle "aborted txn was the victim, not the cause"?
6. Mental simulation — Infrastructure CI/CD: Does alert storm check catch SPCS-INT sub-job duplicates? Does CI/CD tree handle Docker image not-found? Does Stage 1 deprioritize Ring 1?
7. Mental simulation — Telemetry alert storm: Does alert storm check consolidate 6 same-region tickets into 1? Does it consolidate 5-region multi-region storm? Does UAE North get suppression treatment?

---

*This plan is grounded in analysis of 1374 JIRA incidents (Sep 2025 — Mar 2026) and 20+ Slack channels. Supporting artifacts: incident-pattern-analysis.md, analysis-slack-findings.md, investigation-improvement-report.md, analysis-infrastructure-incidents.md, analysis-engine-incidents.md, analysis-erp-incidents.md, analysis-cicd-incidents.md, analysis-cicd-deep-dive-7-incidents.md, analysis-monitored-telemetry-incidents.md, analysis-telemetry-monitored.md, analysis-other-incidents.md.*
