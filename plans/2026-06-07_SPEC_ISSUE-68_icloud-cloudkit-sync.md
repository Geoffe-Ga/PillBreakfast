# SPEC — iCloud Sync via CloudKit-backed SwiftData

| | |
|---|---|
| **Issue** | #68 |
| **Classification** | Future Work (SPEC §12.2) |
| **Labels** | `spec-decomposition`, `future-work`, `needs-spec` |
| **Status** | Draft |
| **Date** | 2026-06-07 |
| **Related** | Epic #11 |

---

## 1. Summary

Make the existing App-Group SwiftData store **CloudKit-backed** (private database) so a user's regimen and history converge across multiple devices via iCloud — and resolve the hard question that creates: what happens to the v1 WatchConnectivity (WC) sync path. **Recommendation: CloudKit *augments*, it does not replace, WC.** WC remains the authoritative, low-latency, phone-off-tolerant channel for the watch logging ritual; CloudKit handles multi-*phone* / new-device convergence and acts as a durable backup. The watch is **not** added as a CloudKit sync peer in this phase.

## 2. Problem Statement / Motivation

v1 is single-phone + single-watch with no cloud component — the entire store lives in one App-Group container per device and syncs only over WC. SPEC §12.2: *"v1 is single-watch + single-phone. CloudKit-backed SwiftData would be a natural v2."* Motivations: a new iPhone restores the full regimen+history without re-entry; an iPad companion could read history; the store survives device loss. 

**Why deferred from v1:** CloudKit imposes real constraints on the `@Model` graph (no `@Attribute(.unique)`, all relationships optional, no `deleteRule: .cascade` enforced by the store — see §4/§5) that conflict with the *current* schema, which leans on `@Attribute(.unique) var id` and cascade deletes throughout. Adopting CloudKit is a schema-discipline change best done deliberately, after the model has stabilized through v1 dogfooding — not while the data model is still moving (note the live `currentSchemaVersion = 4` history in `RegimenSnapshot`).

## 3. Goals & Non-Goals

**Goals**
- Private-database CloudKit mirror of the existing SwiftData store, gated by user opt-in / iCloud availability.
- A clean migration from the current local store to a CloudKit-compatible schema + container config.
- A defined relationship between CloudKit and the existing WC path (which is authoritative for what).
- Conflict-resolution policy for the rare cross-device write.
- Graceful behavior when iCloud is unavailable (no account, restricted, offline).

**Non-Goals**
- **Not** making the watch a CloudKit peer. The watch keeps syncing via WC (rationale §5.3). CloudKit on watchOS is possible but adds account/entitlement complexity for no logging-ritual benefit.
- **Not** caregiver/shared-zone sharing — that's #69 (`CKShare`), a different threat model.
- **Not** a public/shared CloudKit database. Private only.
- **Not** changing the watch logging UX at all.

## 4. Background & Current State

- `Shared/Persistence/PersistenceController.swift`: `@MainActor PersistenceController` builds a `ModelContainer` from `let configuration = ModelConfiguration(url: url)` where `url = appGroupStoreURL` (App-Group `group.com.creekmasons.pillbreakfast`). **There is no `cloudKitDatabase:` argument today** — this is precisely the line CloudKit changes.
- `schema`: `[Ingredient, MedicationComponent, Medication, ScheduledDose, DoseEvent, SnoozeRecord, PillMeal]` — established additive-migration discipline noted inline.
- **Schema features that conflict with CloudKit:**
  - `@Attribute(.unique) var id: UUID` on `Ingredient`, `MedicationComponent`, `Medication`, `ScheduledDose`, `DoseEvent`, `PillMeal`. **CloudKit-backed SwiftData forbids `.unique`.**
  - `@Relationship(deleteRule: .cascade, …)` on `Medication.components/schedule/doseEvents`. **CloudKit requires relationships to be optional and does not enforce cascade server-side** (SwiftData applies cascade locally, but the mirrored records must tolerate optionality).
  - Relationships are already largely optional (`Medication?`, `Ingredient?`, `PillMeal?`) — good. The `Medication` non-optional arrays (`[MedicationComponent]`, etc.) default to `[]`, which is CloudKit-acceptable.
- **WC sync (the incumbent):**
  - `WatchConnectivityCoordinator` pushes the regimen iPhone→watch via `updateApplicationContext(["regimen": data])`; the watch applies `RegimenSnapshot` (`Shared/Sync/RegimenSnapshot.swift`, `currentSchemaVersion = 4`, validate-before-mutate, archive-never-delete).
  - Doses flow watch→iPhone via `DoseEventBatchTransfer` (`transferFile`, idempotent upsert keyed on `DoseEvent.id` in `DoseEventBatchMerger`).
  - **Authority today is implicit:** iPhone owns the regimen (one-way push); watch owns dose creation (reverse merge). `apply(to:)` uses **upsert-by-id** and **archive-never-delete** — already conflict-tolerant by construction.

