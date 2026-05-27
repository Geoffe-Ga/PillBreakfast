---
description: One tick of the local Ralph Wiggum loop. Re-entrant — figures out where the loop is and does the next atomic thing.
---

You are Ralph Wiggum's brain for one tick of PillBreakfast's local outer loop.

> Caffeinated, on Geoff's MacBook, driven by `/loop /ralph-tick`. The `/loop`
> skill will fire you again whenever your turn ends (either by scheduled
> wakeup or by a `<github-webhook-activity>` event delivered through your
> active PR subscription). Be **re-entrant**: every tick reads state from
> disk and figures out what to do — never assume continuity with the
> previous tick.

## Step 0 — Pause check, then read state

```bash
# Honour the pause flag before doing anything.
if [ -f scripts/ralph/.paused ]; then
  echo "Ralph is paused (scripts/ralph/.paused exists). Sleeping."
  # Schedule a long wakeup (~30 min) so the loop wakes occasionally to re-check,
  # but does not burn cycles. ScheduleWakeup, then end the turn.
  exit 0
fi
cat scripts/ralph/state.json
```

If the pause file is present, call `ScheduleWakeup` (delay ~1800s) with the
reason "ralph paused — re-checking later" and end the turn. Do NOT pick or
work.

Otherwise, read `state.json` and continue.

Then determine **which of the four modes** this tick is in:

| Mode | Trigger condition | Action |
| --- | --- | --- |
| **A. Backlog drained** | `scripts/ralph/pick-next.sh` returns empty AND no open PR for Ralph's work | Announce "Backlog drained. Ralph is done." and call `/loop` to **stop**. End the loop. |
| **B. In-flight PR** | An open PR exists with `Closes #N` for an issue Ralph has been working | Inspect the PR (`gh pr view --comments`). Branch by status (Step 2). |
| **C. Groom gate** | No in-flight PR AND `state.completed_since_groom >= state.groom_interval` | Run Step 1 (Groom), reset counter, then fall through to D. |
| **D. New issue** | No in-flight PR AND counter below threshold | Pick next issue and start work (Step 3). |

Determine "in-flight PR" by:

```bash
gh pr list --state open --author "@me" --json number,headRefName,body \
  --jq '.[] | select(.body | test("(?i)(closes|fixes|resolves)\\s+#[0-9]+"))'
```

(Substitute `@me` with the appropriate user if the local CLI is authenticated
as someone else; we only care about Ralph-authored PRs, which are PRs whose
body has a `Closes #N` referencing a `spec-decomposition` child issue.)

---

## Step 1 — Groom gate (every Nth tick, before picking)

When `completed_since_groom >= groom_interval`:

1. Invoke `/backlog-grooming` as a Skill. Let the skill do its full pass —
   close resolved issues, identify gaps, file any missing issues. Do not
   second-guess it.
2. Reset the counter:
   ```bash
   python3 -c "
   import json, datetime
   p='scripts/ralph/state.json'
   s=json.load(open(p))
   s['completed_since_groom']=0
   s['last_groom_at']=datetime.datetime.now().isoformat()
   json.dump(s, open(p,'w'), indent=2)
   "
   ```
3. Commit the state change on the current branch (or directly on `main` if
   not on a feature branch — state-only changes are not load-bearing).
4. Fall through to Step 3 (pick next).

---

## Step 2 — In-flight PR: branch by status

Pull the PR's latest comments and CI checks:

```bash
PR_NUM=<the open PR's number>
gh pr view "$PR_NUM" --comments --json state,mergeable,statusCheckRollup,comments
```

Look at:

- **The latest `Verdict:` comment** (posted by `claude-code-review.yml`).
- **The latest `<!-- iteration-trigger -->` comment** (posted by
  `iteration-trigger.yml`).
- **Statuscheck rollup** (CI pass/fail).
- **PR state** (open/merged/closed).

Then branch:

### 2a. PR is `MERGED`

The `iteration-trigger.yml` auto-merge already fired (or you merged
manually). Process completion:

```bash
ISSUE_N=<the issue number this PR closed>
python3 -c "
import json, datetime
p='scripts/ralph/state.json'
s=json.load(open(p))
s['completed_since_groom']+=1
s['total_completed']+=1
s['last_completed_issue']=$ISSUE_N
json.dump(s, open(p,'w'), indent=2)
"
git checkout main && git pull --ff-only
```

Then fall through to Step 3 (pick next).

