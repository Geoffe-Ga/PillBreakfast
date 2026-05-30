# Privacy Nutrition Labels — App Store Connect

Source of truth for the App Store Connect privacy questionnaire. Drafted to
match what PillBreakfast actually does at v1 submission time. Apple's labels
allow either "Data Not Collected" *or* a per-category disclosure of purpose
and linkage; overclaiming and underclaiming are both grounds for review
rejection, so each row below is what we will answer verbatim.

## Summary

PillBreakfast is a single-user wrist app with **no accounts, no backend, no
third-party SDKs, no advertising, and no analytics**. All data lives on the
user's iPhone (SwiftData store in the App Group container) and on the paired
watch (synchronized via `WCSession`). Crash diagnostics are captured by Apple's
**MetricKit** framework into the App Group's private `Diagnostics/` folder and
are **not transmitted off-device by PillBreakfast** (see
`plans/decisions/2026-05-29_crash-reporting.md` for the trade-off analysis).

## Per-category answers

### Health & Fitness

- **Health** — **Collected** · Linked to User · Used for **App Functionality** · **Not used for tracking.**
  - Source: Apple Health (user-granted, per-medication read scope) and direct
    entry on the iPhone Regimen tab.
  - Storage: SwiftData store in the App Group container on the user's iPhone;
    mirrored to the paired Apple Watch via `WCSession`.
  - Off-device transmission: **None.**
  - Reason for "Linked to User": the data lives on the user's device under
    their iCloud-bound App Group container; Apple's questionnaire treats
    device-bound data as linked to the user even without an explicit account.
  - Reason for "App Functionality": the regimen is what the app exists to
    track; without it the surface is empty.

- **Fitness** — **Not Collected.**

### Contact Info

All sub-categories (Name, Email Address, Phone Number, Physical Address, Other
User Contact Info) — **Not Collected.** There are no accounts and no email
fields anywhere in the app.

### Financial Info

All sub-categories — **Not Collected.** No purchases, no payment information.

### Location

All sub-categories (Precise Location, Coarse Location) — **Not Collected.**

### Sensitive Info

**Not Collected.**

### Contacts

**Not Collected.**

### User Content

- **Email or Text Messages**, **Photos or Videos**, **Audio Data**,
  **Gameplay Content**, **Customer Support**, **Other User Content** —
  **Not Collected.**

### Browsing History

**Not Collected.**

### Search History

**Not Collected.**

### Identifiers

- **User ID** — **Not Collected.** No accounts.
- **Device ID** — **Not Collected.** The App Group container ID is not
  considered a tracking identifier under Apple's guidance, and PillBreakfast
  does not read `identifierForVendor` or any advertising identifier.

### Purchases

- **Purchase History** — **Not Collected.** No IAP, no subscriptions.

### Usage Data

- **Product Interaction** — **Not Collected.** No first-party analytics,
  no event logging beyond local `OSLog` traces (which are not collected
  by PillBreakfast — they live in the OS unified logging system the
  user can inspect via the Console app on their Mac).
- **Advertising Data** — **Not Collected.**
- **Other Usage Data** — **Not Collected.**

### Diagnostics

- **Crash Data** — **Not Collected.** `MetricKit` is Apple's framework; the
  payloads it delivers are written to the App Group's local `Diagnostics/`
  folder and are **not transmitted off-device** by PillBreakfast. Per
  Apple's privacy-nutrition guidance, framework-delivered data the app
  does not redistribute is not "collected" by the app.
- **Performance Data** — **Not Collected.** Same MetricKit reasoning.
- **Other Diagnostic Data** — **Not Collected.**

### Other Data

**Not Collected.**

## Tracking

PillBreakfast performs **no tracking**. The "Tracking" section of the App
Store Connect privacy questionnaire is answered **"No"** across the board.

## Cross-check vs. `Info.plist` usage descriptions

| Key | Present? | Disclosure above |
|---|---|---|
| `NSHealthShareUsageDescription` | ✅ `PillBreakfast/Info.plist:5` | Covered by **Health & Fitness → Health**. |
| `NSHealthUpdateUsageDescription` | ❌ (intentional — read-only per SPEC §3.2 / CLAUDE.md) | n/a. Documenting absence so a future engineer doesn't add a write surface without re-doing this audit. |
| `NSUserNotificationsUsageDescription` | ❌ (system handles this for the watch's local notifications, no prompt key required) | n/a. |
| `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSContactsUsageDescription`, `NSCalendarsUsageDescription`, `NSRemindersUsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSMotionUsageDescription` | ❌ (intentional) | n/a. None of these surfaces are used; their absence matches the **Not Collected** rows above. |

## If a third-party SDK is ever added

The ADR at `plans/decisions/2026-05-29_crash-reporting.md` documents the
sentry-cocoa escape hatch if MetricKit's 24-hour batch latency becomes
unacceptable. Adding sentry-cocoa (or any other third-party SDK) **changes
the answer** in at least the **Diagnostics → Crash Data** row (almost
certainly **Collected → Not Linked to You → App Functionality**) and may
add an **Identifiers → User ID** row depending on configuration. This
document must be revised and the App Store Connect entries updated
**before** the next submission that ships the SDK.