**SPEC §12.2 quoted:** *"iCloud sync for multi-device. v1 is single-watch + single-phone. CloudKit-backed SwiftData would be a natural v2."* SPEC §4 (Persistence row): *"CloudKit-backed for free phone↔watch sync if desired in v2."*

## 5. Detailed Design

### 5.1 Container configuration

```swift
let configuration = ModelConfiguration(
  url: Self.appGroupStoreURL,
  cloudKitDatabase: .private("iCloud.com.creekmasons.pillbreakfast")
)
```

Plus entitlements on the iOS target: iCloud → CloudKit, the container `iCloud.com.creekmasons.pillbreakfast`, and `remote-notification` background mode (already present per CLAUDE.md capabilities) so SwiftData's `NSPersistentCloudKitContainer` underpinnings receive silent pushes.

**Gating:** CloudKit must be conditional on iCloud availability and user opt-in. When no iCloud account exists (or the user opts out), open the *same* App-Group store with a **local-only** `ModelConfiguration` (no `cloudKitDatabase:`). The store URL is identical, so toggling cloud on later mirrors the existing local data up; toggling off leaves the local store intact. This requires the local and cloud configs to be schema-identical (they are — same `Schema`).

### 5.2 Schema changes CloudKit forces

1. **Drop `@Attribute(.unique)` from every `id`.** CloudKit cannot enforce uniqueness. Replace the *uniqueness invariant* with application-level upsert-by-id (which the codebase **already does everywhere it matters** — `RegimenSnapshot.apply(to:)`, `DoseEventBatchMerger.merge`, `MedicationFormState.apply`). Removing `.unique` is therefore lower-risk here than in most apps, because no code relies on the store to reject a duplicate id; all merge paths fetch-by-id and upsert. Audit for any `FetchDescriptor` that assumes at-most-one row per id (they all use `.first`, which stays correct).
2. **All relationships optional / collections default-empty.** `MedicationComponent.medication/ingredient`, `ScheduledDose.medication/pillMeal`, `DoseEvent.medication` are already optional. `Medication`'s child arrays default to `[]`. `PillMeal.scheduledDoses` defaults to `[]`. Verify no relationship is non-optional-singular.
3. **Cascade deletes:** keep `deleteRule: .cascade` for local behavior; understand that CloudKit mirrors deletions as record deletions and SwiftData replays the cascade locally on each device. Orphan cleanup (already handled defensively, e.g. `InlineIngredientCleanup`, archive-never-delete) remains the safety net.
4. **Versioned migration:** introduce an explicit `VersionedSchema` + `SchemaMigrationPlan`. The `.unique`→non-unique transition is a metadata-only change to the model classes (the stored data is unaffected; SwiftData rebuilds the store description). Stage it as a single migration; validate against a populated local store fixture.

### 5.3 The reconciliation question — CloudKit vs. WC (the hard part)

**Decision: CloudKit augments WC; WC stays authoritative for the watch ritual. The watch is not a CloudKit peer.**

Reasoning:
- The product's hard requirement (CLAUDE.md, SPEC §8.1) is that the **watch works when the phone is off** — notifications scheduled on the watch, logging on the watch. CloudKit needs network + iCloud reachability and offers **no** delivery guarantee while the watch is offline or the phone is away. WC's `updateApplicationContext` (latest-wins, persisted) and `transferFile` (queued until reachable) are purpose-built for exactly the offline pairing case. Replacing WC with CloudKit would *regress* the core reliability property.
- CloudKit on watchOS adds entitlement/account surface and battery cost for a sync the watch doesn't need: the watch only needs the *current active regimen* (small, already delivered by WC) and to *emit doses* (already delivered by WC reverse channel).
- Therefore CloudKit's job is **phone↔phone / phone↔iPad / new-device restore / durable backup** — convergence across the user's *non-watch* devices and over time. WC's job is unchanged: **phone↔watch**, the only link that must survive the phone being off.

