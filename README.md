# Shipwright Marketplace

RAI's curated Claude Code plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| **dockyard** | Standalone skills & commands |
| **shipwright** | Orchestrated bug-fix workflows (requires dockyard) |

## Dockyard

Standalone tools that work without orchestration.

### Commands

| Command | Description |
|---------|-------------|
| [`/dockyard:codebase-analyze`](plugins/dockyard/commands/codebase-analyze.md) | Produces 7 focused profile documents covering your stack, architecture, integrations, conventions, and testing patterns. Run it once and every future Claude session deeply understands your project. Supports optional focus areas for extra depth on specific topics. |
| [`/dockyard:code-review`](plugins/dockyard/commands/code-review.md) | Runs a structured 3-pass review — correctness bugs, convention compliance, and test quality — with independent confidence scoring that drops findings below 80%. Presents a human-readable table by default; pass `--json` for machine-readable output in CI pipelines. |
| [`/dockyard:doc-digest`](plugins/dockyard/commands/doc-digest.md) | Walks you through any document section-by-section for interactive review. Instead of reading a wall of text, you get a guided conversation where you can ask questions, give feedback, and build understanding incrementally. |
| [`/dockyard:feedback`](plugins/dockyard/commands/feedback.md) | File bug reports, feature requests, or suggestions against the Dockyard plugin directly from your Claude session. Auto-detects issue type, drafts a formatted GitHub issue, and creates it after your confirmation. |
| [`/dockyard:investigate`](plugins/dockyard/commands/investigate.md) | Stateful two-stage incident investigation. Give it a JIRA ticket, transaction ID, or symptom description and it runs parallel observability queries, classifies the issue, and produces a triage card — resolving 50-80% of issues in Stage 1 alone. Stage 2 runs deeper analysis in the background while you stay interactive. |
| [`/dockyard:observe`](plugins/dockyard/commands/observe.md) | Quick, stateless queries against the Observe platform. Check production health, view active alerts, or run ad-hoc metric queries in natural language. Suggests `/investigate` when you need to go deeper. |
| [`/dockyard:pair-review`](plugins/dockyard/commands/pair-review.md) | Collaborative PR review — Claude helps the human reviewer understand changes and submit a formal review. Fetches PR metadata, presents a concise overview, offers flexible diff exploration, and helps compose the review via `gh` CLI. |
| [`/dockyard:review-and-submit`](plugins/dockyard/commands/review-and-submit.md) | End-to-end flow from "done coding" to "draft PR ready." Runs a full code review, lets you pick which findings to auto-fix, generates a proportional PR description, and creates a draft PR — all context-efficient via sub-agents so it works even in long sessions. |

### Skills

| Skill | Description |
|-------|-------------|
| [`brownfield-analysis`](plugins/dockyard/skills/brownfield-analysis/SKILL.md) | Analyzes an existing codebase and produces 7 profile documents covering stack, architecture, integrations, structure, conventions, testing, and concerns. Profiles auto-refresh incrementally (fast-path for <10 commits, full rewrite at 10+), so they stay current without manual re-runs. |
| [`observability`](plugins/dockyard/skills/observability/SKILL.md) | RAI observability domain knowledge — Observe datasets, correlation tags, triage signals, and MCP tool usage. Loaded automatically by `/investigate` and `/observe`; also answers standalone questions about what telemetry data is available. |

## Shipwright

Orchestrated bug-fix workflows. Requires dockyard.

### Commands

| Command | Description |
|---------|-------------|
| [`/shipwright:shipwright`](plugins/shipwright/commands/shipwright.md) | Orchestrated Tier 1 bug-fix pipeline. Hand it a bug description or JIRA ticket and it dispatches four specialized agents in sequence — Triage, Implement, Review, Validate — with recovery state so you can resume if interrupted. One challenge round between Reviewer and Implementer keeps quality high without infinite loops. |
| [`/shipwright:feedback`](plugins/shipwright/commands/feedback.md) | File bug reports, feature requests, or suggestions against the Shipwright plugin directly from your Claude session. Same workflow as dockyard feedback — auto-detects type, drafts a GitHub issue, creates it after confirmation. |

## Installation

```bash
# 1. Add the marketplace (one-time)
/plugin marketplace add https://github.com/RelationalAI/shipwright

# 2. Install dockyard (standalone skills and commands)
/plugin install dockyard@shipwright-marketplace

# 3. (Optional) Install shipwright (orchestrated workflows -- requires dockyard)
/plugin install shipwright@shipwright-marketplace

# 4. Restart your Claude session to activate
```

## Team Setup

Add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    "https://github.com/RelationalAI/shipwright"
  ]
}
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Attribution

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent -- TDD, verification, systematic debugging, anti-rationalization skills. Apache 2.0.
- **[GSD](https://github.com/gsd-build/get-shit-done)** by gsd-build -- Decision categorization and brownfield analysis patterns.