### 2b. Latest verdict is `LGTM` AND CI is fully green AND PR still `OPEN`

Auto-merge should have fired but hasn't yet. Wait one short cycle:

- Call `mcp__github__subscribe_pr_activity` for this PR if not already
  subscribed.
- `ScheduleWakeup` for ~120 seconds with reason "awaiting auto-merge".
- End turn. Next tick will re-evaluate.

If three consecutive ticks have observed this state without the merge
firing, the auto-merge gate may be broken — squash-merge manually:

```bash
gh pr merge "$PR_NUM" --squash --delete-branch
```

Then fall through to Step 3.

### 2c. Latest verdict is `CHANGES_REQUESTED` or `COMMENTS`

Invoke the **`address-feedback`** skill. It will:

- Parse the verdict comment, triage blockers/problems/nits.
- TDD-fix locally, commit, push.
- Reply to threads and resolve them.
- Re-subscribe to PR activity.

When `address-feedback` returns, end the turn. The push will fire CI and
the reviewer; subscription wakes you when the next verdict lands.

### 2d. CI failed (status check rollup includes a failure)

Invoke the **`ci-debugging`** skill on the failing check. Fix locally,
push. End the turn after pushing — subscription wakes you on the next CI
completion.

### 2e. PR open, no verdict yet, CI in progress

Subscribe to PR activity (if not already subscribed) via the
`await-claude-review` skill:

```
/skill await-claude-review
```

Or call `mcp__github__subscribe_pr_activity` directly. End the turn.
Subscription wakes you when a comment lands or CI fails. (CI passes are
NOT delivered as events — the reviewer's verdict comment is what gates
the next action.)

---

## Step 3 — Pick next issue and open a PR

```bash
ISSUE_N=$(scripts/ralph/pick-next.sh)
```

If empty → Mode A (backlog drained). Announce and call `/loop` to stop the
loop. We are done.

Otherwise, work the issue. The contract is identical to
`scripts/ralph/PROMPT.md` (read it now, substituting `$RALPH_ISSUE` →
the picked number). In short:

1. `git checkout main && git pull --ff-only`
2. `git checkout -b issue/$ISSUE_N-<short-slug>`
3. Read `gh issue view $ISSUE_N --comments`, `CLAUDE.md`, `plans/SPEC.md`.
4. Implement using `stay-green` (TDD) and `max-quality-no-shortcuts`
   (no bypass annotations).
5. `pre-commit run --all-files` clean before commit.
6. Commit with the project's conventional-commit + Co-Authored-By
   trailer.
7. `git push -u origin <branch>`.
8. Open PR with `gh pr create --body-file <tmpfile>`. Body must include
   `Closes #$ISSUE_N` (lets the picker recognise it next tick), `Refs
   #<parent-epic>`, a `## Summary` and `## Test plan`.
9. Subscribe to the new PR's activity via `await-claude-review` /
   `mcp__github__subscribe_pr_activity`.
10. End the turn. The inner loop will fire: CI → reviewer comment →
    iteration-trigger comment → subscription delivers it → you wake →
    Step 0 again.

If an issue turns out to be genuinely blocked (depends on something
unbuilt), comment on the issue explaining the block, apply the
`needs-spec` label via `gh issue edit`, and **do not** open a PR. End the
turn; next tick the picker will skip it and pick the next one.

---

## Hard rules (do not deviate)

- **One issue per tick of work.** Never bundle.
- **Never write to `main` directly** except for state-only changes
  (`scripts/ralph/state.json`).
- **Never force-push.**
- **Never disable a CI check or pre-commit hook.** If a hook fails for an
  environmental reason (e.g. SwiftFormat not on PATH), install the tool;
  do not bypass.
- **Re-entrancy first.** Always read `state.json` and PR state at the top
  of the tick. Never assume the previous tick succeeded.
- **End the turn after each atomic action.** Webhook subscription is the
  preferred wake signal; `ScheduleWakeup` (~30 min) is the fallback.

## Anti-bypass (verbatim, non-negotiable)

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`,
> `@available(*, deprecated)` shims to hide warnings, force-unwraps to
> silence the optional checker, `@unchecked Sendable` to silence Swift 6
> concurrency, or `try?` that swallows errors silently. Fix the root cause.
> The only exception is the documented 4-line escape hatch
> (third-party-SDK bug / OS-version compat / benchmarked-perf / generated
> code) with a review date. See `max-quality-no-shortcuts`.
