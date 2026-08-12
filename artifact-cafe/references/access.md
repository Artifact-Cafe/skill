# Access: who can open, sharing by email, reading content back

Read this when the user asks who can see an artifact, wants to share a gated
artifact with someone outside, or when you need to read a published
artifact's content over HTTP.

## Who can open the review link

Every artifact has a **visibility**, and it decides whether the review URL is
something you can paste into a group chat or something that stops at a sign-in:

| Visibility | Who can open the review URL |
|---|---|
| `public` | Anyone with the link, no account. Also listed on the workspace's public page. |
| `unlisted` | Anyone with the link, no account. Not listed anywhere. **The default for a new artifact.** |
| `workspace` | **Members of the owning workspace only** — everyone else is asked to sign in. |
| `private` | The publisher, the workspace's owner/admins, and people invited by email. |

A new artifact is `unlisted` unless it lands in a folder, in which case it takes
that folder's visibility. **Check it after publishing** — `publish --json`
returns `visibility`, and `npx artifact-cafe@latest share --list` prints it as
`General access` for an artifact you already have.

**The CLI cannot change visibility** — there is no `--visibility` flag. It's a
dashboard action (the artifact's share menu), or a consequence of which folder
the artifact sits in. If the user wants a members-only artifact opened up, point
them at the dashboard rather than guessing at a flag.

## Share with one person

When an artifact is `workspace` or `private` and someone outside needs in,
invite them by email instead of loosening the artifact for everyone:

```bash
npx artifact-cafe@latest share alex@example.com     # invite (prints a link, once)
npx artifact-cafe@latest share a@x.com b@y.com      # several at once
npx artifact-cafe@latest share --list               # who has access + general access
npx artifact-cafe@latest unshare alex@example.com   # revoke
```

Each invite returns an invitation URL **printed once** — surface it to the user
verbatim, the same way you'd treat a claim URL. A grant survives redemption and
is revoked by `unshare`, not by expiry. Same targeting as the rest
(`--artifact <id>`, `--json`).

## Read an artifact back

To read a published artifact's content — yours or one you were pointed at —
append `.md` to its content URL for a Markdown rendition:

```bash
curl -L https://<slug>.artifactcafe.dev/index.md
```

If the artifact is `workspace` or `private`, that request **401s with
`workspace_required`** unless it carries an account credential. A browser
session doesn't help here: the content origin is a different site and can't see
it. Pass your account key instead:

```bash
curl -L -H "Authorization: Bearer ack_<key>" https://<slug>.artifactcafe.dev/index.md
```

The key is the one `artifact-cafe login` stored; it must belong to an account
that is a member of the owning workspace (or holds a grant). Getting
`workspace_required` while signed in on the website is expected — it means the
request had no key, not that your account lacks access.
