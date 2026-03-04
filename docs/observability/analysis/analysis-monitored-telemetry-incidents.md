# Monitored Account & Telemetry Deep Analysis (147 incidents)

Analysis period: September 2025 - March 2026
Source: NCDNTS JIRA project (94 monitored account errors + 53 telemetry/observability incidents)

---

## Monitored Account Error Analysis (94 tickets)

### How These Incidents Work

Every monitored account error follows the same pattern: an automated bot ("Untracked Automation") detects an error fingerprint in a production transaction for a *monitored* customer account, creates a RAI-XXXXX bug ticket, and then escalates it to a NCDNTS incident because it hit a monitored account. The NCDNTS ticket is auto-linked to the RAI bug via a "Repairs" relationship. An oncaller then triages, determines if it is a known error, and closes the incident.

All 94 tickets are **Closed**. The vast majority are SEV3 (Moderate Impact - 1 Business Day ACK). They are almost always resolved by the oncaller saying "known issue, see linked repair" and closing.

### RAI Bug to Incident Mapping

**19 unique RAI bugs generated 2+ incidents each (55 of 94 incidents, or 59%):**

| RAI Bug | Incidents | Bug Status | Description | Auto-close candidate? |
|---------|-----------|------------|-------------|----------------------|
| RAI-45343 | 4 | Closed | FailedKVUpdateException - KV update txn state ABORTED | Yes - now fixed |
| RAI-31774 | 3 | Closed | AssertionError: is_mutts_mutable(dict) in insert! | Yes - now fixed |
| RAI-43366 | 3 | Closed | MethodError: rel_primitive_concat Int128/VariableSizeString | Yes - now fixed |
| RAI-43403 | 3 | Closed | AssertionError: isnothing(current_fragment) || current_fragment == fragment_id | Yes - now fixed |
| RAI-43235 | 3 | Closed | Database was closed and this transaction was discarded | Yes - now fixed |
| RAI-46881 | 2 | Closed | Bug/race condition in handling aborted/completed state when txn aborts | Yes - now fixed |
| RAI-42855 | 2 | Closed | Internal compiler exception: unknown declaration | Yes - now fixed |
| RAI-35820 | 2 | Closed | MethodError: close_stream! | Yes - now fixed |
| RAI-45812 | 2 | Closed | [LQP] Bump LQP semantics version in PyRel from 0 to 1 | Yes - now fixed |
| RAI-46277 | 2 | Closed | MethodError: _parallel_monus | Yes - now fixed |
| RAI-43246 | 2 | Closed | MethodError: rel_primitive_format_date | Yes - now fixed |
| RAI-45801 | 2 | Closed | CompositeException (5 tasks) | Yes - now fixed |
| RAI-44630 | 2 | Closed | IllegalDatabaseAccessPattern | Yes - now fixed |
| RAI-27308 | 2 | Closed | IOError in unsafe_get_page! | Yes - now fixed |
| RAI-43468 | 2 | Closed | AssertionError: Unsupported logical type PhaseEvaluability | Yes - now fixed |
| RAI-40215 | 2 | Closed | Flaky test detected in raicode | Yes - test infra noise |
| RAI-14582 | 2 | Closed | MethodError: logical_runtime_argument(Float64, Int64) | Yes - now fixed |
| RAI-41822 | 2 | Closed | AssertionError: ScanOp variable types mismatch | Yes - now fixed |
| RAI-37908 | 2 | Closed | AssertionError: Arroyo attempt to reassign key | Yes - now fixed |

**39 unique RAI bugs generated exactly 1 incident each (39 of 94, or 41%).**

### Bugs Still Open (In Backlog or In Development)

These bugs have NOT been fixed yet and could generate new incidents:

