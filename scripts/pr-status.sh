#!/usr/bin/env bash
#
# pr-status.sh — concise, multi-PR status check for efficient CI monitoring.
#
# === USAGE ===
# Usage:
#   scripts/pr-status.sh [options] <pr-number> [<pr-number>...]
#   echo "64 65 66" | scripts/pr-status.sh
#
# Options:
#   -h, --help        Show this help and exit
#   -v, --verbose     Show every individual check name and conclusion
#       --json        Emit a JSON array instead of human-readable text
#       --summary     One-line summary per PR
#       --ci-only     Only CI status (omit reviews/mergeable/timestamps)
#       --reviews-only  Only review status (omit CI rollup)
#       --no-cache    Skip reading/writing the local cache
#       --no-color    Disable ANSI colors (also auto-disabled when stdout
#                     is not a terminal or NO_COLOR is set)
#
# Environment:
#   GH_CMD                  Path to the gh binary (default: gh). Tests inject
#                           a stub here.
#   PR_STATUS_CACHE_DIR     Cache directory (default: ${TMPDIR:-/tmp}/pr-status-cache)
#   PR_STATUS_CACHE_TTL     Cache lifetime in seconds (default: 30)
#
# Exit codes:
#   0  All PRs passing / merged / closed without failures
#   1  At least one PR has a failing check or unmergeable conflict
#   2  No failures, but at least one PR has pending checks
#   3  Usage error (bad option, no PRs, non-numeric PR number)
# === END USAGE ===

set -euo pipefail

GH_CMD="${GH_CMD:-gh}"
CACHE_DIR="${PR_STATUS_CACHE_DIR:-${TMPDIR:-/tmp}/pr-status-cache}"
CACHE_TTL="${PR_STATUS_CACHE_TTL:-30}"

VERBOSE=0
JSON=0
SUMMARY=0
CI_ONLY=0
REVIEWS_ONLY=0
USE_CACHE=1
USE_COLOR=1

if [[ -n "${NO_COLOR:-}" ]] || ! [[ -t 1 ]]; then
    USE_COLOR=0
fi

usage() {
    # Extract the block between the === USAGE === sentinels so the help text
    # survives future edits to this header without line-number fixups.
    sed -n '/^# === USAGE ===$/,/^# === END USAGE ===$/p' "$0" \
        | sed '1d;$d' \
        | sed 's/^# \{0,1\}//'
}

die_usage() {
    if [[ $# -gt 0 ]]; then
        printf 'Error: %s\n\n' "$*" >&2
    fi
    usage >&2
    exit 3
}

PR_NUMBERS=()
while (( $# > 0 )); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -v|--verbose) VERBOSE=1 ;;
        --json) JSON=1 ;;
        --summary) SUMMARY=1 ;;
        --ci-only) CI_ONLY=1 ;;
        --reviews-only) REVIEWS_ONLY=1 ;;
        --no-cache) USE_CACHE=0 ;;
        --no-color) USE_COLOR=0 ;;
        --)
            shift
            while (( $# > 0 )); do
                PR_NUMBERS+=("$1"); shift
            done
            break
            ;;
        -*)
            die_usage "unknown option: $1"
            ;;
        *)
            PR_NUMBERS+=("$1")
            ;;
    esac
    shift
done

