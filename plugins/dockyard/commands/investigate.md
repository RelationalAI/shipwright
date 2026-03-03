---
description: Investigate live service issues using observability data (logs, spans, metrics)
argument-hint: [incident key, transaction ID, error description, or service name]
---

# /investigate — Issue Investigation

Stateful two-stage investigation command. Works with any issue: incidents (NCDNTS), bugs, performance complaints, customer-reported problems.

## Prerequisites

Before starting, verify these MCP tools are available. If any are missing, stop and tell the user which server is missing and how to set it up — do not proceed with the investigation.

| MCP Server | Tools | If Missing |
|---|---|---|
| **Observe** | `generate-query-card` | "Observe MCP is not configured. Set it up at https://171608476159.observeinc.com/settings/mcp — if you don't have access, post a :ticket: in #ext-relationalai-observe to get whitelisted." |
| **Atlassian** | `getJiraIssue`, `getJiraIssueRemoteIssueLinks`, `getConfluencePage`, `searchConfluenceUsingCql` | "Atlassian MCP is not configured. Set it up at https://www.atlassian.com/solutions/ai/mcp — this is needed to read JIRA tickets and Confluence runbooks." |

## Setup

Load from the Dockyard plugin root:
1. **Always:** `skills/observability/SKILL.md`
2. **Always:** `skills/observability/knowledge/platform.md`

Additional knowledge files loaded in Stage 2 based on classification (see Stage 2 section).

## Account-Aware Pre-Triage

Before any investigation, check the account/engine name against known patterns. This can short-circuit investigation for 30-40% of incidents.

| Pattern | Detection | Action |
|---|---|---|
| `rai_studio_*`, `rai_int_*`, `rai_latest_*` | Internal test account | Lower priority; likely known error or expected behavior |
| `*_cicd_validation_*` | CI/CD test account | Check if intentional test run; close if confirmed |
| `ey_fabric233_*` + "database failed to open" | EY old engine version | Check for `CancelledException` in deserialization logs → close as Known Error |
| `ritchie_brothers_*` + weekend timing | Ritchie Brothers + maintenance | Check SF maintenance window first; 33% of engine incidents are maintenance false positives |
| Engine name matches a person's name (e.g., `tolga_*`, `ryan_gao_*`) | Dev engine | Auto-close heartbeat alerts |
| `by_dev_*`, `by_perf_*` | BY dev/perf account | Lower priority; check for known repeat patterns |
| UAE North region + telemetry alert | Noisy telemetry account | 38% of all telemetry incidents; check for alert storm before investigating |

## Entry Points

| Input | Detection | Action |
|---|---|---|
| `NCDNTS-1234` | Matches `[A-Z]+-\d+` | JIRA ticket path |
| `RAI-56789` | Matches `[A-Z]+-\d+` | JIRA ticket path |
| `6f6d1441-...` | Matches UUID | Transaction ID path |
| Free text | No pattern match | Symptom path |
| No arguments | Empty | Ask what to investigate |

### JIRA Ticket Path
1. Read the JIRA ticket using Atlassian MCP (`getJiraIssue`)
2. Read ticket comments (do NOT call any Atlassian write tools — see Rules section)
3. Read remote issue links (`getJiraIssueRemoteIssueLinks`) — if this call fails, briefly note "Remote links unavailable, continuing without them" and proceed
4. Extract anchors from ticket body, comments, and remote links:
   - Transaction IDs (UUIDs)
   - Engine names
   - Account/org aliases
   - Observe dashboard/query links
   - Confluence runbook links — save page title and URL for Stage 2 (do NOT fetch or search Confluence now)
   - Ignore external links (GitHub Actions, PRs, etc.) — they are not investigation anchors
5. Determine time anchor (see Time Anchor Strategy)
6. Proceed to Stage 1

### Transaction ID Path
1. Use the transaction ID as the primary anchor
2. Time anchor: query transaction dataset for timestamp
3. Proceed to Stage 1

### Symptom Path
1. Parse the symptom description for any anchors (account names, service names, time references)
2. If time reference found, parse and convert to UTC
3. If no anchors, ask the user for: what service/account, when it started, what they observed
4. Proceed to Stage 1

