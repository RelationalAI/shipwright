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

Load these files from the Dockyard plugin root:
1. **Always:** `skills/observability/SKILL.md`
2. **Always:** `skills/observability/knowledge/platform.md`
3. **Conditionally:** Load additional knowledge files ONLY when the query explicitly references that domain:
   - CDC / pipeline / batch / stream → also load `skills/observability/knowledge/data-pipeline.md`
   - Engine crash / OOM / brownout → also load `skills/observability/knowledge/engine-failures.md`
   - Architecture / services / cross-service → also load `skills/observability/knowledge/architecture.md`

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
4. Present results:
   - **All clear:** "No active alerts. Error rates nominal. Transaction success rate: X%." — Zero active alerts is a positive signal, not silence.
   - **Issues found:** Summarize alerts, error trends, affected services. Suggest `/investigate` for any specific issue.
   - **Partial data:** If some queries failed, report health based on available data and note which checks could not be performed.
   - **No data:** If all queries failed, tell the user Observe appears degraded. Do not report "all clear" when you have no data.

### Monitor Query
1. Query monitor status using `generate-query-card` with the monitor names/IDs from `platform.md`
2. Filter by severity if specified (SEV2, SEV3)
3. Present: monitor name, status, last triggered, affected entity

### Ad-Hoc Query
1. Use `generate-query-card` with the user's natural language query
2. Follow query workflow from SKILL.md (retry strategies and failure handling)
3. If query succeeds: present results with Observe links (only include links where query returned data). Summarize — do not dump raw data.
4. If query fails after retry: tell the user what you tried and that it failed. Suggest rephrasing or checking #ext-relationalai-observe if Observe appears degraded.

## Result Presentation

Follow result presentation rules from SKILL.md.

## MCP Degradation

If Observe MCP tools are unavailable or return errors, follow the degradation guidance in SKILL.md.
