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
# Plugin smoke tests
bash plugins/dockyard/tests/smoke/run-all.sh

# Repo-level tests
bash tests/smoke/validate-readme.sh
```

Plugin smoke tests run 5 suites: structure, skills, agents, commands, doc-digest-consistency. Validates both plugins.

Repo-level tests validate the README catalog against actual plugin contents.

## Key Conventions

- Commands use YAML frontmatter with `description:` and optional `argument-hint:`
- Skills live in `skills/<name>/SKILL.md`
- Agents are markdown files in `agents/` (dockyard) or `internal/agents/` (shipwright)
- Cross-plugin references use `dockyard:<name>` notation (skills and agents)
- `${CLAUDE_PLUGIN_ROOT}` works in hooks.json but NOT in markdown files
- Version lives only in marketplace.json (not plugin.json)
- All plugin entries share the same version (bumped together)
- PRs should NOT include version bumps (CI will block them)
- To release: `./scripts/release.sh <patch|minor|major>` — creates a PR; merging it triggers a GitHub release
