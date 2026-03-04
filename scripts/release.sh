#!/usr/bin/env bash
#
# release.sh — Bump the unified marketplace version and create a release PR.
#
# Usage:
#   ./scripts/release.sh <patch|minor|major>
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

# --- Validate arguments ---
bump_type="${1:-}"
if [[ ! "$bump_type" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: $0 <patch|minor|major>"
  exit 1
fi

# --- Ensure clean working tree ---
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# --- Ensure gh CLI is available ---
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI is required. Install it: https://cli.github.com"
  exit 1
fi

# --- Ensure jq is available ---
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install it: brew install jq"
  exit 1
fi

# --- Read current version from first plugin entry ---
current_version=$(jq -r '.plugins[0].version' "$MARKETPLACE")
if [[ -z "$current_version" || "$current_version" == "null" ]]; then
  echo "Error: Could not read version from $MARKETPLACE"
  exit 1
fi

# --- Compute new version ---
IFS='.' read -r major minor patch <<< "$current_version"
case "$bump_type" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac
new_version="$major.$minor.$patch"

echo "Bumping version: $current_version → $new_version"

# --- Update all plugin versions in marketplace.json ---
tmp=$(mktemp)
jq --arg v "$new_version" '.plugins |= map(.version = $v)' "$MARKETPLACE" > "$tmp"
mv "$tmp" "$MARKETPLACE"

# --- Create branch, commit, push, and open PR ---
branch="release/v$new_version"
git checkout -b "$branch"
git add "$MARKETPLACE"
git commit -m "release: v$new_version"
git push -u origin "$branch"

pr_url=$(gh pr create \
  --title "release: v$new_version" \
  --body "Bumps marketplace version from $current_version to $new_version.

Merging this PR will trigger a GitHub release with auto-generated notes." \
  --base main)

echo ""
echo "Release PR created: $pr_url"
echo "Merge it to trigger the v$new_version release."
