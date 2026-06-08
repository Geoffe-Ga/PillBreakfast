# Memory Utilization — Root-Cause Investigation (RCA)

- **Date:** 2026-06-02
- **Investigator:** performance engineering (agent)
- **Branch:** `investigation/memory-rca-probes`
- **Method:** `bug-squashing-methodology` (Document → Understand), evidence-first
- **Verdict:** **The reported symptoms are NOT caused by a memory leak, unbounded
  growth, or excessive memory use in PillBreakfast's code.** The app's charged
  memory (`phys_footprint`) is a healthy **~36 MB, flat across every symptom flow**.
  The symptoms are dominated by the **Debug-build + iOS-Simulator + Liquid-Glass
  environment under host-machine memory pressure**. One genuine, *separate*
  code-level memory-safety defect was confirmed: a **MetricKit subscriber teardown
  crash** (a dangling-pointer crash, not a footprint problem).

---

## 1. Reported symptoms (owner)

1. iOS app **very slow to load** on first launch.
2. **Typing in text fields is very slow** to respond.
3. Xcode reported the app was **"terminated due to memory usage."**
4. **PDF export froze the app completely.**

## 2. What the evidence shows

### 2.1 The authoritative measurement: `phys_footprint` is flat at ~36 MB

`phys_footprint` is the metric the kernel's jetsam uses for memory-limit
terminations. Measured via `xcrun simctl spawn <sim> vmmap --summary <pid>` while
a UITest (`PillBreakfastUITests/MemoryReproUITests`) drove the exact symptom flows
on **iPhone 17 / iOS 26.3**:

| Phase | phys_footprint | session peak |
| --- | --- | --- |
| Launch idle | 35.7 MB | 45.8 MB |
| History tab appear → **auto PDF export** (`.task`) | 35.9 MB | 45.8 MB |
| **5× History↔Regimen cycles (5 PDF exports)** | 36.0 → 36.6 MB | 45.8 MB |
| Add-medication form → **60-keystroke typing storm** | 36.6 MB | 45.8 MB |
| Final idle (settled) | 36.4 MB | 45.8 MB |

**Interpretation.** The working set is ~36 MB and rock-solid. The peak (45.8 MB)
is hit *at launch* and is never exceeded — not by 5 PDF exports, not by typing.
The ~0.6 MB drift across 5 History cycles **reclaims** back to 36.4 MB at idle, so
it is a transient working set, **not** a leak. This single measurement directly
refutes "PDF export causes a memory blowup" and "typing leaks memory."

> ⚠️ Earlier `ps`-based **RSS** readings (~150–200 MB, with a noisy
> 314→14 MB decline) are *not* the app's charged memory — RSS includes shared
> simulator frameworks and clean pages not counted against the jetsam limit. They
> were discarded as a measurement artifact in favor of `phys_footprint`.

### 2.2 Code review found no growth source (all three surfaces)

- **Store size:** ~150–200 KB on disk across every simulator (a few hundred rows).
  Not a data-volume problem.
- **Seeders idempotent:** `IngredientLibrarySeeder` (stable-UUID dedup, ~95 static
  specs) and `StubMedicationSeeder` (fixed-ID early-return) cannot grow the store
  across launches.
- **Queries bounded:** History `@Query` is 30-day windowed
  (`HistoryTabView.swift:158`); drill-down single-day; PDF `collectBlocks` fetches a
  30-day predicate (`PDFExporter.swift:75`); watch hot-paths cap with
  `fetchLimit` (`IngredientQueries`, `PendingQueueSelector`).
- **No classic leak surface:** zero Combine / `ObservableObject`, zero
  `Timer`/`CADisplayLink`/KVO/`NSNotificationCenter` observers. The only delegates
  are app-lifetime singletons (`WCSession`, `UNUserNotificationCenter`).
- **PDF render is off-main:** `PDFExporter.render` is `nonisolated`, dispatched on a
  detached `userInitiated` task over `Sendable` value snapshots
  (`PDFExporter.swift:49`). 5 automated export cycles ran at constant 36 MB.

### 2.3 Probe: paged history scan (`investigation/memory-rca-probes`, commit cc76652)

A deterministic XCTest seeding no-match `DoseEvent`s confirmed: the long-lived
`mainContext` does **not** permanently retain fetched objects (weak-ref nils after
scope), but a *no-match* `pagedScan` walks the whole history with a peak footprint
of ~176 B/event (288 KB @ 2k events, 1.4 MB @ 8k). This is a **watch-side**
transient spike proportional to history depth — single-digit MB even at multi-year
histories, and reclaimed after the scan. **Not** related to the iOS symptoms; kept
as a lead for the watch surface only.