## Time Anchor Strategy

Detect whether the incident was system-reported or human-reported:

| Source | Detection | Time Strategy |
|---|---|---|
| System-reported | JIRA reporter is `640a20b693cf25994631a644` or `557058:f58131cb-b67d-43c7-b30d-6b58d40bd077` | Use incident start time from ticket directly |
| Human + transaction ID | Has UUID anchor | Query transaction dataset for actual timestamp |
| Human + time in description | Parseable time string | Parse, convert to UTC (watch for EST/PST/CET) |
| Human + no time info | None of the above | Query recent activity for referenced entity, or ask user |

## Stage 1: Light Triage

Target: resolve 50-80% of issues without deep investigation. Run immediately.

### Parallel Queries (3-4 simultaneous)
Using anchors from the entry point, run in parallel:
1. **Transaction status:** Query transaction + transaction info datasets for the anchor
2. **Error logs:** Dispatch log agent (see Log Agent section)
3. **Active alerts:** Query monitors that fired near the incident time
4. **Span errors:** Query spans dataset for errors related to the anchor

### Alert Storm / Duplicate Check

Before classifying, check if this incident is part of an alert storm:

1. If the incident is from an automated monitor, search JIRA for other open incidents with the same monitor name or entity (engine name, pod name, account, region) in the last 24h
2. If an existing open incident exists for the same entity, classify as **noise** and recommend closing as duplicate — link to the root incident

**Known alert storm patterns:**

| Pattern | Detection | Action |
|---|---|---|
| Pod memory alerts | Same `pod_name` with existing open incident | Close as duplicate of root ticket |
| AWS Key/Token detection | Same detection event within 24h | Close all but first |
| Telemetry outages (same region) | Same region, multiple signal types (NA Logs, SPCS Logs, OTEL Metrics, SF Platform Metrics, NA Spans) within 30 min | Single event — investigate one, close rest |
| Telemetry outages (multi-region) | 3+ regions within 60 min | Single upstream event — investigate one, close rest |
| Synthetic tests | 3+ regions failing within 60 seconds | Upstream outage — check status pages, close all |
| SPCS-INT sub-jobs | Same GitHub Actions run ID | Same failure — close extras |
| Engine provisioning | Same Datadog monitor re-firing at SEV2 and SEV3 | Single event — close extras |

### Classification

**Causal chain validation (CRITICAL):** Before classifying, verify that signals are directly connected to the entity being investigated — not just present in the same time window.

A signal is **anchor-correlated** if it:
- Matches the investigation's transaction ID, engine name, or account
- Comes from the log agent's "anchor-correlated errors" category (not "temporally-adjacent")
- Appears in span/transaction query results filtered by the investigation's anchor

A signal is **coincidental** if it:
- Was found only because it shares a time window with the incident
- Comes from a different engine, transaction, or account than the one being investigated
- Appears in the log agent's "temporally-adjacent" category

**Classification rules:**
1. Match anchor-correlated signals against the triage signals table in SKILL.md
2. IGNORE coincidental signals for classification — they are noise unless they indicate a systemic issue affecting the anchor entity
3. If multiple anchor-correlated signals exist, record ALL of them on the triage card. Do not determine root cause in Stage 1 — only classify the incident type and set confidence. Root cause determination happens in Stage 2.
4. If the ONLY signals found are coincidental (no anchor-correlated signals), classify as **unknown / Low** — do NOT pick a coincidental error and call it root cause

Assign:
- **Classification:** crash / OOM / brownout / pipeline / cross-service / erp-error / cascade / noise / cicd / telemetry / unknown
- **Confidence:** High (anchor-correlated signal clearly matches a triage pattern) / Medium (anchor-correlated but ambiguous) / Low (no anchor-correlated signals, or conflicting signals)

