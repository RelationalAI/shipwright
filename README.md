# Shipwright

An adaptive agentic development framework for RAI engineering teams.

**Status:** Design complete. 3 open questions punted for team discussion.

## What it does

- Right-sizes process to the task (3 tiers: Quick Fix, Standard, Full Ceremony)
- Enforces engineering discipline (TDD, verification, systematic debugging as hard gates)
- Survives context loss (4-layer recovery system)
- Produces docs humans actually read (human-primary, AI supplements derived)
- Tracks costs transparently (token usage + configurable heuristic)

## Design docs

- [Design doc](docs/plans/shipwright-design-v1.md) — the full design (12 sections, 38 decisions)
- [Comparison](docs/plans/shipwright-vs-others-v1.md) — how Shipwright compares to Superpowers, GSD, and Beads
- [Ideas from Beads/GSD](docs/plans/shipwright-ideas-from-beads-gsd-v1.md) — 14 ideas reviewed, 8 adopted

## Lineage

Combines ideas from [Superpowers](https://github.com/anthropics/superpowers), [GSD](https://github.com/gsd-build/get-shit-done), and [Beads](https://github.com/steveyegge/beads), with RAI-specific requirements layered in.

## Platform

Claude Code (designed for future portability). Distributed via RAI plugin marketplace.