### 2.4 The "terminated due to memory" message: host-level pressure

Host state at investigation time:

- **16 GB RAM Mac**, **7.9 GB of swap in use** — sustained heavy memory pressure.
- Concurrent load: Xcode + paired iOS **and** watch simulators + Debug build +
  multiple `claude` processes (~1.5 GB combined).

When macOS is swapping this hard, it jettisons the *simulated* app and Xcode
surfaces **"Terminated due to memory issue"** — independent of the app's 36 MB
footprint. There is **no jetsam `DiagnosticReport` (`bug_type 298`)** for
PillBreakfast, which is consistent with a host-level kill rather than the app
exceeding its own limit.

### 2.5 Confirmed separate defect: MetricKit subscriber teardown crash

**25 crash reports** (`~/Library/Logs/DiagnosticReports/PillBreakfast-2026-05-27*`,
`-05-29*`), every one `bug_type 309` (crash, *not* jetsam), identical stack:

```
objc_msgSend
hashProbe
-[NSConcreteHashTable removeItem:]
__36-[MXMetricManager removeSubscriber:]_block_invoke   (libdispatch worker)
```

`EXC_BAD_ACCESS` / `KERN_INVALID_ADDRESS` (`0x…beadde82a4b0`, "possible pointer
authentication failure") — MetricKit messaging a torn-down subscriber on its
internal queue at process teardown. `CrashReporting` (`Shared/Diagnostics/
CrashReporting.swift`) registers via `MXMetricManager.shared.add(self)` in
`start()` and has **no `deinit { stop() }`**. The production singleton is immortal
(so it doesn't dangle in normal runs), but the teardown-time `removeSubscriber`
path is crashing on the simulator. This is a real memory-**safety** bug
(dangling pointer), distinct from the footprint symptoms. Severity: medium
(teardown-only, simulator-observed); fixing it removes a confounding crash from the
diagnostics trail.

## 3. Per-symptom verdict

| Symptom | Root cause (evidence) | Category |
| --- | --- | --- |
| Slow first launch | Synchronous first-launch seeding (`PersistenceController.init` → `IngredientLibrarySeeder.seedIfNeeded`, ~95 specs) + Debug build + first Liquid-Glass composite, amplified by host swap. One-time, main-thread CPU — **not memory**. | Transient / main-thread |
| Slow typing | Debug build + Liquid-Glass form re-render in the simulator (software-rendered), amplified by host swap. phys_footprint flat at 36.6 MB during a 60-keystroke storm. **Not memory.** | Render/CPU (environmental) |
| "Terminated due to memory" | **Host-level** memory pressure (16 GB RAM, 7.9 GB swap) jettisons the simulated app; no app-level jetsam report; app footprint 36 MB. **Not the app's memory.** | Environmental |
| PDF export froze | Not reproduced in 5 automated export cycles (constant 36 MB). Consistent with a `ShareLink`/`UIActivityViewController` share-sheet stall or a render hitch under host swap. **Not memory.** | UI stall (unreproduced) |

## 4. Disconfirming evidence recorded

- No leak: idle flat; History/PDF cycles reclaim to baseline.
- No unbounded growth: bounded queries + idempotent seeders + tiny store.
- No app-level jetsam report exists for the symptom window.
- PDF/typing flows measured at constant footprint — refutes the two code-pointed
  hypotheses.

## 5. Recommendations (in priority order)

1. **Re-measure on a real device and/or a Release build, with the watch simulator
   and other heavy host processes closed.** The strong prior is that the slowness
   and the termination both disappear — they track host pressure + Debug/Simulator
   render cost, not app memory. *(This is the single highest-value next step and
   needs the owner, not code.)*
2. **Fix the MetricKit teardown crash** (§2.5) — genuine, independently verifiable.
3. *(Optional, minor)* Move first-launch seeding off the main thread / behind the
   first frame, to shave the cold-launch stall (§3 row 1).
4. *(Watch only, pre-existing lead)* Consider an early-exit bound on the no-match
   `pagedScan` (§2.3) before the watch history grows large. Low urgency.

## 6. Artifacts

- `PillBreakfastTests/Memory/SwiftDataContextRetentionProbeTests.swift` (commit cc76652)
- `PillBreakfastUITests/MemoryReproUITests.swift` (repro driver; investigation only)
- This report.
