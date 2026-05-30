# 2026-05-29 — Crash and diagnostic reporting

## Status

Accepted. MetricKit selected.

## Context

The watch-first thesis lives or dies on PillBreakfast not silently losing a dose
log to a crash Geoff never sees. Before submission we need *some* way to recover
crash signal from the field. The question is which mechanism, since each has a
non-trivial cost on the privacy-nutrition-label surface we ship to App Store
Connect.

## Options considered

### MetricKit + on-device JSON (selected)

- **Privacy label:** clean. No new data collection — MetricKit dispatches Apple-
  authored telemetry already covered by the OS's own labels. We don't
  redistribute it; we write payloads to the App Group's private container for
  the user (and only the user) to share if they want to.
- **Latency:** 24-hour batching is the documented worst case (`MXMetricPayload`
  is delivered once per day; `MXDiagnosticPayload` is more bursty after an
  actual crash but still next-foreground at the earliest).
- **Network:** none. No third-party SDK init, no SDK background task, no DNS.
- **SDK weight:** zero — system framework.
- **Watch coverage:** `MXMetricManager` exists on watchOS 7+; the diagnostic
  payload shape is reduced but the subscription pattern is identical.

### Crashlytics (Firebase)

- **Privacy label:** new entries — "Diagnostics → Crash Data" gets a "Data
  Linked to You" check, and the Firebase Analytics dependency Crashlytics
  drags in adds identifier collection by default unless we audit and disable it.
- **Latency:** real-time (post-crash, on next launch).
- **Network:** SDK initializes a background sender and uploads to Firebase on
  every launch. Adds DNS / TLS / payload egress on the critical-launch path.
- **SDK weight:** ~3 MB compressed, ~7 MB uncompressed; Firebase Core is a
  transitive dependency.
- **Watch coverage:** unofficial. The standalone watch target is not a primary
  Firebase use case.

### Sentry (sentry-cocoa)

- **Privacy label:** new entries — "Diagnostics → Crash Data" linked to a user
  ID if you keep `enableUserInteractionTracing` on. OSS so the data flow is
  auditable, but it's still third-party egress.
- **Latency:** real-time (post-crash, on next launch).
- **Network:** SDK initializes a sender and uploads to a Sentry tenant. Same
  critical-launch-path tax as Crashlytics, with the additional decision of
  self-hosting vs. SaaS Sentry.
- **SDK weight:** ~1.5 MB compressed.
- **Watch coverage:** supported but documented under "experimental" headers.

## Decision

Go with **MetricKit** for v1 submission. The 24-hour worst-case latency is
acceptable because PillBreakfast isn't crash-loop sensitive — Geoff opens it
multiple times a day; crashes will surface in the local diagnostics folder
within one full active session.

The privacy-label cleanliness is the deciding factor: a single-user wrist app
in a medical-adjacent category cannot afford to gain a "Diagnostics" /
"Identifiers" check on its App Store Connect label without a meaningful
benefit, and a third-party SDK's real-time delivery doesn't clear that bar
when MetricKit's batched delivery does.

## If MetricKit turns out to be unacceptable

The escape hatch is sentry-cocoa with `tracesSampleRate = 0`, no user
interaction tracing, and a clean App Group identifier so the SDK can't link
sessions across launches. The accompanying privacy-label entry is documented
in `Submission/marketing-copy.md` (filed by #62) before re-submission.

## Implementation

`Shared/Diagnostics/CrashReporting.swift` — `MXMetricManagerSubscriber` that
writes each received payload's `jsonRepresentation()` to the App Group's
`Diagnostics/` subdirectory. The App's init constructs one instance and calls
`start()`; MetricKit holds the reference for the process lifetime.