| RAI Bug | Status | Description |
|---------|--------|-------------|
| RAI-47451 | Backlog | AssertionError in disjoint_chunk_merge_nosamples (affected: EY, Azure) |
| RAI-47264 | Backlog | GetException in load_csv |
| RAI-46713 | Backlog | AssertionError: REDACTED unsafe assertion message |
| RAI-43371 | Backlog | AssertionError: Unexpected pvo_cost |
| RAI-42962 | Backlog | MethodError: logical_runtime_argument(Int128, Int64) |
| RAI-42554 | Backlog | Exception without safe logs defined: ArgumentError |
| RAI-40786 | Backlog | Flaky test detected in raicode |
| RAI-42932 | In Review | Support hash sum sketch for normalized BeTree's with strings |
| RAI-35647 | In Development | Check whether metadata is guaranteed committed at ERP startup |

### Error Fingerprint Patterns

**New vs Known Error distribution:**
- **Done** (first-time or actionable): 54 incidents (57%) -- oncaller triaged, linked to repair, closed
- **Known Error** (repeat of known bug): 25 incidents (27%) -- purely mechanical close
- **Won't Do**: 9 incidents (10%) -- false positive or not actionable
- **Cannot Reproduce**: 2 incidents (2%)
- **Declined**: 2 incidents (2%)
- **Incomplete**: 2 incidents (2%)

**Key finding:** 27% of all monitored account incidents are "Known Error" closures -- the oncaller is spending time triaging something the system already knows about. This is pure toil that an AI agent can eliminate.

**Triage speed:** Most incidents are ACKed within the 1 business day SLA. The common pattern is oncaller opens ticket, sees the linked RAI bug, checks if it's known, writes "known issue, see linked repair", and closes. Average handling is ~30 minutes of human attention for a known error.

### Error Type Taxonomy

The errors fall into clear categories:

1. **AssertionError** (most common, ~35 incidents): Internal invariant violations -- `is_mutts_mutable`, `current_fragment`, `ScanOp variable types`, `m > 0`, `Arroyo reassign key`, `shadowed variables`, etc.
2. **MethodError** (~20 incidents): Julia type dispatch failures -- `rel_primitive_concat`, `_parallel_monus`, `close_stream!`, `rel_primitive_format_date`, `logical_runtime_argument`, `VarargSum`, etc.
3. **Database/Transaction errors** (~12 incidents): `DatabaseClosedException`, `FailedKVUpdateException`, `IllegalDatabaseAccessPattern`, `Database was closed`, etc.
4. **Exception/Error wrappers** (~8 incidents): `CompositeException`, `SafeErrorException`, `GetException`, `PutException`, `IOError`, etc.
5. **Compiler errors** (~5 incidents): `internal compiler exception`, `UnboundError`, `KeyError in _is_valid_prefix`

### Accounts Most Affected by Monitored Errors

| Customer | Incidents | Notes |
|----------|-----------|-------|
| No Customer Impact | 37 | Internal/test accounts hitting errors |
| EY | 15 | Both Azure (9) and SPCS (6) |
| BY (Bertelsmann/ByteYard) | 15 | Primarily SPCS |
| Other (specified in comment) | 24 | Various smaller accounts |
| O3AI | 3 | SPCS only |
| Great American | 1 | SPCS |
| Ritchie Brothers | 1 | SPCS |
| ROC360 | 1 | SPCS |
| New Customer | 1 | SPCS |

**EY and BY are the dominant customer-impacting accounts**, each with 15 incidents. EY runs on both Azure and SPCS; BY is SPCS-only.

### Platform Distribution

| Platform | Count | % |
|----------|-------|---|
| SPCS (Snowflake) | 79 | 84% |
| Azure | 14 | 15% |
| N/A | 2 | 1% |

SPCS dominates because most monitored accounts are on Snowflake.

---

## Telemetry/Observability Analysis (53 tickets)

### Incident Categories

