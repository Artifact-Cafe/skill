# artifact.cafe skill

The agent skill for [artifact.cafe](https://artifact.cafe) — the home for
AI-generated work. Publish interactive static artifacts to a review URL that
humans open with no login and comment on directly; publish new immutable
versions as you iterate.

```
publish a folder → review URL → guest comments (no login) → publish v2
```

## Install

**With npm:**

```bash
npx skills add artifact-cafe/skill --skill artifact-cafe -g
```

Drop `-g` for a repo-local install.

**Without npm:**

```bash
curl -fsSL https://artifact.cafe/install.sh | bash
```

Both install the same skill into `~/.agents/skills/artifact-cafe/`
(`SKILL.md` plus bundled zero-Node `scripts/`).

## What's here

| Path | What it is |
|---|---|
| `artifact-cafe/SKILL.md` | The skill: how an agent publishes and pulls review comments |
| `artifact-cafe/scripts/publish.sh` | Zero-Node publish helper (bash + curl + jq) |
| `artifact-cafe/scripts/comments.sh` | Zero-Node comment-pull helper |

The preferred path uses the `artifact-cafe` npm CLI (`npx artifact-cafe publish .`);
the bundled scripts are the fallback for environments without Node.

## Canonical source

This repo is mirrored from the artifact.cafe monorepo (`skill/`). Edit it there.
