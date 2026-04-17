#!/usr/bin/env bash
# Install the docs-from-code-with-llm-wiki post-commit hook.
#
# Usage:   bash .llmwiki/install-hook.sh
#
# What it does:
#   1. Verifies this is a git repo
#   2. Backs up any existing .git/hooks/post-commit
#   3. Symlinks .git/hooks/post-commit -> .llmwiki/post-commit
#   4. Makes the hook scripts executable
#   5. Checks the configured CLI is on PATH and warns if not

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
  echo "error: not inside a git repository. Run 'git init' first." >&2
  exit 1
fi
cd "$REPO_ROOT"

if [ ! -f .llmwiki/config.yml ]; then
  echo "error: .llmwiki/config.yml is missing. Is this the docs-from-code-with-llm-wiki template?" >&2
  exit 1
fi

# Make scripts executable
chmod +x .llmwiki/post-commit .llmwiki/ingest.sh .llmwiki/freshness.sh

# Seed the per-machine Obsidian workspace from the committed template, if not already present.
# Obsidian mutates .obsidian/workspace.json on every open; we gitignore the real file and
# ship workspace-template.json so clones get a sensible starting layout without churn.
if [ -f .obsidian/workspace-template.json ] && [ ! -f .obsidian/workspace.json ]; then
  cp .obsidian/workspace-template.json .obsidian/workspace.json
  echo "seeded: .obsidian/workspace.json (from workspace-template.json)"
fi

HOOK_PATH=".git/hooks/post-commit"
TARGET="../../.llmwiki/post-commit"

if [ -e "$HOOK_PATH" ] && [ ! -L "$HOOK_PATH" ]; then
  BACKUP="${HOOK_PATH}.backup.$(date +%s)"
  echo "note: existing $HOOK_PATH found. Moving to $BACKUP"
  mv "$HOOK_PATH" "$BACKUP"
fi

mkdir -p .git/hooks
ln -sf "$TARGET" "$HOOK_PATH"
echo "installed: $HOOK_PATH -> $TARGET"

# Verify configured CLI is on PATH (robust YAML scalar read; ignores quotes and trailing comments)
CLI=$(awk '
  /^cli:/ {
    sub(/^cli:[[:space:]]*/, "")
    sub(/[[:space:]]*#.*$/, "")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    gsub(/^["\x27]|["\x27]$/, "")
    print; exit
  }' .llmwiki/config.yml)
CLI=${CLI:-claude}
if ! command -v "$CLI" >/dev/null 2>&1; then
  echo ""
  echo "warning: configured CLI '$CLI' is not on PATH."
  echo "         The hook will log a skip message until you install it."
  echo "         Install one of:"
  echo "           - Claude Code CLI:  https://docs.claude.com/claude-code"
  echo "           - Cursor CLI:       https://docs.cursor.com/cli"
  echo "           - Codex CLI:        https://github.com/openai/codex"
  echo "         Or change 'cli:' in .llmwiki/config.yml to one you have installed."
fi

echo ""
echo "Done. Make a commit and the wiki will update in the background."
echo "Check progress with: tail -f .llmwiki/state/ingest.log"
