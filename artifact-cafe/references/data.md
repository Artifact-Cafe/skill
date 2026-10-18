# Persistent shared data (Artifact Data)

Read this before writing a manifest for a poll, guestbook, RSVP, form, or shared
checklist that collects submissions across visitors. Use Artifact Data on a
claimed artifact. Guests can submit without accounts; the artifact itself
must belong to an account/workspace (`403 account_required` until claimed).
Use `localStorage` for per-viewer state. See [the data guide](https://artifact.cafe/docs/data).

## Declare the manifest and use the client

Create `.artifact/data.json` beside the entry file:

```json
{
  "collections": {
    "entries": {
      "fields": {
        "name": { "type": "string", "required": true, "maxLength": 80 },
        "message": { "type": "string", "required": true, "maxLength": 1000 }
      },
      "access": { "read": "public", "insert": "public", "update": "creator", "delete": "none" }
    }
  }
}
```

```html
<script src="/__ac/data.js"></script>
<script type="module">
  const { records } = await cafe.data.list("entries");
  await cafe.data.insert("entries", { name: "Ada", message: "hi" });
</script>
```

## Fields and access

Use relative URLs; raw REST lives at `/__ac/data/:collection[/:id]` on the
artifact origin. Field types: string, number, integer, boolean, datetime, url,
email, array, object. Constraints: required, default, maxLength, trim,
minimum, maximum. Names match `^[a-z][a-z0-9_]*$`, max 64 chars; `id`,
`created_at`, `updated_at` are server stamps. Content responses return `mine: boolean`
for the requesting creator and hide creator credentials and signed account ids.
Only the authenticated owner API includes `created_by`. All five metadata names
(`id`, `created_at`, `updated_at`, `created_by`, `mine`) are reserved. Unknown fields
return 400 naming them. Escape submitted values with `textContent`.

Access per read/insert/update/delete is public, creator, owner, or none;
default read public, writes owner. Public update/delete additionally require
`publicMutation: "open"`. Creator is the signed-in account when present,
otherwise a per-browser guest id (possession, not identity). Whoever can't open
the artifact can't touch its data (visibility, membership, shares, password);
browser mutations must come from the artifact's own origin.

## Persistence and limits

Records survive v2, slug rename, and workspace transfers. A supplied manifest
replaces config, omission preserves it, and `{"collections":{}}` disables the
API. Claimed-artifact deletion clears its whole store. A store outage returns
`503 service_unavailable` with `retryAfter` and keeps the artifact for retry.

Limits: 64 KB manifest, 10 collections, 50 fields each, 16 KB record.
Free-tier capacity is 10,000
records/artifact; there is no cap on how many artifacts use data.
Default per-IP reads are 120/minute, writes 10/minute. All non-owner callers also share 10,000
reads/hour and 1,000 writes/hour per artifact; owner calls are exempt.
`rateLimit` accepts N/hour/ip or N/minute/ip and overrides only the per-IP write
rate, never the artifact ceiling. Leave it out by default; tighten it (e.g.
10/hour/ip) only for a public form that attracts spam. Rate errors are 429 with `retryAfter` and `scope: "ip" | "artifact"`.

## Owner tooling

Owner tooling accepts `ack_` keys, scoped `aat_` tokens, or the linked publish
token:

```sh
npx artifact-cafe@latest data ls entries --json
npx artifact-cafe@latest data insert entries --record '{"name":"Ada","message":"hi"}' --json
npx artifact-cafe@latest data insert entries --file seed.json --json   # JSON array, batched
npx artifact-cafe@latest data export --json
npx artifact-cafe@latest data clear entries --yes --json
```

The `/api/v1/artifacts/:id/data` owner API also accepts a signed-in session.
