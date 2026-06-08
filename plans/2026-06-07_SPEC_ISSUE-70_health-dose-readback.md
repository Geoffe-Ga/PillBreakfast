# SPEC — Issue #70: Health Dose Readback Enrichment

| Field | Value |
|---|---|
| Issue | #70 |
| Phase | Future Work (SPEC §12.4) |
| Labels | `spec-decomposition`, `future-work`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #11 |
| Related | #72 (Feedback Assistant write-access request — the long-term fix this works around), Phase 6 HealthKit import (`PillBreakfast/HealthKitImport/`) |

---

## 1. Summary

PillBreakfast owns its own SwiftData store and prompts on the watch for every scheduled
dose. Apple Health can *also* log medication doses through its own UI (the Health app's
medication reminders). When that happens, PillBreakfast has no idea — so it will still fire
its watch prompt for a dose the user already took, inviting a duplicate log. For a regimen
that includes lithium, a spurious "take this now" prompt for a dose already recorded
elsewhere is exactly the ambiguity the product exists to eliminate.

This feature closes that gap by running an `HKAnchoredObjectQuery` over `HKMedicationDoseEvent`
**on the iPhone only** (the Medications API is iOS-only), detecting doses the user logged in
Health, matching them to a PillBreakfast `Medication` via `healthKitConceptID`, and syncing an
"already taken in Health" signal to the watch over the existing WatchConnectivity channel. The
watch then **suppresses or annotates** the corresponding pending-dose card and notification.
PillBreakfast still never writes to Health — this is strictly read-side enrichment.

---

## 2. Problem Statement / Motivation

**Value.** The product's one job is "make sure Geoff knows what he has and hasn't taken, with
zero ambiguity." A user who keeps medication reminders in *both* Apple Health and PillBreakfast
(a realistic transition state, especially right after onboarding via the Phase 6 import) will be
double-prompted: Health says "take lithium," they take it and tap Health's confirm, then
PillBreakfast's own `UNCalendarNotificationTrigger` fires the same reminder. The user either
re-logs (corrupting their own history and PRN running totals) or learns to ignore PillBreakfast
prompts (eroding trust in a safety tool). Readback enrichment makes the two surfaces agree.

**Why deferred to v1.1.** v1 deliberately treats Health as a *one-way import source for
onboarding only* (SPEC §3.3). The core tap-through UX must be dogfooded first to confirm whether
dual-logging is a real problem in practice or a theoretical one. It also depends on Phase 6's
authorization and query infrastructure (`HealthKitImportService`) already shipping, which it now
has. It is genuinely a nice-to-have: the failure mode is an *extra* prompt, never a *missed* one,
so it is safe to defer.

---

## 3. Goals and Non-Goals

**Goals**
- Detect `HKMedicationDoseEvent`s authored in Apple Health (status `.taken`) via an
  incremental `HKAnchoredObjectQuery`, on the iPhone.
- Match each Health dose event to a local `Medication` through `healthKitConceptID` (the
  link Phase 6 already persists on import).
- Persist the query anchor durably so each pass is a delta, not a full re-scan.
- Sync a compact "this scheduled slot was already taken in Health" signal to the watch over
  the existing WC application-context / file-transfer machinery.
- On the watch, suppress (or visibly annotate) the matching pending-dose card and the matching
  `UNCalendarNotificationTrigger`-driven prompt, without ever recording a `DoseEvent` the user
  did not make on PillBreakfast's own surface.
- Stay strictly read-only against HealthKit. Zero write paths introduced.

**Non-Goals**
- Writing dose events back to Health. Blocked by Apple (SPEC §3.2). That is issue #72's domain.
- Querying Health *from the watch.* The Medications API is iOS/iPadOS/visionOS-only
  (SPEC §3.2). All Health access stays in the `PillBreakfast` app target, never `Shared/`.
- Treating Health as the source of truth. PillBreakfast's SwiftData store remains authoritative
  (SPEC §3.3). The Health signal is an *advisory suppression hint*, not a logged dose.
- Importing dose *history* from Health into PillBreakfast's history/PDF export. (Possible future
  extension; out of scope here — it would muddy authorship provenance in the doctor export.)
- Matching by fuzzy name. Only `healthKitConceptID` matches are honored (see §5.4).

---

## 4. Background and Current State

### 4.1 The HealthKit constraint (quoted)

From SPEC §3.2:

