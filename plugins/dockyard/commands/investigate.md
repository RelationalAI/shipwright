---
description: Investigate live service issues using observability data (logs, spans, metrics)
argument-hint: "[incident key, transaction ID, error description, or service name]"
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

1. **Always:** Read the `dockyard:observability` skill. It contains tool usage rules, query workflow, failure handling, and paths to all knowledge files.
2. **Always:** Read the platform knowledge file at the path listed in the skill's Reference Data section (`platform.md`).
3. **Always:** Read the triage signals file at the path listed in the skill's Reference Data section (`triage-signals.md`).

Additional knowledge files loaded in Stage 2 — use the paths from the skill's Reference Data section. Initially pre-loaded from Stage 1's classification, then confirmed or overridden by Stage 2's own Phase B classification (see Knowledge File Loading in Stage 2 section).

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
2. Read ticket comments (do NOT call any Atlassian write tools — see Rules section). **Skip OpsAgent comments** — OpsAgent is an automated triage bot whose guesses can bias your independent classification.
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

### Parallel Queries (3-5 simultaneous)
Using anchors from the entry point, run in parallel:
1. **Transaction status:** Query transaction + transaction info datasets for the anchor
2. **Error logs:** Dispatch log agent (see Log Agent section)
3. **Active alerts:** Query monitors that fired near the incident time
4. **Span errors:** Query spans dataset for errors related to the anchor
5. **External status (CI/CD only):** If the incident appears to be a CI/CD workflow failure (detected from JIRA title/labels containing "workflow", "deployment", "CI", "CD", GitHub Actions links, or `cd` label), check https://www.githubstatus.com using WebFetch for active GitHub Actions incidents around the incident time. ~70% of CI/CD failures trace to GitHub platform issues — checking early avoids unnecessary internal investigation.

### CI/CD Fast Path

When the incident is detected as CI/CD (using the criteria from query 5 above):

1. **Do not wait for all parallel queries to complete.** As soon as the GitHub status check (query 5) returns AND the JIRA ticket has been read, present the Stage 1 triage card immediately with whatever data is available.
2. The log agent (query 2), monitor query (query 3), and span query (query 4) continue running in the background — their results feed into Stage 2, not Stage 1.
3. Transaction status (query 1) is also skipped for CI/CD — CD workflows don't produce RAI transactions.
4. If the GitHub status check confirms an active GitHub Actions incident overlapping the failure time, classify as **cicd (external outage) / Medium** and present the triage card. Stage 2 will confirm or override.
5. If no GitHub outage is active, wait for the remaining queries to complete before classifying (fall back to normal Stage 1 flow).

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
1. Match anchor-correlated signals against the triage signals table in triage-signals.md
2. IGNORE coincidental signals for classification — they are noise unless they indicate a systemic issue affecting the anchor entity
3. If multiple anchor-correlated signals exist, record ALL of them on the triage card. Do not determine root cause in Stage 1 — only classify the incident type and set confidence. Root cause determination happens in Stage 2.
4. If the ONLY signals found are coincidental (no anchor-correlated signals), classify as **unknown / Low** — do NOT pick a coincidental error and call it root cause

Assign:
- **Classification:** crash / OOM / brownout / pipeline / cross-service / erp-error / cascade / noise / cicd / telemetry / unknown
- **Confidence:** High (anchor-correlated signal clearly matches a triage pattern) / Medium (anchor-correlated but ambiguous) / Low (no anchor-correlated signals, or conflicting signals)

**Classification definitions:**
- **erp-error:** ERP subsystem error (BlobGC, CompCache, transaction manager). Use the ERP error taxonomy in erp-incidents.md.
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
| **Classification** | Crash / OOM / brownout / pipeline / cross-service / erp-error / cascade / noise / cicd / telemetry / unknown |
| **Confidence** | High / Medium / Low — with brief justification |
| **Escalation** | Recommended team + Slack channel |
| **Timeline** | Key timestamps: when started, duration, when detected |
| **Evidence** | Observe links from queries that found errors/failures/anomalies — omit links to queries that returned clean or empty results |
| **Dashboard** | Classification-specific investigation dashboard (see table below) |

### [Classification] Details

