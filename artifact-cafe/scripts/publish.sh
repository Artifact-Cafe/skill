#!/usr/bin/env bash
# artifact.cafe — zero-Node publish helper.
#
# This is the fallback for environments without Node/npx. When Node is
# available, prefer `npx artifact-cafe publish .` (same behavior, richer
# output). This script speaks the same /api/v1 contract as the npm CLI:
#
#   scan → ignore rules → entry → manifest (sha256) → create session →
#   presigned PUT uploads → finalize → print review URL → write config.
#
# Requires: bash, curl, jq, and one of {shasum, sha256sum}.
set -euo pipefail

DEFAULT_API_URL="https://artifact.cafe"
UPLOAD_TIMEOUT=120

DIR="."
TITLE=""
ENTRY=""
ARTIFACT_ID_FLAG=""
TOKEN_FLAG=""
API_URL_FLAG=""
CLIENT="${ARTIFACT_CAFE_AGENT:-}"
JSON=0
OPEN=1

usage() {
  cat <<'USAGE'
Usage: publish.sh [dir] [options]

Publishes a folder of static files as an artifact for review.

Options:
  --title <text>       Artifact title
  --entry <file>       Entry file (default: auto-detect index.html)
  --artifact <id>      Publish a new version to an existing artifact id
  --client <name>      Agent name for attribution (e.g. claude-code, cursor)
  --token <token>      Publish token (else read from config / $ARTIFACT_CAFE_TOKEN)
  --api-url <url>      API base (default: https://artifact.cafe)
  --json               Machine-readable output
  --no-open            Don't open the review URL in a browser
  -h, --help           Show this help
USAGE
  exit "${1:-1}"
}

die() {
  if [[ "$JSON" -eq 1 ]]; then
    jq -n --arg m "$1" '{error:$m}' >&2
  else
    echo "error: $1" >&2
  fi
  exit 1
}

for cmd in curl jq file; do
  command -v "$cmd" >/dev/null 2>&1 || die "requires $cmd (not found on PATH)"
done

# sha256 helper — macOS ships shasum, most Linux ship sha256sum.
if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  die "requires sha256sum or shasum"
fi

# byte size of a file — BSD (macOS) vs GNU stat differ.
if stat -f%z . >/dev/null 2>&1; then
  size_of() { stat -f%z "$1"; }
else
  size_of() { stat -c%s "$1"; }
fi

# Parse args. First non-flag positional is the directory.
DIR_SET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)    TITLE="$2"; shift 2 ;;
    --entry)    ENTRY="$2"; shift 2 ;;
    --artifact) ARTIFACT_ID_FLAG="$2"; shift 2 ;;
    --client)   CLIENT="$2"; shift 2 ;;
    --token)    TOKEN_FLAG="$2"; shift 2 ;;
    --api-url)  API_URL_FLAG="$2"; shift 2 ;;
    --json)     JSON=1; shift ;;
    --no-open)  OPEN=0; shift ;;
    -h|--help)  usage 0 ;;
    -*)         die "unknown option: $1" ;;
    *)          [[ "$DIR_SET" -eq 0 ]] && { DIR="$1"; DIR_SET=1; shift; } || die "unexpected argument: $1" ;;
  esac
done

[[ -d "$DIR" ]] || die "not a directory: $DIR"
DIR="$(cd "$DIR" && pwd)"

log() { [[ "$JSON" -eq 1 ]] || echo "$@"; }

