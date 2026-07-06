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

DIR="."
JSON=0
STATUS="open"      # open | resolved | all
VERSION="current"  # current | all

usage() {
  cat <<'USAGE'
Usage: comments.sh [dir] [options]

Options:
  --status <s>    open | resolved | all   (default: open)
  --version <v>   current | all           (default: current)
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
    --status)  STATUS="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --json)    JSON=1; shift ;;
    -h|--help) usage 0 ;;
    -*)        die "unknown option: $1" ;;
    *)         [[ "$DIR_SET" -eq 0 ]] && { DIR="$1"; DIR_SET=1; shift; } || die "unexpected argument: $1" ;;
  esac
done

case "$STATUS" in open|resolved|all) ;; *) die "--status must be open | resolved | all" ;; esac
case "$VERSION" in current|all) ;; *) die "--version must be current | all" ;; esac

CONFIG_FILE="$DIR/.artifactcafe/config.json"
[[ -f "$CONFIG_FILE" ]] || die "No artifact linked in $DIR — run publish.sh there first."
ARTIFACT_ID="$(jq -r '.artifactId' "$CONFIG_FILE")"
URL="$(jq -r '.url' "$CONFIG_FILE")"
API_URL="${ARTIFACT_CAFE_URL:-$(jq -r '.apiUrl' "$CONFIG_FILE")}"
API_URL="${API_URL%/}"

resp="$(curl -sS -w $'\n%{http_code}' \
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
