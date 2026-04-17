# I Pointed Karpathy's LLM Wiki at My Own Code. Now Every `git commit` Writes Its Own Docs.

*How a background git hook, a configurable schema, and some hallucination guardrails turn any code repo into a self-maintaining wiki — ideal for vibe coders who want docs without breaking flow.*

**By Balu Kosuri**

---

Two weeks ago I published an article about LLM Wiki — the pattern by Andrej Karpathy for turning piles of documents into a self-maintaining wiki. In the comments, someone asked:

> can we ingest code repositories?

My short reply:

> Yes you can and ask it to create wiki's as per you required template. it can be a end user docs, internal docs, anything. Challenges would be: since code is not written for docs for any UI based products it struggles with hallucinations, but for CLI based products it's very good.

I promised a follow-up article and a GitHub project. This is both.

**Repository:** `https://github.com/balukosuri/docs-from-code-with-llm-wiki` *(swap for your fork)*

If you just want the template, clone the repo, edit one config file, run one install script, and your next `git commit` will populate the wiki in the background. The article is the story of why it works and where it breaks.

---

## Before anything else — what this is, and what it isn't

I want to be blunt about this because it's the question that gets asked (and answered wrongly) most often.

**This is a small personal project.** It instantiates one of Andrej Karpathy's ideas — the `llm-wiki.md` pattern — and points it at a code repository instead of a document folder. That's the entire contribution. The hard work is Karpathy's; mine is one adapter and a git hook.

**The problem it addresses** is specific: internal wikis and engineering knowledge bases die on the vine. They start well, drift out of date because maintenance is nobody's job, and end up distrusted. A README that's 20% wrong is worse than no README, because now people are confidently misinformed. Moving the bookkeeping from human hands to a git hook keeps the wiki roughly in lockstep with the code — and that is most of what anyone actually wanted from a wiki in the first place.

**This is not a replacement for a technical writer.** I want to say that twice because it's important and because I am a technical writer. A writer brings judgment, narrative, audience empathy, editorial voice, and the willingness to push back on the engineers they work with. An LLM has none of those. What this tool produces is:

- a **draft** a writer can polish — not a finished doc
- an **internal reference** for developers — not a published product manual
- a **bookkeeper** for the 80% of content that decays as code changes, freeing human writers for the 20% that needs voice

If you have a writer on your team, this tool helps them by giving them a living, code-grounded reference to work from. It does not replace them. If you do not have a writer, this tool gives you something your team can trust for internal use — but do not mistake it for customer-ready documentation without a human in the loop.

**Best fit:** internal developer docs, CLI tools and libraries, solo devs and small teams without a docs function, teams that want a living reference alongside their human-authored product docs.

**Poor fit without a human editor:** shipped end-user product documentation, UI-heavy apps where behaviour depends on runtime data, compliance / legal / safety-critical content.

With that disclaimer out of the way, here's why I built it.

---

## The problem with docs for code

Think about every README you've ever written. It started strong. Someone onboarded, skimmed it, and shipped a fix. A month later a feature got renamed. The README didn't. Three months later a whole subsystem was rewritten. The README didn't change. Six months later the README is a relic — wrong enough to mislead, right enough that nobody deletes it.

This is not a motivation problem. It is a **timing** problem.

Documentation decays because the moment the code changes is not the moment the docs get updated. By the time anyone notices, the developer who made the change has context-switched away and now lives in another world.

For my previous article this was easy to solve for static documents — you just "ingest" a PDF once and you're done. But code is not static. Every commit is a potential ingest. Nobody wants to type `ingest src/auth/login.ts` every time they save a file.

So I needed a different trigger.

## The insight: the trigger should be `git commit`

Here is the move. The natural heartbeat of a code project is not "when the developer remembers to update docs". It is **`git commit`**. Every commit is an atomic unit of change — tested, reviewed (hopefully), and marked with a human-written subject. If the wiki updates itself on every commit, the docs never fall more than one commit behind the code.

That is what `docs-from-code-with-llm-wiki` does. A `post-commit` git hook fires in the background. It diffs `HEAD~1..HEAD`, hands the diff to whichever AI CLI you configured, and the CLI updates the wiki in place. A few seconds later a follow-up commit lands with the subject `wiki: update (<sha>)`. Your `git commit` returned instantly — you kept coding.

Here is the whole flow:

```
git commit (code)
   │
   ▼
post-commit hook → nohup ingest.sh &   (returns immediately, you keep coding)
                          │
                          ├─ flock (prevents overlapping runs)
                          ├─ git diff <last-ingested>..HEAD
                          ├─ claude -p  (or cursor-agent, or codex)
                          │     └─ reads CLAUDE.md + config.yml
                          │        edits wiki/*.md in place
                          └─ git commit -m "wiki: update (<sha>)"
```