| Category | Count | % |
|----------|-------|---|
| Event Table Heartbeat Failures | 29 | 55% |
| Telemetry Outages (full) | 14 | 26% |
| Ingestion Lag | 4 | 8% |
| NA Logs Outage | 2 | 4% |
| OTEL Metrics Outage | 1 | 2% |
| Telemetry Scanning (Secret Detection) | 1 | 2% |
| Telemetry Stopped (RAICloud) | 1 | 2% |
| Test Tickets | 1 | 2% |

### Telemetry Outage Patterns by Region

| Region | Outage Count | Notes |
|--------|-------------|-------|
| AZURE_WESTUS2 | 5 | Most affected Azure region |
| AWS_US_WEST_2 | 5 | Most affected AWS region |
| AWS_US_EAST_1 | 2 | Including 1 test ticket |
| AZURE_EASTUS2 | 2 | |
| AWS_EU_WEST_1 | 2 | |
| AZURE_WESTEUROPE | 1 | |

**Key pattern:** AZURE_WESTUS2 and AWS_US_WEST_2 are the most frequently affected regions for full telemetry outages. These tend to be transient -- all resolved as "Done" -- and rarely have linked repair items, suggesting they are upstream infrastructure issues (Snowflake event table processing, O4S task failures).

### Event Table Heartbeat Failures

This is the **dominant telemetry problem** -- 29 of 53 tickets (55%).

**Account breakdown:**

| Account | Heartbeat Failures | Type |
|---------|-------------------|------|
| rai_azure_uaenorth_events_ye96117 | **20** | LOG (11), NA TRACE (9) |
| rai_azure_useast_2_events_doa24270 | 3 | NA TRACE (2), LOG (1) |
| rai_prod_us_east_1_provider_qwb38646 | 2 | LOG (1), NA TRACE (1) |
| rai_staging_provider_bub00109 | 2 | LOG (1), NA TRACE (1) |
| rai_latest_idb96670 | 1 | LOG |
| rai_azure_uswest2_events_qp91071 | 1 | LOG |

**The `rai_azure_uaenorth_events_ye96117` account is overwhelmingly dominant** -- responsible for 20 of 29 heartbeat failures (69%). This single account in UAE North generates the majority of all telemetry incidents. The heartbeat failures are split between LOG (16 total) and NA TRACE (13 total) types.

**Temporal clustering:** 11 heartbeat tickets (NCDNTS-10636 through NCDNTS-10644) were all filed on 2025-10-16, all for `rai_azure_uaenorth_events_ye96117`. This is a single outage event generating many duplicate tickets -- a clear alert storm.

### Ingestion Lag Incidents

4 tickets, mostly in Nov 2025:
- NCDNTS-11202: Canceled, region field empty (webhook misconfiguration)
- NCDNTS-11152: Canceled, AZURE_UAENORTH
- NCDNTS-11151: Canceled, `{{webhookData.SNOWFLAKE_REGION}}` -- **template variable not resolved**
- NCDNTS-11150: Done, `{{webhookData.SNOWFLAKE_REGION}}` -- same template bug

**The template variable leak in NCDNTS-11151 and NCDNTS-11150** reveals that the Observe webhook payload was not being parsed correctly at the time. This was a monitor configuration bug.

### Linked Repairs for Telemetry Issues

Most telemetry tickets have NO linked repair (NO_LINK). Only 5 of 53 have repairs:

| NCDNTS | Repair | Status | Description |
|--------|--------|--------|-------------|
| NCDNTS-12234 | RAI-47369 | Closed | Improve telemetry scanning regex to reduce false positives (AWS key detection) |
| NCDNTS-12225 | RAI-47552 | Backlog | Create monitors on failing O4S tasks |
| NCDNTS-11740 | RAI-46306 | Ready for Development | Add basic monitors for missing telemetry on RAICloud |
| NCDNTS-11542 | RAI-45712 | Backlog | Runbook improvements for full outage with old events still flowing |
| NCDNTS-10103 | RAI-42133 | Backlog | Document how to inspect O4S task durations in the SF account |

