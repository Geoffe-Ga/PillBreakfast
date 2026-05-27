#!/usr/bin/env bash
# scripts/ralph/pick-next.sh
#
# Ralph's picker. Picks the lowest-numbered open issue that is a real,
# unblocked implementation child issue. Prints the issue number on stdout, or
# nothing if no eligible issue exists.
#
# Rules:
#   - Must have label `spec-decomposition`.
#   - Must NOT have label `epic` (epics are tracking only).
#   - Must NOT have label `future-work` or `needs-spec` (deferred / unspecified).
#   - Must not already have an open PR pointing at it (`Closes #N` or `Fixes #N`
#     in the PR body, case-insensitive). We check this so Ralph never opens a
#     second PR for the same issue while iteration is in flight.
#
# Usage:
#   scripts/ralph/pick-next.sh
#
# Exit codes:
#   0 — issue number printed (or nothing if backlog empty)
#   2 — gh CLI not authenticated / missing
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "pick-next: gh CLI not found" >&2
  exit 2
fi

# Open child issues, ascending by number. jq filters out epic/future-work/needs-spec.
candidates=$(
  gh issue list \
    --state open \
    --label spec-decomposition \
    --limit 200 \
    --json number,title,labels \
    --jq '
      sort_by(.number)
      | map(select(
          (.labels | map(.name) | index("epic")) == null
          and (.labels | map(.name) | index("future-work")) == null
          and (.labels | map(.name) | index("needs-spec")) == null
        ))
      | .[].number
    '
)

if [[ -z "$candidates" ]]; then
  exit 0
fi

# Build the set of issue numbers already addressed by an open PR.
# `gh pr list` body contains things like "Closes #34" or "Fixes #34"; we grep
# those out. Single regex run keeps this cheap even with many open PRs.
inflight=$(
  gh pr list \
    --state open \
    --limit 200 \
    --json number,body \
    --jq '.[].body' \
  | grep -oiE '(closes|fixes|resolves)[[:space:]]+#[0-9]+' \
  | grep -oE '[0-9]+' \
  | sort -u || true
)

# Print the lowest candidate that isn't already in-flight.
while IFS= read -r n; do
  [[ -z "$n" ]] && continue
  if [[ -z "$inflight" ]] || ! grep -qx "$n" <<<"$inflight"; then
    echo "$n"
    exit 0
  fi
done <<<"$candidates"

# No eligible issue (all open ones already have PRs in flight, or backlog drained).
exit 0