For a vibe coder — someone who codes in flow, commits when they feel like it, and does not want to be a documentation bureaucrat — this is the ideal loop. You never type "ingest". You just commit. The docs appear.

---

## What the AI actually writes

The second question, after "what triggers it", is "what does it produce". And here I did not want to make one opinionated choice. Internal architecture docs, end-user README drafts, API reference, ADRs — different projects want different mixes. Some want all of them; some want none.

So the template has **one configuration file** that flips categories on and off:

```yaml
# .llmwiki/config.yml

cli: claude              # claude | cursor-agent | codex

doc_types:
  architecture: true     # Internal: module map, data flow
  api: true              # Public function / class / CLI reference
  user: false            # End-user README drafts — turn on for CLI tools
  decisions: true        # ADR-style decision records
  concepts: true         # Domain ideas discovered in the code

include:
  - "src/**"
  - "lib/**"

exclude:
  - "**/*.test.*"
  - "dist/**"

custom_types: []
#  - name: runbook
#    dir: runbooks/
#    trigger: "when the diff touches infra/ or ops/"
```

Turn on what you care about. Add your own categories under `custom_types`. That's the only knob.

On every ingest, the CLI re-reads this file. If you had `user: false` yesterday and flip it to `true` today, the next commit will start drafting end-user docs. No code changes required.

The enabled categories map one-to-one to folders under `wiki/`:

```
wiki/
  index.md          ← master catalog
  log.md            ← append-only activity log (great for `git blame` of docs)
  overview.md       ← big-picture synthesis
  glossary.md       ← every public identifier, CLI flag, config key
  architecture/     ← per-subsystem pages (grouped by responsibility)
  api/              ← one page per exported function, class, command
  user/             ← README drafts, how-tos, CLI usage
  decisions/        ← ADR pages proposed from commit messages
  concepts/         ← domain ideas (e.g. "retry backoff", "job queue")
  sources/          ← one summary page per significant source file
```

Open it in Obsidian and the graph view colour-codes by folder. You can see at a glance which subsystems are hubs and which are orphans.

---

## The hallucination problem (the honest part)

Here is the part I flagged in my comment reply. Code is an ungrateful source to summarize.

Code narrates *what* happens — `function login(user, pass)`. It almost never narrates *why* the function exists, who calls it, what happens when it fails at 3am in production, or what the user sees when it does. An LLM summarizing a function without that context will happily fill in the gaps from its training distribution. If React components look like other React components it has seen, it will describe their behaviour the same way — even when the specific component does something unique.

This gets worse with UI code. A React component is a function. The rendered behaviour depends on CSS, router state, data that arrives at runtime, and a dozen hooks that are defined elsewhere. Reading the source tells you a small fraction of what the component does for the user. Asking the AI to document "what the user sees when they click this button" is an invitation to fabricate.

CLI tools are the opposite. A `cobra`/`click`/`commander` command definition contains its name, its flags, their types, their defaults, its subcommands, and often its help text. You can read the whole public surface from one file. This is why I said in the comment that **CLI-based projects are the sweet spot for this tool.**

There is no silver bullet for hallucinations in code summarization, but two layered defences cover most of the damage:

### 1. Prompt discipline in `CLAUDE.md`

`CLAUDE.md` is the schema file that every AI CLI reads before it does anything. The version that ships with this template has seven hard rules. The key ones:

- **Cite or do not claim.** Every non-trivial statement must be followed by `(path:start-end)`. If you can't produce the citation, you are speculating — stop and emit a `> TODO-VERIFY:` blockquote instead.
- **Never describe an API that is not at HEAD.** Don't write "this function accepts an optional `timeout`" if `timeout` is not in the current signature.
- **Never narrate runtime behaviour you cannot read.** No "this probably does X". If behaviour is only inferable from tests, cite the test file.
- **UI clamp.** For React components, templated HTML, and CSS-driven behaviour, do not describe what the user sees unless a test, snapshot, or storybook file confirms it.
- **Never cite anything outside this repo.** No external docs, no "frameworks like this usually...". Only code at HEAD.

The CLI is told, in loud uppercase, that `TODO-VERIFY` blocks are a feature, not a failure. A page with two confident paragraphs and three `TODO-VERIFY` markers is more useful than a page covered in confident hallucinations.

### 2. Freshness check backed by real SHAs

Every wiki page stores the `git hash-object` SHA of each file it cites, right there in the frontmatter:

```yaml
---
title: Login flow
type: module
sources:
  - path: src/auth/login.ts
    sha: 3f9a21bccd4e0f12abc34...
    lines: 1-120
  - path: src/auth/session.ts
    sha: 0b12aa99cc8d77eeff01...
    lines: 15-88
updated: 2026-04-17
---
```

The freshness script walks every page, re-runs `git hash-object` on each cited file, and reports any page whose citations no longer match. Two things make this cheap and reliable:

- Git blob SHAs are deterministic. Same content → same SHA. Always.
- You can run it in a pre-push hook, a CI job, or manually with `bash .llmwiki/freshness.sh`. It reads nothing but the working tree.

When a page is stale, you paste the stale list to your AI and say "re-generate these". The next ingest has real code in front of it, and the hallucinated claims go away.

Is this bulletproof? No. Nothing is. But it turns hallucinations from a silent, cumulative decay problem into a loud, dated, traceable one. You always know which pages might be wrong, and why.

---

## How `CLAUDE.md` is different from the document version

Side-by-side comparison with the original technical-writer version I shipped two weeks ago:

| Aspect | Documents version | Code version |
|---|---|---|
| Source of truth | `raw/` folder of PDFs, transcripts, clippings | The git repo at HEAD |
| Trigger | Human types "ingest" | `post-commit` hook fires automatically |
| Entity types | Source, Product, Feature, Persona, Concept, Style | Source, Module, API, User-doc, Decision, Concept |
| Citation format | "As noted in `[[onboarding-prd]]`" | `(src/auth/login.ts:45-62)` with a blob SHA in frontmatter |
| Update cadence | Whenever the human ingests | Every commit |
| Main failure mode | Stale when new documents arrive and aren't ingested | Hallucination from insufficient code context |
| Best fit | Research, writing, PM work | CLI tools, libraries, services |

Same pattern, different dials.

---

## A vibe-coding walkthrough

Here is what the loop looks like in practice. Imagine you are spinning up a small CLI tool — a JSON-to-YAML converter — over an evening.

**Commit 1:** `initial skeleton`. You scaffold `src/cli.ts` with a single `convert` command. The hook fires. The ingest worker picks up the new file, creates `wiki/architecture/cli.md` with a short "CLI entry point" summary, creates `wiki/api/convert.md` with the signature, seeds `wiki/glossary.md` with `convert`, appends a log entry, and commits `wiki: update`.

You never saw the wiki happen. You started on commit 2.

**Commit 2:** `add -o / --output flag`. You add the flag, commit. Hook fires. `wiki/api/convert.md` picks up the new flag with its default value. `wiki/glossary.md` gains `--output`. Log entry says `Pages updated: [[convert]], [[glossary]]`.

**Commit 3:** `refactor: split yaml writer into writer.ts`. You extract a helper. Hook fires. The CLI notices a new module, creates `wiki/architecture/writer.md`, updates `wiki/architecture/cli.md` to link to `[[writer]]`, updates `wiki/overview.md` with the new two-file shape, commits.

**Commit 4:** `handle --pretty`. You add a flag but forget to update the help text. The AI flags it: `> TODO-VERIFY: flag --pretty is defined at src/cli.ts:42 but does not appear in the help block at src/cli.ts:15-30`. You fix the help text and commit again. The TODO resolves itself.

**Commit 5:** you decide your `api` docs should go in a CLI reference style. You open `.llmwiki/config.yml`, flip `doc_types.user: true`, commit. Next ingest starts drafting `wiki/user/convert.md` — a README-style usage page — in addition to the API reference.

Five commits, zero documentation keystrokes. You open Obsidian on the side, press `Cmd+G`, and see the graph fill out in real time.

---

## Limitations (be honest with yourself)

- **Hallucinations are mitigated, not eliminated.** The citation discipline in `CLAUDE.md` and the SHA-based freshness check reduce drift — they do not guarantee correctness. Any AI-authored claim can still be wrong.
- **UI-heavy code** is the weakest case. If you work on a React/Vue/Svelte app, turn `api` and `architecture` on, turn `user` off, and treat the output as a skeleton a human has to finish. Do not publish the generated end-user docs without review.
- **Large diffs** (massive refactors, rename-everything commits) get skipped by default above 2000 lines. You can lift the limit, but expect cost. The template prints a skip message rather than silently burning tokens.
- **Renames across files** — Git's rename detection is heuristic. If the AI sees "delete foo.ts + add bar.ts" it may not realise they are the same thing. The hook passes the commit subject through, so a subject like `refactor: rename foo.ts to bar.ts` gives it a strong hint.
- **Every commit costs money.** The hook calls an AI API on every matching commit. Tighten the globs and turn off unused doc types to keep the bill sane.
- **Not a single source of truth.** If you also have Confluence / Notion / a docs site, this sits alongside them. It documents the code-grounded slice; the rest stays where it is.
- **Private APIs vs public APIs** — The template defaults to documenting the public surface. If you want internals documented too, broaden the `include` glob and enable `architecture`.
- **Monorepos** — Works fine with one wiki per repo. For a monorepo, either run one wiki in the repo root (broad) or put a separate `.llmwiki/` and `wiki/` per package (focused). The latter tends to be more useful.
- **CI-only workflows** — This template runs locally. Teams that want the wiki updated on merge-to-main rather than per-commit-per-developer should adapt the hook into a GitHub Action. The prompts and `CLAUDE.md` port straight over.
- **Windows** — Tested on macOS. Linux should work. Windows requires Git Bash or WSL; native cmd / PowerShell will not run the hook.
- **Quality tracks the CLI.** The wiki is only as good as the model you put behind it. Upgrade the model, upgrade the wiki.
- **Not a reviewer.** This documents code. It does not tell you the code is wrong, insecure, or could be simpler.

