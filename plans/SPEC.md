# PillBreakfast — Product & Engineering Specification

> A minimalist medication tracking app for Apple Watch, optimized for someone who takes a dozen pills a day across maintenance and as-needed regimens, with safety-critical doses (e.g. lithium) that must not be doubled.

**Targets:** watchOS 26 + iOS 26
**Design language:** Liquid Glass
**Author of this spec:** Geoff
**Audience of this spec:** Claude Code (and future Geoff)
**Status:** Draft v1.0 — ready for tracer-code execution

---

## 1. Vision

PillBreakfast is a watch-first medication tracker that turns the daily pill regimen into a tap-through ritual: glance, tap, done. Each prompted pill is its own page on the watch — never a checklist. The user opens the app (or the notification fires), taps a single confirmation per medication, and moves on. The iPhone exists only so the user can define the regimen once and review history with a psychiatrist; in steady state, the phone never opens.

The product has one job: **make sure Geoff knows what he has and hasn't taken, with zero ambiguity, on the device that's already on his wrist.**

---

## 2. North-Star User Journeys

### 2.1 Morning Maintenance (Lithium 300mg AM)

1. 8:00 AM — Watch notification fires: "Morning pills · 4 to take."
2. Tap notification → opens watch app on first prompted med.
3. Screen 1: **Lithium 300mg** — single Confirm button, with a *high-risk* confirmation gesture (e.g. press-and-hold 0.5s) to prevent accidental tap.
4. Tap Confirm → screen advances to next pill.
5. Screens 2–4: remaining maintenance meds, each a simple single-tap confirm.
6. Final screen: "All morning pills logged ✓" — Liquid Glass success state.

### 2.2 Snooze Until Specific Time

1. Notification fires at 8:00 AM. Geoff is brushing teeth.
2. Long-press notification → action menu → **Snooze**.
3. Wheel picker appears: "Until [10:17 PM]" — idiomatic clock-style time picker.
4. Tap Done. Local notification rescheduled for 10:17 PM.
5. Watch complication continues to show "4 pills pending."

### 2.3 PRN Dose (Gabapentin)

1. Geoff feels anxious. Opens app from watch face complication.
2. Tap "Take as-needed" → PRN section.
3. Sees: "**Gabapentin** · 600mg taken today · last dose 11:42 AM."
4. Tap Gabapentin → quantity picker: 1 pill (100mg) / 2 pills (200mg) / 3 pills (300mg).
5. Pick 3 → confirm → logged. Running total now reads "900mg today."
6. If a dose would exceed the configured daily ceiling (1200mg) or violate min-interval, the app shows a soft warning before confirming. Geoff can override.

### 2.4 Doctor Export

1. Geoff opens iPhone companion before psychiatrist appointment.
2. Tap "Export 30 days" → PDF generated → shares via standard share sheet (Mail, Messages, Files).
3. PDF shows date-grouped log of every dose: time taken, medication, dosage, status (taken/skipped/snoozed), running daily totals for PRN meds.

---

## 3. Critical Architecture Decision: The HealthKit Medications Constraint

The single biggest architecture decision is informed by an Apple API constraint that was not obvious before research.

### 3.1 What Apple Health Medications Offers (iOS 26)

Apple introduced the HealthKit Medications API at WWDC 2025. It exposes two new types:
- `HKUserAnnotatedMedication` — represents a medication with user customizations (name, nickname, schedule, archived flag).
- `HKMedicationDoseEvent` — an `HKSample` representing a logged dose, with status `.taken / .skipped / .missed / .delayed`, scheduled date, quantity.

The API supports per-medication read authorization (user picks which meds your app can see) and anchored object queries for efficient sync.

### 3.2 The Constraint

**Third-party apps cannot write to HealthKit Medications.** This is confirmed directly by Apple DTS:
> "Medication data is read-only in HealthKit." — Apple Developer Forums, 2025

Medications and dose events must be authored in the **Health app itself**. Apps can consume the data but cannot contribute.

