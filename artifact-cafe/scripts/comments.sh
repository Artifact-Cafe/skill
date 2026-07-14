#!/usr/bin/env bash
# artifact.cafe — zero-Node comment pull.
#
# Fallback for environments without Node/npx. When Node is available,
# prefer `npx artifact-cafe comments` (same data, nicer formatting).
# Reads the artifact linked in ./.artifactcafe/config.json and prints
# the review threads (the agent's read side of the comment loop).
#
# Requires: bash, curl, jq.
set -euo pipefail

DEFAULT_API_URL="https://artifact.cafe"

DIR="."
JSON=0
STATUS="open"      # open | resolved | all
VERSION="current"  # current | all
ARTIFACT_ID_FLAG=""
TOKEN_FLAG=""
API_URL_FLAG=""

usage() {
  cat <<'USAGE'
Usage: comments.sh [dir] [options]

Options:
  --status <s>    open | resolved | all   (default: open)
  --version <v>   current | all           (default: current)
  --artifact <id> Read an artifact by id instead of the linked folder
                  (else read from config / $ARTIFACT_CAFE_ARTIFACT_ID)
  --token <token> Publish token, for a password-protected artifact
                  (else read from config / $ARTIFACT_CAFE_TOKEN)
  --api-url <url> API base (default: https://artifact.cafe)
  --json          Machine-readable output
  -h, --help      Show this help
USAGE
  exit "${1:-1}"
}
die() { echo "error: $1" >&2; exit 1; }

for cmd in curl jq; do command -v "$cmd" >/dev/null 2>&1 || die "requires $cmd"; done

DIR_SET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)   STATUS="$2"; shift 2 ;;
    --version)  VERSION="$2"; shift 2 ;;
    --artifact) ARTIFACT_ID_FLAG="$2"; shift 2 ;;
    --token)    TOKEN_FLAG="$2"; shift 2 ;;
    --api-url)  API_URL_FLAG="$2"; shift 2 ;;
    --json)     JSON=1; shift ;;
    -h|--help)  usage 0 ;;
    -*)         die "unknown option: $1" ;;
    *)         [[ "$DIR_SET" -eq 0 ]] && { DIR="$1"; DIR_SET=1; shift; } || die "unexpected argument: $1" ;;
  esac
done

case "$STATUS" in open|resolved|all) ;; *) die "--status must be open | resolved | all" ;; esac
case "$VERSION" in current|all) ;; *) die "--version must be current | all" ;; esac

CONFIG_FILE="$DIR/.artifactcafe/config.json"
cfg() { [[ -f "$CONFIG_FILE" ]] && jq -r "(.$1 // \"\")" "$CONFIG_FILE" 2>/dev/null || echo ""; }
CFG_ARTIFACT_ID="$(cfg artifactId)"
CFG_URL="$(cfg url)"
CFG_API_URL="$(cfg apiUrl)"

# artifactId: --artifact → $ARTIFACT_CAFE_ARTIFACT_ID → config.
ARTIFACT_ID="${ARTIFACT_ID_FLAG:-${ARTIFACT_CAFE_ARTIFACT_ID:-$CFG_ARTIFACT_ID}}"
[[ -n "$ARTIFACT_ID" ]] || die "No artifact to read in $DIR — run publish.sh there first, or pass --artifact <id> (or set ARTIFACT_CAFE_ARTIFACT_ID)."

API_URL="${API_URL_FLAG:-${ARTIFACT_CAFE_URL:-${CFG_API_URL:-$DEFAULT_API_URL}}}"
API_URL="${API_URL%/}"

# Token authorizes reads of a password-protected artifact; public reads need
# none. The folder token only speaks for its own artifact (like publish.sh).
TOKEN=""
if [[ -n "$TOKEN_FLAG" ]]; then
  TOKEN="$TOKEN_FLAG"
elif [[ "$ARTIFACT_ID" == "$CFG_ARTIFACT_ID" && -n "$(cfg publishToken)" ]]; then
  TOKEN="$(cfg publishToken)"
elif [[ -n "${ARTIFACT_CAFE_TOKEN:-}" ]]; then
  TOKEN="$ARTIFACT_CAFE_TOKEN"
fi
auth_args=()
[[ -n "$TOKEN" ]] && auth_args=(-H "authorization: Bearer $TOKEN")

# Review URL for display: known from config, else derive it from the slug.
URL="$CFG_URL"
if [[ -z "$URL" || "$ARTIFACT_ID" != "$CFG_ARTIFACT_ID" ]]; then
  slug="$(curl -sS ${auth_args[@]+"${auth_args[@]}"} "$API_URL/api/v1/artifacts/$ARTIFACT_ID" \
    | jq -r '.slug // empty' 2>/dev/null || true)"
  [[ -n "$slug" ]] && URL="$API_URL/a/$slug" || URL="$API_URL/a/$ARTIFACT_ID"
fi

resp="$(curl -sS ${auth_args[@]+"${auth_args[@]}"} -w $'\n%{http_code}' \
  "$API_URL/api/v1/artifacts/$ARTIFACT_ID/comments/export?status=$STATUS&version=$VERSION")" \
  || die "could not reach $API_URL"
code="${resp##*$'\n'}"
data="${resp%$'\n'*}"
[[ "$code" -ge 200 && "$code" -lt 300 ]] || \
  die "$(jq -r '.message // ("http_" + ("'"$code"'"))' <<<"$data" 2>/dev/null)"

if [[ "$JSON" -eq 1 ]]; then
  echo "$data"
  exit 0
fi

count="$(jq -r '.comments | length' <<<"$data")"
if [[ "$count" -eq 0 ]]; then
  echo "No $STATUS comments ($VERSION) — $URL"
  exit 0
fi
echo "$count $STATUS thread(s) — $URL"
echo ""
jq -r '
  .comments[] |
  ((if .status == "resolved" then "✓" else "●" end) + " " + .author +
     " · v" + (.versionNumber|tostring) + " · " + (.createdAt[0:10]) + " · " + .id),
  ("  ↳ " + (if .anchor.type == "text" then ("\"" + (.anchor.quote // "") + "\"")
            else (.anchor.elementPath // "element") end)),
  ("  " + (.body | gsub("\n"; "\n  "))),
  (.replies[]? | "    " + .author + ": " + (.body | gsub("\n"; "\n    "))),
  ""
' <<<"$data"
