---
name: observability
description: >
  RAI observability domain knowledge — Observe datasets, correlation tags, triage signals, and MCP tool usage.
  Shared library loaded by /investigate and /observe commands — do not invoke directly. When the user asks
  about observability data, dashboards, or metrics, suggest /observe. For incident investigation, suggest
  /investigate.
---

# Observability

---

## Reference Data

Dataset definitions (IDs, key fields, join paths), metrics, monitors, dashboards, environments, services, and ERP error codes are in `knowledge/platform.md` (always loaded by commands).

---

## Tools

### generate-query-card (Primary)
- Accepts natural language. Returns data + Observe links.
- Auto-fetches knowledge graph context — do NOT call `generate-knowledge-graph-context` before querying.
- Use specific anchor values (transaction IDs, engine names) in queries.
- Always request bounded results — include "top 10", "top 20", or "limit N" in aggregation prompts.
- Prefer aggregated over raw — ask for counts, groupings, summaries rather than raw log lines.

### generate-knowledge-graph-context (Exploration only)
- Use ONLY when exploring what data exists, not for actual queries.
- Parameters: `kind` (one of `"correlation tag"`, `"dataset"`, `"metric"`), `prompt` (natural language search).

## Query Workflow

1. Identify anchors (transaction ID, engine name, account, time range)
2. Run up to 5 parallel queries using `generate-query-card`
3. Analyze results before running more queries
4. Use retry strategies if no data: rephrase → broaden time range → try different dataset → fall back to `generate-knowledge-graph-context` to discover valid names

### Query Failure Handling

When a `generate-query-card` call returns no result, an error, or empty data:

1. **Tell the user** when a query still fails after retry strategies (step 4 above). Do not silently skip the failed query. State:
   - Which query failed (e.g., "Error logs query for engine X returned no results")
   - What data is now missing (e.g., "I don't have error log data for the incident window")
   - Impact on the analysis (e.g., "I cannot confirm whether a segfault occurred — my crash assessment may be incomplete")
2. **Proceed with available data.** Do not block on a failed query — use results from other parallel queries that succeeded.
3. **If ALL queries fail or return no results**, tell the user Observe may be degraded and suggest checking `#ext-relationalai-observe`. Do not attempt to analyze without data.

### Result Presentation
- Include Observe links from `generate-query-card` only when the query returned errors, failures, or anomalies — omit links to clean/empty results. Do not construct URLs manually.
- Convert nanosecond durations to human-readable
- Distinguish "all clear" (no errors, system healthy) from "no data available" (possible data gap)
- Summarize results — do not dump raw query output

## MCP Degradation

### Observe MCP unavailable
1. Direct to setup: https://171608476159.observeinc.com/settings/mcp
2. If no access: whitelist via #ext-relationalai-observe (post :ticket: emoji)

### Observe MCP degraded (partial failures)
When some queries succeed but others fail:
1. Inform the user which queries failed and what data is missing
2. Proceed with available results, noting any gaps in your analysis
3. If the missing data is critical to the classification or root cause, say so explicitly

### Observe MCP degraded (all queries fail)
When all `generate-query-card` calls fail:
1. Tell the user: "Observe appears to be degraded — all queries failed. I cannot proceed with data-driven analysis."
2. Suggest checking `#ext-relationalai-observe` for platform status
3. Run `/dockyard:feedback` to report the issue
4. Do NOT guess or speculate without data

### Atlassian MCP unavailable
1. Direct to: https://www.atlassian.com/solutions/ai/mcp
