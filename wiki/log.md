---
title: Log
type: meta
updated: 1970-01-01
---

# Log

Append-only chronological record. Every ingest, lint, and query gets a dated entry.

Entries start with `## [YYYY-MM-DD HH:MM] <op> | <commit-sha> | <one-line summary>` so they are grep-parseable:

```bash
grep "^## \[" wiki/log.md | tail -10
```

---

_No entries yet. The first `git commit` will trigger the ingest hook and the first entry will appear here._
