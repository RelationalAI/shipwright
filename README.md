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
| [`/dockyard:codebase-analyze`](plugins/dockyard/commands/codebase-analyze.md) | TODO |
| [`/dockyard:code-review`](plugins/dockyard/commands/code-review.md) | TODO |
| [`/dockyard:doc-digest`](plugins/dockyard/commands/doc-digest.md) | TODO |
| [`/dockyard:feedback`](plugins/dockyard/commands/feedback.md) | TODO |
| [`/dockyard:investigate`](plugins/dockyard/commands/investigate.md) | TODO |
| [`/dockyard:observe`](plugins/dockyard/commands/observe.md) | TODO |
| [`/dockyard:review-and-submit`](plugins/dockyard/commands/review-and-submit.md) | TODO |

### Skills

| Skill | Description |
|-------|-------------|
| [`brownfield-analysis`](plugins/dockyard/skills/brownfield-analysis/SKILL.md) | TODO |
| [`code-review`](plugins/dockyard/skills/code-review/SKILL.md) | TODO |
| [`observability`](plugins/dockyard/skills/observability/SKILL.md) | TODO |
| [`review-and-submit`](plugins/dockyard/skills/review-and-submit/SKILL.md) | TODO |

## Shipwright

Orchestrated bug-fix workflows. Requires dockyard.

### Commands

| Command | Description |
|---------|-------------|
| [`/shipwright:shipwright`](plugins/shipwright/commands/shipwright.md) | TODO |
| [`/shipwright:feedback`](plugins/shipwright/commands/feedback.md) | TODO |

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
