# Organize the library (folders playbook)

Read this when the user asks you to organize their artifacts ("organize my
artifacts", "clean up my workspace", "file these into folders") — or when you
need folder mechanics beyond the publish-time basics in SKILL.md. Everything
here needs the Node CLI and a signed-in account (`artifact-cafe login`); the
bash fallback can't manage placement.

## The folder model

Every workspace — Personal included — has a **flat** list of folders (no
nesting). A folder is `workspace` (members-only, the default) or `public`
(listed on the workspace's public page). The folder's visibility is the
**default applied to artifacts placed in it** — that's the one dangerous
mechanic, restated below.

`--folder` (on `publish` and `move`) matches the exact folder name
(case-sensitive) or the folder id. If two folders share a name, pass the id.

## Creating folders

```bash
npx artifact-cafe@latest folders create "Design specs" --workspace <handle> --visibility workspace
```

- `--visibility workspace` (default) or `public`.
- **Reuse before creating.** The CLI refuses a name that already exists
  (case-insensitively) in the workspace — treat that refusal as "file into
  the existing folder", not an obstacle.
- **Never create a folder for a single artifact.** Create one when a real
  group exists: this artifact plus two or more existing artifacts share a
  theme, or the user names a project or series they'll keep publishing to.
- Name folders as short noun phrases ("Design specs", "Q3 planning"), and
  follow the naming style the workspace's existing folders already use.
- Tell the user when you create a folder; creation in a *team* workspace
  needs an owner/admin role (in Personal you always have it).

## ⚠ Folder visibility rewrites artifact visibility

Artifacts default to `unlisted`, but a first publish into a folder **adopts
the folder's visibility immediately** — publishing into a public folder makes
the artifact public, with no confirmation prompt anywhere. Moving an artifact
you published (or any move by an admin) applies the folder default the same
way. Before placing anything into a **public** folder, confirm with the user
that going public is intended, and always report a visibility change after a
move.

## Re-file without republishing

`move` changes only the placement — no new version, comments untouched:

```bash
npx artifact-cafe@latest move --folder "Design specs"        # linked folder
npx artifact-cafe@latest move --artifact art_x --folder specs
npx artifact-cafe@latest move --artifact art_x --unfiled     # back to root
```

It authorizes with your login (a publish token can't re-file) and reports
`previousVisibility` → `visibility` in `--json` output — surface that change
to the user.

## Organize on request

When the user asks you to tidy up:

1. `npx artifact-cafe@latest workspaces --json` — pick the workspace to
   organize; ask if ambiguous.
2. `npx artifact-cafe@latest list --workspace <handle> --json` — returns
   every artifact (with its `folderId`) *and* the folder list in one call.
3. Propose a filing plan **before acting**: which folders to create, which
   artifact moves where, and any visibility changes those moves will cause.
   Group by evident theme; leave genuine one-offs unfiled; don't invent a
   "Misc" folder.
4. On approval, `folders create` what's missing, `move` each artifact, then
   report the resulting tree (and every visibility change).

Never bulk-move or bulk-create without showing the plan first. Renaming and
deleting folders stay in the dashboard — the CLI deliberately has no
destructive folder commands.