**Key finding:** Telemetry issues are overwhelmingly treated as transient operational events with no structural repair. The team acknowledges, waits for resolution, and closes. There are open backlog items to improve monitoring (RAI-47552, RAI-46306, RAI-45712, RAI-42133) but none are actively in development.

### Resolution Patterns for Telemetry

All 53 telemetry tickets are Closed. Breakdown:
- **Done**: 47 (89%) -- acknowledged and resolved/self-resolved
- **Canceled**: 3 (6%) -- false positive or misconfigured alert
- **Won't Do**: 1 (2%) -- test ticket
- **Declined**: 1 (2%) -- test ticket

---

## Cross-Cutting Patterns

### Pattern 1: Known Error Toil (Monitored Accounts)
27% of monitored account incidents are closed as "Known Error" with zero new investigation. The oncaller is doing manual dedup work that an AI agent should handle automatically.

### Pattern 2: Repeat Bug Cascade
19 bugs generated 55 of 94 incidents (59%). When a bug hits production, it generates incidents across every monitored account that triggers it. A single bug like RAI-45343 generates 4 separate NCDNTS tickets that all require individual human triage.

### Pattern 3: UAE North Alert Storm (Telemetry)
A single account (`rai_azure_uaenorth_events_ye96117`) generates 38% of ALL telemetry incidents (20/53). On one day (Oct 16, 2025), it generated 11 tickets in rapid succession. This is a noisy monitor that needs dedup/suppression.

### Pattern 4: Template/Config Bugs in Monitors
Ingestion lag alerts fired with unresolved template variables (`{{webhookData.SNOWFLAKE_REGION}}`), indicating the Observe-to-JIRA webhook was misconfigured.

### Pattern 5: No Structural Repairs for Telemetry
91% of telemetry incidents have no linked repair. The team treats these as operational noise rather than opportunities for systemic improvement.

---

## Recommendations for /investigate

### 1. Auto-Link and Auto-Close Known Bugs

**When the AI agent encounters a monitored account error:**

1. **Extract the RAI-XXXXX bug ID** from the NCDNTS title (pattern: `Error in monitored account due to RAI-XXXXX:` or `New error in monitored account (fingerprint: 0x...)`)
2. **Check if the RAI bug is already Closed/Merged** -- if so, determine if the error occurred on an engine version older than the fix. If the fix is deployed, auto-close as "Known Error - fix deployed."
3. **Check if the RAI bug is in Backlog** -- flag it for escalation since it means the bug is known but unfixed and still hitting customers.
4. **Check for other open NCDNTS incidents for the same RAI bug** -- deduplicate and cross-reference.

**Specific auto-close rules:**
- If RAI bug status is Closed AND the incident's engine version is >= the version containing the fix, auto-close.
- If the same RAI bug has generated 2+ NCDNTS incidents in the past 30 days, suppress new alerts and add a comment to the existing incident instead.

### 2. Error Fingerprint-Based Routing

Build a lookup table of error fingerprints to owning teams:

| Error Pattern | Component | Owning Team |
|---------------|-----------|-------------|
| `AssertionError` in compiler/IR phases | Rel Compiler | Engine & Rel Compiler |
| `MethodError: no method matching rel_primitive_*` | Primitives/FFI | Engine & Rel Compiler |
| `DatabaseClosedException`, `FailedKVUpdateException` | Storage/ERP | Engine Resource Providers |
| `IllegalDatabaseAccessPattern` | Database Access | Engine Resource Providers |
| `CompositeException` | Transaction Management | Engine & Rel Compiler |
| `MissingPageException`, `IOError in unsafe_get_page!` | Storage/Pager | Storage |
| `MethodError: _parallel_monus`, `close_stream!` | Backend Operators | Backend |
| `KeyError in _is_valid_prefix` | Optimizer | Optimizer |

### 3. Customer Impact Assessment Automation

