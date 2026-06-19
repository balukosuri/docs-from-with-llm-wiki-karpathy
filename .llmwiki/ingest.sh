#!/usr/bin/env bash
# ingest.sh — the actual ingest worker. Runs in the background from the post-commit hook,
# or manually with:   bash .llmwiki/ingest.sh [--force] [--dry-run]
#
# Flags:
#   --force     ingest even if HEAD matches last-ingested-sha, and override max_diff_lines
#   --dry-run   build the prompt file but do NOT call the AI and do NOT commit. Inspect
#               the prompt at .llmwiki/state/ingest-prompt.md to see exactly what would
#               have been sent. Useful for debugging and for privacy review on sensitive
#               repos before enabling the hook for real.
#
# What it does (non-dry-run):
#   1. Holds a mkdir-based lock so overlapping commits queue safely
#   2. Diffs <last-ingested-sha>..HEAD (or HEAD~1..HEAD on first run)
#   3. Pipes the prompt template + diff into the configured AI CLI in headless mode
#   4. The CLI reads CLAUDE.md + config.yml, updates wiki/ pages, saves the files
#   5. We commit wiki/ as a follow-up commit with message "wiki: update (<sha>)"
#
# Supported CLIs and their headless invocation:
#   claude  → claude -p --allowedTools ... < prompt
#   codex   → codex exec --sandbox workspace-write < prompt  (stdin via "-")
#   agent   → agent -p --force < prompt                      (Cursor CLI)

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

STATE_DIR=".llmwiki/state"
LOCK="$STATE_DIR/ingest.lock"
LAST_SHA_FILE="$STATE_DIR/last-ingested-sha"
mkdir -p "$STATE_DIR"

# Prevent overlapping runs (uses mkdir which is atomic on all POSIX systems,
# including macOS where flock is not available).
_cleanup_lock() { rmdir "$LOCK" 2>/dev/null || true; }
trap _cleanup_lock EXIT

while ! mkdir "$LOCK" 2>/dev/null; do
  echo "[$(date '+%F %T')] ingest already running, waiting..."
  sleep 1
done

FORCE=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --force)   FORCE=1 ;;
    --dry-run) DRY=1 ;;
    *) echo "[$(date '+%F %T')] unknown flag: $arg (accepted: --force, --dry-run)"; exit 2 ;;
  esac
done

HEAD_SHA=$(git rev-parse HEAD)
HEAD_SHORT=$(git rev-parse --short HEAD)
SUBJECT=$(git log -1 --pretty=%s)

# Bail if HEAD is a wiki update commit we made ourselves
case "$SUBJECT" in
  "wiki: update"*)
    echo "[$(date '+%F %T')] $HEAD_SHORT is our own wiki commit — skipping"
    exit 0
    ;;
esac

# Establish the baseline commit to diff from
if [ -s "$LAST_SHA_FILE" ]; then
  LAST=$(cat "$LAST_SHA_FILE")
else
  # First run: diff against the empty tree so the ingest covers the entire repo
  LAST=$(git hash-object -t tree /dev/null)
fi

if [ "$LAST" = "$HEAD_SHA" ] && [ "$FORCE" = "0" ]; then
  echo "[$(date '+%F %T')] nothing to ingest (already at $HEAD_SHORT)"
  exit 0
fi

# Compute the diff, excluding wiki/ and .llmwiki/ (we never document ourselves)
DIFF_FILES=$(git diff --name-status "$LAST" "$HEAD_SHA" -- . ':!wiki' ':!.llmwiki' || true)
if [ -z "$DIFF_FILES" ]; then
  echo "[$(date '+%F %T')] no tracked code changed between $LAST and $HEAD_SHORT"
  echo "$HEAD_SHA" > "$LAST_SHA_FILE"
  exit 0
fi