if (( ${#PR_NUMBERS[@]} == 0 )) && ! [[ -t 0 ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Intentional word-splitting so ``echo "64 65 66" | pr-status.sh`` works.
        # Safe because every token is validated against ^[0-9]+$ below.
        # shellcheck disable=SC2206
        toks=( $line )
        for tok in "${toks[@]}"; do
            PR_NUMBERS+=("$tok")
        done
    done
fi

if (( ${#PR_NUMBERS[@]} == 0 )); then
    die_usage "no PR numbers supplied"
fi

for n in "${PR_NUMBERS[@]}"; do
    if ! [[ "$n" =~ ^[0-9]+$ ]]; then
        die_usage "'$n' is not a valid PR number"
    fi
done

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not found in PATH" >&2
    exit 3
fi

if (( USE_COLOR )); then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m'
    C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'
    C_CYAN=$'\033[36m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_GREEN=''
    C_RED=''
    C_YELLOW=''
    C_CYAN=''
fi

file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

fetch_pr() {
    local num="$1"
    local cache_file="$CACHE_DIR/$num.json"
    if (( USE_CACHE )) && [[ -f "$cache_file" ]]; then
        local mtime now age
        mtime=$(file_mtime "$cache_file" || echo 0)
        now=$(date +%s)
        age=$(( now - mtime ))
        if (( age >= 0 && age < CACHE_TTL )); then
            cat "$cache_file"
            return 0
        fi
    fi

    local fields
    fields="number,title,state,url,author,headRefName,baseRefName,createdAt,updatedAt,mergeable,mergeStateStatus,reviewDecision,reviews,comments,statusCheckRollup"
    # ``local data`` is declared on its own line so the subsequent command
    # substitution's exit status propagates to ``set -e``. Combining
    # ``local data=$(...)`` would mask the gh failure because ``local``
    # always succeeds.
    local data
    if ! data=$("$GH_CMD" pr view "$num" --json "$fields" 2>&1); then
        printf 'Error: failed to fetch PR #%s: %s\n' "$num" "$data" >&2
        return 1
    fi
    if (( USE_CACHE )); then
        mkdir -p "$CACHE_DIR"
        # Write via a tempfile + rename so a crash/interrupt can't leave a
        # truncated cache file that the next run would read as valid JSON.
        local tmp_file
        tmp_file=$(mktemp "${CACHE_DIR}/.pr-${num}-XXXXXX.json")
        printf '%s' "$data" > "$tmp_file"
        mv "$tmp_file" "$cache_file"
    fi
    printf '%s' "$data"
}

map_mergeable() {
    case "$1" in
        MERGEABLE) echo "YES" ;;
        CONFLICTING) echo "NO" ;;
        "") echo "UNKNOWN" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Input: raw gh JSON for one PR on stdin.
# Output: a normalized JSON object on stdout containing the fields the rest
# of the script (and the --json mode) needs.
normalize_pr() {
    jq '
      def passing_conclusions: ["SUCCESS", "NEUTRAL", "SKIPPED"];
      def failing_conclusions: ["FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"];

      def short_updated: (.updatedAt // "" | sub("T"; " ") | sub("Z$"; "") | .[0:16]);

      def mergeable_label:
        (.mergeable // "") as $m
        | if $m == "MERGEABLE" then "YES"
          elif $m == "CONFLICTING" then "NO"
          else "UNKNOWN" end;

      (.statusCheckRollup // []) as $checks
      | ($checks | length) as $total
      | ([$checks[] | select((.status // "") == "COMPLETED" and ((.conclusion // "") | IN(passing_conclusions[])))] | length) as $passing
      | ([$checks[] | select((.status // "") == "COMPLETED" and ((.conclusion // "") | IN(failing_conclusions[])))] | length) as $failing
      | ([$checks[] | select((.status // "") != "COMPLETED")] | length) as $pending
      | ([(.reviews // [])[] | select(.state == "APPROVED")] | length) as $approvals
      | ((.comments // []) | length) as $comment_count
      | (if $total == 0 then "none"
         elif $failing > 0 then "failing"
         elif $pending > 0 then "pending"
         else "passing" end) as $ci_state
      | {
          number: .number,
          title: (.title // ""),
          state: (.state // ""),
          url: (.url // ""),
          author: ((.author // {}).login // ""),
          headRefName: (.headRefName // ""),
          baseRefName: (.baseRefName // ""),
          createdAt: (.createdAt // ""),
          updatedAt: (.updatedAt // ""),
          updatedShort: short_updated,
          mergeable: mergeable_label,
          mergeStateStatus: (.mergeStateStatus // ""),
          ci: {
            total: $total,
            passing: $passing,
            failing: $failing,
            pending: $pending,
            state: $ci_state,
            checks: [$checks[] | {
              name: (.name // ""),
              status: (.status // ""),
              conclusion: (.conclusion // "")
            }]
          },
          reviews: {
            approvals: $approvals,
            decision: (.reviewDecision // ""),
            comments: $comment_count
          }
        }
    '
}

ci_human_line() {
    local total="$1" passing="$2" failing="$3" pending="$4" state="$5"
    case "$state" in
        passing)
            printf '%s✅ All passing (%d/%d checks)%s' \
                "$C_GREEN" "$passing" "$total" "$C_RESET"
            ;;
        failing)
            printf '%s❌ %d failing (%d/%d checks)%s' \
                "$C_RED" "$failing" "$failing" "$total" "$C_RESET"
            ;;
        pending)
            local started=$(( total - pending ))
            printf '%s⏳ Pending (%d/%d checks started)%s' \
                "$C_YELLOW" "$started" "$total" "$C_RESET"
            ;;
        none|*)
            printf '%s— No checks reported%s' "$C_DIM" "$C_RESET"
            ;;
    esac
}

pluralize() {
    # $1 count, $2 singular, $3 plural
    if [[ "$1" == "1" ]]; then
        printf '%s' "$2"
    else
        printf '%s' "$3"
    fi
}

render_default() {
    local norm="$1"
    local number title state approvals decision comments mergeable updated
    local ci_total ci_pass ci_fail ci_pending ci_state

    number=$(jq -r '.number' <<<"$norm")
    title=$(jq -r '.title' <<<"$norm")
    state=$(jq -r '.state' <<<"$norm")
    approvals=$(jq -r '.reviews.approvals' <<<"$norm")
    decision=$(jq -r '.reviews.decision' <<<"$norm")
    comments=$(jq -r '.reviews.comments' <<<"$norm")
    mergeable=$(jq -r '.mergeable' <<<"$norm")
    updated=$(jq -r '.updatedShort' <<<"$norm")
    ci_total=$(jq -r '.ci.total' <<<"$norm")
    ci_pass=$(jq -r '.ci.passing' <<<"$norm")
    ci_fail=$(jq -r '.ci.failing' <<<"$norm")
    ci_pending=$(jq -r '.ci.pending' <<<"$norm")
    ci_state=$(jq -r '.ci.state' <<<"$norm")

    printf '%s=== PR #%s: %s ===%s\n' "$C_BOLD" "$number" "$title" "$C_RESET"

    if (( ! REVIEWS_ONLY )); then
        printf 'Status: %s\n' "$state"
    fi

    if (( ! REVIEWS_ONLY )); then
        printf 'CI: '
        ci_human_line "$ci_total" "$ci_pass" "$ci_fail" "$ci_pending" "$ci_state"
        printf '\n'

        if (( VERBOSE )); then
            local checks
            checks=$(jq -c '.ci.checks[]' <<<"$norm")
            while IFS= read -r chk; do
                [[ -z "$chk" ]] && continue
                local cname cstatus cconclusion badge
                cname=$(jq -r '.name' <<<"$chk")
                cstatus=$(jq -r '.status' <<<"$chk")
                cconclusion=$(jq -r '.conclusion' <<<"$chk")
                case "$cconclusion" in
                    SUCCESS|NEUTRAL|SKIPPED) badge="${C_GREEN}✓${C_RESET}" ;;
                    FAILURE|TIMED_OUT|CANCELLED|ACTION_REQUIRED|STARTUP_FAILURE) badge="${C_RED}✗${C_RESET}" ;;
                    "") badge="${C_YELLOW}…${C_RESET}" ;;
                    *) badge="${C_DIM}?${C_RESET}" ;;
                esac
                local label="$cconclusion"
                [[ -z "$label" ]] && label="$cstatus"
                printf '  %b %s: %s\n' "$badge" "$cname" "$label"
            done <<<"$checks"
        fi
    fi

    if (( ! CI_ONLY )); then
        local approval_word comment_word
        approval_word=$(pluralize "$approvals" "approval" "approvals")
        comment_word=$(pluralize "$comments" "comment" "comments")
        if [[ -n "$decision" && "$decision" != "null" ]]; then
            printf 'Reviews: %s %s, %s %s (%s)\n' \
                "$approvals" "$approval_word" \
                "$comments" "$comment_word" \
                "$decision"
        else
            printf 'Reviews: %s %s, %s %s\n' \
                "$approvals" "$approval_word" \
                "$comments" "$comment_word"
        fi
        printf 'Mergeable: %s\n' "$mergeable"
        if [[ -n "$updated" && "$updated" != "null" ]]; then
            printf 'Last updated: %s\n' "$updated"
        fi
    fi

    if (( VERBOSE )); then
        local url author head base
        url=$(jq -r '.url' <<<"$norm")
        author=$(jq -r '.author' <<<"$norm")
        head=$(jq -r '.headRefName' <<<"$norm")
        base=$(jq -r '.baseRefName' <<<"$norm")
        printf 'Author: %s\n' "$author"
        printf 'Branch: %s -> %s\n' "$head" "$base"
        printf 'URL: %s\n' "$url"
    fi

    printf '\n'
}

render_summary() {
    local norm="$1"
    local number state ci_state ci_total ci_pass ci_fail ci_pending
    local approvals comments mergeable badge
    number=$(jq -r '.number' <<<"$norm")
    state=$(jq -r '.state' <<<"$norm")
    ci_total=$(jq -r '.ci.total' <<<"$norm")
    ci_pass=$(jq -r '.ci.passing' <<<"$norm")
    ci_fail=$(jq -r '.ci.failing' <<<"$norm")
    ci_pending=$(jq -r '.ci.pending' <<<"$norm")
    ci_state=$(jq -r '.ci.state' <<<"$norm")
    approvals=$(jq -r '.reviews.approvals' <<<"$norm")
    comments=$(jq -r '.reviews.comments' <<<"$norm")
    mergeable=$(jq -r '.mergeable' <<<"$norm")
    case "$ci_state" in
        passing) badge="${C_GREEN}✅${C_RESET} ${ci_pass}/${ci_total}" ;;
        failing) badge="${C_RED}❌${C_RESET} ${ci_fail}/${ci_total} fail" ;;
        pending) badge="${C_YELLOW}⏳${C_RESET} $(( ci_total - ci_pending ))/${ci_total}" ;;
        *) badge="${C_DIM}—${C_RESET}" ;;
    esac
    printf '#%s %-6s %b  %s approvals, %s comments  mergeable=%s\n' \
        "$number" "$state" "$badge" "$approvals" "$comments" "$mergeable"
}

OVERALL="passing"   # 0 => passing
update_overall() {
    local incoming="$1"
    case "$incoming" in
        failing) OVERALL="failing" ;;
        pending)
            if [[ "$OVERALL" != "failing" ]]; then
                OVERALL="pending"
            fi
            ;;
    esac
}

# Accumulate normalized PRs so we can emit JSON at the end if requested.
NORMALIZED=()

for num in "${PR_NUMBERS[@]}"; do
    raw=$(fetch_pr "$num")
    norm=$(printf '%s' "$raw" | normalize_pr)
    NORMALIZED+=("$norm")
    ci_state=$(jq -r '.ci.state' <<<"$norm")
    update_overall "$ci_state"
    mergeable=$(jq -r '.mergeable' <<<"$norm")
    if [[ "$mergeable" == "NO" ]]; then
        OVERALL="failing"
    fi
done

if (( JSON )); then
    printf '%s\n' "${NORMALIZED[@]}" | jq -s '.'
elif (( SUMMARY )); then
    for norm in "${NORMALIZED[@]}"; do
        render_summary "$norm"
    done
else
    for norm in "${NORMALIZED[@]}"; do
        render_default "$norm"
    done
fi

case "$OVERALL" in
    failing) exit 1 ;;
    pending) exit 2 ;;
    *) exit 0 ;;
esac
