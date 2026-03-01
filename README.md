# Shipwright Marketplace

RAI's curated Claude Code plugin marketplace.

## Plugins

| Plugin | Description | Commands |
|--------|-------------|----------|
| **dockyard** | Standalone skills & commands | `codebase-analyze`, `code-review`, `doc-digest`, `investigate`, `review-and-submit`, `feedback` |
| **shipwright** | Orchestrated bug-fix workflows (requires dockyard) | `shipwright`, `feedback` |

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