> "Third-party apps cannot write to HealthKit Medications. ... Medications and dose events must
> be authored in the Health app itself. Apps can consume the data but cannot contribute.
> Additionally, the API is documented as iOS / iPadOS / visionOS — not watchOS."

From SPEC §3.3:

> "We treat Apple Health as ... a future *read-back enrichment* (if Health logged a dose via its
> own notification, we can detect and avoid double-prompting). We do not write to Health."

From SPEC §12.4 (this issue's charter):

> "Health dose readback enrichment. If Health logs a dose via its own UI, detect via
> `HKAnchoredObjectQuery` and avoid double-prompting on the watch. Nice-to-have for v1.1."

This feature is the literal realization of the "read-back enrichment" clause, and `healthKitConceptID`
is the hook the spec reserved for it.

### 4.2 What already exists in the codebase

- **`Medication.healthKitConceptID: String?`** (`Shared/Models/Medication.swift`) — base64 of the
  `NSKeyedArchiver`-archived `HKHealthConceptIdentifier`. Populated *only* on import; documented as
  "a link for future readback enrichment ... never a write channel" (CLAUDE.md). This is the join key.
- **`HealthKitImportService`** (`PillBreakfast/HealthKitImport/HealthKitImportService.swift`) — an
  `actor` that already owns the single `HKHealthStore`, requests per-medication read scope via
  `requestPerObjectReadAuthorization(for: HKObjectType.userAnnotatedMedicationType(), predicate:)`,
  and runs a one-shot `HKUserAnnotatedMedicationQuery` accumulating under a `Mutex` for Swift 6
  concurrency. The readback query is a natural sibling method on this actor (or a peer actor sharing
  the store). The `static draft(from:)` helper already shows how the concept identifier is archived
  to the exact same string format stored on `Medication.healthKitConceptID` — we reuse that token
  for matching.
- **`HealthMedicationMapper.isAlreadyImported(_:existingConceptIDs:)`**
  (`PillBreakfast/HealthKitImport/HealthMedicationMapper.swift`) — already does set-membership matching
  on `healthKitConceptID`. The readback matcher is the same idea applied to dose events.
- **`WatchConnectivityCoordinator`** (`Shared/Sync/WatchConnectivityCoordinator.swift`) —
  `updateApplicationContext` carries the regimen iPhone → watch ("latest wins," persists while the
  watch is offline); `transferFile` carries dose-event batches watch → iPhone. The Health
  suppression signal rides one of these (see §5.5).
- **`PendingQueueSelector`** (`Shared/Queue/PendingQueueSelector.swift`) — computes the watch's
  pending-dose set, keyed by `SlotKey(medicationID, hour, minute)`, already excluding slots already
  logged today. This is the exact filter point the suppression hint plugs into.
- **`NotificationScheduler` / `NotificationBootstrap`** (`Shared/Notifications/`) — rebuilds all
  `UNCalendarNotificationTrigger`s on every regimen change ("full rebuild, not a diff," CLAUDE.md).
  A suppression hint participates in this rebuild.

### 4.3 The cross-device shape of the problem

Because the Medications API is iOS-only, the watch **cannot** observe Health directly. The
detection must run on the iPhone and the *result* must be synced. This mirrors the existing
asymmetry: regimen flows iPhone → watch, doses flow watch → iPhone. The suppression hint is a new
iPhone → watch payload, so it belongs on the `updateApplicationContext` / regimen channel family.

---

## 5. Detailed Design

### 5.1 Component overview

```
┌─ iPhone (PillBreakfast app target) ──────────────────────────────┐
│  HealthDoseReadbackService (actor, owns HKHealthStore)            │
│    • requestDoseEventReadAuthorization()                          │
│    • startObserving() → HKAnchoredObjectQuery(updateHandler:)     │
│    • anchor persisted in HealthReadbackAnchorStore (App Group)    │
│         │ new/changed HKMedicationDoseEvent samples               │
│         ▼                                                         │
│  HealthDoseMatcher (pure)                                         │
│    • match concept token → Medication.healthKitConceptID         │
│    • map to HealthTakenSlot(medicationID, day, ~scheduledFor)    │
│         │                                                         │
│         ▼                                                         │
│  Persist HealthTakenSlot rows (SwiftData) + recompute the        │
│  suppression set → WatchConnectivityCoordinator.pushRegimen()    │
└──────────────────────────┬───────────────────────────────────────┘
                           │  updateApplicationContext (regimen + suppressions)
                           ▼
┌─ watch (Shared/) ────────────────────────────────────────────────┐
│  RegimenSnapshot.apply(...) seats suppressions into the store     │
│  PendingQueueSelector excludes suppressed slots                   │
│  NotificationBootstrap.refresh(...) omits suppressed triggers     │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 Authorization scope

Phase 6 already requests **read** access to `userAnnotatedMedicationType()`. Dose events are a
*separate* sample type and require their own per-object read grant. Extend the existing actor's
authorization request to additionally cover `HKMedicationDoseEvent`'s type:

```swift
// PillBreakfast/HealthKitImport/ (iOS-only target — never Shared/)
func requestDoseEventReadAuthorization() async throws -> HealthKitImportAuthorizationResult {
    guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
    do {
        // Dose events are scoped per-medication, same pattern as the import grant.
        try await store.requestPerObjectReadAuthorization(
            for: HKObjectType.medicationDoseEventType(),
            predicate: nil
        )
        return .authorized
    } catch let error as HKError where error.code == .errorUserCanceled {
        return .denied
    }
}
```

The same DTS caveat from the existing code applies verbatim: a successful authorization request
reports only that the *prompt finished*, never whether access was granted, and read
`authorizationStatus(for:)` stays `.notDetermined` by design. So the only honest signal is
"the query returned rows" — the readback feature must degrade gracefully to "no suppressions" when
the user declined, never assume access.

### 5.3 The anchored object query and concurrency

`HKAnchoredObjectQuery` is the right tool because it delivers (a) an initial batch matching the
predicate and (b) a long-lived `updateHandler` that fires with *just the deltas* on subsequent
changes, plus a persistable `HKQueryAnchor`. This matches the existing actor-owned, off-main-actor
HealthKit pattern in `HealthKitImportService`.

```swift
actor HealthDoseReadbackService {
    private let store = HKHealthStore()
    private let anchorStore: HealthReadbackAnchorStore   // App Group-backed
    private var liveQuery: HKAnchoredObjectQuery?

    /// Starts (or restarts) the long-lived observation. Idempotent: a second call
    /// stops the prior query before issuing a new one, so a re-auth or app foreground
    /// can't stack handlers.
    func startObserving(onDoses: @escaping @Sendable ([HealthTakenSlot]) async -> Void) {
        if let liveQuery { store.stop(liveQuery) }

        let anchor = anchorStore.loadAnchor()      // nil on first run → full initial batch
        // Only sample doses with status .taken; .skipped/.missed/.delayed do not
        // represent a consumed dose and must NOT suppress a PillBreakfast prompt.
        let predicate = HKQuery.predicateForMedicationDoseEvent(withStatus: .taken)

        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
            = { [anchorStore] _, samples, deleted, newAnchor, error in
                guard error == nil else { return }   // surfaced via os_log; not swallowed silently
                if let newAnchor { anchorStore.save(newAnchor) }
                let slots = HealthDoseMatcher.slots(from: samples ?? [])
                // Deletions: a dose retracted in Health should *un*-suppress.
                let retracted = HealthDoseMatcher.retractedSlots(from: deleted ?? [])
                Task { await onDoses(slots /* + retractions, see §8 */) }
            }

        let query = HKAnchoredObjectQuery(
            type: HKObjectType.medicationDoseEventType(),
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        liveQuery = query
        store.execute(query)
    }
}
```

Swift 6 notes:
- The actor owns `store` and `liveQuery`; the query's handler runs on an arbitrary HealthKit
  queue, so it must be `@Sendable` and must not touch actor state directly — it hops back via
  `Task { await onDoses(...) }`, exactly as `HealthKitImportService` hops via `Task { @MainActor }`.
- `HealthTakenSlot` is a `Sendable` value type (see §5.4) so it crosses the boundary cleanly.
- `HKQueryAnchor` is `NSSecureCoding`; the anchor store archives it (same technique as the
  concept-ID token) into App Group `UserDefaults` or a small file.

### 5.4 Matching a Health dose event to a Medication

The only sanctioned join key is `healthKitConceptID`. Each `HKMedicationDoseEvent` exposes the
medication concept it belongs to; archive its `HKHealthConceptIdentifier` to the same base64 token
format `HealthKitImportService.draft(from:)` already produces, then look up the local `Medication`.

```swift
enum HealthDoseMatcher {
    /// Pure: no model context, no HK store. Returns advisory slots; the caller
    /// resolves them against the live Medication set.
    static func slots(from samples: [HKSample]) -> [HealthTakenSlot] {
        samples.compactMap { sample in
            guard let dose = sample as? HKMedicationDoseEvent else { return nil }
            guard let token = conceptToken(for: dose) else { return nil }
            return HealthTakenSlot(
                healthKitConceptID: token,
                takenAt: dose.startDate,
                // scheduledDate is the *prescription* slot the Health dose satisfies;
                // it's how we line a Health dose up with a PillBreakfast SlotKey.
                scheduledFor: dose.scheduledDate
            )
        }
    }
}

/// Sendable advisory record. NOT a DoseEvent — it never enters history or PRN totals.
public struct HealthTakenSlot: Codable, Sendable, Hashable {
    public let healthKitConceptID: String
    public let takenAt: Date
    public let scheduledFor: Date?     // the scheduled slot the Health dose satisfied
}
```

**Matching policy decision.** Only `healthKitConceptID` matches suppress a prompt. This means
suppression works *only for medications that were imported from Health* (the sole path that
populates the field). Manually-added meds never carry the token and so are never suppressed —
which is correct: a manually-added med is not the same identity as a Health-tracked one, and
fuzzy name-matching across the two would risk suppressing the wrong drug. The matching open
question in the issue ("name match? concept match?") is resolved firmly in favor of concept-only.
Name matching is explicitly rejected (see §6).

### 5.5 Crossing to the watch

The suppression hint is iPhone → watch state, so it rides the **regimen / application-context
channel**, not the dose-event file channel. Add an optional, additive field to `RegimenSnapshot`
(schema v5 — the snapshot already versions additively; see `RegimenSnapshot.currentSchemaVersion`):

```swift
// Shared/Sync/RegimenSnapshot.swift  (v5, additive — older payloads decode with [] default)
public let healthSuppressedSlots: [HealthSuppressedSlotDTO]

public struct HealthSuppressedSlotDTO: Codable, Sendable, Hashable {
    public let medicationID: UUID    // resolved on iPhone from healthKitConceptID
    public let hour: Int             // derived from scheduledFor in the watch-local calendar
    public let minute: Int
    public let day: Date             // start-of-day the suppression applies to
}
```

Rationale for resolving `healthKitConceptID → medicationID` **on the iPhone** before syncing: the
watch's `RegimenSnapshot` already carries `Medication.id`, and `PendingQueueSelector` keys on
`SlotKey(medicationID, hour, minute)`. Sending a resolved `(medicationID, hour, minute, day)`
lets the watch plug suppression directly into its existing slot index with no new HealthKit
knowledge on the watch — preserving the iOS-only constraint cleanly. The watch never sees a
concept token it can't use.

The hint is **ephemeral and day-scoped**: it suppresses *today's* slot only. Because
`updateApplicationContext` is "latest wins" and persists while the watch is offline, the iPhone
recomputes and re-pushes the suppression set whenever (a) the anchored query fires, or (b) the
regimen changes. Stale next-day suppressions are dropped by the day filter on the watch side.

### 5.6 Watch-side consumption

Two plug points, both already centralized:

1. **`PendingQueueSelector.pendingDoses(at:in:)`** — after computing `loggedSlots`, also exclude
   any slot present in the synced `healthSuppressedSlots` for `now`'s day. One-line addition to the
   existing `guard !loggedSlots.contains(slotKey)` filter (union the two sets, or check both).

2. **`NotificationBootstrap.refresh(from:)`** — when rebuilding `UNCalendarNotificationTrigger`s,
   skip (or down-rank) a trigger whose slot is suppressed for that day. Consistent with the
   "full rebuild on regimen change, not a diff" rule — the suppression set is just another input
   to the rebuild.

**Suppress vs. annotate.** Default behavior is **suppress** (the cleanest, matches §12.4 "avoid
double-prompting"). But because Health and PillBreakfast histories diverge, we keep an **annotate**
fallback for the queue card: if the user opens the watch app anyway (e.g., via complication), the
slot can render a subdued "Logged in Health ✓" state rather than vanishing entirely — so the user
isn't confused about why a scheduled pill is missing from "Right Now." This is a UX toggle
(see §7), not two code paths in the safety layer.

### 5.7 What we still cannot do

PillBreakfast still **cannot write** a `HKMedicationDoseEvent` back to Health. So a dose logged on
the *watch* does not appear in Health. Readback is one-directional (Health → suppress PillBreakfast
prompt). The symmetric case — "PillBreakfast logged it, suppress Health's reminder" — is impossible
under the current API and is precisely what issue #72 petitions Apple to change. This SPEC and #72
are deliberately complementary: #70 makes the best of read-only today; #72 asks for the write that
would obviate half of it.

---

## 6. Alternatives Considered

| Option | Verdict |
|---|---|
| `HKAnchoredObjectQuery` on iPhone, sync resolved slots to watch (chosen) | ✅ Delta-efficient, respects iOS-only + read-only constraints, plugs into existing slot index. |
| `HKObserverQuery` + background delivery instead of anchored | ⚠️ Observer only signals "something changed"; you still need an anchored query to get deltas. Background delivery is a possible *trigger* for refresh (§11) but not a replacement. |
| Match by medication name / fuzzy match | ❌ Risks suppressing the wrong drug (lithium vs. a look-alike). Concept-ID is the only identity Apple guarantees stable. Rejected. |
| Sync the raw Health dose events to the watch and match there | ❌ Violates the iOS-only constraint conceptually and bloats the WC payload; the watch has no use for HK sample objects. |
| Auto-create a `DoseEvent` in PillBreakfast from the Health dose | ❌ Corrupts authorship provenance (the doctor export distinguishes watch/iphone via `LogSource`; there is no `.health` source and adding one implies we logged it). Suppression ≠ logging. Rejected. |
| Suppress permanently (not day-scoped) | ❌ A suppression must expire with the day or a one-off Health log would silently kill a recurring prompt. Day-scoped is required. |
| Do nothing (stay v1) | ⚠️ Acceptable until dogfooding proves dual-logging real; that's why this is future-work. |

---

## 7. UX and Visual Design

The product rule "the iPhone never shows take-pills prompts" is untouched — all UX here is on the
watch, plus an iPhone *settings* toggle.

- **No-double-prompt (default, suppress).** A slot the user already took in Health simply does not
  appear in "Right Now" and fires no notification. The user experiences PillBreakfast as
  *agreeing* with Health.
- **Annotate mode (opt-in, Settings → "Show Health-logged doses").** The slot renders in the queue
  as a non-interactive, subdued glass card: "Lithium · logged in Health" with a small checkmark,
  monochromatic (no amber — amber stays reserved for high-risk press-and-hold per §9 / CLAUDE.md).
  It cannot be tapped to log (it's already taken). This avoids the "where did my scheduled pill go?"
  confusion for users who watch their counts.
- **iPhone Settings additions** (Tab 3, SPEC §6.3): a "Sync from Apple Health" section with the
  dose-event read authorization affordance and a "last readback: 2 min ago" diagnostic, mirroring
  the existing watch-sync diagnostics. No logging UI — strictly setup/review.
- **High-risk interaction.** Suppression for a high-risk med (lithium) is *safe by construction*:
  removing a prompt can never cause a double-dose; it can at most cause a *missed* PillBreakfast
  prompt for a dose that Health already confirmed taken. We still surface high-risk suppressions in
  annotate mode so the user can eyeball that lithium was in fact logged somewhere.

---

## 8. Edge Cases and Failure Modes

- **User declines dose-event read auth.** Query returns nothing; suppression set is empty; behavior
  is identical to v1 (prompt as normal). Fail open to prompting — never fail into silence on a
  safety-critical med.
- **Med not imported from Health (no `healthKitConceptID`).** Never matched, never suppressed. Correct.
- **Health dose retracted/edited.** `HKAnchoredObjectQuery` delivers it via `deletedObjects` /
  a re-delivered sample with changed status. The handler must *un-suppress* (remove the slot from
  the set and re-push). A retracted Health dose must restore the PillBreakfast prompt.
- **Health dose status `.skipped` / `.missed`.** The predicate filters to `.taken` only, so these
  never suppress. A skipped Health dose leaves PillBreakfast's prompt intact (the pill wasn't taken).
- **Scheduled-time mismatch.** Health's `scheduledDate` may not align to PillBreakfast's
  `ScheduledDose.hour/minute` (different reminder times). Matching is by `(medicationID, day)` with
  a tolerance window around the scheduled slot; if no slot matches within tolerance, do **not**
  suppress (avoid suppressing an unrelated slot). Tolerance is an open question (§11).
- **Anchor loss / App reinstall.** First run with `nil` anchor returns the full current batch; the
  predicate limits to recent taken doses (bound the initial query by date, e.g. last 48h) so a fresh
  anchor doesn't suppress doses far in the past.
- **Watch offline at push time.** `updateApplicationContext` persists the latest suppression set;
  the watch applies it on next reachability — but day-scoping means a stale (yesterday) suppression
  is filtered out on apply.
- **Clock skew between devices.** Day boundaries are computed in each device's local calendar
  (consistent with `PendingQueueSelector`'s injected calendar). Edge slots near midnight may
  briefly disagree; acceptable since the failure is at worst an extra prompt.
- **Multiple Health doses for one slot.** Deduplicate by `(medicationID, day, hour, minute)` before
  building the DTO set.

---

## 9. Privacy, Security and Compliance

- **PHI.** Medication dose events are sensitive health data. The readback service reads the
  *minimum*: status, concept identity, scheduled/start dates. It never persists raw Health sample
  bodies — only the derived `HealthTakenSlot` (concept token + dates) and, after resolution, an
  even more reduced `(medicationID, hour, minute, day)` DTO.
- **HealthKit authorization** is per-medication read, requested explicitly with a clear usage
  string. No write scope is ever requested (none exists). The Privacy nutrition label (SPEC §9
  Phase 9) gains a "Health · Read" disclosure for dose events.
- **What crosses the wire.** Only resolved internal UUIDs + times go over WatchConnectivity, never
  HealthKit identifiers or sample objects. The watch never holds a Health concept token.
- **No third-party transmission.** Everything is on-device + the local WC link; no servers.
- **Provenance integrity.** Suppression deliberately does *not* fabricate a `DoseEvent`, so the
  doctor's PDF export (SPEC §2.4) never misrepresents who logged what.

---

## 10. Testing Strategy

- **`HealthDoseMatcher` (pure, no HK):** unit tests mapping fixture `HKMedicationDoseEvent`-shaped
  inputs (via a protocol seam) to `HealthTakenSlot`s; concept-token round-trip equality against the
  format `HealthKitImportService.draft(from:)` produces; `.skipped`/`.missed` produce no slot;
  deletions produce retractions.
- **Resolution layer:** given a `HealthTakenSlot` set and a `Medication` set, assert correct
  `HealthSuppressedSlotDTO` resolution; unmatched concept tokens drop; dedup within a day.
- **`RegimenSnapshot` v5:** additive-decode tests — a v4 payload decodes with
  `healthSuppressedSlots == []` (mirrors the existing v3→v4 `pillMeals` default test).
- **`PendingQueueSelector`:** a suppressed slot is excluded; a suppression for a *different* day is
  ignored; a retraction re-surfaces the slot. Reuses the existing deterministic `now` + injected
  `Calendar` contract.
- **`NotificationBootstrap`:** a suppressed slot produces no `UNCalendarNotificationTrigger`.
- **Authorization seam:** the `HealthKitImporting`-style protocol is extended so the readback path
  is exercised with a fake; the real `HKHealthStore`-touching actor is never instantiated in tests
  (same discipline as the existing import service).
- **Anchor persistence:** save/load round-trip of `HKQueryAnchor` through the anchor store.
- **End-to-end (manual, paired sim + real device):** log a dose in Apple Health's UI, confirm the
  watch prompt for that slot disappears within one foreground/background cycle; retract it in Health,
  confirm the prompt returns.

---

## 11. Risks and Open Questions

- **Latency.** Anchored queries refresh on app launch and (if wired) background delivery. How soon
  after a Health log can we suppress? Realistically: next iPhone foreground or next background
  refresh, then the next WC push. If that's too slow to prevent a near-simultaneous PillBreakfast
  prompt, consider `HKObserverQuery` + `enableBackgroundDelivery(for:frequency:)` as a wake source.
  **Open:** is background delivery available for the medication dose type, and at what frequency?
- **Scheduled-time tolerance.** What window aligns a Health `scheduledDate` to a PillBreakfast
  `SlotKey`? Too tight → misses; too loose → suppresses the wrong slot. Needs dogfooding to tune.
  **Open.**
- **Does `HKObjectType.medicationDoseEventType()` / `predicateForMedicationDoseEvent(withStatus:)`
  exist with those exact spellings in the shipping iOS 26 SDK?** API names here are inferred from the
  WWDC 2025 shape; confirm against Xcode 26 headers before implementation. **Open.**
- **Annotate vs. suppress default.** Ship suppress-only first; add annotate if dogfooding shows
  users are confused by vanishing slots.
- **Concept-ID stability across OS updates.** SPEC/Phase 6 assumes the archived
  `HKHealthConceptIdentifier` bytes are stable; if Apple ever changes the archive, both import and
  readback matching break together (and visibly), which is acceptable.

---

## 12. Decomposition Hints (post-v1 child issues)

1. **#70a — Dose-event read authorization.** Extend the HealthKit actor with
   `requestDoseEventReadAuthorization()`; iPhone Settings affordance + usage string. Tests via the
   protocol seam.
2. **#70b — Anchored query + anchor persistence.** `HealthDoseReadbackService` actor,
   `HealthReadbackAnchorStore`, off-main-actor handler hopping. Returns `HealthTakenSlot`s.
3. **#70c — Matcher + resolution.** Pure `HealthDoseMatcher`; concept-token → `Medication`
   resolution into `HealthSuppressedSlotDTO`. Heavily unit-tested.
4. **#70d — `RegimenSnapshot` v5 + WC push.** Additive schema field, encode/apply, re-push on
   readback fire.
5. **#70e — Watch consumption.** `PendingQueueSelector` + `NotificationBootstrap` suppression;
   retraction handling.
6. **#70f — Annotate mode + Settings toggle** (optional, gated on dogfooding).
7. **#70g — Background refresh trigger** (`HKObserverQuery` + background delivery), only if latency
   proves unacceptable.

---

## 13. Acceptance Criteria / Done-Done

- [ ] iPhone requests per-medication **read** authorization for `HKMedicationDoseEvent`; never
      requests write.
- [ ] An `HKAnchoredObjectQuery` observes `.taken` dose events; the `HKQueryAnchor` persists across
      launches in the App Group; each pass processes deltas only.
- [ ] Health dose events match local `Medication`s **only** via `healthKitConceptID`; unmatched and
      manually-added meds are never suppressed.
- [ ] A resolved, day-scoped suppression set syncs iPhone → watch on the regimen channel
      (`RegimenSnapshot` v5, additively decodable from v4).
- [ ] The watch suppresses the matching pending-dose card (`PendingQueueSelector`) and notification
      (`NotificationBootstrap`) for that day; a retracted/skipped Health dose un-suppresses.
- [ ] No `DoseEvent` is ever fabricated from a Health dose; PRN totals and the PDF export are
      unaffected.
- [ ] Declined authorization fails open to normal prompting.
- [ ] All new + existing tests pass; `pre-commit run --all-files` clean; both targets build and run
      on the paired simulator.
- [ ] No anti-bypass violations (no `@unchecked Sendable`, force-unwraps, or swallowed `try?` —
      HealthKit errors are logged via `os.Logger`, not discarded).
- [ ] PR opens with `Refs #11` and `Closes #70`.

---

## 14. References

- `plans/SPEC.md` §3 (HealthKit constraint), §3.3 (read-back enrichment clause), §3.4
  (alternatives), §5.2/§5.3 (data model, denormalized snapshot), §7.1 (Right Now), §8 (notifications),
  §12.4 (this charter).
- `CLAUDE.md` — HealthKit read-only/iOS-only; `healthKitConceptID` is a readback link, never a write
  channel; full-rebuild notifications; iPhone never logs.
- Code: `Shared/Models/Medication.swift`, `PillBreakfast/HealthKitImport/HealthKitImportService.swift`,
  `PillBreakfast/HealthKitImport/HealthMedicationMapper.swift`, `Shared/Sync/WatchConnectivityCoordinator.swift`,
  `Shared/Sync/RegimenSnapshot.swift`, `Shared/Queue/PendingQueueSelector.swift`,
  `Shared/Notifications/NotificationScheduler.swift`, `Shared/Notifications/NotificationBootstrap.swift`.
- Apple: HealthKit `HKAnchoredObjectQuery`, `HKMedicationDoseEvent`, `HKQueryAnchor`,
  `HKObserverQuery` + `enableBackgroundDelivery`, per-object read authorization (WWDC 2025
  "Meet the HealthKit Medications API").
- Related issues: #72 (write-access advocacy — the complementary long-term fix), Phase 6 HealthKit import.
