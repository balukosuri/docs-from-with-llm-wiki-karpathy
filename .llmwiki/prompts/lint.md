# Lint prompt — health-check the wiki

You are the docs-from-code-with-llm-wiki linter. The developer asked you to review the current state
of the wiki. Do not ingest new code. Do not update pages unless the developer confirms
each fix.

## Steps

1. Read `CLAUDE.md` and `.llmwiki/config.yml`.
2. Run the freshness report:

   ```bash
   bash .llmwiki/freshness.sh --json
   ```

   This gives you the stale and ungrounded pages.

3. Walk `wiki/**/*.md` yourself and additionally check for:
   - **Orphan pages** — no inbound `[[wiki-link]]` from any other page.
   - **Stale `TODO-VERIFY` blocks** — blocks older than 30 days that are still unresolved.
   - **Unresolved `CONTRADICTION` blocks** — ever flagged, never cleaned up.
   - **Ungrounded claims** — paragraphs without a `(path:line-line)` citation nearby.
   - **Glossary gaps** — public identifiers that appear in `wiki/api/` or `wiki/architecture/`
     but not in `wiki/glossary.md`.
   - **Broken internal links** — `[[page]]` references where `page.md` does not exist.
   - **Terminology drift** — the same concept spelled two different ways across pages.

## Output

Produce a report in this shape:

```
# Lint report — YYYY-MM-DD

## Stale pages (from freshness.sh)
- wiki/architecture/auth.md — src/auth/login.ts sha changed
- ...

## Orphan pages
- ...

## Unresolved TODO-VERIFY / CONTRADICTION blocks
- ...

## Ungrounded claims
- ...

## Glossary gaps
- ...

## Broken [[links]]
- ...

## Terminology drift
- ...

## Proposed fixes
1. Re-ingest these pages: ...
2. Delete these orphans: ...
3. Rename these terms: ...
```

Then ask the developer: "Which fixes should I apply?" Apply only confirmed fixes.
Append a `## [YYYY-MM-DD HH:MM] lint | summary` entry to `wiki/log.md`.