---

## Things people assume that aren't true

A handful of misinterpretations worth clearing up in one place:

- **"This replaces technical writers."** It does not. It produces drafts and a living reference. The last mile — voice, narrative, audience empathy, editorial judgement — is still a human job.
- **"I can publish the generated output as end-user docs."** For internal use, often yes. For customer-facing content, always review. The hallucination risk on behaviour is real.
- **"It understands the whole codebase."** It understands the diff and the pages that cite the changed files. For a full sweep, ask your CLI directly to "re-read `wiki/index.md` and deep-scan" — that's a different operation.
- **"No `CONTRADICTION` block means the wiki is correct."** Absence of flagged issues is not absence of issues. Run `freshness.sh` and spot-check the cited line ranges. Trust, but verify.
- **"The hook fixes bad code."** It documents whatever is there. It is not a reviewer or a refactor tool.
- **"One commit updates one wiki page."** One commit often touches 5–15 pages — glossary, index, overview, plus the affected entity pages. That is the design.
- **"Turning on every doc type gives me better docs."** It gives you broader docs at higher cost. Narrow, enabled categories produce sharper pages.
- **"My team can use this instead of Confluence."** Different tool, different purpose. This lives next to the code. Product specs, org knowledge, and customer-facing docs belong in their existing homes.
- **"A `wiki: update` commit that looks right means the wiki is right."** It means the AI thought it was right. Periodic human review is still required.

If you catch yourself thinking any of the left-hand versions, come back to this list.

---

## Clone it, point it at your code, commit once

```bash
git clone https://github.com/balukosuri/docs-from-code-with-llm-wiki.git my-project
cd my-project

# Edit .llmwiki/config.yml — pick your CLI, toggle doc types
$EDITOR .llmwiki/config.yml

# Install the hook
bash .llmwiki/install-hook.sh

# Commit some code (even "initial commit" works)
git add . && git commit -m "start"

# Watch the wiki populate
tail -f .llmwiki/state/ingest.log
```

Open the folder in Obsidian as a vault. The overview page opens by default. Graph view is `Cmd+G`.

**If you are vibe coding**, the whole thing is: clone, edit one YAML file, run one script, then forget the wiki exists. Your commits write it for you.

---

## Closing thought

Documentation failures are almost never "we didn't know how to write docs". They are "the moment the code changed and the moment the docs should have changed are separated by too much time and too many context switches".

Karpathy's LLM Wiki pattern collapses that gap for documents by making an AI agent the wiki maintainer. This variant collapses it for code by making `git commit` the trigger and grounding every claim in `path:line` citations that a freshness check can verify.

The wiki is not a thing you maintain alone — it's a thing the hook drafts and you refine. Your job shifts from bookkeeper to reviewer: write the code, commit it, and review what the hook proposes. The authoring that actually matters — voice, narrative, judgement, editorial taste — is still yours. The tool just removes the grunt work that used to stand between you and the parts of documentation that need a human.

If the previous article was about turning 15 scattered documents into a self-updating knowledge base, this one is about turning a live, evolving codebase into its own living documentation. The pattern is the same. The trigger is what changed.

---

My name is Balasubramanyam Kosuri, and I work as a technical writer. Connect with me on LinkedIn for more such content.

*Repository: `https://github.com/balukosuri/docs-from-code-with-llm-wiki`*
*Previous article: [I used Karpathy's LLM Wiki to build a knowledge base that maintains itself with AI](https://medium.com/@balukosuri/i-used-karpathys-llm-wiki-to-build-a-knowledge-base-that-maintains-itself-with-ai)*
*Original idea: [Karpathy's llm-wiki.md](https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285)*
