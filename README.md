# Shipwright Marketplace

RAI's curated Claude Code plugin marketplace.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| **dockyard** | Standalone skills and commands -- codebase analysis, systematic debugging, doc digest, and more |
| **shipwright** | Orchestrated multi-agent workflows -- triage, implement, review, validate (requires dockyard) |

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

> **Note:** The shipwright plugin depends on dockyard. Install dockyard first.

## Team Setup

To pre-configure the marketplace for your team, add it to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    "https://github.com/RelationalAI/shipwright"
  ]
}
```

Team members can then install plugins directly without the marketplace-add step.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add skills, agents, and commands.

## Attribution

Shipwright builds on the work of:

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent -- TDD, verification, systematic debugging, and anti-rationalization skills. Licensed under Apache 2.0.
- **[GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done)** by gsd-build -- Decision categorization and brownfield codebase analysis patterns.

## License

[TBD]
