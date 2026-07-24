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

**Skill version: 0.7.0**

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
  ahead of time — `npx artifact-cafe@latest` fetches the CLI on demand.
- **Fallback (no Node):** `bash`, `curl`, `jq`, and `shasum`/`sha256sum`. Use the
  bundled `./scripts/publish.sh`.

## Staying up to date

- **Always invoke the CLI as `npx artifact-cafe@latest …`** (as every example
  here does). The `@latest` tag makes npx fetch the newest published CLI on
  each run instead of reusing a stale cache — that *is* the CLI auto-update.
- The CLI checks for updates (at most once per day) and prints
  `[artifact-cafe] …` notices on **stderr**; they never pollute `--json`
  stdout. When you see `Skill update available`, run the command it prints —
  `npx skills add artifact-cafe/skill --skill artifact-cafe -g` (drop `-g`
  for a repo-local copy) — then re-read the updated SKILL.md before
  continuing. Don't ask permission for this refresh; it only rewrites this
  skill's own files.

## Publish (preferred path)

Run from the skill-invoking session, pointed at the folder to publish:

```bash
npx artifact-cafe@latest publish ./my-artifact --title "Onboarding redesign"
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
--workspace acme                # explicit team workspace
--folder specs                  # optional folder in that workspace
--json                          # machine-readable output (use this for agents)
--no-open                       # don't try to open a browser
```

On the **first** publish of a new folder the command prints a **review URL**
and a **claim URL** (shown once). It writes `.artifactcafe/config.json` with the
artifact id and a secret publish token, and gitignores it.

Decide the destination **before** the first publish — see "Choose where to
publish" below. Always use `--json` and report its `destination` and
`destinationSource` fields.

## Choose where to publish (do this before a new artifact)

This applies to the **first** publish of a new folder. A new *version* reuses
the destination already recorded in `.artifactcafe/config.json` — skip all of
this and just `publish` again. Resolve the destination in this priority order:

**1. Check login first.** Run `npx artifact-cafe@latest whoami --json`.

- **Logged in** (exit 0): publish under that account. A logged-in user should
  never land on an anonymous, 24-hour artifact by accident — that is the bug
  this order exists to prevent. Note that keys resolve **per origin** and
  `ARTIFACT_CAFE_URL` selects the origin: if `whoami` fails for the origin you
  are about to publish to, the account key won't apply to the publish either —
  surface that (they're logged out for this origin) instead of silently
  publishing anonymously.
- **Not logged in** (non-zero exit): publish directly. This is an **anonymous**
  artifact — it expires in 24h and returns a one-time claim URL. Tell the user
  it's anonymous, and that `artifact-cafe login` first gives a permanent,
  account-owned artifact instead.

**2. Then pick the workspace (logged-in only).** If the user named an explicit
`--workspace`, or a project `artifact-cafe.json` default applies, use it and
don't ask. Otherwise list the account's workspaces with
`npx artifact-cafe@latest workspaces --json` and choose:

- **Only Personal** (no team workspaces): publish to Personal, no question.
- **Personal plus team workspaces**: do not silently default to Personal. Look
  at what the artifact is about; if its evident subject matches one of the
  user's workspaces (e.g. planning for a "hellyeah" product when a `hellyeah`
  workspace exists), **ask** the user whether to publish to that workspace or to
  Personal, then pass `--workspace <handle>` accordingly.

Content is only a hint for *what to ask* — never silently commit an artifact to
a workspace you guessed from its content; the user's choice decides. `--json`
disables the CLI's own interactive workspace picker, so a logged-in agent that
skips this step defaults straight to Personal — which is exactly why you run
these two checks yourself.

## Publish without Node (fallback)

The same static publish pipeline, pure bash — for environments where `npx`
isn't available:

```bash
./scripts/publish.sh ./my-artifact --title "Onboarding redesign"
```

It supports `--title`, `--entry`, `--artifact`, `--json`, and `--no-open`,
speaks the same API, and writes the same `.artifactcafe/config.json`. Workspace
discovery, project defaults, and the human picker require the npm CLI. If a
new artifact has an `artifact-cafe.json` policy, the fallback refuses instead
of silently publishing to a different destination.

## Publish a new version

Versions are **immutable** — a new publish never mutates an existing version,
and comments stay attached to the version they were made on. To ship v2, just
publish the same folder again from the same directory:

```bash
npx artifact-cafe@latest publish ./my-artifact      # → v2, v3, …
```

The stored publish token in `.artifactcafe/config.json` authorizes the new
version automatically. From a fresh checkout that lacks the token, set
`ARTIFACT_CAFE_TOKEN` (the publish token) or target it with `--artifact <id>`.
If you're logged in, `artifact-cafe link --artifact <id>` binds the folder to
one of your own artifacts (or `link --json` to list them first) so later
commands run bare — no token needed, owner actions use your login.

## Pull comments

The read side of the loop — what reviewers said, so the agent can address it:

```bash
npx artifact-cafe@latest comments            # open threads on the current version
npx artifact-cafe@latest comments --json     # structured, for programmatic handling
./scripts/comments.sh                 # no-Node fallback
```

Filters: `--status open|resolved|all`, `--version current|all`. Each thread
carries its author, the version it was made on, the anchor (a quoted text span
or an element path), the message body, and replies. Address the feedback,
publish the next version, then close the loop with `reply`/`resolve` (below).