Additionally, the API is documented as `iOS / iPadOS / visionOS` — **not** watchOS. HealthKit access on the watch is still possible for other data types, but the medication-specific objects must be queried from the iPhone and synced to the watch via WatchConnectivity.

### 3.3 Decision

**PillBreakfast owns its own data.** SwiftData store on each device, WatchConnectivity for sync.

We treat Apple Health as an *optional one-way import source for onboarding* (so the user doesn't have to type Lithium twice if they already have it set up in Health), and as a future *read-back enrichment* (if Health logged a dose via its own notification, we can detect and avoid double-prompting). We do not write to Health.

This decision also unlocks the **PRN running-total feature**, which Health cannot provide to us under any model — we need our own write-capable store regardless.

### 3.4 Alternatives Considered

| Option | Verdict |
| --- | --- |
| Pure Health piggyback (read-only) | ❌ Breaks the core watch tap-through UX — user would have to log doses in Health's own UI. |
| Health as authority + our app as viewer | ❌ Same problem. Also no PRN running totals. |
| Our own store + Health import (chosen) | ✅ Owns the full UX; Health enhances onboarding only. |
| Our own store + no Health integration | ⚠️ Works but loses one-tap onboarding. Fallback if HealthKit auth proves painful. |

---

## 4. Tech Stack

| Layer | Choice | Rationale |
| --- | --- | --- |
| OS targets | watchOS 26, iOS 26 | Required for Liquid Glass and HealthKit Medications API. |
| Language | Swift 6 (strict concurrency) | Senior-track learning goal: master actor isolation and `Sendable`. |
| UI | SwiftUI | Native to both platforms; Liquid Glass is SwiftUI-first. |
| Persistence | SwiftData | Modern, type-safe, plays well with `@Observable`. CloudKit-backed for free phone↔watch sync if desired in v2. |
| Sync | WatchConnectivity (`WCSession`) | Direct phone↔watch for initial regimen seed and history. |
| Notifications | UserNotifications framework | Local-only; no server needed. Custom action for snooze-until-time. |
| HealthKit | Read-only, iPhone only | Optional onboarding import + future dose readback. |
| Widgets | WidgetKit + ActivityKit | Complication on watch face; Smart Stack widget. |
| Design language | Liquid Glass (`.glassEffect()` / `Material` APIs) | watchOS 26 system look. |
| Build/CI | Xcode 17 + Xcode Cloud | Standard. |

---

## 5. Data Model

SwiftData. Each model below maps to a `@Model` class. Identical schema on iPhone and watch; sync via WatchConnectivity application context + transferable file for history.

### 5.1 The Ingredient Layer (Why This Looks More Complicated Than You'd Expect)

A naive medication tracker uses one row per product: `Tylenol Extra Strength → 500mg`. That works until you take a combination product. Excedrin Extra Strength contains 250mg acetaminophen + 250mg aspirin + 65mg caffeine per tablet. NyQuil contains acetaminophen + doxylamine + dextromethorphan. If PillBreakfast just tracks products, you could take 1500mg of standalone Tylenol *and* 4 Excedrin (1000mg more acetaminophen) and the app would happily show "Tylenol: 1500mg today" while you sail past the 4000mg acetaminophen ceiling that actually matters.

Safety ceilings are properties of the *active ingredient*, not the product. So PillBreakfast models both layers: `Medication` is what you buy and take; `Ingredient` is what your liver has to process. The running-total and ceiling logic operates on ingredients, aggregated across all medications taken today.

For single-ingredient meds (Lithium, Gabapentin, plain Tylenol), this is a one-component setup at entry — slightly more clicks once, then invisible. For combo products, it Just Works. Most importantly: by putting the ingredient layer in v1, we avoid a migration if you ever start taking a combo product later.

### 5.2 Schema

```swift
@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var name: String                 // "Acetaminophen"
    var aliases: [String]            // ["Paracetamol", "APAP"] — for import matching
    var isHighRisk: Bool             // requires press-and-hold confirm on any product containing it

    // Safety thresholds live HERE, not on the product.
    // User-configurable. Defaults are suggestions, not medical advice.
    var dailyCeilingMg: Double?      // e.g., 4000 for acetaminophen
    var minIntervalMinutes: Int?     // e.g., 240 = 4hr spacing
}

@Model
final class MedicationComponent {
    // The join table: "this product contains X mg of this ingredient per unit"
    @Attribute(.unique) var id: UUID
    var medication: Medication?
    var ingredient: Ingredient?
    var dosagePerUnitMg: Double      // 500.0 = 500mg acetaminophen per Tylenol Extra Strength tablet
}

@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var displayName: String          // "Tylenol Extra Strength"
    var fullName: String?            // "Acetaminophen 500mg"
    var unitForm: MedicationForm     // .tablet | .capsule | .liquid | .other
    var kind: MedicationKind         // .maintenance | .prn
    var colorHex: String?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date

    // Optional Health link, populated only if imported
    var healthKitConceptID: String?

    // PRN UX config (per-product, not per-ingredient)
    var prnAvailableQuantities: [Int]  // [1, 2] for Tylenol Extra Strength

    @Relationship(deleteRule: .cascade, inverse: \MedicationComponent.medication)
    var components: [MedicationComponent]   // 1 for simple meds, 2-4 for combos

    @Relationship(deleteRule: .cascade, inverse: \ScheduledDose.medication)
    var schedule: [ScheduledDose]

    @Relationship(deleteRule: .cascade, inverse: \DoseEvent.medication)
    var doseEvents: [DoseEvent]

    // Computed: a product is high-risk if any of its ingredients is.
    var isHighRisk: Bool {
        components.contains { $0.ingredient?.isHighRisk == true }
    }
}

@Model
final class ScheduledDose {
    @Attribute(.unique) var id: UUID
    var hour: Int                    // 0..23
    var minute: Int                  // 0..59
    var quantity: Int                // number of pills
    var daysOfWeek: [Int]            // 1..7, ISO weekday; empty = every day
    var medication: Medication?
}

@Model
final class DoseEvent {
    @Attribute(.unique) var id: UUID
    var medication: Medication?
    var scheduledFor: Date?          // nil for PRN
    var takenAt: Date
    var quantity: Int                // pills taken
    var status: DoseStatus           // .taken | .skipped | .snoozed
    var loggedOn: LogSource          // .watch | .iphone
    var notes: String?

    // Denormalized snapshot of what was actually consumed, per ingredient.
    // Stored at log time so that editing a Medication's components later
    // does not retroactively rewrite history.
    var ingredientAmounts: [LoggedIngredientAmount]
}

struct LoggedIngredientAmount: Codable {
    var ingredientID: UUID
    var ingredientName: String       // denormalized for readable history & PDF export
    var totalMg: Double              // quantity × component.dosagePerUnitMg at log time
}

enum MedicationKind: String, Codable { case maintenance, prn }
enum MedicationForm: String, Codable { case tablet, capsule, liquid, other }
enum DoseStatus: String, Codable { case taken, skipped, snoozed }
enum LogSource: String, Codable { case watch, iphone }
```

### 5.3 Design Notes

**Why denormalize ingredient amounts onto `DoseEvent`:** Running totals are queried every time the watch app opens, and we want them fast even with months of history. Storing a snapshot also means historical totals stay correct if you later edit a product's component list (e.g., you bought Tylenol Extra Strength last month, regular Tylenol this month, and edit the "Tylenol" product's mg per pill — your history shouldn't silently rewrite).

**Why a separate `MedicationComponent` join model rather than a dictionary:** SwiftData relationships work cleanly with `@Model`. A `[Ingredient: Double]` dictionary would require custom transformer logic and lose referential integrity if an ingredient is later edited or merged.

**Why `isHighRisk` lives on `Ingredient`:** lithium is risky whether it comes as Lithobid or generic carbonate. Same logic for any future high-risk additions (e.g., warfarin). A product inherits high-risk status from any of its ingredients.

**Seeded ingredient library:** First launch seeds a small library of common ingredients (Acetaminophen, Ibuprofen, Aspirin, Naproxen, Diphenhydramine, Caffeine) with *suggested* ceilings the user can accept or override. We do not ship pre-filled values as "safe limits" — these are user-defined defaults with a clear disclaimer that the user is responsible for confirming with their prescriber. Geoff's specific meds (Lithium, Gabapentin) are entered by him; we don't presume to know his prescription.

**Ceiling/interval logic in pseudocode:**

```swift
// When user is about to log `quantity` units of `medication`:
func violationsIfTaken(_ medication: Medication, quantity: Int, at now: Date) -> [Violation] {
    var violations: [Violation] = []
    for component in medication.components {
        guard let ingredient = component.ingredient else { continue }
        let addedMg = Double(quantity) * component.dosagePerUnitMg

        // Daily ceiling: sum ingredient across ALL products taken today
        if let ceiling = ingredient.dailyCeilingMg {
            let todayMg = totalToday(ingredient: ingredient)
            if todayMg + addedMg > ceiling {
                violations.append(.ceiling(ingredient, current: todayMg, proposed: todayMg + addedMg, ceiling: ceiling))
            }
        }

        // Min interval: check last dose of any product containing this ingredient
        if let minInterval = ingredient.minIntervalMinutes,
           let lastDose = lastDoseTime(ingredient: ingredient),
           now.timeIntervalSince(lastDose) < Double(minInterval * 60) {
            violations.append(.tooSoon(ingredient, lastTakenAt: lastDose, minInterval: minInterval))
        }
    }
    return violations
}
```

This is the function that makes Tylenol + Excedrin safe together, gabapentin self-pacing, and lithium uneventful.

---

## 6. iPhone Companion App

Deliberately minimal. Three tabs, no more.

### 6.1 Tab 1 — Regimen

- List of active medications, grouped by Maintenance / As-Needed.
- Swipe to archive (soft delete; preserves history).
- Tap to edit: name, components (active ingredients + mg per unit), schedule, PRN configuration.
- **Add Medication** flow:
  1. "Import from Apple Health" (one tap; if user has medications in Health, this populates name + scheduled times; ingredient components must be confirmed manually because Health doesn't expose composition reliably).
  2. "Add manually" (form):
     - Product name, form (tablet/capsule/liquid).
     - **Active ingredients:** pick from the seeded library (Acetaminophen, Ibuprofen, etc.) or add a new one. Specify mg per unit. Most meds will have 1 component (the easy path); combo products get 2–4.
     - Schedule (if maintenance) or PRN settings (available quantities like [1, 2, 3] for 100mg gabapentin capsules).
- Separate **Ingredients** screen (accessed from settings or the Regimen edit view) to manage the ingredient library: edit ceilings, intervals, high-risk flag. This is where you'd configure that acetaminophen has a 4000mg/day ceiling, or that lithium is high-risk.

### 6.2 Tab 2 — History

- Calendar heatmap (last 30 days).
- Per-day drill-down: list of doses with timestamps, status icons, PRN running totals.
- Filter by medication.
- **Export 30 days as PDF** → standard share sheet.

### 6.3 Tab 3 — Settings

- HealthKit re-authorization.
- Watch sync diagnostics ("Last synced 2 min ago").
- High-risk confirmation gesture (press duration tweakable).
- Default snooze offset for the snooze picker.
- About / privacy.

**Hard rule:** the iPhone app does **not** show "take pills now" prompts or logging UI. Logging is the watch's job. The iPhone is for setup and review only.

---

## 7. watchOS App (Primary Surface)

### 7.1 Root View — "Right Now"

Determined by current time:
- **Pending scheduled doses** (within ±60 min of a scheduled time, not yet taken): tap-through queue.
- **All caught up state**: shows next upcoming scheduled time + "Take PRN" affordance.

### 7.2 Tap-Through Queue

One pill per screen. Each screen:
- Medication name (large, top).
- Dosage and pill count (e.g. "300 mg · 1 tablet").
- Optional color dot.
- Single primary action: **Mark Taken**.
  - For `isHighRisk == true`: button requires press-and-hold (Liquid Glass progress ring fills as user holds; releases too early → no log).
- Secondary action via Digital Crown long-press menu: **Skip** / **Snooze until…**

After log: animated transition to next screen. Final screen: success state with a glass shimmer.

### 7.3 PRN Section

- List of PRN products.
- Each row displays the most-relevant ingredient running total for safety scanning:
  - Single-ingredient meds: "**Gabapentin** · 600 mg today · last 11:42 AM"
  - Single-ingredient OTC: "**Tylenol** · 1500 mg acetaminophen today · last 11:42 AM"
  - Combo product: "**Excedrin** · last 11:42 AM · acetaminophen 38% of daily limit" (shows the highest-utilization ingredient)
- Tap → quantity picker (uses `prnAvailableQuantities`) → confirm.
- Before logging, run the `violationsIfTaken` check from §5.3 against **all ingredients across all products taken today**. If any ingredient would exceed its daily ceiling or violate its min-interval, show a soft warning interstitial naming the specific ingredient and current total. User can override.
- "Last dose" timestamp on the row reflects the last time this *product* was taken, but safety checks aggregate by *ingredient*. This means: take 2 Tylenol at 11:42 AM, then try to take 2 Excedrin at 1:42 PM, and the warning will fire on the shared acetaminophen interval even though it's a different product.

### 7.4 Complication

- Watch face complication (circular, corner, inline variants).
- Shows count of pending doses for current window (e.g. "2 pending") or "✓" when clear.
- Tap → opens app to tap-through queue.

### 7.5 Smart Stack Widget

- Surfaces 15 min before each scheduled time.
- Single-tap from widget → logs the next pending dose (no need to open app).
- Liquid Glass background per watchOS 26 guidelines.

---

## 8. Notifications & Snooze Flow

### 8.1 Scheduling

- Each `ScheduledDose` produces a `UNCalendarNotificationTrigger`.
- Notifications are scheduled on the **watch directly** (so it works even if iPhone is off).
- Rescheduled whenever the regimen changes (full rebuild on regimen edit — simpler than diffing).

### 8.2 Notification Content

- Title: "Pills · 4 to take"
- Body: First two medication names ("Lithium · Vitamin D · +2 more")
- Custom actions: **Mark all taken** · **Open app** · **Snooze…**

### 8.3 Snooze-Until-Time Flow

The default iOS snooze is fixed-duration. We need "Snooze until 10:17 PM."

Implementation:
1. The **Snooze…** action is a `UNNotificationAction` with `.foreground` option.
2. Tapping it opens a dedicated `SnoozeView` on the watch with a `DatePicker(.hourAndMinute)` styled with Liquid Glass.
3. User picks a time → tap Done.
4. App cancels the current notification's pending re-fire and schedules a new `UNCalendarNotificationTrigger` for the selected time.
5. If the user snoozes past midnight, the notification re-fires the next morning at the chosen time.

**Edge case:** If a snoozed notification is re-snoozed three times, surface a soft "You've snoozed this 3 times — skip instead?" prompt on the fourth.

---

## 9. Liquid Glass Design Language

watchOS 26's Liquid Glass is the primary aesthetic. Specifics:

- **Backgrounds:** every screen uses a translucent glass background (`.glassEffect()` modifier or equivalent — confirm exact API in Xcode 17). Avoid solid fills.
- **Hierarchy:** establish depth via subtle drop shadow + glass refraction, not via colored chrome.
- **Color palette:** monochromatic baseline (black/white per system theme). Accent color reserved for **high-risk meds only** (warm amber for press-and-hold confirmation).
- **Typography:** SF Pro Rounded for medication names; SF Pro Display for dosage figures.
- **Motion:** confirm-and-advance uses a glass-shimmer + slide. Press-and-hold uses a ring that fills with refraction.
- **Negative space:** lots of it. The watch screen should look mostly empty. One name, one number, one button.

**Reference:** Apple's WWDC 2025 "Meet Liquid Glass" and "Build with Liquid Glass on watchOS" sessions.

---

## 10. Roadmap — Tracer-Code Execution

The roadmap follows tracer-code methodology: wire the skeleton end-to-end first, then iteratively replace stubs. **At every phase boundary, the app must be runnable and demoable on a paired iPhone + watch simulator.**

Each phase below will be expanded into its own plan file under `plan/` using the 6-component prompt structure (Role / Goal / Context / Format / Examples / Constraints), named `YYYY-MM-DD_PHASE_N_<NAME>.md`.

### Phase 0 — Skeleton (10% time budget)

**Goal:** Empty paired iOS + watchOS targets in a single Xcode project, both running, with placeholder SwiftUI views.

- Create Xcode project: "Watch-only App with iOS Companion."
- Configure capabilities: HealthKit (iOS only), Background Modes (Remote Notifications, Background Fetch).
- Set up SwiftData container shared by both targets via app group.
- Stub `WCSession` setup on both sides; log handshake to console.
- Smoke test: open both apps, see `"Hello PillBreakfast"` on each.

**Gate:** Both targets build, run, and log a successful `WCSession` activation.

### Phase 1 — Data Model & WC Sync Tracer

**Goal:** SwiftData models in place; an `applicationContext` round-trip from phone to watch with a dummy medication.

- Implement all `@Model` classes from §5.
- iPhone seeds one hardcoded medication ("Stub Lithium 300mg, daily 8am").
- Push regimen to watch via `WCSession.updateApplicationContext`.
- Watch displays the medication name.

**Gate:** Edit medication name on iPhone → see updated name on watch within 5 seconds.

### Phase 2 — Maintenance Flow

**Goal:** Geoff can add his real maintenance meds on iPhone, see the morning queue on the watch, and tap to log doses (stored locally on watch, synced back to iPhone).

- iPhone: full Regimen tab (add/edit/archive).
- Watch: tap-through queue for current time window.
- Local notification scheduling (basic — fixed time, no snooze yet).
- Reverse sync: `DoseEvent`s from watch → iPhone history.

**Gate:** Real morning regimen works end-to-end. Notifications fire at correct times.

### Phase 3 — High-Risk Confirmation + Liquid Glass First Pass

**Goal:** Lithium feels safe to take. The app feels like watchOS 26.

- Press-and-hold gesture with Liquid Glass progress ring.
- Apply `.glassEffect()` throughout primary screens.
- Color reserved for high-risk only.
- Success-state shimmer animation.

**Gate:** Visual review — looks like a watchOS 26 native app, not a port of iOS chrome. Press-and-hold can't be triggered accidentally.

### Phase 4 — PRN Flow + Ingredient-Aware Running Totals

**Goal:** Both prescription PRN (Gabapentin) and OTC analgesics (Tylenol, Excedrin) work safely. Running totals aggregate by ingredient across products. Ceiling and interval warnings fire correctly even across different product names sharing an ingredient.

- PRN section on watch with per-product rows showing ingredient-level totals.
- Quantity picker.
- `totalToday(ingredient:)` and `lastDoseTime(ingredient:)` query helpers operating on the denormalized `LoggedIngredientAmount` snapshots.
- `violationsIfTaken(_:quantity:at:)` safety check (see §5.3).
- Soft warning interstitial that names the *ingredient* (not just the product) that's at risk.
- Seeded ingredient library with suggested defaults and clear "you are responsible for confirming with your prescriber" disclaimer.

**Gate (three test cases must all pass):**
1. *Gabapentin self-pacing:* Take 600mg gabapentin; total reads 600mg. Attempt to take more than 1200mg cumulative, see warning, can override.
2. *Tylenol self-pacing:* Take 1000mg Tylenol; total reads 1000mg acetaminophen. Attempt to take another 1000mg within 4 hours, see min-interval warning.
3. *Cross-product safety (the killer test):* Take 1500mg standalone Tylenol, then attempt to take 4 tablets of a combo product (e.g., Excedrin Extra Strength = 1000mg additional acetaminophen). Warning fires on acetaminophen total exceeding 4000mg daily ceiling, even though product names are different.

### Phase 5 — Snooze-Until-Time

**Goal:** The flagship snooze interaction works.

- Custom `UNNotificationAction` for Snooze.
- `SnoozeView` with `DatePicker(.hourAndMinute)`.
- Reschedule logic, including post-midnight handling.
- Three-snooze soft warning.

**Gate:** Snooze until 10:17 PM, notification fires at 10:17 PM. Snooze three times, see soft warning on fourth.

### Phase 6 — HealthKit Import

**Goal:** First-run users with existing Health medications can onboard in one tap.

- iPhone HealthKit authorization flow (per-medication read).
- Query `HKUserAnnotatedMedication` and surface them in an import sheet.
- Map Health concept → PillBreakfast `Medication` (preserve `healthKitConceptID`).
- Skip duplicates on re-import.

**Gate:** Wipe app, set up Lithium in Apple Health first, then install PillBreakfast. Import flow pulls it in without re-typing.

### Phase 7 — Widgets & Complication

**Goal:** Geoff can log from his watch face without opening the app.

- Watch complication (3 variants: circular, corner, inline).
- Smart Stack widget that appears 15 min before scheduled doses.
- Single-tap log from widget (`AppIntent` driven).
- Background refresh logic.

**Gate:** Add complication to watch face. See pending count update in real time after a dose is logged.

### Phase 8 — History, Export, Polish

**Goal:** Geoff can hand his psychiatrist a PDF of the last 30 days.

- iPhone calendar heatmap.
- Per-day drill-down view.
- PDF export via `PDFKit`.
- Share sheet integration.
- Final polish: empty states, error handling, accessibility audit (VoiceOver labels on every interactive element).

**Gate:** Generate PDF for the last 30 days that's readable, well-formatted, and survives email.

### Phase 9 — Hardening & Submission Prep

**Goal:** App Store ready (or TestFlight ready, if Geoff prefers).

- App icons, screenshots, marketing copy.
- Privacy nutrition labels (HealthKit usage disclosure).
- Crash reporting.
- Mutation-tested critical paths: dose logging, running-total computation, ceiling enforcement.
- 5-day soak test on real hardware.

**Gate:** Submit to TestFlight; one week of dogfooding with no critical bugs.

---

## 11. Skill-Building Callouts (Junior → Senior Track)

Each phase has deliberate stretch zones designed to grow Geoff toward senior-level Swift/iOS.

| Phase | Stretch Skill | Why It Matters |
| --- | --- | --- |
| 1 | Swift 6 strict concurrency, `Sendable` conformance for SwiftData models | Modern Swift is concurrency-first; understanding actor isolation distinguishes senior engineers. |
| 1 | `WCSession` lifecycle and reachability handling | Watch dev is full of state edge cases; senior engineers map state machines explicitly. |
| 2 | `@Observable` + SwiftData `@Query` patterns | The new observation system replaces `ObservableObject`; mastering it is current-decade Swift. |
| 3 | Custom gesture recognizers with haptic feedback | UX polish is what separates products from prototypes. |
| 4 | Many-to-many modeling with SwiftData, denormalized history snapshots, and reasoning about which writes invalidate which reads | This is a real schema design problem with no obvious right answer; senior engineers can articulate trade-offs in plain English. |
| 5 | Background task scheduling and `BGTaskScheduler` | Real-world apps live in the background; junior code often breaks here. |
| 6 | HealthKit per-object authorization (a deliberately confusing API) | Reading Apple framework docs critically is a senior skill. |
| 7 | `AppIntent` and the new actions framework | Powering Siri/Spotlight/widgets is the modern integration story. |
| 8 | `PDFKit` and shareable file generation | File I/O on iOS is its own genre of bug. |
| 9 | Mutation testing (Geoff has opinions here already) | Apply existing convictions to a new codebase. |

---

## 12. Open Questions / Future Work

The following are intentionally **out of scope for v1** but worth flagging:

1. **iCloud sync for multi-device.** v1 is single-watch + single-phone. CloudKit-backed SwiftData would be a natural v2.
2. **Caregiver mode.** Sharing regimen visibility with a partner (Freedom?) — out of scope; would require a real backend.
3. **Pill image recognition.** Snap a photo of a pill bottle → autofill medication. Heavy lift; defer.
4. **Health dose readback enrichment.** If Health logs a dose via its own UI, detect via `HKAnchoredObjectQuery` and avoid double-prompting on the watch. Nice-to-have for v1.1.
5. **Apple Watch Ultra Action Button binding.** "Log next pill" on a press. Deferred.
6. **Negotiating with Apple for write access.** Worth filing a feedback request asking for `HKMedicationDoseEvent` write capability for the user's own data. Long shot, but a single API change would dramatically simplify v2.

---

## 13. File & Project Layout (Recommended)

```
PillBreakfast/
├── SPEC.md                           ← this file (living reference)
├── README.md
├── plan/                             ← Claude Code prompts, dated per Geoff's convention
│   ├── 2026-05-15_PHASE_0_SKELETON.md
│   ├── 2026-05-15_PHASE_1_DATA_MODEL.md
│   └── ...
├── PillBreakfast.xcodeproj
├── Shared/                           ← used by both targets
│   ├── Models/                       ← SwiftData @Model classes
│   ├── Sync/                         ← WatchConnectivity wrapper
│   ├── Notifications/                ← scheduling + snooze logic
│   └── DesignSystem/                 ← Liquid Glass extensions, colors, typography
├── iOSApp/
│   ├── RegimenTab/
│   ├── HistoryTab/
│   ├── SettingsTab/
│   └── HealthKitImport/
├── WatchApp/
│   ├── RootView/
│   ├── TapThroughQueue/
│   ├── PRNSection/
│   ├── SnoozeView/
│   └── Complications/
└── PillBreakfastTests/
    ├── Unit/
    └── UITests/
```

---

## 14. Glossary

- **Maintenance med:** Fixed dose, fixed schedule, every day or per weekday rule. Example: Lithium.
- **PRN:** *Pro re nata* — Latin for "as the situation demands." Variable dosing, no fixed schedule. Example: Gabapentin for anxiety; Tylenol for pain.
- **Medication / Product:** A thing you buy and take, identified by brand or generic name. Example: "Tylenol Extra Strength," "Excedrin Migraine," "Gabapentin 100mg."
- **Ingredient:** An active pharmaceutical substance. Example: Acetaminophen, Ibuprofen, Lithium Carbonate, Gabapentin. One ingredient can appear in many products.
- **Component:** The link between a product and an ingredient, with a dosage. Tylenol Extra Strength has one component (500mg acetaminophen per tablet); Excedrin Extra Strength has three (250mg acetaminophen, 250mg aspirin, 65mg caffeine per tablet).
- **Combo / combination product:** A medication with two or more active ingredients. Common in OTC cold and pain products. The reason ingredients are modeled separately from products.
- **Dose event:** A single recorded instance of taking (or skipping) a medication. Stores a snapshot of ingredient amounts at the time of logging.
- **Daily ceiling / min-interval:** Safety thresholds attached to ingredients (not products), so the app can warn you when taking another product would push a shared ingredient over its limit.
- **Liquid Glass:** Apple's design language introduced in iOS 26 / watchOS 26 (WWDC 2025); translucent, refractive material as the primary surface.
- **High-risk med:** A medication whose accidental double-dose carries serious clinical risk. Inherited from any high-risk ingredient. Receives press-and-hold confirmation. Lithium qualifies; user can flag others.
- **Tap-through:** The watch UX pattern where each pill is its own full-screen page with one primary action, advancing on confirm.

---

*End of spec. Next step: generate `plan/2026-05-15_PHASE_0_SKELETON.md` and hand the SPEC plus that plan file to Claude Code.*
