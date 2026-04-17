---
title: Login flow (example page)
type: module
created: 2026-04-17
updated: 2026-04-17
sources:
  - path: src/auth/login.ts
    sha: 3f9a21bccd4e0f12abc34def567890abcdef1234
    lines: 1-120
  - path: src/auth/session.ts
    sha: 0b12aa99cc8d77eeff0112233445566778899aa
    lines: 15-88
tags: [auth, example]
---

> **DELETE THIS PAGE AFTER YOUR FIRST INGEST.** This file (`wiki/_example-page.md`) is a template that shows the format the AI should follow when producing wiki pages. It cites files that do not exist in your repo. As soon as your first real `wiki: update` commit lands, delete this file — it will never be regenerated.

## One-line summary

Example only — shows the expected shape of a module page: frontmatter with real git blob SHAs, a short summary, body sections with inline citations, a TODO-VERIFY block, and a Related pages section.

## Responsibility

The login module authenticates a user by email and password, creates a session, and returns a signed cookie. It is called only from the HTTP handler in `src/server/routes.ts:42-58`, not from background jobs.

## Public surface

| Export | Signature | Defined at |
|---|---|---|
| `login` | `(email: string, password: string) => Promise<Session>` | `src/auth/login.ts:12-45` |
| `refresh` | `(token: string) => Promise<Session>` | `src/auth/login.ts:48-72` |
| `logout` | `(token: string) => Promise<void>` | `src/auth/login.ts:75-88` |

## How it works

1. `login` hashes the submitted password with bcrypt and compares against `users.password_hash` (`src/auth/login.ts:18-26`).
2. On success it calls `createSession` from `src/auth/session.ts:15-40` to generate a session ID and insert a row in the `sessions` table.
3. The session ID is signed with the server's HMAC key (`src/auth/session.ts:62-78`) and returned as the cookie value.
4. Rate limiting is applied via the `rateLimit` middleware in `src/server/middleware.ts:30-55` — five attempts per IP per minute.

> **TODO-VERIFY:** The rate-limit window is described as "per minute" based on the middleware's `windowMs: 60_000` constant, but the accompanying comment in `src/server/middleware.ts:32` says "per hour". One of these is wrong. Confirm against a running instance or a test before relying on this page.

## Error cases

| Condition | Response |
|---|---|
| Unknown email | `401 Unauthorized` with `"invalid credentials"` (`src/auth/login.ts:22`) |
| Wrong password | `401 Unauthorized` with `"invalid credentials"` (`src/auth/login.ts:27`) |
| Rate limit exceeded | `429 Too Many Requests` (`src/server/middleware.ts:50`) |
| DB unreachable | Propagates the driver error; handler logs and returns `500` (`src/server/routes.ts:55`) |

## Related pages

- [[session]] — session lifecycle and signing
- [[routes]] — the HTTP surface that calls this module
- [[glossary]] — terms: `session`, `bcrypt`, `HMAC`
