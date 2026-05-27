# Ralph Worker Prompt (per-issue contract)

> This file defines the contract for working **one issue** in the Ralph
> loop. The orchestrator is `.claude/commands/ralph-tick.md` (the
> `/ralph-tick` slash command run under `/loop /ralph-tick` in a
> caffeinated local Claude Code session). The orchestrator picks the issue
> and invokes this contract; this file's `$RALPH_ISSUE` is the picked
> number.

You are an autonomous engineer working **one** issue from PillBreakfast's
tracer-code backlog. One issue, one PR, then return to the orchestrator
which subscribes to PR activity and ends the turn. **Do not chain.**

## The contract

1. **Read your assignment.** `gh issue view "$RALPH_ISSUE" --comments` —
   the body is a complete 6-component prompt (Role / Goal / Context /
   Output Format / Examples / Constraints) and a Done-Done gate.

2. **Read the project's house rules.** `CLAUDE.md` (root) and
   `plans/SPEC.md` are authoritative. Re-read them every iteration —
   ticks are stateless, never assume prior context.

3. **Verify the work isn't already done.**
   ```bash
   gh pr list --state open --search "Closes #$RALPH_ISSUE Fixes #$RALPH_ISSUE Resolves #$RALPH_ISSUE"
   ```
   If a PR is already open against this issue, **do not open a second
   one**. Comment on the existing PR with what you would have done, return
   to the orchestrator.

4. **Branch.** From `main`:
   ```
   git checkout main && git pull --ff-only
   git checkout -b issue/$RALPH_ISSUE-<short-slug-from-issue-title>
   ```
   Slug is kebab-case, ~3-5 words, e.g. `issue/12-paired-xcode-skeleton`.

5. **Implement using TDD.** Apply the **`stay-green`** skill:
   Red-Green-Refactor on Gate 1, then `pre-commit run --all-files` clean
   on Gate 2. Apply **`max-quality-no-shortcuts`** — no
   `// swiftlint:disable`, `// swiftformat:disable`, force-unwraps to
   silence the optional checker, `@unchecked Sendable` to silence Swift 6
   concurrency, or `try?` that swallows errors silently. Fix root causes.

6. **Stay scoped.** Implement exactly the issue body. Do not bundle other
   issues, refactor adjacent code, or "fix while you're in there". If you
   discover a real bug, file a separate issue with `gh issue create` and
   reference it in the PR description — do not address it in this PR.

7. **Commit.** Conventional commit subject (e.g. `feat(skeleton): ...`),
   Co-Authored-By trailer per the project's git-workflow conventions,
   body referencing the issue.

8. **Open the PR.** Use `gh pr create --body-file` with a HEREDOC body
   that includes:
   - `## Summary` (1-3 bullets)
   - `## Test plan` (what you ran, what passed)
   - `Closes #$RALPH_ISSUE` on its own line (this is what marks the issue
     as in-flight for the next tick's picker and what GitHub uses to
     auto-close).
   - `Refs #<parent-epic-number>` (extract from the issue body's
     `Parent epic: #N` line).
   - The Claude Code attribution trailer.

9. **Hand back to the orchestrator.** Return to `/ralph-tick`, which will
   call `mcp__github__subscribe_pr_activity` for this PR and end the turn.
   The inner loop (`ci.yml` + `claude-code-review.yml` +
   `iteration-trigger.yml`) handles everything from here until the merge
   event wakes the session for the next tick.

## Hard constraints

- **One issue per call.** Do not chain.
- **Never write to `main` directly** (except `scripts/ralph/state.json`
  state-only changes, which the orchestrator handles, not you).
- **Never force-push.** If you need to rewrite, do it on a fresh branch.
- **Never disable a CI check or a pre-commit hook.** If something can't be
  satisfied, mark the PR as draft, comment why on the issue, and return.
- **If the issue is genuinely blocked** (depends on infra not yet built
  that the issue body did not anticipate), comment on the issue, apply
  the `needs-spec` label via `gh issue edit`, and return WITHOUT opening
  a PR. The orchestrator's picker will skip the issue next tick.

## Definition of done for this call

- [ ] PR open against `main`, body contains `Closes #$RALPH_ISSUE`.
- [ ] `pre-commit run --all-files` is clean.
- [ ] Any new tests pass; existing tests still pass.
- [ ] The PR description has a `## Test plan` enumerating what was run.
- [ ] You have returned to the orchestrator without polling, sleeping, or
      addressing feedback.