**New classification definitions:**
- **erp-error:** ERP subsystem error (BlobGC, CompCache, transaction manager). Use the ERP error taxonomy in the triage signals table.
- **cascade:** Downstream symptom of an upstream failure. Example: BlobGC storage alert caused by a preceding engine crash. Always look for the parent incident.
- **noise:** Known false positive or auto-closeable pattern (test incidents, internal dev engine heartbeats, EY old-engine DB failures, Trust Center ingestion failures, AWS key detection false positives).
- **cicd:** CI/CD workflow failure (poison commit, deployment failure, test ring failure, synthetic test failure). See CI/CD decision tree.
- **telemetry:** Telemetry pipeline outage (Observe, Snowflake tasks, event table heartbeats).

### Triage Card Output

Present the triage card in this exact format:

```
## Triage Card

| Field | |
|-------|---|
| **What** | One-line description of the issue |
| **Who** | Customer (org_alias + account_alias), reporter if from JIRA |
| **Where** | Environment, region, service, engine |
| **Status** | Transaction state, abort reason, current incident status |
| **Classification** | Crash / OOM / brownout / pipeline / cross-service / unknown |
| **Confidence** | High / Medium / Low — with brief justification |
| **Escalation** | Recommended team + Slack channel |
| **Timeline** | Key timestamps: when started, duration, when detected |
| **Observe Links** | Direct links from generate-query-card — use as returned |

### [Classification] Details

(Adaptive section — content varies by classification, see below)
```

**When a field has no data:** show "—" (em dash). Never omit fields.

**Adaptive section by classification:**