# Read a top-level scalar from config.yml. Handles quotes, single-line comments, and whitespace.
# Usage: yaml_get <key> <default>     (only supports unindented top-level keys and scalar values)
yaml_get() {
  local key=$1 default=$2 val
  val=$(awk -v k="$key" '
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      sub("[[:space:]]*#.*$", "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      gsub(/^["\x27]|["\x27]$/, "")
      print; exit
    }' .llmwiki/config.yml)
  [ -n "$val" ] && echo "$val" || echo "$default"
}

yaml_get_nested() {
  # Reads `parent:` then an indented `  child:` scalar value. Used for hook.max_diff_lines.
  local parent=$1 child=$2 default=$3 val
  val=$(awk -v p="$parent" -v c="$child" '
    $0 ~ "^"p":" { in_block=1; next }
    in_block && /^[^[:space:]]/ { in_block=0 }
    in_block && $0 ~ "^[[:space:]]+"c":" {
      sub("^[[:space:]]+"c":[[:space:]]*", "")
      sub("[[:space:]]*#.*$", "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      gsub(/^["\x27]|["\x27]$/, "")
      print; exit
    }' .llmwiki/config.yml)
  [ -n "$val" ] && echo "$val" || echo "$default"
}

# Size guard — skip if the diff is huge (prevents runaway costs on big refactors).
# max_diff_lines lives under `hook:` in config.yml; fall back to the top-level form for
# backward compatibility, then to a 2000-line default.
MAX_LINES=$(yaml_get_nested hook max_diff_lines "")
[ -z "$MAX_LINES" ] && MAX_LINES=$(yaml_get max_diff_lines 2000)
case "$MAX_LINES" in
  ''|*[!0-9]*) MAX_LINES=2000 ;;
esac
DIFF_LINES=$(git diff --unified=0 "$LAST" "$HEAD_SHA" -- . ':!wiki' ':!.llmwiki' | wc -l | tr -d ' ')
if [ "$DIFF_LINES" -gt "$MAX_LINES" ] && [ "$FORCE" = "0" ]; then
  echo "[$(date '+%F %T')] diff is $DIFF_LINES lines (> $MAX_LINES). Skipping. Re-run with:  bash .llmwiki/ingest.sh --force"
  exit 0
fi

# Read the configured CLI (handles quotes, trailing comments, whitespace).
CLI=$(yaml_get cli claude)

if ! command -v "$CLI" >/dev/null 2>&1; then
  echo "[$(date '+%F %T')] configured CLI '$CLI' is not on PATH. Install it or edit .llmwiki/config.yml. Skipping."
  exit 0
fi

echo "[$(date '+%F %T')] ingesting $HEAD_SHORT ($SUBJECT)"
echo "[$(date '+%F %T')] diff: $(echo "$DIFF_FILES" | wc -l | tr -d ' ') files, $DIFF_LINES lines"

PROMPT_FILE=".llmwiki/prompts/ingest.md"
if [ ! -f "$PROMPT_FILE" ]; then
  echo "[$(date '+%F %T')] missing $PROMPT_FILE — aborting"
  exit 1
fi

# Build the prompt: template + structured diff payload
{
  cat "$PROMPT_FILE"
  echo ""
  echo "## Commit"
  echo "- sha: $HEAD_SHA"
  echo "- short: $HEAD_SHORT"
  echo "- subject: $SUBJECT"
  echo "- author: $(git log -1 --pretty='%an <%ae>')"
  echo "- date: $(git log -1 --pretty='%ad' --date=iso-strict)"
  echo ""
  echo "## Changed files"
  echo '```'
  echo "$DIFF_FILES"
  echo '```'
  echo ""
  echo "## Full diff"
  echo '```diff'
  git diff "$LAST" "$HEAD_SHA" -- . ':!wiki' ':!.llmwiki'
  echo '```'
} > "$STATE_DIR/ingest-prompt.md"

# Build the CLI invocation command based on which CLI is configured.
# Each CLI has different flags for headless mode, permissions, and model selection.
MODEL=$(yaml_get_nested hook model "")

if [ "$DRY" = "1" ]; then
  PROMPT_BYTES=$(wc -c < "$STATE_DIR/ingest-prompt.md" | tr -d ' ')
  echo "[$(date '+%F %T')] dry-run: prompt built at $STATE_DIR/ingest-prompt.md ($PROMPT_BYTES bytes)"
  echo "[$(date '+%F %T')] dry-run: would invoke $CLI (model: ${MODEL:-default}) with prompt from $STATE_DIR/ingest-prompt.md"
  echo "[$(date '+%F %T')] dry-run: NO network call made, NO wiki commit produced"
  echo "[$(date '+%F %T')] inspect with: cat $STATE_DIR/ingest-prompt.md"
  exit 0
fi

# Invoke the CLI in headless mode. Environment variable lets the hook recognise its own work.
export LLMWIKI_INGEST_IN_PROGRESS=1

run_cli() {
  local prompt_file="$1" log_file="$2"
  case "$CLI" in
    claude)
      local model_flag=""
      [ -n "$MODEL" ] && model_flag="--model $MODEL"
      # shellcheck disable=SC2086
      "$CLI" -p $model_flag --allowedTools Edit,Write,Read,Glob,Grep,Bash \
        < "$prompt_file" > "$log_file" 2>&1
      ;;
    codex)
      local model_flag=""
      [ -n "$MODEL" ] && model_flag="--model $MODEL"
      # codex exec reads stdin when "-" is the prompt argument
      # shellcheck disable=SC2086
      "$CLI" exec $model_flag --sandbox workspace-write - \
        < "$prompt_file" > "$log_file" 2>&1
      ;;
    agent)
      local model_flag=""
      [ -n "$MODEL" ] && model_flag="--model $MODEL"
      # Cursor CLI takes the prompt as a positional argument, not stdin
      # shellcheck disable=SC2086
      "$CLI" -p --force $model_flag "$(cat "$prompt_file")" \
        > "$log_file" 2>&1
      ;;
    *)
      echo "[$(date '+%F %T')] unsupported CLI: $CLI" >&2
      return 1
      ;;
  esac
}

if ! run_cli "$STATE_DIR/ingest-prompt.md" "$STATE_DIR/ingest-output.log"; then
  echo "[$(date '+%F %T')] $CLI exited non-zero. Output:"
  tail -n 50 "$STATE_DIR/ingest-output.log" || true
  echo "[$(date '+%F %T')] ingest failed — wiki NOT updated. Re-run manually:  bash .llmwiki/ingest.sh --force"
  exit 1
fi

# Commit the wiki if anything changed
if git diff --quiet wiki/ && git diff --cached --quiet wiki/; then
  echo "[$(date '+%F %T')] CLI ran but no wiki changes produced"
else
  git add wiki/
  # Skip hooks on our own commit to avoid recursion. The env var is a second line of defence.
  git -c core.hooksPath=/dev/null commit -m "wiki: update ($HEAD_SHORT)" -m "Ingested commit $HEAD_SHA: $SUBJECT"
  echo "[$(date '+%F %T')] wiki committed"
fi

echo "$HEAD_SHA" > "$LAST_SHA_FILE"
echo "[$(date '+%F %T')] done"