# ── MIME map — kept in sync with packages/cli/src/manifest.ts ──────────────
mime_for() {
  local ext
  ext="$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    html|htm)  echo "text/html" ;;
    css)       echo "text/css" ;;
    js|mjs)    echo "text/javascript" ;;
    json|map)  echo "application/json" ;;
    txt)       echo "text/plain" ;;
    md)        echo "text/markdown" ;;
    xml)       echo "application/xml" ;;
    svg)       echo "image/svg+xml" ;;
    png)       echo "image/png" ;;
    jpg|jpeg)  echo "image/jpeg" ;;
    gif)       echo "image/gif" ;;
    webp)      echo "image/webp" ;;
    avif)      echo "image/avif" ;;
    ico)       echo "image/x-icon" ;;
    woff)      echo "font/woff" ;;
    woff2)     echo "font/woff2" ;;
    ttf)       echo "font/ttf" ;;
    otf)       echo "font/otf" ;;
    pdf)       echo "application/pdf" ;;
    mp4)       echo "video/mp4" ;;
    webm)      echo "video/webm" ;;
    mp3)       echo "audio/mpeg" ;;
    wav)       echo "audio/wav" ;;
    wasm)      echo "application/wasm" ;;
    *)         echo "application/octet-stream" ;;
  esac
}

# ── Ignore rules — kept in sync with packages/cli/src/manifest.ts ──────────
# Secrets and junk never leave the machine; the API enforces size limits.
ignored_file() {
  local base="$1"
  case "$base" in
    .DS_Store|.env|.env.*|.git*) return 0 ;;
    *.pem|*.key) return 0 ;;
  esac
  return 1
}

# ── Scan ───────────────────────────────────────────────────────────────────
# Prune ignored directories (node_modules, .artifactcafe, .git*), then filter
# files. Paths are relative to DIR with forward slashes.
MANIFEST_NDJSON="$(mktemp)"
IGNORED_LIST="$(mktemp)"
trap 'rm -f "$MANIFEST_NDJSON" "$IGNORED_LIST"' EXIT

file_count=0

while IFS= read -r -d '' abs; do
  rel="${abs#"$DIR"/}"
  base="${abs##*/}"
  if ignored_file "$base"; then
    printf '%s\n' "$rel" >>"$IGNORED_LIST"
    continue
  fi
  size="$(size_of "$abs")"
  if [[ "$size" -le 0 ]]; then
    printf '%s\n' "$rel" >>"$IGNORED_LIST"
    continue
  fi
  hash="sha256_$(sha256_of "$abs")"
  mime="$(mime_for "$rel")"
  jq -n --arg p "$rel" --arg h "$hash" --argjson s "$size" --arg m "$mime" \
    '{path:$p,hash:$h,size:$s,mimeType:$m}' >>"$MANIFEST_NDJSON"
  file_count=$((file_count + 1))
done < <(
  find "$DIR" -type d \( -name node_modules -o -name .artifactcafe -o -name '.git*' \) -prune -o \
    -type f -print0
)

[[ "$file_count" -gt 0 ]] || die "Nothing to publish in $DIR (after ignore rules)."

FILES_JSON="$(jq -s 'sort_by(.path)' "$MANIFEST_NDJSON")"
IGNORED_JSON="$(jq -R -s 'split("\n") | map(select(length > 0))' "$IGNORED_LIST")"
skipped_count="$(jq 'length' <<<"$IGNORED_JSON")"
if [[ "$skipped_count" -gt 0 ]]; then
  preview="$(awk 'NR<=5{printf "%s%s",(NR>1?", ":""),$0} END{if(NR>5)printf ", …"}' "$IGNORED_LIST")"
  log "  ignoring $skipped_count item(s): $preview"
fi

# ── Resolve entry ──────────────────────────────────────────────────────────
have_path() { jq -e --arg p "$1" 'any(.[]; .path == $p)' >/dev/null <<<"$FILES_JSON"; }
if [[ -n "$ENTRY" ]]; then
  have_path "$ENTRY" || die "Entry file \"$ENTRY\" not found in the publish folder."
elif have_path "index.html"; then
  ENTRY="index.html"