**Authority model after #68:**
- **Regimen:** the SwiftData store (whichever device the user edits on) is the source of truth; CloudKit converges it across phones/iPads. The watch continues to receive the regimen via WC `updateApplicationContext` from *the* paired phone. If two phones edit the regimen, CloudKit converges them (last-writer-wins per field, see §5.4) and the converged result is what gets pushed to the watch.
- **Dose events:** created on the watch, delivered to the paired phone via `DoseEventBatchTransfer` (unchanged), then mirrored to CloudKit and fanned out to other devices. `DoseEvent` is **append-mostly** (immutable history except `notes`, per `DoseEventBatchMerger`), so cross-device dose conflicts are nearly impossible by construction.
- **No double-write loop:** because the watch is not a CloudKit peer, there's no risk of WC and CloudKit both writing the same row on the watch. On the phone, a dose arriving via WC and the *same* dose arriving via CloudKit are reconciled by the existing **upsert-by-`DoseEvent.id`** (idempotent — a re-seen id is a no-op except a changed note). This is the key reason the two channels coexist safely: every merge path is already id-keyed and idempotent.

### 5.4 Conflict resolution

- **DoseEvent:** practically conflict-free (immutable except `notes`). Policy: id-keyed upsert; for `notes`, last-writer-wins by `takenAt`-adjacent modification (or simply "non-nil newer note wins," matching the current `DoseEventBatchMerger` rule). CloudKit's per-record server change tag handles ordering.
- **Regimen entities (`Medication`, `Ingredient`, schedule, meals):** CloudKit-mirrored SwiftData resolves at the **record/field** level with last-writer-wins. For PillBreakfast this is acceptable because regimen edits are rare and single-user; the realistic conflict (same user edits on two phones minutes apart) resolves to the later edit. **Archive-never-delete** (already the rule in `RegimenSnapshot.apply`) prevents a stale-device deletion from destroying history.
- **Ingredient safety ceilings:** highest-consequence field. Last-writer-wins is acceptable but the **watch must always re-derive `violationsIfTaken` from the currently-synced ceilings** (it already reads them from the applied snapshot), so a converged ceiling is enforced on the next watch open.

### 5.5 Concurrency

No new isolation surface: `PersistenceController` stays `@MainActor`, `NSPersistentCloudKitContainer` operates under SwiftData's hood. The DTO/value-type boundary (`RegimenSnapshot`, `DoseEventDTO`, `LoggedIngredientAmount`) is unchanged and still the only thing crossing the WC/actor boundary. **No `@unchecked Sendable`** is introduced.

## 6. Alternatives Considered

| Decision | Options | Verdict |
|---|---|---|
| CloudKit role | Replace WC entirely / augment WC (recommended) / no CloudKit | **Augment.** Replacing WC regresses phone-off reliability; CloudKit handles non-watch convergence + backup. |
| Watch as CloudKit peer | Yes / no (recommended) | **No.** Adds entitlement/battery surface for a sync WC already does better for the offline ritual. |
| Database scope | Private / shared(`CKShare`) / public | **Private.** Sharing is #69's concern with a stricter threat model. |
| Uniqueness after dropping `.unique` | App-level upsert-by-id (recommended) / synthetic compound keys / accept dupes | **App-level upsert.** Already the de-facto pattern in every merge path; low marginal risk. |
| Migration shape | `VersionedSchema` + plan (recommended) / new store + copy | **Versioned migration.** `.unique`-removal is metadata-only; staged migration is cleaner than a copy. |
| Offline fallback | Local-only `ModelConfiguration` on same URL (recommended) / block app until iCloud / separate stores | **Same-URL local config.** Lets cloud toggle on/off without data loss. |

## 7. UX & Visual Design

- Settings (iPhone Tab 3, per SPEC §6.3) gains an **iCloud Sync** toggle + status ("Synced just now" / "Waiting for iCloud" / "iCloud unavailable — using this device only"). Liquid Glass, monochrome, no accent color.
- First-launch / first-enable: a one-screen explainer that medical data will be stored in the user's **private** iCloud (encrypted, Apple-account-scoped, not shared). 
- No watch-facing UI changes.

## 8. Edge Cases & Failure Modes

- **No iCloud account / signed out:** open local-only config; app fully functional; status shows "using this device only."
- **iCloud restricted (MDM/Screen Time):** same local-only fallback.
- **Account switch:** SwiftData/CloudKit scopes the mirror to the signed-in account; on switch, the local App-Group store persists but the cloud mirror re-scopes. Surface a "signed-in account changed" note; never silently merge two users' data.
- **Schema-version skew across devices:** an older device must tolerate records with fields it doesn't know (CloudKit ignores unknown record fields). Keep all schema additions additive, exactly as `RegimenSnapshot` already does.
- **Large initial sync** (months of `DoseEvent`s on a new device): CloudKit batches; the `#Index<DoseEvent>([\.takenAt])` keeps post-sync queries off a full scan.
- **WC + CloudKit double-delivery of a dose:** idempotent upsert-by-id no-ops the duplicate (the safety property that makes augmentation viable).
- **Quota exceeded:** CloudKit private DB counts against the user's iCloud; surface a clear error; local store keeps working.

