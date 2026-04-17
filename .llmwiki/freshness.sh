#!/usr/bin/env bash
# freshness.sh — report which wiki pages have become stale.
#
# A page is stale if any entry in its frontmatter `sources[]` has a `sha:` that no longer
# matches `git hash-object <path>` at HEAD. In other words, the code the page describes
# has changed since the page was last generated.
#
# Usage:
#   bash .llmwiki/freshness.sh               # text report
#   bash .llmwiki/freshness.sh --json        # machine-readable
#   bash .llmwiki/freshness.sh --stale-only  # only stale page paths (one per line)

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

MODE="text"
case "${1:-}" in
  --json)        MODE="json" ;;
  --stale-only)  MODE="stale" ;;
esac

stale_pages=()
ok_pages=0
ungrounded=()

# Iterate every .md file under wiki/ (skip index.md and log.md — they have no sources[])
while IFS= read -r -d '' page; do
  case "$page" in
    wiki/index.md|wiki/log.md) continue ;;
  esac

  # Extract YAML frontmatter (between the first two --- lines)
  fm=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$page")
  if [ -z "$fm" ]; then
    continue
  fi

  # Skip meta pages (overview, glossary, example, etc.) — they don't cite code so staleness
  # doesn't apply and an empty sources[] list should not be flagged as ungrounded.
  if printf '%s\n' "$fm" | grep -qE '^type:[[:space:]]*meta([[:space:]]|$)'; then
    continue
  fi

  # Parse sources[] entries. Expect lines like:
  #   sources:
  #     - path: src/foo.ts
  #       sha: abc123...
  #       lines: 1-50
  # We don't require yq — simple awk state machine is enough.
  # Using a while-read loop instead of `mapfile` so this works on macOS default bash 3.2.
  entries=()
  while IFS= read -r line; do
    [ -n "$line" ] && entries+=("$line")
  done < <(
    printf '%s\n' "$fm" | awk '
      /^sources:/ { in_sources = 1; next }
      in_sources && /^[^[:space:]]/ { in_sources = 0 }
      in_sources && /^[[:space:]]*-[[:space:]]*path:/ {
        if (path != "") print path "\t" sha
        path = $0; sub(/^[[:space:]]*-[[:space:]]*path:[[:space:]]*/, "", path); sha = ""
      }
      in_sources && /^[[:space:]]+sha:/ {
        sha = $0; sub(/^[[:space:]]+sha:[[:space:]]*/, "", sha)
      }
      END { if (path != "") print path "\t" sha }
    '
  )

  if [ "${#entries[@]}" -eq 0 ]; then
    ungrounded+=("$page")
    continue
  fi

  page_stale=0
  stale_reasons=()
  for entry in "${entries[@]}"; do
    path=${entry%%$'\t'*}
    recorded_sha=${entry##*$'\t'}
    path=$(echo "$path" | tr -d '"' | tr -d "'")
    recorded_sha=$(echo "$recorded_sha" | tr -d '"' | tr -d "'")

    if [ ! -f "$path" ]; then
      page_stale=1
      stale_reasons+=("$path: file missing at HEAD")
      continue
    fi

    current_sha=$(git hash-object "$path")
    if [ "$current_sha" != "$recorded_sha" ]; then
      page_stale=1
      stale_reasons+=("$path: sha changed (${recorded_sha:0:8} -> ${current_sha:0:8})")
    fi
  done

  if [ "$page_stale" = "1" ]; then
    reasons_joined=$(printf '%s\n' "${stale_reasons[@]}" | paste -sd ';' -)
    stale_pages+=("$page	$reasons_joined")
  else
    ok_pages=$((ok_pages + 1))
  fi
done < <(find wiki -type f -name '*.md' -print0)

case "$MODE" in
  json)
    printf '{\n  "ok": %d,\n  "stale": [\n' "$ok_pages"
    first=1
    for line in "${stale_pages[@]:-}"; do
      [ -z "$line" ] && continue
      page=${line%%$'\t'*}; reasons=${line##*$'\t'}
      if [ "$first" = "0" ]; then printf ',\n'; fi
      printf '    {"page": "%s", "reasons": "%s"}' "$page" "$reasons"
      first=0
    done
    printf '\n  ],\n  "ungrounded": [\n'
    first=1
    for p in "${ungrounded[@]:-}"; do
      [ -z "$p" ] && continue
      if [ "$first" = "0" ]; then printf ',\n'; fi
      printf '    "%s"' "$p"
      first=0
    done
    printf '\n  ]\n}\n'
    ;;
  stale)
    for line in "${stale_pages[@]:-}"; do
      [ -z "$line" ] && continue
      echo "${line%%$'\t'*}"
    done
    ;;
  *)
    echo "Freshness report"
    echo "================"
    echo "Up-to-date pages : $ok_pages"
    echo "Stale pages      : ${#stale_pages[@]}"
    echo "Ungrounded pages : ${#ungrounded[@]} (no sources[] frontmatter)"
    echo ""
    if [ "${#stale_pages[@]}" -gt 0 ]; then
      echo "Stale:"
      for line in "${stale_pages[@]}"; do
        page=${line%%$'\t'*}; reasons=${line##*$'\t'}
        echo "  $page"
        echo "    reasons: $reasons"
      done
      echo ""
    fi
    if [ "${#ungrounded[@]}" -gt 0 ]; then
      echo "Ungrounded (no sources cited — consider re-generating):"
      for p in "${ungrounded[@]}"; do echo "  $p"; done
      echo ""
    fi
    echo "To re-ingest stale pages, ask your AI agent:"
    echo "  \"Re-generate these pages using the current code:\" (paste the stale list)"
    ;;
esac