| Classification | Adaptive section includes |
|---|---|
| Crash | Termination reason, crash log summary, core dump availability |
| OOM | Termination reason, Jemalloc profile availability, memory metrics. OOM subtypes: GC brownout (false alarm), rapid Julia spike (pager can't react), undersized engine (OOM brake). |
| Brownout | Heartbeat rate, Julia GC/compilation metrics, thread blocking indicators |
| Pipeline | Pipeline stage affected, batch processing status, stream state |
| Cross-service | SQL-layer timeline, ERP-layer timeline, correlation key used |
| ERP-error | ERP error code, affected subsystem (BlobGC/CompCache/TxnMgr), upstream engine status, cascade check |
| Cascade | Parent incident identification, upstream failure → downstream symptom chain |
| Noise | Pattern matched, auto-close recommendation, justification |
| CI/CD | Workflow name, failure stage, poison commit SHA (if applicable), next-run status, GH/SF platform status |
| Telemetry | Affected region/account, Observe dashboard status, self-recovery check, pattern (transient/RAI-bug/misconfiguration) |
| Unknown | Raw signals found (if any), suggested next steps, request for user context |

### After Stage 1

If confidence is High and the issue is clear-cut, Stage 1 may be sufficient. Present the triage card and ask if the user wants deep investigation.

If confidence is Medium or Low, automatically proceed to Stage 2.

## Stage 2: Deep Investigation

Runs as a **background agent** after Stage 1 output is presented. The foreground remains interactive — the user can ask clarifying questions while Stage 2 runs.

When triage identifies multiple distinct investigation threads (e.g., engine crash + CDC failure), Stage 2 can split into multiple parallel background agents, each loading only its relevant knowledge file.

### Knowledge File Loading

Load based on Stage 1 classification:

| Classification | Load |
|---|---|
| Crash / OOM / brownout | `skills/observability/knowledge/engine-failures.md` + `skills/observability/knowledge/incident-patterns/engine-incidents.md` |
| Pipeline | `skills/observability/knowledge/data-pipeline.md` + `skills/observability/knowledge/incident-patterns/pipeline-incidents.md` |
| Cross-service | `skills/observability/knowledge/architecture.md` |
| ERP-error | `skills/observability/knowledge/incident-patterns/erp-incidents.md` + `skills/observability/knowledge/incident-patterns/control-plane-incidents.md` |
| Cascade | Load knowledge file for the suspected parent classification + `skills/observability/knowledge/incident-patterns/erp-incidents.md` (cascades commonly involve BlobGC) |
| CI/CD | `skills/observability/knowledge/incident-patterns/infrastructure-incidents.md` |
| Telemetry | `skills/observability/knowledge/incident-patterns/telemetry-incidents.md` |
| Noise | No deep investigation needed — present auto-close recommendation |
| Unknown | `skills/observability/knowledge/incident-patterns/engine-incidents.md` + `skills/observability/knowledge/incident-patterns/pipeline-incidents.md` + `skills/observability/knowledge/incident-patterns/control-plane-incidents.md` + `skills/observability/knowledge/incident-patterns/infrastructure-incidents.md` + `skills/observability/knowledge/incident-patterns/erp-incidents.md` + `skills/observability/knowledge/incident-patterns/telemetry-incidents.md` — pattern match against symptoms |

> Heartbeat timeout signals use the brownout classification (see SKILL.md triage signals). The same knowledge files apply.

**Exception:** If JIRA ticket contained Confluence runbook links, read those via Atlassian MCP and use as primary investigation guide INSTEAD of knowledge files.
- If you have the Confluence page ID → use `getConfluencePage` directly
- If you only have the page title → use `searchConfluenceUsingCql` with `title = "Page Title"`
- Do NOT use WebFetch on Confluence URLs — they require authentication and will redirect

### Investigation Steps: Collect Then Eliminate

**Phase A — Comprehensive Error Inventory:**
- Dispatch Stage 2 log agent (unconstrained) with full anchor set
- Query ALL failed transactions on this engine/account in the incident window (not just the reported one)
- Query ALL error spans on this engine/account in the incident window
- Query ALL monitor detections for this account/engine in the +/-2h window
- If Confluence runbook linked in JIRA, read it and add its diagnostic queries
- Produce an **error inventory**: flat list of every error/failure/anomaly, each tagged with:
  - Timestamp
  - Source (logs / spans / metrics / monitors)
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
  - Engine crash followed by BlobGC errors within 2h = cascade (not two separate incidents)
  - SF maintenance followed by multiple "engine failed" aborts = single event
  - GitHub outage followed by ArgoCD + synthetic + CI/CD failures = single event
  - Azure outage followed by provisioning + disk mount + webhook failures = single event

**Phase D — Evaluation and Elimination:**
For each candidate cause, check:
1. **Causal chain:** Can you trace candidate -> intermediate effects -> observed symptom?
2. **Timing:** Did candidate occur BEFORE the symptom?
3. **Scope:** Does candidate affect the investigated entity (not a different engine/account)?
4. **Knowledge match:** Does a pattern in the knowledge file explain this candidate?
5. **Upstream check:** Is this a known downstream symptom? (BlobGC after engine crash, "engine failed" after SF maintenance, CI failure after GH outage)

Eliminate candidates that fail checks. Note WHY each was eliminated (one line per elimination).

**Phase E — Root Cause Declaration:**

| Situation | Action |
|---|---|
| One candidate, clear causal chain | Root cause — High confidence |
| One candidate, gap in chain | "Suspected root cause" — Medium confidence, explain gap |
| Multiple candidates survive | "Multiple potential causes" — list each with evidence and what would distinguish them |
| No candidates survive | "Root cause undetermined" — list what was checked and what is missing |
| Upstream/external cause identified | "External root cause" — name the upstream system (SF, GitHub, Azure), link to status page |

**Never declare root cause by picking the earliest error.** The earliest error is often a symptom of a deeper cause (e.g., SF maintenance triggers engine restart which triggers transaction abort which triggers BlobGC failure).

### Deep Investigation Output

Update the triage card header with any new findings (confidence may increase, classification may change).

Add free-form analysis body, ordered by priority:
1. **Root cause** — lead with this if identified. Must be anchor-correlated (connected to the specific entity under investigation). If you cannot establish a causal chain from the root cause to the reported symptom, say "suspected root cause" and explain the gap. Never state a root cause with high confidence unless you can trace the causal chain: root cause event → intermediate effects → observed symptom.
2. **Detailed timeline with evidence**
3. **Impact assessment** — customers, transactions, duration
4. **Correlated data across services**
5. **Related historical incidents** — from incident-patterns files
6. **Recommended actions** — mitigation, escalation, follow-up

## ERP Error Decision Tree

When the incident involves an ERP error code, use this decision tree before deep investigation:

```
ERP error arrives
├─ BlobGC error?
│   ├─ Check for upstream engine crash in same account (last 2h)
│   │   YES → cascade classification. Link to engine incident. Close as downstream.
│   │   NO  → Investigate BlobGC independently (metadata deserialization OOM? storage threshold?)
│   └─ GapKeyWithoutJuliaValError in logs? → Engine version mismatch marker (not primary cause)
│
├─ broken_pipe / stream error? → Transient. Close if single occurrence, no txn failure.
├─ compute_pool_suspended? → Check for manual account changes (user-initiated suspension).
├─ circuit_breaker_open? → Find the failing upstream engine. This is a cascade.
├─ txn_commit_error? → Check status.snowflake.com first. SF platform issue.
├─ S3/storage rate limit (next_page_error)? → Check if internal GC span (no user txn ID). Transient.
├─ send_rai_request_error? → Engine briefly unreachable. Check for Julia GC brownout (1-min log gap).
└─ Account in repeat-offender list? (rai_studio_sac08949, by_dev_ov40102, rai_int_sqllib)
    → Check if known recurring pattern for that account before investigating.
```

### ERP Runbooks
- ERP monitoring runbook: `https://relationalai.atlassian.net/wiki/spaces/ES/pages/658407425`
- BlobGC/CompCache: `https://relationalai.atlassian.net/wiki/spaces/ES/pages/890929153`
- BlobGC Dashboard: `https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311`

## CI/CD Decision Tree

When the incident involves a CI/CD workflow failure:

```
CI/CD incident arrives
├─ Title: "Poison commit <sha> is added to repository <repo>"?
│   → poison_commit. Extract commit SHA and repo.
│   → Resolution: revert (preferred) or antidote workflow (forward-fix).
│   → Check: does this root cause match a prior poison commit ticket?
│   → Answer the 5 standard questions: how identified? why poison? why not caught? what next? follow-ups?
│
├─ Multiple unrelated CI systems failing simultaneously?
│   → Check https://www.githubstatus.com FIRST.
│   → If GitHub outage active: external_outage. Stop internal investigation.
│   → If no GH outage, check for Snowflake platform issues (SF releases, native app activation failures).
│
├─ ArgoCD out-of-sync?
│   → Simultaneous multi-environment sync failure? → Bad config commit. Investigate. Revert.
│   → Single-environment? → GitHub transient. Self-resolved <20 min? Close.
│   → ArgoCD prod: https://argocd.prod.internal.relational.ai:8443/
│   → ArgoCD staging: https://argocd.staging.internal.relational.ai:8443/
│
├─ SPCS-INT workflow failure?
│   → Check if other spcs-int sub-job failures in same 30-min window (likely same root cause).
│   → Check if subsequent run passed → transient, close.
│   → 87% of these are closed without root cause; auto-check is the main value add.
│
├─ Test Ring 3 failure?
│   → Check if failure is from a dev branch run (should be excluded from monitor).
│   → If not dev branch: check for specific test file/line in logs.
│
├─ Setup step fails (Setup Go, Setup Node)?
│   → CI configuration regression. Find recent PR that modified go.mod/workflow YAML. Revert.
│
├─ "EnginePending" in logs?
│   → Infrastructure misconfiguration. Check engine auto_suspend_mins. Recreate with auto_suspend_mins=0.
│
├─ "/sys/fs/cgroup/" file not found?
│   → Environment mismatch. Revert the commit that added cgroup file access.
│
├─ "CVE-" in title?
│   → security_vuln. Route via code-ownership.yaml. Batch concurrent CVEs from same base image.
│
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
│
└─ Account matches *_cicd_validation_*?
    → Likely intentional test run. Close as non-incident.
```

### CI/CD Links
- Deployment failure runbook: `https://relationalai.atlassian.net/wiki/x/AQBrWQ`
- Repair dashboard: `https://relationalai.atlassian.net/jira/dashboards/10058`
- Observe synthetic test dashboard: `https://171608476159.observeinc.com/workspace/41759331/dashboard/Synthetic-Tests-Insights-42313552`

## Cascade Detection

When any alert fires for BlobGC, storage threshold, or CompCache:
1. Check if an engine failure occurred in the same account within the last 2 hours
2. If yes → classify as **cascade**. The engine failure is the root cause; the BlobGC/storage alert is a downstream symptom.
3. Link to the engine incident ticket and close as downstream.
4. If no upstream engine failure → investigate the alert independently.

Common cascade chain: **engine crash/OOM → BlobGC cannot run → storage threshold exceeded**

## Log Agent

Log analysis is ALWAYS offloaded to a dedicated agent (logs are unbounded context). The main agent never sees raw log lines — only the log agent's summary.

### Anchor Filtering (CRITICAL)

The log agent MUST receive the investigation's anchors and use them as primary query filters. Logs contain errors from many engines/transactions simultaneously — unfiltered time-window queries will return irrelevant errors.

**Pass to the log agent:** all available anchors from the entry point (transaction ID, engine name, account alias, environment). The log agent must include these in every query.

**Query construction:** Always filter by anchor FIRST, then by time window and severity. Example: "Error logs for engine X in account Y in the last 30 minutes" — not "Error logs in the last 30 minutes".

**If no anchors are available** (rare — symptom path with minimal info): the log agent must return ALL errors found in the time window, grouped by engine/transaction/account, and explicitly flag that results are unfiltered. The main agent must NOT pick one at random — it must ask the user which entity to focus on.

### Stage 1 Log Agent (time-bounded)

Escalation ladder — each step only fires if the previous found no signal:

| Step | Time Window | Severity | Filter |
|---|---|---|---|
| 1 | ±15 min around incident time | error | Anchor-filtered (transaction ID, engine name, account) |
| 2 | ±30 min | error | Anchor-filtered |
| 3 | ±15 min | warning | Anchor-filtered |
| 4 | ±30 min | warning | Anchor-filtered |

- Capped at 10 agent turns
- Typical: resolves at step 1 (~20-25s). Full escalation: ~50-60s.

**Return format — the log agent must return a structured summary:**
1. **Anchor-correlated errors:** Errors that directly match the investigation anchors (same transaction ID, engine name, or account). These are the primary signal.
2. **Temporally-adjacent errors:** Errors in the time window that do NOT match the anchor. Include only if they might indicate a systemic issue (e.g., same error across multiple engines). Label these clearly as "nearby but unrelated to anchor."
3. **Error timeline:** Chronological sequence of anchor-correlated errors showing what happened first.
4. **Error count:** Total errors found vs. anchor-correlated errors (e.g., "3 of 47 errors matched the anchor").

### Stage 2 Log Agent (unconstrained)

Full severity range, wider time windows, thorough reconstruction. No turn cap. Same anchor-filtering rules apply — always filter by anchor first.

## MCP Runtime Errors

Prerequisites catch missing MCP servers. This section handles errors from servers that are present but return failures.

### Atlassian MCP call failure
- If any single Atlassian MCP call errors (e.g., `getJiraIssueRemoteIssueLinks`, `searchConfluenceUsingCql`), tell the user in one line what failed and that you're working around it — e.g., "Remote links unavailable, continuing without them"
- Do NOT surface raw MCP error details to the user
- If `searchConfluenceUsingCql` fails, try `getConfluencePage` with the page ID if available, or skip the runbook and fall back to knowledge files
- Continue investigation with available data

### Observe MCP query failure
- Follow retry strategies from SKILL.md (rephrase → broaden time range → different dataset)
- If persistent, suggest user check Observe MCP status in #ext-relationalai-observe

## Rules

Follow query workflow and result presentation rules from SKILL.md. Additionally:
- `maxlevel` is NOT transaction status. Terminal states: COMPLETED (status = success), ABORTED (status = failure).
- **JIRA/Confluence is READ-ONLY.** Never call any Atlassian write tool during investigation. Allowed tools: `getJiraIssue`, `getJiraIssueRemoteIssueLinks`, `searchJiraIssuesUsingJql`, `getConfluencePage`, `searchConfluenceUsingCql`. Prohibited tools (non-exhaustive): `addCommentToJiraIssue`, `editJiraIssue`, `createJiraIssue`, `transitionJiraIssue`, `addWorklogToJiraIssue`, `jiraWrite`, `createConfluencePage`, `updateConfluencePage`. If in doubt whether a tool is a read or write operation, do not call it.