else
  # Exactly one top-level .html file is an unambiguous entry.
  root_html="$(jq -r '[.[] | select(.path | test("^[^/]+\\.html$"))] | map(.path) | @tsv' <<<"$FILES_JSON")"
  n=0; [[ -n "$root_html" ]] && n="$(awk -F'\t' '{print NF}' <<<"$root_html")"
  if [[ "$n" -eq 1 ]]; then
    ENTRY="$root_html"
  elif [[ "$n" -eq 0 ]]; then
    die "No entry file found. Add an index.html or pass --entry <file>."
  else
    die "Multiple HTML files found ($root_html). Pass --entry <file>."
  fi
fi

# ── Config & auth (SPEC §5.3 / §5.4) ───────────────────────────────────────
CONFIG_DIR="$DIR/.artifactcafe"
CONFIG_FILE="$CONFIG_DIR/config.json"
cfg() { [[ -f "$CONFIG_FILE" ]] && jq -r --arg k "$1" '.[$k] // empty' "$CONFIG_FILE" 2>/dev/null || true; }
CFG_ARTIFACT_ID="$(cfg artifactId)"
CFG_TOKEN="$(cfg publishToken)"
CFG_API_URL="$(cfg apiUrl)"

ARTIFACT_ID="${ARTIFACT_ID_FLAG:-$CFG_ARTIFACT_ID}"
API_URL="${API_URL_FLAG:-${ARTIFACT_CAFE_URL:-${CFG_API_URL:-$DEFAULT_API_URL}}}"
API_URL="${API_URL%/}"

# The stored token only authorizes its own artifact.
TOKEN=""
if [[ -n "$TOKEN_FLAG" ]]; then
  TOKEN="$TOKEN_FLAG"
elif [[ -n "$ARTIFACT_ID" && "$ARTIFACT_ID" == "$CFG_ARTIFACT_ID" && -n "$CFG_TOKEN" ]]; then
  TOKEN="$CFG_TOKEN"
elif [[ -n "${ARTIFACT_CAFE_TOKEN:-}" ]]; then
  TOKEN="$ARTIFACT_CAFE_TOKEN"
fi

auth_args=()
[[ -n "$TOKEN" ]] && auth_args=(-H "authorization: Bearer $TOKEN")

# ── Create publish session ─────────────────────────────────────────────────
aid_json="null"; [[ -n "$ARTIFACT_ID" ]] && aid_json="$(jq -n --arg a "$ARTIFACT_ID" '$a')"
body="$(
  jq -n \
    --argjson aid "$aid_json" \
    --arg entry "$ENTRY" \
    --argjson files "$FILES_JSON" \
    --arg title "$TITLE" \
    --arg agent "$CLIENT" \
    --arg runid "${ARTIFACT_CAFE_RUN_ID:-}" \
    '{
      artifactId: $aid,
      entryPath: $entry,
      files: $files,
      source: ({type:"cli"}
        + (if $agent == "" then {} else {agent:$agent} end)
        + (if $runid == "" then {} else {runId:$runid} end))
    }
    + (if $title == "" then {} else {title:$title} end)'
)"

api_post() { # path body → prints body, dies on non-2xx with structured error
  local path="$1" data="$2" resp status
  resp="$(curl -sS -X POST ${auth_args[@]+"${auth_args[@]}"} -H "content-type: application/json" \
    --data "$data" -w $'\n%{http_code}' "$API_URL$path")" \
    || die "could not reach $API_URL — is the API up?"
  status="${resp##*$'\n'}"
  local out="${resp%$'\n'*}"
  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    local code msg
    code="$(jq -r '.code // "http_'"$status"'"' <<<"$out" 2>/dev/null || echo "http_$status")"
    msg="$(jq -r '.message // empty' <<<"$out" 2>/dev/null || true)"
    die "${msg:-request failed} [$code]"
  fi
  printf '%s' "$out"
}

log "  publishing $file_count file(s) from $DIR"
session="$(api_post "/api/v1/publish" "$body")"
SESSION_ID="$(jq -r '.publishSessionId' <<<"$session")"
UP_COUNT="$(jq -r '.filesToUpload | length' <<<"$session")"
SKIP_UNCHANGED="$(jq -r '.skippedFiles | length' <<<"$session")"

