# Docs From Code with LLM Wiki

> A self-maintaining wiki for your codebase. Commit code, the wiki commits itself.

This is a drop-in template inspired by [Andrej Karpathy's llm-wiki.md](./llm-wiki.md) and the companion article [*I used Karpathy's LLM Wiki to build a knowledge base that maintains itself with AI*](https://medium.com/). The original pattern ingests documents; this variant ingests **your own code** via a background git post-commit hook.

Every time you run `git commit`, a hook fires in the background, diffs the change, feeds it to the AI CLI of your choice, and the AI updates the wiki — new pages, updated signatures, refreshed glossary, appended log entry. A follow-up `wiki: update` commit lands a few seconds later. Your `git commit` returns instantly; you keep coding.

## Contents

- [What this is, and what it isn't](#what-this-is-and-what-it-isnt)
- [What you get](#what-you-get)
- [Install](#install) — [new project](#a-new-project-starting-from-scratch) / [existing project](#b-existing-project-adding-this-to-a-repo-you-already-have) / [verify](#verify-it-worked) / [Obsidian](#open-the-wiki-in-obsidian) / [team](#team-setup) / [Windows](#windows)
- [How it works](#how-it-works)
- [Configuring what gets documented](#configuring-what-gets-documented)
- [Hallucinations — how the template mitigates them](#hallucinations--how-the-template-mitigates-them)
- [Manual operations](#manual-operations)
- [Will it really start documenting on its own?](#will-it-really-start-documenting-on-its-own)
- [Where the docs live](#where-the-docs-live)
- [Viewing and querying the wiki](#viewing-and-querying-the-wiki)
- [Best practices](#best-practices)
- [Limitations](#limitations)
- [Common misinterpretations](#common-misinterpretations)
- [Privacy and security](#privacy-and-security)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

## What this is, and what it isn't

**What this is.** A small personal project that instantiates an idea Andrej Karpathy published as [llm-wiki.md](./llm-wiki.md) — using an AI agent to build and maintain a knowledge base. The original was document-centric; this variant points the same pattern at a code repository and triggers it from `git commit`.

**The problem it addresses.** The slow death of internal wikis and engineering knowledge bases. They start with good intent. They slide out of date because nobody has time to maintain them. They end up distrusted and then ignored. By moving the bookkeeping from human hands to a git hook, the wiki stays roughly current with the code — and that is most of what people actually wanted from a wiki in the first place.

**This is NOT a replacement for a technical writer.** A writer brings judgment, narrative, audience awareness, editorial voice, and the willingness to disagree with engineers. An LLM cannot do any of those. What this template produces is:

- a **draft** that a writer can polish, not a finished doc
- an **internal reference** for developers, not a published product manual
- a **bookkeeper** for the 80% of content that decays as code changes, freeing human writers for the 20% that actually needs voice

If you have a technical writer on your team, this tool helps them by giving them a living reference to work from. It does not replace them. If you do not have one, this tool gives you something your team can trust for internal use — but do not mistake it for customer-ready documentation without a human in the loop.

**Best fit.**
- Internal / developer-facing documentation
- CLI tools, libraries, and services where the public surface is readable from the code
- Solo developers and small teams without a dedicated docs function
- Teams that want a living, code-grounded reference alongside their human-authored product docs

**Poor fit (without a human editor).**
- Shipped end-user documentation where wording, brand voice, and UX clarity matter
- UI-heavy apps where behaviour depends on runtime data, CSS, and design choices the code does not narrate
- Compliance, legal, or safety-critical docs where every claim needs verification

Treat the output as a first draft. A reviewer (ideally a writer, ideally someone on your team) owns the last mile.

## What you get

- `llm-wiki.md` — [Andrej Karpathy's original idea document](./llm-wiki.md), copied verbatim for reference and attribution
- `CLAUDE.md` — an operating manual that keeps the AI grounded in the code at HEAD, with hard rules against hallucination (cite `path:line` or don't claim) and a draft-not-final self-concept
- `.llmwiki/config.yml` — one file to pick your CLI (Claude Code, Cursor, or Codex) and toggle doc categories (`architecture`, `api`, `user`, `decisions`, `concepts`, plus your own custom types)
- `.llmwiki/post-commit` + `ingest.sh` — the async background ingest worker (supports `--force` and `--dry-run`)
- `.llmwiki/freshness.sh` — a freshness check that compares stored source SHAs against the working tree and reports stale wiki pages
- `wiki/` — pre-seeded with `index.md`, `log.md`, `overview.md`, `glossary.md`, a `_example-page.md` demonstrating the expected format, and the category folders
- `.obsidian/` — a pre-tuned Obsidian vault (graph view colour-coded by doc type, sensible hotkeys, overview page opens on launch)

## Install

Pick the scenario that matches where you are.

### A. New project (starting from scratch)

Clone the template and code inside it. The one step people miss is detaching from the template's git history.

```bash
# 1. Clone the template under whatever name you want
git clone https://github.com/balukosuri/docs-from-code-with-llm-wiki.git my-new-project
cd my-new-project

# 2. Detach from the template's history and start your own
rm -rf .git
git init
git add .
git commit -m "initial commit (from docs-from-code-with-llm-wiki template)"

# 3. (Optional) Point it at your own GitHub repo
git remote add origin https://github.com/<you>/my-new-project.git
git push -u origin main

# 4. Pick your AI CLI and doc types
$EDITOR .llmwiki/config.yml
#    cli: claude | cursor-agent | codex
#    doc_types: { architecture: true, api: true, user: false, decisions: true, concepts: true }

# 5. Install the git hook
bash .llmwiki/install-hook.sh

# 6. Start coding. Every commit now auto-updates the wiki in the background.
```

### B. Existing project (adding this to a repo you already have)

You already have a project with its own git history. Drop in only the four scaffold things — no git-history surgery required.

```bash
cd /path/to/my-existing-project

# 1. Clone the template into a temp dir, then copy the scaffold files only
TMP=$(mktemp -d)
git clone https://github.com/balukosuri/docs-from-code-with-llm-wiki.git "$TMP/docs-from-code-with-llm-wiki"

cp -r "$TMP/docs-from-code-with-llm-wiki/.llmwiki"     .
cp -r "$TMP/docs-from-code-with-llm-wiki/wiki"         .
cp -r "$TMP/docs-from-code-with-llm-wiki/.obsidian"    .
cp    "$TMP/docs-from-code-with-llm-wiki/CLAUDE.md"    .
cp    "$TMP/docs-from-code-with-llm-wiki/llm-wiki.md"  .   # optional, for reference

# 2. Append the template's .gitignore rules to yours (do NOT overwrite)
cat "$TMP/docs-from-code-with-llm-wiki/.gitignore" >> .gitignore

rm -rf "$TMP"

# 3. Configure for YOUR project — make sure include: globs match your source layout
$EDITOR .llmwiki/config.yml
#    include: ["src/**", "app/**", "packages/**"]   ← edit for your repo
#    exclude: ["**/*.test.*", "dist/**", "vendor/**"]

# 4. Install the hook
bash .llmwiki/install-hook.sh

# 5. Commit the scaffold — this triggers the very first ingest
git add .llmwiki wiki .obsidian CLAUDE.md llm-wiki.md .gitignore
git commit -m "add docs-from-code-with-llm-wiki — self-maintaining wiki"

# 6. Watch the first pass over your codebase populate wiki/
tail -f .llmwiki/state/ingest.log
```

### Verify it worked

Three sanity checks after either path:

```bash
# The hook symlink should resolve to .llmwiki/post-commit
ls -la .git/hooks/post-commit

# Your chosen CLI should be on PATH
which claude   # or:  which cursor-agent  |  which codex

# Make a trivial commit and watch the ingest log
echo "// test" >> README.md && git add README.md && git commit -m "test ingest"
tail -n 20 .llmwiki/state/ingest.log
# A "wiki: update (<sha>)" commit should land a few seconds later:
git log --oneline -3
```

### Open the wiki in Obsidian

Either scenario:

1. Install Obsidian — `brew install --cask obsidian` on macOS, or download from [obsidian.md](https://obsidian.md).
2. **File → Open vault → Open folder as vault** — pick your project root (the folder that contains `wiki/` and `.obsidian/`).
3. `install-hook.sh` seeded `.obsidian/workspace.json` from the committed `workspace-template.json` on install. That starting layout opens `wiki/overview.md` by default and places backlinks + graph on the right. `Cmd+G` toggles graph view; graph nodes are colour-coded by doc type. Obsidian mutates `workspace.json` as you use it — those changes stay local (the file is gitignored; the template stays fixed).

### Team setup

Git hooks live under `.git/hooks/` which git **never pushes**, so each teammate activates the hook once after cloning. The install script also seeds a per-machine Obsidian workspace from the committed template:

```bash
git clone <team-repo> && cd <team-repo>
bash .llmwiki/install-hook.sh
# Installs the git hook AND copies .obsidian/workspace-template.json -> .obsidian/workspace.json
```

What IS committed and shared with the team:
- `.llmwiki/` (config, scripts, prompts) — the whole policy of the wiki
- `CLAUDE.md` — the schema
- `wiki/` — the wiki content itself, versioned alongside the code
- `.obsidian/workspace-template.json` — the starting vault layout (read-only on install)

What is NOT committed (already in `.gitignore`):
- `.llmwiki/state/` — local per-machine SHA cache and the ingest log
- `.obsidian/workspace.json` — Obsidian mutates this on every open; it's seeded locally per-clone from the template
- `.obsidian/cache`, `.obsidian/workspaces.json` — per-user Obsidian noise

One "wiki owner" on the team typically keeps an eye on the `wiki: update` commits in code review. Everyone else just commits code.

### Windows

The hook is bash. Run everything under **Git Bash** (ships with [Git for Windows](https://git-scm.com/download/win)) or **WSL**. Native `cmd`/PowerShell will not execute `.llmwiki/post-commit`. The template has not been tested on native Windows shells.

## How it works

```
┌──────────────────────┐
│ git commit (yours)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐     forks to background
│ .git/hooks/post-     │ ──────────────────────────┐
│ commit (symlink)     │                           │
└──────────┬───────────┘                           ▼
           │                               ┌──────────────────┐
      returns instantly                    │ ingest.sh        │
                                           │  - flock         │
                                           │  - diff last..HEAD
                                           │  - pipe prompt   │
                                           │    + diff → CLI  │
                                           │  - CLI edits     │
                                           │    wiki/ pages   │
                                           │  - commits wiki/ │
                                           └──────────────────┘
```

The CLI reads `CLAUDE.md` and `.llmwiki/config.yml` at the start of every ingest. That is where the behaviour is configured — not in the script.

## Configuring what gets documented

Open [.llmwiki/config.yml](.llmwiki/config.yml) and pick your lanes:

- **Internal docs only** — keep `architecture`, `concepts`, `decisions`. Turn off `user` and `api`. Good for services where the audience is your future self.
- **End-user docs** — turn on `user` and `api`, turn off `architecture` if you don't care about internals. Good for CLI tools and libraries.
- **Everything** — all flags on. Works well for products where you want both customer-facing and internal docs from one source.
- **Custom categories** — add entries under `custom_types:` (runbooks, schemas, migrations, anything). The AI picks them up on the next ingest via `CLAUDE.md`.

## Hallucinations — how the template mitigates them

Code is a tricky source. It narrates *what* happens but rarely *why*, and LLMs will happily fabricate behaviour to fill the gap. Two guardrails ship by default:

1. **Prompt discipline in `CLAUDE.md`.** Every non-trivial claim on a wiki page must be followed by a `(path:start-end)` citation. APIs that do not exist at HEAD cannot be described. Runtime behaviour that is not in the code gets a `> TODO-VERIFY:` blockquote instead of a confident paragraph. UI code has extra clamps — no behavioural claims about rendered output unless a test or snapshot confirms it.
2. **Freshness check.** Every wiki page stores the `git hash-object` SHA of the files it cites. Run `bash .llmwiki/freshness.sh` (or ask the AI to "lint the wiki") and you get a report of every page whose source code has changed since the page was generated. Those pages get re-ingested.

**Known weak spot:** UI-heavy code. Because rendered behaviour depends on CSS, JS, and data flow that is hard to read statically, the AI is more likely to hallucinate user-visible behaviour. CLI-based projects are the sweet spot. See the [companion article](./article.md) for a fuller discussion.

## Manual operations

```bash
# Ingest a specific commit range manually (useful after force-push or for first setup)
bash .llmwiki/ingest.sh --force

# Dry-run — build the prompt but DO NOT call the AI and DO NOT commit.
# Inspect the prompt at .llmwiki/state/ingest-prompt.md to see exactly what would be sent.
# Great for privacy review on sensitive repos before you enable the hook for real.
bash .llmwiki/ingest.sh --dry-run

# Check which wiki pages are stale
bash .llmwiki/freshness.sh                 # text report
bash .llmwiki/freshness.sh --stale-only    # one path per line, pipeable
bash .llmwiki/freshness.sh --json          # machine-readable

# Uninstall the hook
rm .git/hooks/post-commit
# (or restore your previous hook from .git/hooks/post-commit.backup.<timestamp>)
```

## Will it really start documenting on its own?

Yes, once three things are true:

1. The git hook is installed — `ls -la .git/hooks/post-commit` shows a symlink to `.llmwiki/post-commit`.
2. Your chosen AI CLI is on `PATH` and authenticated — `claude`, `cursor-agent`, or `codex` depending on `.llmwiki/config.yml`. Each has its own login flow; follow the one you picked. Without this, the hook logs a skip and does nothing.
3. You actually run `git commit` on code that matches the `include:` globs. Commits that only touch `wiki/` or `.llmwiki/` are skipped by design.

After that, the loop runs itself. You code, you commit, the wiki commits itself a few seconds later.

For a vibe coder the honest setup cost is: **one CLI install + one login + one `bash .llmwiki/install-hook.sh`.** After that you forget this exists.

---

## Where the docs live

**The wiki is stored inside your repo.** That is deliberate.

```
my-project/
├── src/                          ← your code
├── wiki/                         ← the generated wiki (tracked in git)
│   ├── index.md
│   ├── log.md
│   ├── overview.md
│   ├── glossary.md
│   ├── architecture/
│   ├── api/
│   └── ...
├── .llmwiki/                     ← config, scripts, prompts (tracked)
│   ├── config.yml
│   ├── post-commit
│   ├── ingest.sh
│   └── ...
├── .llmwiki/state/               ← local-only (NOT tracked)
│   ├── last-ingested-sha        ← last commit the hook processed
│   ├── ingest.log               ← running log of every ingest attempt
│   └── ingest.lock              ← flock file
└── .git/hooks/post-commit        ← symlink, NOT tracked (per-machine)
```

### Why in the repo?

- **Version history for free.** Every wiki update is a git commit with its own SHA. `git log wiki/api/login.md` tells you exactly how a page evolved.
- **Diffable.** Code review can cover the docs too. A PR that changes `src/auth/login.ts` will also touch `wiki/api/login.md` — reviewers see both sides.
- **Atomic with the code.** Checkout any commit and the wiki at that commit matches the code at that commit. You cannot drift.
- **Portable.** Clone the repo, get the wiki. No external storage, no separate database, no hosting.
- **No vendor lock-in.** It is plain markdown. You can read it with any editor forever.

### Where the private bits go

Only four things are machine-local and never pushed:
- `.llmwiki/state/last-ingested-sha` — your local cache of which commit was last processed
- `.llmwiki/state/ingest.log` — your local running log
- `.llmwiki/state/ingest.lock` — the flock file
- `.git/hooks/post-commit` — the hook symlink (git never pushes `.git/hooks/`)

This is why each teammate runs `install-hook.sh` once after cloning.

### Storage concerns and their answers

| Concern | Answer |
|---|---|
| Will the wiki bloat the repo? | No. Markdown is tiny. 500 wiki pages ≈ a few MB. Well below the noise of any real codebase. |
| I want docs in a different location / private when code is public | Two options: (a) put the wiki on a separate branch via `git worktree`, or (b) keep `wiki/` in a separate private repo and run the hook so it commits there. Either is a one-script change — ask the AI to adapt `ingest.sh`. |
| What about images / diagrams? | `.obsidian/app.json` points attachments at `wiki/assets/`. Anything you paste in gets stored there and committed alongside text. |
| Commit log gets noisy with `wiki: update` entries | True. Three options: (1) live with it — `git log --grep "^wiki:" --invert-grep` filters them out for code-history views; (2) squash `wiki: update` commits on merge; (3) put the wiki on a sibling branch. Most teams find option 1 is fine. |
| Can I push the wiki to a static site? | Yes. Point MkDocs, Docusaurus, or GitHub Pages at `wiki/` and you get a searchable HTML site for free. |

---

## Viewing and querying the wiki

Four ways to read it. Pick whichever fits the moment.

### 1. Obsidian (best for exploration)

The template ships with a pre-tuned `.obsidian/` vault. Install Obsidian (`brew install --cask obsidian` on macOS) and open your project folder as a vault.

What you get out of the box:
- `wiki/overview.md` opens on launch
- Backlinks panel and outline on the right
- Graph view on `Cmd+G` — colour-coded by doc type (architecture = blue, api = cyan, user = orange, decisions = red, concepts = grey, sources = green)
- Full-text search on `Cmd+Shift+F`
- Quick switcher on `Cmd+O` (fuzzy-find any page)
- `[[wiki-links]]` resolve across folders automatically

The graph view is the fastest way to see what's a hub, what's an orphan, and how subsystems connect.

### 2. Your IDE (best while coding)

Cursor, VS Code, and most IDEs render markdown inline. `Cmd+Shift+V` (or equivalent) shows a live preview. Open `wiki/api/login.md` next to `src/auth/login.ts` and the docs are always at hand while you code.

### 3. GitHub (best for teammates)

`wiki/*.md` files render as markdown on GitHub. Your whole team can read the docs in-browser without installing Obsidian. The landing URL `github.com/<you>/<repo>/blob/main/wiki/overview.md` is a decent home page. Pin it in your README.

### 4. Static site (best for publishing to non-developers)

Point MkDocs, Docusaurus, or GitHub Pages at the `wiki/` folder and you get a searchable public site. The content is plain markdown with frontmatter, so it works with whatever static generator you prefer. A GitHub Actions workflow that runs `mkdocs build && deploy` on every push turns your wiki into a live site with zero extra tooling.

### Querying: ask the wiki questions

The wiki is not just a thing you read — it's a thing you can talk to.

Open your AI CLI in the repo root and ask:

```
claude
> What does the login flow do, and which modules does it touch?
```

or

```
cursor-agent
> Summarize how caching works across this codebase.
```

Because `CLAUDE.md` defines a **Query workflow**, the CLI:

1. Reads `wiki/index.md` to find relevant pages
2. Reads those pages (and cited source files if it needs to verify a claim)
3. Synthesizes an answer with `[[page]]` citations
4. Asks: **"Should I save this as `wiki/analyses/<slug>.md`?"**

If you say yes, the answer becomes a permanent page — so questions you've asked before don't need re-asking. This is the "compounding" part of the pattern: exploration turns into content the next person can find without asking.

### Other ways to query

- **Grep / ripgrep** for exact symbols: `rg --type md "getUserById" wiki/`
- **Obsidian search** with operators: `tag:#feature path:wiki/api/ line:(*timeout*)`
- **Obsidian Dataview plugin** for structured queries on frontmatter:
  ```dataview
  table updated, sources.length as "Source count"
  from "wiki/architecture"
  sort updated desc
  ```
- **`bash .llmwiki/freshness.sh`** to find stale pages (pages whose cited code SHAs no longer match)

---

## Best practices

### For vibe coders (solo, flow-first)

- **Commit often with meaningful subjects.** The commit subject is passed to the AI — "refactor: rename `foo` to `bar`" gives it a strong hint. "wip" gives it nothing.
- **Don't edit wiki pages manually mid-flow.** If you need to fix something, fix it after the ingest lands. Editing during ingest is a race.
- **Turn off doc types you won't read.** Cost scales with enabled categories. If you only care about API reference, turn `architecture`, `decisions`, `concepts` off.
- **Run `freshness.sh` before shipping.** It takes a second and tells you which pages might be out of date after a messy refactor.
- **Trust `TODO-VERIFY` blocks.** If the AI flagged something, it's because the code is ambiguous. Fix the code or confirm the doc — don't just delete the block.

### For teams

- **One "wiki owner" reviews `wiki: update` commits.** Same way someone reviews changelog or README PRs. Once a week is usually enough.
- **Treat `wiki/analyses/` as the shared memory.** When anyone explores a question, save the answer as an analysis page. Future questions get shorter.
- **Put `.llmwiki/state/` behind a gitignore, but keep `.llmwiki/config.yml` in git.** Share the policy; keep the per-machine state local. The template already does this.
- **Lift `max_diff_lines` for intentional big refactors.** Default is 2000. For a rename-everything commit, run `bash .llmwiki/ingest.sh --force` manually afterward.
- **Run lint on release branches.** `bash .llmwiki/freshness.sh --stale-only | xargs ...` gives you a list of pages to re-ingest before tagging a version.

### For the wiki to stay accurate

- **Every week-ish, read the log.** `tail -n 30 wiki/log.md` shows you what's been happening. `git log --oneline --grep "^wiki:"` gives you the wiki's own history.
- **Delete pages you don't want.** The AI won't recreate a deleted page unless the underlying code changes in a way that re-triggers the category. If a page bothers you, `git rm wiki/api/foo.md` and commit. The next ingest respects that.
- **Resolve `CONTRADICTION` blocks promptly.** The AI flags them when a new diff disagrees with existing wiki claims. Left alone, they rot.
- **Don't let the wiki drift from the code.** That is what `freshness.sh` is for. If you haven't run it in a month, run it now.

### What NOT to do

- Don't run the hook against repos you don't own or don't trust. The CLI reads your whole codebase.
- Don't commit API keys or secrets to `.llmwiki/config.yml`. The config file is in git; it's for policy, not credentials. CLIs have their own auth (typically `~/.config/<cli>/`).
- Don't point `include:` at a directory of generated / vendored code. You will spend tokens documenting `node_modules`.
- Don't treat the wiki as authoritative for UI behaviour. The template explicitly clamps this (see the Hallucinations section), but it's still the highest-risk area. Humans verify UX claims.

---

## Limitations

Be honest with yourself about what this tool is and isn't capable of.

- **Hallucinations are mitigated, not eliminated.** The citation discipline in `CLAUDE.md` and the SHA-based freshness check reduce drift, but they do not guarantee correctness. Any AI-authored claim can be wrong.
- **UI code is the highest-risk case.** Rendering behaviour depends on CSS, router state, runtime data, and hooks defined elsewhere. The template explicitly clamps UI claims, but even so, anything in `wiki/user/` for a UI-heavy project is a sketch.
- **Large diffs are skipped.** Above `hook.max_diff_lines` (default 2000) the hook logs and bails to avoid runaway cost. Big refactors need a manual `bash .llmwiki/ingest.sh --force`.
- **Rename detection is heuristic.** Git does its best; the AI does its best. Good commit subjects ("rename X to Y") help more than anything.
- **Every commit costs money.** The hook calls an AI API on every `git commit` that matches your `include:` globs. Tighten the globs and turn off unused `doc_types` to keep costs sane.
- **Not a single source of truth.** If you also have Confluence, Notion, Google Docs, or a static docs site, this does not replace them. It sits alongside them, closer to the code. Use it for the code-grounded slice; use the others for the rest.
- **Local-first, per-checkout.** Hooks don't push. Each teammate installs the hook themselves. Two developers on parallel branches produce independent `wiki: update` commits — those can conflict on merge like any markdown file.
- **macOS / Linux tested; Windows requires Git Bash or WSL.** Native cmd / PowerShell will not run the hook.
- **Quality tracks CLI quality.** The wiki is only as good as the model behind your CLI. Upgrading the model upgrades the wiki.
- **Cannot read anything outside the repo.** No external API docs, no Stack Overflow, no design docs in Figma. Only what's committed in git at HEAD.
- **Not a code reviewer or refactor tool.** It documents what's there. It does not tell you the code is bad, has security holes, or could be simpler.

## Common misinterpretations

Clearing up things people occasionally assume that are not true.

| What people sometimes think | What's actually true |
|---|---|
| "This replaces technical writers." | **No.** It produces drafts and a living reference. Writers bring judgment, narrative, and voice that the template cannot and does not try to. |
| "I can publish the generated output as end-user documentation." | For **internal** use, often yes. For customer-facing product docs, **always** review with a human. Hallucination risk on behaviour is real. |
| "It understands the entire codebase." | It understands the diff and the wiki pages that cite the changed files. That is the trade-off that keeps latency and cost reasonable. For a full sweep, ask your CLI directly to "re-read `wiki/index.md` and deep-scan". |
| "If the wiki has no `CONTRADICTION` blocks it must be correct." | Absence of flagged issues is not absence of issues. Run `freshness.sh` and spot-check cited line ranges against the code. |
| "The hook will fix bad code." | No. It documents whatever is there. It is not a reviewer, a linter, or a refactor tool. |
| "One commit = one wiki page change." | One commit often updates 5–15 pages — glossary, index, overview, plus each affected entity page. That is expected. |
| "Turning on all doc types makes docs better." | It makes them broader at higher cost. Narrow, enabled categories produce higher-quality pages than everything-on. |
| "My team can use this instead of Confluence / Notion." | Different tool, different purpose. This lives next to the code and documents the code. Product requirements, org knowledge, customer-facing docs belong in their existing homes. |
| "A `wiki: update` commit that looks right means the wiki is right." | It means the AI thought it was right. Periodic human review of `wiki: update` PRs is still required. |
| "Running `freshness.sh` re-ingests stale pages." | No — it only *reports* them. Paste the list back to your AI and ask for a regeneration. |
| "I need to hand-write my first wiki page." | You don't. Make any commit that touches `include:` paths and the first ingest will create the initial pages for you. |

## Privacy and security

Read this before you install the hook on any repo that contains code you don't own or that your employer considers confidential.

### What gets sent over the network

Every commit that touches paths matching `include:` and not matching `exclude:` causes the hook to:

1. Assemble the full diff of the commit (minus `wiki/` and `.llmwiki/`)
2. Read the full current contents of the changed files (the AI needs more than just the diff to write good docs)
3. Read the affected wiki pages
4. Send **all of the above** to whichever AI provider you configured in `.llmwiki/config.yml` (Anthropic for `claude`, Cursor's backend for `cursor-agent`, OpenAI for `codex`)

Your source code leaves your machine on every ingest. The AI providers' own data-handling policies apply — check them before running on proprietary code.

### What to do for sensitive or proprietary code

Pick whichever fits your situation:

- **Don't install the hook on that repo.** The scaffold doesn't activate until you run `bash .llmwiki/install-hook.sh`. Committing without the hook is a no-op.
- **Check your org's AI-use policy first.** Many companies have explicit rules about what can be sent to third-party LLM providers. Follow them.
- **Narrow the `include:` globs aggressively.** If one directory holds secrets or generated keys, make sure it's both in `.gitignore` AND excluded from `include:`. The hook follows `include:`/`exclude:` — it does not honour `.gitignore` directly.
- **Use a CLI that supports on-device or private-endpoint models** if your tooling allows it (e.g. `codex` with a self-hosted backend, or a Claude-compatible local gateway). The template's CLI choice is pluggable — point it at whatever you have.
- **Use a dry-run** — `bash .llmwiki/ingest.sh --dry-run` builds the prompt file and writes it to `.llmwiki/state/ingest-prompt.md` **without** calling the AI. Open that file and check exactly what would have been sent.

### What NOT to put in `.llmwiki/config.yml`

The config file is tracked in git — it's shared with your team. Never put credentials there. In particular:

- **No API keys.** Each CLI has its own auth mechanism (`claude`, `cursor-agent login`, `codex login`) — credentials live under `~/.config/<cli>/`, not in the repo.
- **No private endpoints with embedded tokens.** If your private endpoint URL contains a token, keep the URL in an environment variable and reference it from a local uncommitted wrapper script.
- **No organisation-specific secrets** (internal hostnames, Slack URLs, etc.) — treat `config.yml` as public even if the repo is private, since private repos are one access-control mistake away from public.

### What the hook does NOT do

- It does **not** push anything to the AI provider when you're not making a matching commit.
- It does **not** read files outside the repo root.
- It does **not** run on pull or fetch. Only `git commit`.
- It does **not** persist your code on disk outside `.llmwiki/state/ingest-prompt.md` (the last prompt sent) and `.llmwiki/state/ingest.log` (timestamps and the CLI's stdout/stderr). Both are `.gitignore`'d.

If in doubt, run `cat .llmwiki/state/ingest-prompt.md` after your next commit to see exactly what was sent.

## Troubleshooting

### Hook behaviour

**"Hook installed but nothing happens after I commit"**
Run `tail -n 50 .llmwiki/state/ingest.log`. Most likely the configured CLI is not on `PATH`, or the API key is missing, or the CLI session is not authenticated. The hook logs a skip message and exits 0 — it will never block your commit.

**"The CLI prints an auth / API key error in the log"**
Each CLI has its own login. Run it interactively once and complete the auth flow:
- Claude Code: `claude` → follow the prompt
- Cursor CLI: `cursor-agent login`
- Codex CLI: `codex login`
Then try another commit.

**"The hook keeps looping"**
It shouldn't — the wrapper skips commits whose subject starts with `wiki: update`, and `ingest.sh` exports `LLMWIKI_INGEST_IN_PROGRESS` before its own commit. If you see recursion, check that `.git/hooks/post-commit` is a symlink to `.llmwiki/post-commit` and the symlink resolves: `ls -la .git/hooks/post-commit`.

**"Two commits in quick succession — does the second ingest wait?"**
Yes. `ingest.sh` holds an `flock` on `.llmwiki/state/ingest.lock`. Overlapping runs queue; they do not clobber.

**"A refactor is huge and I don't want the wiki churned"**
`.llmwiki/config.yml → hook.max_diff_lines` (default 2000). Diffs above this are skipped with a log note. Run `bash .llmwiki/ingest.sh --force` manually when you're ready to ingest the big change.

### Output quality

**"I committed and got an instant `wiki: update` — it looks wrong"**
Open the offending page, fix it, commit. The next ingest re-reads your corrections and won't re-hallucinate the same thing. Or delete the page entirely and run `bash .llmwiki/ingest.sh --force` to regenerate from scratch.

**"Pages have confident claims that aren't true"**
This is the hallucination case. Two actions:
1. Edit `CLAUDE.md` → Hallucination Rules section and make the constraints stricter for your domain.
2. Run `bash .llmwiki/freshness.sh` and re-generate the stale list.
Also verify: does the page have a `sources[]` frontmatter with real SHAs? If not, it's ungrounded — the AI should not have produced it. Tighten your prompt in `.llmwiki/prompts/ingest.md`.

**"`freshness.sh` reports everything as stale"**
That's normal after the first install (there are no SHAs in the frontmatter yet). The first few ingests populate the SHAs. After ~5 commits the steady state is reached and `freshness.sh` only flags genuine drift.

**"The AI keeps inventing an API that doesn't exist"**
Usually the `include:` globs are too broad or `exclude:` is missing a generated-code directory. Tighten both. Also check that `CLAUDE.md` is the version that ships with this template — the "cite or don't claim" rule is the load-bearing one.

### Git / team workflow

**"I get a merge conflict on `wiki/*.md`"**
Standard markdown merge conflict. Resolve like any other. If it's a minor conflict in YAML frontmatter (e.g. two branches updated the same `sha:`), pick the newer one and let the next ingest reconcile. If it's a content conflict, pick whichever branch reflects the current code and run `bash .llmwiki/ingest.sh --force` after the merge.

**"A squash-merge killed the wiki updates that were on the feature branch"**
After a squash-merge on `main`, run `bash .llmwiki/ingest.sh --force` once. It sees everything new since the last recorded ingest and regenerates.

**"CI sees two commits per human commit and runs twice"**
Configure your CI to skip runs where the commit subject starts with `wiki: update`. In GitHub Actions: `if: "!startsWith(github.event.head_commit.message, 'wiki: update')"`.

**"My pull request has `wiki: update` commits that clutter the review"**
Three options:
1. Leave them — reviewers benefit from seeing the doc changes inline.
2. Squash-merge — they disappear into the merge commit.
3. Fold them into the preceding code commit: `git rebase -i` and mark each `wiki: update` as `fixup`.

### Cost and scope

**"Cost is too high"**
Lower `hook.max_diff_lines`. Tighten the `include` / `exclude` globs. Turn off doc categories you don't actively use. Consider a cheaper model tier on your CLI.

**"The hook runs on trivial commits (typos, formatting)"**
Git commits are the trigger. If you want finer control, either (a) commit formatting / typo changes as `chore:` with no `include:`-matching paths, (b) temporarily disable the hook with `chmod -x .git/hooks/post-commit` during churn, or (c) set a very strict `include:` glob.

**"I work on a monorepo and one wiki is too broad"**
Put a separate `.llmwiki/` and `wiki/` inside each package directory. The hook runs at the repo root — in a monorepo, the simplest path is one wiki per package. Adapt `ingest.sh` to `cd` into each package root before ingesting, or run one wiki at the root and narrow the `include:` globs to the package you care about.

## Credits

- The idea: [Andrej Karpathy's llm-wiki.md](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285) (copied verbatim into this repo as [llm-wiki.md](./llm-wiki.md))
- The document-ingest variant this builds on: [llm-wiki-karpathy on GitHub](https://github.com/balukosuri/llm-wiki-karpathy) and its [companion Medium article](https://medium.com/@balukosuri/i-used-karpathys-llm-wiki-to-build-a-knowledge-base-that-maintains-itself-with-ai)
- This repo: [article.md](./article.md) tells the story.