The agent should auto-determine customer impact:
- Parse the affected account name from the description (e.g., `ey-production` -> EY, `by_dev_*` -> BY)
- Cross-reference with a customer account mapping table
- Auto-set the severity/priority based on whether it's a paying customer vs internal account
- **For "No Customer Impact" incidents** (37/94 = 39%), the agent should auto-resolve with minimal investigation

### 4. Telemetry Outage Investigation Workflow

**For `[Observe] Telemetry outage in REGION`:**
1. Check O4S task status in Snowflake for the affected region
2. Check if there's a known Snowflake outage or maintenance window
3. Check if other regions are also affected (correlated outage vs isolated)
4. If self-resolved within 30 min, auto-close with "transient outage" resolution
5. If lasting > 30 min, escalate with O4S task failure details

**For `[Observe] Event table heartbeat of type X is missing for account: Y`:**
1. Check if account is `rai_azure_uaenorth_events_ye96117` -- if so, apply UAE North suppression (this account is chronically flaky)
2. Check if there are other heartbeat failures for the same region (correlated vs isolated)
3. Check O4S task health for the specific account
4. If the account is a non-critical/test region, auto-close with low priority

**For `[Observe] High event table ingestion lag`:**
1. Check if the alert has a valid region (watch for `{{webhookData.SNOWFLAKE_REGION}}` template leak)
2. Check Snowflake warehouse query history for the region
3. Check if there was a spike in event volume

### 5. Dedup and Alert Storm Suppression

The agent should implement:
- **Time-window dedup:** If 3+ heartbeat failures for the same account fire within 1 hour, batch them into a single incident
- **Known-noisy-account suppression:** For `rai_azure_uaenorth_events_ye96117`, require 2+ consecutive missed heartbeats before creating an incident
- **Same-bug dedup:** If a RAI bug already has an open NCDNTS incident, add a comment to the existing one rather than creating a new one

### 6. Investigate Command Enhancement

The `/investigate` command should:

1. **For monitored account errors:**
   - Immediately identify the linked RAI bug
   - Show bug status (Open/Closed) and which version contains the fix
   - List all other NCDNTS incidents for the same bug (dedup view)
   - Show affected customer tier (paying vs internal)
   - Recommend auto-close if the bug is fixed and deployed

2. **For telemetry outages:**
   - Check O4S task status via Observe MCP
   - Check for correlated outages across regions
   - Show historical frequency for this alert type
   - Classify as transient vs structural
   - If transient, recommend auto-close after service restoration confirmed

3. **For both types:**
   - Surface the oncaller's typical resolution pattern from past similar incidents
   - Pre-fill the 5-Whys template when the root cause is obvious from the linked bug
   - Auto-link to existing repairs if the error fingerprint matches a known bug

### 7. Metrics the Agent Should Track

| Metric | Current Baseline | Target |
|--------|-----------------|--------|
| % of incidents auto-closeable | ~40% (known errors + no-impact) | Auto-close 80%+ |
| Mean time to triage (monitored account) | ~4-24 hours | < 15 min for known errors |
| Duplicate incidents per bug | Up to 4 per bug | 1 (dedup the rest) |
| UAE North heartbeat noise | 20 incidents | < 3 (with suppression) |
| Telemetry incidents with linked repairs | 9% | > 50% |

---

## Appendix: Full Incident Inventory

### Monitored Account Errors - By RAI Bug (Multi-Incident Bugs)