msg="  uploading $UP_COUNT file(s)"
[[ "$SKIP_UNCHANGED" -gt 0 ]] && msg+=", $SKIP_UNCHANGED unchanged"
log "$msg"

# ── Upload each new blob via its presigned PUT ─────────────────────────────
# The presign signs content-type + content-length; curl sets content-length
# from --data-binary, and we send the matching content-type.
while IFS=$'\t' read -r up_path up_url; do
  [[ -n "$up_path" ]] || continue
  abs="$DIR/$up_path"
  mime="$(mime_for "$up_path")"
  curl -fsS --max-time "$UPLOAD_TIMEOUT" -X PUT \
    -H "content-type: $mime" -H "Expect:" \
    --data-binary @"$abs" "$up_url" >/dev/null \
    || die "upload failed for $up_path"
done < <(jq -r '.filesToUpload[] | [.path, .uploadUrl] | @tsv' <<<"$session")

# ── Finalize ───────────────────────────────────────────────────────────────
result="$(api_post "/api/v1/publish/$SESSION_ID/finalize" "")"
URL="$(jq -r '.url' <<<"$result")"
VERSION="$(jq -r '.versionNumber' <<<"$result")"
NEW_TOKEN="$(jq -r '.publishToken // empty' <<<"$result")"
CLAIM_URL="$(jq -r '.claimUrl // empty' <<<"$result")"
RESULT_ARTIFACT_ID="$(jq -r '.artifactId' <<<"$result")"

# ── Persist config on first publish (never print the token) ────────────────
if [[ -n "$NEW_TOKEN" ]]; then
  slug="${URL##*/a/}"
  mkdir -p "$CONFIG_DIR"
  ( umask 177
    jq -n --arg id "$RESULT_ARTIFACT_ID" --arg slug "$slug" --arg url "$URL" \
      --arg api "$API_URL" --arg tok "$NEW_TOKEN" \
      '{artifactId:$id, slug:$slug, url:$url, apiUrl:$api, publishToken:$tok}' \
      >"$CONFIG_FILE" )
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
  # Add .artifactcafe/ to .gitignore if a .gitignore already exists.
  gi="$DIR/.gitignore"
  if [[ -f "$gi" ]] && ! grep -qE '^/?\.artifactcafe/?$' "$gi"; then
    printf '\n# artifact.cafe publish token\n.artifactcafe/\n' >>"$gi"
  fi
fi

# ── Output ─────────────────────────────────────────────────────────────────
if [[ "$JSON" -eq 1 ]]; then
  jq -n \
    --arg id "$RESULT_ARTIFACT_ID" --argjson v "$VERSION" --arg url "$URL" \
    --arg claim "$CLAIM_URL" --argjson session "$session" --argjson ignored "$IGNORED_JSON" \
    '{
      artifactId:$id, versionNumber:$v, url:$url,
      filesUploaded: ($session.filesToUpload | map(.path)),
      skippedFiles: $session.skippedFiles,
      ignored: $ignored
    } + (if $claim == "" then {} else {claimUrl:$claim} end)'
elif [[ "$VERSION" == "1" ]]; then
  echo ""
  echo "✓ Published to artifact.cafe"
  echo ""
  echo "Review URL:"
  echo "$URL"
  if [[ -n "$CLAIM_URL" ]]; then
    echo ""
    echo "Claim URL (shown once — claim to keep this artifact):"
    echo "$CLAIM_URL"
  fi
  echo ""
else
  echo ""
  echo "✓ Published v$VERSION"
  echo "$URL"
  echo ""
fi

# Best-effort browser open for interactive terminals only.
if [[ "$OPEN" -eq 1 && "$JSON" -eq 0 && -t 1 ]]; then
  if command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 || true
  fi
fi
