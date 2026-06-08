# Epic — Mutation testing the three critical safety modules to ≥85%

## Outcome

The product's three safety-critical modules — `DoseEventWriter`, `IngredientQueries`, `SafetyEvaluator` — are mutation-tested with Muter and reach a mutation score of ≥85% each. The green test suite stops being coverage theater: a `>`→`>=` on the ceiling check, a `<`→`<=` on the interval boundary, a `*`→`+` on ingredient-mg scaling, or a dropped `status == .taken` filter all get killed by sharp boundary / exact-value tests. The tooling is reproducible (`scripts/mutate.sh` + `muter.conf.yml`), documented (`plans/decisions/`), and the achieved score is recorded (`Submission/mutation-report.md`).

## Spec sections

- `plans/2026-06-07_SPEC_ISSUE-65_mutation-testing-safety.md` (full spec)
- SPEC §5.1–§5.3 (ingredient layer, denormalized snapshots, `violationsIfTaken`), §10 Phase 4 (cross-product killer case), §10/§11 Phase 9 (mutation-tested critical paths gate)

## Locked decisions inherited from the spec

- **Tool: Muter** (`https://github.com/muter-mutation-testing/muter`), Homebrew or pinned binary, version recorded in the script header and the decision doc.
- **iOS scheme, not watchOS** — the three modules live in `Shared/` and their tests live in `PillBreakfastTests/`; the iOS simulator boots faster.
- **Scope fence: only the three files.** `muter.conf.yml` lists exactly `Shared/Logging/DoseEventWriter.swift`, `Shared/Queries/IngredientQueries.swift`, `Shared/Safety/SafetyEvaluator.swift`.
- **CI integration is out of scope** — `scripts/mutate.sh` runs locally (30–90 min); the new tests it drives run in CI like any other.
- **No score inflation.** Surviving non-equivalent mutants get real tests. Equivalent mutants are documented, never deleted from the config.

## Child issues

- [ ] **Issue: skeleton** — install Muter, add `muter.conf.yml` (three files, iOS scheme), replace the `scripts/mutate.sh` stub with a real reproducible run (incl. `--version` print and `--dry-run`), capture a baseline score, and write `plans/decisions/2026-06-07_mutation-tester.md`.
- [ ] **Issue: core mutant-killing tests** — drive each of the three modules to ≥85% by adding the boundary / exact-value tests the spec specifies, especially the `<` interval-boundary pair (`tooSoonAtExactIntervalBoundaryIsAllowed` + `…OneSecondBeforeBoundaryFires`) and the cross-product 4000mg acetaminophen exact-`proposed` assertion.
- [ ] **Issue: report + surviving-mutant documentation** — re-run to confirm ≥85% on all three, write `Submission/mutation-report.md` (per-module score, killed/survived/equivalent with explanations, version, date).

## Acceptance for the epic

- Mutation score ≥85% on each of the three modules individually, reproducible via `scripts/mutate.sh`.
- All non-equivalent surviving mutants have corresponding new tests in `PillBreakfastTests/`; equivalent mutants documented, none deleted from config.
- The four spec-named tests exist and pass: `tooSoonAtExactIntervalBoundaryIsAllowed`, `tooSoonOneSecondBeforeBoundaryFires`, `writeDoseEventStoresExactTimestamp`, and a `pageSize`-boundary test.
- `muter.conf.yml`, `scripts/mutate.sh`, `plans/decisions/2026-06-07_mutation-tester.md`, `Submission/mutation-report.md` all present and consistent.
- Both schemes' `xcodebuild test` pass; `pre-commit run --all-files` clean; no `Task.sleep`, force-unwrap, `@unchecked Sendable`, or error-swallowing `try?` in new code.

## Out of scope (for this epic)

- Mutation-testing any module beyond the three critical paths.
- CI integration of the Muter run itself.
- Achieving 100% — equivalent mutants are documented, not chased.

## Sequencing notes

- Parent issue: **#65** (child of phase-epic **#10**, Phase 9: Hardening and Submission Prep).
- Predecessor: EPIC_10_ISSUE_05 (privacy nutrition labels); successor: EPIC_10_ISSUE_07 (soak test).
- Children chain: skeleton (tool + baseline) → core (kill mutants to ≥85%) → polish (report + equivalent-mutant docs).