**RAI-45343** (4 incidents: NCDNTS-11909, 11793, 11727, 11558) - FailedKVUpdateException KV update txn ABORTED - Status: Closed
**RAI-31774** (3 incidents: NCDNTS-11954, 11731, 11574) - AssertionError is_mutts_mutable(dict) - Status: Closed
**RAI-43366** (3 incidents: NCDNTS-11732, 11193, 10716) - MethodError rel_primitive_concat - Status: Closed
**RAI-43403** (3 incidents: NCDNTS-11568, 10847, 10723) - AssertionError current_fragment - Status: Closed
**RAI-43235** (3 incidents: NCDNTS-11114, 11002, 10628) - Database was closed - Status: Closed
**RAI-46881** (2 incidents: NCDNTS-12792, 12196) - Race condition aborted/completed state - Status: Closed
**RAI-42855** (2 incidents: NCDNTS-12153, 10435) - Internal compiler exception unknown declaration - Status: Closed
**RAI-35820** (2 incidents: NCDNTS-12039, 11790) - MethodError close_stream! - Status: Closed
**RAI-45812** (2 incidents: NCDNTS-11874, 11735) - LQP Bump semantics version - Status: Closed
**RAI-46277** (2 incidents: NCDNTS-11868, 11791) - MethodError _parallel_monus - Status: Closed
**RAI-43246** (2 incidents: NCDNTS-11780, 10632) - MethodError rel_primitive_format_date - Status: Closed
**RAI-45801** (2 incidents: NCDNTS-11730, 11679) - CompositeException (5 tasks) - Status: Closed
**RAI-44630** (2 incidents: NCDNTS-11496, 11266) - IllegalDatabaseAccessPattern - Status: Closed
**RAI-27308** (2 incidents: NCDNTS-11312, 11238) - IOError in unsafe_get_page! - Status: Closed
**RAI-43468** (2 incidents: NCDNTS-11022, 10738) - AssertionError PhaseEvaluability - Status: Closed
**RAI-40215** (2 incidents: NCDNTS-10508, 10181) - Flaky test detected - Status: Closed
**RAI-14582** (2 incidents: NCDNTS-10487, 10413) - MethodError logical_runtime_argument - Status: Closed
**RAI-41822** (2 incidents: NCDNTS-10416, 10084) - AssertionError ScanOp variable types - Status: Closed
**RAI-37908** (2 incidents: NCDNTS-10007, 9938) - AssertionError Arroyo reassign key - Status: Closed

### Telemetry/Observability - Full List

**Telemetry Outages (14):**
NCDNTS-12512 (AWS_US_EAST_1), NCDNTS-11765 (AZURE_WESTUS2), NCDNTS-11763 (AZURE_WESTUS2), NCDNTS-11733 (AWS_US_WEST_2), NCDNTS-11652 (AZURE_EASTUS2), NCDNTS-11645 (AWS_US_WEST_2), NCDNTS-11560 (AZURE_WESTUS2), NCDNTS-11539 (AWS_EU_WEST_1), NCDNTS-11519 (AWS_US_WEST_2), NCDNTS-11327 (AZURE_WESTEUROPE), NCDNTS-11269 (AZURE_WESTUS2), NCDNTS-11223 (AWS_US_WEST_2), NCDNTS-11041 (AZURE_WESTUS2), NCDNTS-10845 (TEST)

**NA Logs Outages (2):**
NCDNTS-12225 (AZURE_EASTUS2), NCDNTS-11542 (AWS_EU_WEST_1)

**OTEL Metrics Outages (1):**
NCDNTS-11014 (AWS_US_WEST_2)

**Event Table Heartbeat Failures (29):**
rai_azure_uaenorth_events_ye96117: NCDNTS-10995, 10931, 10811, 10798, 10726, 10676, 10670, 10663, 10644, 10643, 10642, 10641, 10640, 10639, 10638, 10637, 10636, 10103, 9980, 9978
rai_azure_useast_2_events_doa24270: NCDNTS-10963, 10873, 10259
rai_prod_us_east_1_provider_qwb38646: NCDNTS-10688, 10324
rai_staging_provider_bub00109: NCDNTS-10260, 9957
rai_latest_idb96670: NCDNTS-10966
rai_azure_uswest2_events_qp91071: NCDNTS-10659

**Ingestion Lag (4):**
NCDNTS-11202, 11152, 11151, 11150

**Other (3):**
NCDNTS-12234 (secret detection), NCDNTS-11740 (RAICloud telemetry stopped), NCDNTS-10832 (test)