## 9. Privacy, Security & Compliance

- This is **PHI in the cloud** — the central new risk. CloudKit **private database** is end-to-end scoped to the user's Apple ID and encrypted in transit and at rest by Apple. It is *not* shared with anyone (that's #69).
- **Opt-in, not default-on**, with an explicit explainer. The user must be able to turn it off and keep using the app locally.
- **Privacy nutrition label delta** (explicit issue open question): declare "Health & Fitness → Health" / "Sensitive Info" data linked to the user and stored in iCloud; disclose CloudKit usage. No third-party sharing, no tracking.
- No analytics on synced data. No server we operate (Apple's CloudKit only).
- Document that disabling iCloud and reinstalling will not silently re-upload unless re-enabled.

## 10. Testing Strategy

- **Migration:** populated local-store fixture (with `.unique` ids and cascade graphs) migrates cleanly to the CloudKit-compatible schema; counts and relationships preserved.
- **Idempotent reconciliation:** same `DoseEvent.id` arriving via WC and via CloudKit yields one row (existing `DoseEventBatchMerger` tests extended).
- **Authority:** regimen edited on phone A converges to phone B, then pushes to the watch via WC; verify the watch sees the converged regimen.
- **Offline fallback:** no-account environment opens local-only config; full CRUD works; re-enabling cloud mirrors existing rows up.
- **Conflict policy:** concurrent regimen edits resolve last-writer-wins; archive-never-delete prevents history loss.
- CloudKit-dependent tests run against the local CloudKit dev environment / are gated so CI without an iCloud account still passes (the local-only path must be testable headless).
- **No `@unchecked Sendable` / no swallowed errors** in any new sync code.

## 11. Risks & Open Questions

- **`.unique` removal blast radius** — audit every fetch/merge that could now see duplicate ids. (Current code is already upsert-by-id everywhere, mitigating this.)
- **Migration on a populated production store** — must be validated on a real dogfood store before shipping.
- **Last-writer-wins on ingredient ceilings** — is field-level LWW acceptable for a safety value, or do we want a merge that keeps the *stricter* ceiling? Open for grooming; recommend "stricter wins" as a custom reconciliation if feasible.
- **CloudKit dev/prod schema promotion** — CloudKit schema must be promoted to production before App Store release; coordinate with release process.
- **Watch-as-peer revisited?** If a future multi-watch scenario emerges, re-evaluate; v2 keeps the watch WC-only.

## 12. Decomposition Hints (post-v1, tracer-code order)

1. Schema discipline pass: drop `@Attribute(.unique)`, confirm relationship optionality; `VersionedSchema` + `SchemaMigrationPlan`; migration tests. *(Local-only; no cloud yet — stays green.)*
2. Entitlements + container id; conditional `ModelConfiguration` (cloud vs. local-only) with availability gating.
3. Settings toggle + status UI; opt-in explainer.
4. Reconciliation hardening: assert idempotency where WC and CloudKit overlap (dose upsert, regimen archive-never-delete).
5. Conflict policy for ingredient ceilings (stricter-wins if adopted).
6. Privacy nutrition-label delta + in-app disclosure.
7. CloudKit schema promotion to production in the release runbook.

## 13. Acceptance Criteria / Done-Done

- Regimen + history converge across two phones signed into the same iCloud account.
- The watch continues to receive the regimen and emit doses over WC, unchanged, **including when the phone is off** (no regression).
- A dose seen via both WC and CloudKit produces exactly one row.
- No-iCloud-account devices run fully on the local-only store and can later enable sync without data loss.
- Migration from the current local store is validated on a populated fixture.
- Privacy nutrition label updated; opt-in explainer shipped.
- No anti-bypass violations.

## 14. References

- `plans/SPEC.md` §12.2, §4 (Persistence/Sync rows), §5 (data model), §8.1 (watch-off requirement).
- Code: `Shared/Persistence/PersistenceController.swift`, all `Shared/Models/*.swift` (esp. `.unique` + cascade usage), `Shared/Sync/WatchConnectivityCoordinator.swift`, `Shared/Sync/RegimenSnapshot.swift`, `Shared/Sync/DoseEventBatchTransfer.swift`, `Shared/Sync/DoseEventBatchDTO.swift`.
- Apple: SwiftData + CloudKit (`ModelConfiguration(cloudKitDatabase:)`, `NSPersistentCloudKitContainer`), CloudKit private database, `VersionedSchema`/`SchemaMigrationPlan`.
- CLAUDE.md: HealthKit read-only/iOS-only; watch-off requirement; denormalization rules.
- Issues: #68, epic #11.
