---
description: Query Observe for service health, metrics, alerts, and ad-hoc operational data
argument-hint: "[health check, error query, monitor status, or natural language question]"
---

# /observe — Operational Queries

Stateless command for querying the Observe platform. Read-only.

## Prerequisites

Before starting, verify the Observe MCP tool is available. If missing, stop and tell the user how to set it up — do not proceed with the query.

| MCP Server | Tools | If Missing |
|---|---|---|
| **Observe** | `generate-query-card` | "Observe MCP is not configured. Set it up at https://171608476159.observeinc.com/settings/mcp — if you don't have access, post a :ticket: in #ext-relationalai-observe to get whitelisted." |

## Setup

1. **Always:** Read the `dockyard:observability` skill. It contains tool usage rules, query workflow, failure handling, and paths to all knowledge files.
2. **Always:** Read the platform knowledge file at the path listed in the skill's Reference Data section (`platform.md`).
3. **Conditionally:** Read additional knowledge files ONLY when the query explicitly references that domain. Use the paths listed in the skill's Reference Data section:
   - CDC / pipeline / batch / stream → `data-pipeline.md`
   - Engine crash / OOM / brownout → `engine-failures.md`
   - Architecture / services / cross-service → `architecture.md`
   - Monitor status queries or metrics exploration → `platform-extended.md`

## Entry Points

### With arguments
Parse the user's query to determine intent:

| Intent | Examples | Action |
|---|---|---|
| **Health check** | "how's prod doing?", "fleet health", "is production stable?" | Run health check workflow |
| **Monitor status** | "active alerts", "what's firing?", "SEV2 alerts" | Run monitor query workflow |
| **Ad-hoc query** | "error rates for rai-server last 2 hours", "transaction failures for account X" | Run ad-hoc query workflow |

### No arguments
Ask the user what they want to check. Suggest:
- "Check production health"
- "View active alerts"
- "Query specific metrics or errors"

## Workflows

### Health Check
1. Query active alerts/monitors using `generate-query-card`: "active SEV2 and SEV3 alerts in the last hour"
2. Query error rates: "error rate across all services in the last hour"
3. Query transaction failure rate: "transaction failure rate in the last hour"
4. **Enrich alert severity:** For each active monitor, determine its true operational severity by checking:
   - The monitor's configured threshold severity (Error, Critical, Informational) from Monitor Detections
   - What JIRA incident severity the monitor creates (SEV2, SEV3) — query the JIRA Incidents dataset (42521777) for recent incidents created by the same monitor name to determine the JIRA severity level
   - Present alerts grouped by effective severity (SEV2 > SEV3 > informational), not just raw count
5. Present results:
   - **All clear:** "No active alerts. Error rates nominal. Transaction success rate: X%." — Zero active alerts is a positive signal, not silence.
   - **Issues found:** Summarize alerts by severity tier, error trends, affected services. Lead with SEV2 alerts (page-worthy), then SEV3 (ack within 1 business day), then informational. Suggest `/investigate` for any specific issue.
   - **Partial data:** If some queries failed, report health based on available data and note which checks could not be performed.
   - **No data:** If all queries failed, tell the user Observe appears degraded. Do not report "all clear" when you have no data.

### Monitor Query
1. Query monitor status using `generate-query-card` with the monitor names/IDs from `platform-extended.md`
2. Filter by severity if specified (SEV2, SEV3)
3. Present: monitor name, status, last triggered, affected entity
4. If query fails: tell the user which monitors could not be checked. Suggest checking #ext-relationalai-observe if Observe appears degraded.

### Ad-Hoc Query
1. Use `generate-query-card` with the user's natural language query
2. Follow query workflow from SKILL.md (retry strategies and failure handling)
3. If query succeeds: present results with Observe links (only include links where query returned data). Summarize — do not dump raw data.
4. If query fails after retry: tell the user what you tried and that it failed. Suggest rephrasing or checking #ext-relationalai-observe if Observe appears degraded.

## Rules

- Follow result presentation rules from SKILL.md.
- If Observe MCP tools are unavailable or return errors, follow degradation guidance in SKILL.md.
