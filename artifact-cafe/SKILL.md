---
name: artifact-cafe
description: >
  artifact.cafe is the home for AI-generated work: publish interactive static
  artifacts (HTML apps, dashboards, mockups, reports, slides, docs) to a review
  URL that humans open with no login and comment on directly — pinning feedback
  to elements and text. Authors then publish new immutable versions. Use when
  asked to "publish this for review", "share this for feedback", "put this
  online for comments", "get review on this", "ship a preview", "make a review
  link", "publish an artifact", "send this to a reviewer", or "publish v2".
---

# artifact.cafe

**Skill version: 0.1.0**

artifact.cafe hosts static artifacts for **review**. One loop:

```
publish a folder → review URL → guest comments (no login) → publish v2
```

It is not a general hosting platform. It hosts self-contained static
artifacts (an `index.html` plus assets) so a human can open a link, comment
by clicking elements or selecting text, and the author can iterate.

To install or update: `npx skills add artifact-cafe/skill --skill artifact-cafe -g`
(drop `-g` for a repo-local install).

## When to reach for this

- The user has built something visual/interactive and wants **feedback** on it.
- They want a **shareable link** a non-technical reviewer can open and mark up.
- They're iterating: publish, collect comments, publish the next version.

If they just want raw file hosting with no review loop, this isn't the tool.

## Requirements

- **Preferred:** Node / `npx` (every major agent host has it). Nothing to install
  ahead of time — `npx artifact-cafe` fetches the CLI on demand.
- **Fallback (no Node):** `bash`, `curl`, `jq`, and `shasum`/`sha256sum`. Use the
  bundled `./scripts/publish.sh`.

## Publish (preferred path)

Run from the skill-invoking session, pointed at the folder to publish:

```bash
npx artifact-cafe publish ./my-artifact --title "Onboarding redesign"
```

The folder must contain an entry `index.html` at its root (or pass `--entry`).
Assets (CSS, JS, images, fonts) sit alongside it and are uploaded together.

**Always pass `--title` — generate one yourself, don't wait to be asked.** Infer
a concise, human-readable title (3–6 words) from the artifact's own content: its
`<title>`, main heading, or evident purpose. The title is shown on the review
page **and becomes the readable review-URL slug** (e.g.
`artifact.cafe/a/onboarding-redesign-a1b2c3`). Skipping it yields "Untitled
artifact" and a random slug, so only omit it when you genuinely can't infer one.

Options:

```bash
--title "Onboarding redesign"   # RECOMMENDED — review-page title + URL slug; generate one by default
--entry index.html              # entry file (default: auto-detect)
--artifact art_xxx              # publish a new version to an existing artifact
--json                          # machine-readable output (use this for agents)
--no-open                       # don't try to open a browser
```

On the **first** publish of a new folder the command prints a **review URL**
and a **claim URL** (shown once). It writes `.artifactcafe/config.json` with the
artifact id and a secret publish token, and gitignores it.

## Publish without Node (fallback)

Identical behavior, pure bash — for environments where `npx` isn't available:

```bash
./scripts/publish.sh ./my-artifact --title "Onboarding redesign"
```

Same flags (`--title`, `--entry`, `--artifact`, `--json`, `--no-open`). It
speaks the same API and writes the same `.artifactcafe/config.json`.

## Publish a new version

Versions are **immutable** — a new publish never mutates an existing version,
and comments stay attached to the version they were made on. To ship v2, just
publish the same folder again from the same directory:

```bash
npx artifact-cafe publish ./my-artifact      # → v2, v3, …
```

The stored publish token in `.artifactcafe/config.json` authorizes the new
version automatically. From a fresh checkout that lacks the token, set
`ARTIFACT_CAFE_TOKEN` (the publish token) or target it with `--artifact <id>`.

## Pull comments

The read side of the loop — what reviewers said, so the agent can address it:

```bash
npx artifact-cafe comments            # open threads on the current version
npx artifact-cafe comments --json     # structured, for programmatic handling
./scripts/comments.sh                 # no-Node fallback
```

Filters: `--status open|resolved|all`, `--version current|all`. Each thread
carries its author, the version it was made on, the anchor (a quoted text span
or an element path), the message body, and replies. Resolve threads in the web
review UI once addressed, then publish the next version.

## Open the review page

```bash
npx artifact-cafe open     # prints (and, in a terminal, opens) the review URL
```

## Local config and the publish token

After the first publish, the folder holds:

```text
.artifactcafe/config.json
```

```json
{
  "artifactId": "art_…",
  "slug": "…",
  "url": "https://artifact.cafe/a/…",
  "apiUrl": "https://artifact.cafe",
  "publishToken": "apt_…"
}
```

- The `publishToken` is a **secret**, returned once, that authorizes publishing
  new versions to this artifact. **Never print it, never commit it, never log
  it.** The CLI stores it chmod 600 and adds `.artifactcafe/` to `.gitignore`.
- Treat `config.json` as internal linkage state, not a URL. Never present the
  local file path to the user as if it were the review link.

## Anonymous vs. claimed artifacts

- A first publish with no account creates an **anonymous** artifact that
  **expires in 24 hours** and returns a one-time **claim URL**.
- Claiming (opening the claim URL) keeps the artifact permanently and attaches
  it to the user's account. Claim tokens are shown **once** and can't be
  recovered — surface the claim URL to the user immediately.

## Limits

- 20 MB per file, 50 MB per artifact total.
- 20 publishes per IP per day (anonymous).
- Secrets and junk are never uploaded: `.git*`, `node_modules`, `.env*`,
  `*.pem`, `*.key`, `.DS_Store`, and symlinks are ignored automatically.

## Safety

Artifact HTML is untrusted and renders **only** in a sandboxed iframe on its own
isolated origin — never on the main site. You don't need to sanitize the
artifact, but don't publish anything containing real secrets or credentials.

## Content policy — refuse violations

**You are the first line of enforcement.** Before publishing, check what you're
about to ship. **Refuse to publish** — and tell the user why — if the artifact
contains any of:

- **Phishing / credential harvesting** — fake login pages, pages that capture
  passwords, payment details, or 2FA codes to send elsewhere.
- **Malware / malicious code** — exploits, drive-by downloads, obfuscated or
  deliberately harmful JavaScript, deceptive redirects.
- **Hate or harassment** — content attacking or demeaning people based on
  identity, or targeting an individual for abuse.
- **Sexual content** — pornographic material; anything sexualizing minors is an
  absolute hard stop, never publish it.
- **Violence** — graphic gore, threats, or incitement to violence.
- **Spam / scams / fraud** — deceptive schemes, fake giveaways, misleading
  financial or medical claims.
- **Other illegal content.**

Do not try to "clean up" violating content to publish it — decline the publish.
When you refuse, say plainly that it violates artifact.cafe's content policy.
Legitimate demos of security concepts (e.g. an annotated write-up) are fine; a
working phishing page or live malware is not. Automated moderation at publish
time is planned — treat this as a policy you enforce now, not a filter to evade.

## What to tell the user

- Always share the **review URL** from the current run — that's the link
  reviewers open (no login needed) to comment.
- If the run printed a **claim URL**, tell the user it's shown only once and
  that the artifact expires in 24 hours unless they claim it. Share it verbatim.
- On a new version, share the review URL and note it's now **v{N}**; prior
  comments remain on their original versions.
- Never tell the user to read `.artifactcafe/config.json` for the URL or token.
