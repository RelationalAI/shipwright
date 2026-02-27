---
description: Investigate live service issues using observability data (logs, spans, metrics)
argument-hint: [incident key, transaction ID, error description, or service name]
---

You are running the Shipwright Investigate command. This provides observability-driven investigation of live service issues.

## Behavior
- This is a standalone command -- no orchestrator, no recovery, no .workflow/ files
- The user drives the process directly
- Focus is on querying, correlating, and interpreting observability data -- not code fixes

## Setup

Load this skill from the Shipwright plugin root before starting:
1. `skills/observability/SKILL.md` -- domain context, tools, workflow, and runbooks

Read the file and internalize its rules, domain context, and runbooks. They are non-negotiable during this session.

## Getting the Investigation Context

If `$ARGUMENTS` is provided, determine the input type and follow the matching path:

### Path A: JIRA Incident Key (e.g., NCDNTS-12795, PROJ-123)

If the argument matches a JIRA issue key pattern (`[A-Z]+-\d+`):

1. **Read the incident** — Use `mcp__claude_ai_Atlassian__getJiraIssue` with `expand: "renderedFields"` to get the full issue including comments. Use `relationalai.atlassian.net` as the cloudId.
2. **Read remote links** — Use `mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks` to get linked issues and external URLs.
3. **Extract investigation anchors** from the description, comments, and links:
   - Transaction IDs (`rai_transaction_id`)
   - Engine names (`rai_engine_name`)
   - Customer accounts (`org_alias`, `account_alias`)
   - Observe dashboard/query URLs
   - Confluence page links (read these with `mcp__claude_ai_Atlassian__getConfluencePage` if they look relevant)
   - Error messages, stack traces, symptoms
4. **Summarize the incident** to the user: what is reported, who reported it, current status, and what anchors you found.
5. **Proceed to Runbook Selection** using the extracted anchors and symptoms.

### Path B: Direct Input (transaction ID, symptom, service name)

Use directly as the starting point for Runbook Selection.

### No Arguments

Ask the user what they want to investigate. Useful starting points:
- A JIRA incident key (e.g., `NCDNTS-12795`)
- A `rai_transaction_id`
- An engine name
- A customer account (`org_alias` / `account_alias`)
- A symptom ("data isn't loading", "transaction failed", "engine crashed")

## Runbook Selection

Based on the input (or extracted from JIRA), select the matching runbook from the skill:

| Input | Runbook |
|-------|---------|
| Transaction ID or "what happened with transaction X?" | **Runbook 1: Transaction Investigation** |
| Engine crash, abort, OOM, hang | **Runbook 2: Engine Failure Investigation** |
| Stale data, CDC issues, slow sync | **Runbook 3: Data Pipeline Investigation** |
| Issue spanning SQL layer and ERP, or Snowflake query ID | **Runbook 4: Cross-Service Correlation** |

If unclear, start with **Runbook 1** — it routes to the others based on findings.

## Execution

Follow the selected runbook step by step:
1. Run the prescribed queries (in parallel where indicated)
2. Interpret results using the runbook's guidance
3. Route to another runbook if the findings point there
4. Present a summary with timeline, root cause (or current hypothesis), and next steps

## Rules
- Always present the Observe link returned by query tools
- Convert durations from nanoseconds to human-readable units
- Extract key data points from large results -- do not dump raw output
- Limit to 5 queries before pausing to analyze, unless the user asks for more
- If a query returns no data, use retry strategies from the skill before giving up
- When investigating from a JIRA incident, tie findings back to the reported symptoms