(Adaptive section — content varies by classification, see below)
```

**When a field has no data:** show "—" (em dash). Never omit fields.

**Classification → Investigation Dashboard:**

| Classification | Dashboard |
|---|---|
| Crash / Brownout | [Engine Failures (41949642)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Engine-failures-41949642) |
| OOM | [OOM Investigations (41777956)](https://171608476159.observeinc.com/workspace/41759331/dashboard/OOM-Investigations-41777956) |
| Pipeline | [O4S Pipeline Health (42090551)](https://171608476159.observeinc.com/workspace/41759331/dashboard/RelationalAI-O4S-Pipeline-Health-42090551) |
| ERP-error / Cascade | [BlobGC (42245311)](https://171608476159.observeinc.com/workspace/41759331/dashboard/42245311) |
| CI/CD | [Synthetic Tests Insights (42313552)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Synthetic-Tests-Insights-42313552) |
| Telemetry | [Telemetry Outages (42760073)](https://171608476159.observeinc.com/workspace/41759331/dashboard/Telemetry-Outages-42760073) |
| Cross-service | [Account Health (42358249)](https://171608476159.observeinc.com/workspace/41759331/dashboard/42358249) |
| Noise / Unknown | — |

**Adaptive section by classification:**

| Classification | Adaptive section includes |
|---|---|
| Crash | Termination reason, crash log summary, stack trace from error logs |
| OOM | Termination reason, Jemalloc profile availability, memory metrics. OOM subtypes: GC brownout (false alarm), rapid Julia spike (pager can't react), undersized engine (OOM brake). |
| Brownout | Heartbeat rate, Julia GC/compilation metrics, thread blocking indicators |
| Pipeline | Pipeline stage affected, batch processing status, stream state |
| Cross-service | SQL-layer timeline, ERP-layer timeline, correlation key used |
| ERP-error | ERP error code, affected subsystem (BlobGC/CompCache/TxnMgr), upstream engine status, cascade check |
| Cascade | Parent incident identification, upstream failure → downstream symptom chain |
| Noise | Pattern matched, auto-close recommendation, justification |
| CI/CD | Workflow name, failure stage, poison commit SHA (if applicable), next-run status, **GitHub Actions status** (from githubstatus.com — always checked), SF platform status if relevant |
| Telemetry | Affected region/account, Observe dashboard status, self-recovery check, pattern (transient/RAI-bug/misconfiguration) |
| Unknown | Raw signals found (if any), suggested next steps, request for user context |

### After Stage 1

Present the triage card. If classification is **noise**, stop — present auto-close recommendation and do not proceed to Stage 2.

For **CI/CD fast-path** (triage card presented before all queries complete): launch Stage 2 immediately as a background agent. The remaining Stage 1 queries (log agent, monitors, spans) feed into Stage 2's Phase A error inventory instead of the Stage 1 triage card.

For all other classifications, **always proceed to Stage 2** regardless of confidence level. If confidence is High, briefly tell the user: "Stage 1 looks clear-cut, but running deep investigation to confirm." Do not ask whether to proceed.

## Stage 2: Deep Investigation

Runs as a **background agent** after Stage 1 output is presented. The foreground remains interactive — the user can ask clarifying questions while Stage 2 runs.

When triage identifies multiple distinct investigation threads (e.g., engine crash + CDC failure), Stage 2 can split into multiple parallel background agents, each loading only its relevant knowledge file.

### Knowledge File Loading

Stage 2 loads knowledge files based on its own Phase B classification, not Stage 1. Stage 1's classification is used as an initial hint for pre-loading, but Phase B may override it.

**Initial pre-load** (before Phase A completes): use Stage 1 classification to pre-load from the table below. If Stage 1 classification is unavailable, pre-load using the Unknown row.

**Post-Phase B**: if Phase B changes the classification, load the correct files per the table below and discard the pre-loaded ones. If Phase B confirms Stage 1, proceed with the pre-loaded files.

| Classification | Load |
|---|---|
| Crash / OOM / brownout | `engine-failures.md` + `incident-patterns/engine-incidents.md` |
| Pipeline | `data-pipeline.md` + `incident-patterns/pipeline-incidents.md` |
| Cross-service | `architecture.md` |
| ERP-error | `incident-patterns/erp-incidents.md` + `incident-patterns/control-plane-incidents.md` |
| Cascade | Load knowledge file for the suspected parent classification + `incident-patterns/erp-incidents.md` (cascades commonly involve BlobGC) |
| CI/CD | `incident-patterns/infrastructure-incidents.md` |
| Telemetry | `incident-patterns/telemetry-incidents.md` |
| Unknown | `incident-patterns/engine-incidents.md` + `incident-patterns/pipeline-incidents.md` + `incident-patterns/control-plane-incidents.md` + `incident-patterns/infrastructure-incidents.md` + `incident-patterns/erp-incidents.md` + `incident-patterns/telemetry-incidents.md` — pattern match against symptoms |

**Always load in Stage 2:** `platform-extended.md` — contains Tier 3-5 datasets, monitors, metrics catalog, ERP error codes, and query patterns needed for deep investigation.

> **Context management for Unknown:** If context limits become an issue, prioritize knowledge files by matching Phase A inventory signals — load only the 2-3 files whose patterns match observed errors.

> Heartbeat timeout signals use the brownout classification (see triage-signals.md). The same knowledge files apply.

> Noise is excluded — Stage 2 does not run for noise (see After Stage 1).

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

**Phase B — Independent Classification:**
- Classify the incident from the Phase A error inventory using the classification rules and triage-signals.md patterns (crash / OOM / brownout / pipeline / cross-service / erp-error / cascade / noise / cicd / telemetry / unknown)
- If Stage 1 classification is available, compare: if Phase A evidence contradicts it (e.g., Stage 1 said OOM but inventory shows preceding segfault), override with the Phase A-based classification and load the correct knowledge file per the table above
- If Phase A evidence confirms Stage 1, proceed with the pre-loaded knowledge file
- If Stage 1 classification is unavailable, classify purely from Phase A evidence
- If inventory reveals the incident is part of a broader alert storm, reclassify as noise/cascade

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

For ERP error classification, follow the decision tree and signal-vs-noise table in `incident-patterns/erp-incidents.md`. That file contains the full taxonomy, cascade patterns, repeat-offender accounts, and runbook links.

## CI/CD Decision Tree

For CI/CD classification, follow the triage decision tree in `incident-patterns/infrastructure-incidents.md`. That file contains the full decision tree, pattern details, routing table, and CI/CD links.

Key Stage 1 rule (always apply, do not defer to Stage 2): **Always check https://www.githubstatus.com first.** If GitHub Actions outage is active and overlaps the failure time, classify as `cicd (external outage)` immediately.

## Cascade Detection

See BlobGC Cascade pattern in `incident-patterns/erp-incidents.md`. Quick rule: BlobGC/storage/CompCache alert + engine failure in same account within 2h = cascade.

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

**CI/CD early exit:** If the incident classification is CI/CD (detected from JIRA labels/title) and step 1 returns no anchor-correlated errors, stop the escalation ladder. Do not run steps 2-4. CI/CD workflow failures typically occur in GitHub Actions runners, not in Observe-monitored services — continuing the ladder wastes ~60s on queries guaranteed to return nothing. Return immediately with "No relevant logs found — CI/CD failures are not captured in Observe logs."

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
- If a query fails after retry, tell the user: which query failed, what data is missing, and how it affects the investigation. Examples:
  - "Transaction status query failed — I cannot confirm whether the transaction completed or aborted. Classification confidence is reduced."
  - "Error logs query returned no results — I cannot check for segfaults or OOM signals. Proceeding with span and monitor data only."
  - "All Observe queries failed — I cannot perform data-driven triage. Observe may be degraded. Check #ext-relationalai-observe."
- If partial data is available, proceed but flag gaps in the triage card Confidence field (reduce to Medium or Low and state why)
- If ALL queries fail, do not attempt classification — tell the user and suggest manual investigation via Observe dashboards

## Rules

Follow query workflow and result presentation rules from SKILL.md. Additionally:
- `maxlevel` is NOT transaction status. Terminal states: COMPLETED (status = success), ABORTED (status = failure).
- **JIRA/Confluence is READ-ONLY.** Never call any Atlassian write tool during investigation. Allowed tools: `getJiraIssue`, `getJiraIssueRemoteIssueLinks`, `searchJiraIssuesUsingJql`, `getConfluencePage`, `searchConfluenceUsingCql`. Prohibited tools (non-exhaustive): `addCommentToJiraIssue`, `editJiraIssue`, `createJiraIssue`, `transitionJiraIssue`, `addWorklogToJiraIssue`, `jiraWrite`, `createConfluencePage`, `updateConfluencePage`. If in doubt whether a tool is a read or write operation, do not call it.
- **Ignore OpsAgent comments entirely.** OpsAgent is an automated triage bot. When reading JIRA ticket comments, discard any comment authored by OpsAgent. Do not use OpsAgent's classifications, duplicate assessments, or suggested actions as input to your investigation. Your triage must be independent — treat OpsAgent output as if it does not exist.
