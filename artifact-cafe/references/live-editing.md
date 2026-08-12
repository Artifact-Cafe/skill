# Live editing mode (the listen loop)

Read this after the user has **explicitly opted in** to live editing mode
(SKILL.md gates the offer — never start this loop automatically).

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
