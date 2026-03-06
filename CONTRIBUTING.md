# Contributing to Shipwright Marketplace

Shipwright Marketplace is RAI's curated Claude Code plugin marketplace. It hosts two plugins:

- **dockyard** -- standalone skills and commands (codebase analysis, debugging, doc digest, etc.)
- **shipwright** -- orchestrated workflows that compose dockyard skills into multi-agent pipelines (triage, implement, review, validate)

## Which Plugin Should I Contribute To?

| If your contribution is... | Add it to |
|---|---|
| A standalone skill or command (usable on its own) | `plugins/dockyard/` |
| An agent, workflow, or orchestration that composes skills | `plugins/shipwright/` |

## How to Contribute a Skill or Agent

1. **Fork and branch** from `main`.
2. **Add your skill** under the appropriate plugin directory following the required structure:
   - Skills: `plugins/<plugin>/skills/<skill-name>/SKILL.md`
   - Agents: `plugins/<plugin>/agents/<agent-name>.md`
   - Commands: `plugins/<plugin>/commands/<command-name>.md`
3. **Follow the templates** in `templates/SKILL_TEMPLATE.md` or `templates/AGENT_TEMPLATE.md`.
4. **Do not bump versions** — versions are managed centrally in `marketplace.json` and updated automatically by `release.sh`. CI will block PRs that include version changes.
5. **Open a PR** against `main`.

## Quality Gates

Every PR must pass:

- **Template compliance** -- skill/agent files follow the required format
- **Smoke test** -- the skill or agent can be invoked without errors
- **CODEOWNERS review** -- at least one approval from a designated code owner

## Requesting a New Plugin

New plugins require CODEOWNERS approval. To request one:

1. Open an issue describing the plugin's purpose and scope.
2. A code owner will review and, if approved, add the plugin entry to `marketplace.json`.

## Version Bumps

Claude Code caches installed plugins by version string. Versions live only in `marketplace.json` (not in `plugin.json`) and all plugins share the same version, bumped together.

**Do not bump versions in feature PRs** — CI will block them. To release, run `./scripts/release.sh <patch|minor|major>`, which bumps the version, updates `source.ref`, and creates a release PR.

Plugin sources in `marketplace.json` are pinned to release tags via `git-subdir`. The `source.ref` field is updated automatically by `release.sh` — do not change it manually.