Both the CLI and the fallback also accept `--artifact <id>` (or
`ARTIFACT_CAFE_ARTIFACT_ID`) to read an artifact without its folder — the same
detached targeting as `publish`; add `ARTIFACT_CAFE_TOKEN` for a
password-protected one.

## Respond to comments

The write side of the loop — how the agent answers feedback after publishing a
version that addresses it. Take each thread's `id` from `comments --json`:

```bash
# Post what changed back into the thread, then close it — one step
npx artifact-cafe@latest reply <threadId> --body "Fixed in v2 — CTA moved above the fold." --resolve

npx artifact-cafe@latest reply <threadId> --body "…"     # reply, leave it open
echo "$msg" | npx artifact-cafe@latest reply <threadId>  # long body from stdin
npx artifact-cafe@latest resolve <threadId>              # close a thread you addressed
npx artifact-cafe@latest reopen <threadId>               # undo — reopen a resolved one
```

A publish-token reply is attributed to **the agent** (named from the version's
source agent), so the reviewer sees who responded; replying under a signed-in
account renders as the owner. Prefer `reply --resolve` over a bare `resolve` —
it tells the reviewer *what* you changed instead of silently closing the thread.
Same detached targeting as the rest (`--artifact <id>` + `ARTIFACT_CAFE_TOKEN`,
or your account key); every command takes `--json`.

Fix or retract a message you wrote — take the id from `comments --json` (each
thread's `messageId` for its opening comment, each reply's `id`):

```bash
npx artifact-cafe@latest edit <messageId> --body "Revised — moved the CTA, not removed it."
npx artifact-cafe@latest delete <messageId>
```

You can only edit or delete a message **you** authored — a token-authored agent
reply, or your own account comment; the same credential that wrote it authorizes
the change. `edit` adds an "edited" marker (no history). `delete` is a *soft*
delete: the comment becomes a "Comment deleted" tombstone and any replies under
it survive.

## Open a review thread

`reply` answers an existing thread; `comment` **opens a new one** — for leaving
your own review notes on an artifact:

```bash
npx artifact-cafe@latest comment --quote "Where AI work lives" --body "This headline is vague."
npx artifact-cafe@latest comment --body "Overall this reads well."   # page-level, no --quote
```

Unlike the rest of the loop, `comment` authors as **your account**, so it needs
`artifact-cafe login` — a publish token can't open threads (agents respond;
accounts originate) and returns a login hint if that's all you have. `--quote`
anchors the thread to matching text (`--prefix`/`--suffix` disambiguate a quote
that repeats); with no `--quote` it's a page-level comment. `--via "Claude Code"`
adds an attribution label shown after your account name — additive, never a mask.

`comment`, `edit`, and `delete` (like `listen`) need the Node CLI — no bash
fallback.

## Offer live editing mode (opt-in)

Publishing and live editing are separate actions. After publishing and sharing
the review URL, ask the user whether they want to enter **live editing mode**.
Explain that you will stay attached to the local artifact, receive new comments
as they arrive, revise it, and publish new immutable versions while they review.

Do not start live editing mode automatically. A user may want to share the link
with guests and collect feedback asynchronously without keeping a local agent
session active. Only start listening after the user explicitly opts in:

```bash
npx artifact-cafe@latest listen --json --timeout 540
```

`listen` is the live-loop entry point — it's exactly `comments --wait` (same
flags, same output), named for what it does. It does **not** run a local server
or auto-republish on save; publishing the next version stays a separate,
explicit `publish`. The command blocks until a reviewer leaves *new* feedback (a
new thread, or a new reply), then prints only the new/changed threads and exits
`0`. Each thread is tagged `"change": "new" | "updated"`. If nothing arrives
before `--timeout` seconds it exits `2` with `"timedOut": true`. While it runs,
the review page shows a live **"Agent is listening"** indicator, so the reviewer
knows their comments will be acted on immediately.

The opt-in loop, until the user says they're done:

1. `publish` → share the review URL → ask whether to enter live editing mode.
2. After a clear yes, run `listen --json --timeout 540` (pick a timeout under
   your execution environment's command limit — 540s fits a 10-minute cap).
3. Feedback arrives → make the changes it asks for.
4. `publish` again → the reviewer's page offers "v{N} just published — view
   latest" automatically.
5. `reply <threadId> --resolve` each thread you addressed, so the reviewer sees
   what changed and the thread closes. Go to 2.

If the command times out with exit code `2`, tell the user the listening window
ended and ask whether to continue before running it again. Do not keep an
unattended session alive indefinitely.

`listen` needs the Node CLI (no bash-script fallback). It normally runs from
the folder's `.artifactcafe/config.json`, but it doesn't have to: you can listen
from **any machine** — CI, a fresh checkout, a different session than the one
that published — by pointing at the artifact directly with `--artifact <id>`
(or `ARTIFACT_CAFE_ARTIFACT_ID`) plus `ARTIFACT_CAFE_TOKEN`. That credential —
the folder token, the env token, or a signed-in account key — authorizes the
presence heartbeat and unlocks password-protected artifacts.

## Open the review page

```bash
npx artifact-cafe@latest open     # prints (and, in a terminal, opens) the review URL
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
