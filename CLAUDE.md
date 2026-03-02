# CLAUDE.md

This is **shipwright-marketplace** — RAI's curated Claude Code plugin marketplace.

## Structure

```
plugins/
├── dockyard/       ← standalone skills, commands, agents
└── shipwright/     ← orchestrated workflows (depends on dockyard)
```

- Marketplace registry: `.claude-plugin/marketplace.json`
- Plugin manifests: `plugins/<name>/.claude-plugin/plugin.json`
- Smoke tests: `plugins/dockyard/tests/smoke/` (validates both plugins)

## Plugins

**Dockyard** — standalone tools that work without orchestration:
- Skills in `plugins/dockyard/skills/`
- Commands in `plugins/dockyard/commands/`
- Agents in `plugins/dockyard/agents/`

**Shipwright** — orchestrated bug-fix pipeline (requires dockyard):
- Commands in `plugins/shipwright/commands/`
- Internal agents and skills in `plugins/shipwright/internal/`
- Dependency enforced via SessionStart hook (`plugins/shipwright/hooks/check-dockyard.sh`)

## Testing

```bash
bash plugins/dockyard/tests/smoke/run-all.sh
```

Runs 4 suites: structure, skills, agents, commands. Validates both plugins.

## Key Conventions

- Commands use YAML frontmatter with `description:` and optional `argument-hint:`
- Skills live in `skills/<name>/SKILL.md`
- Agents are markdown files in `agents/` (dockyard) or `internal/agents/` (shipwright)
- Cross-plugin skill references use `dockyard:<skill-name>` notation
- `${CLAUDE_PLUGIN_ROOT}` works in hooks.json but NOT in markdown files
- Bump `version` in plugin.json for users to receive updates (cache is keyed on version)
