# Omit Product Specification

Last updated: 2026-08-25
Status: current

## 1. Product position

Omit is a lightweight macOS menu-bar status app. Its promise is: open the panel, understand the Mac's current condition within three seconds, and close it.

The product competes through restraint rather than metric count. The main panel must remain a compact status surface, not evolve into a dashboard of charts, per-core tables, process lists, or configuration-heavy diagnostics.

## 2. Release direction

- Primary distribution target: Mac App Store.
- App Sandbox is required for the App Store build.
- CPU, memory, storage, battery, and network remain usable without Trash authorization.
- Trash is an optional differentiating module. Lack of Trash authorization must never block the rest of the app.
- Trash access will be validated in a later task through an explicit user-selected folder and a security-scoped bookmark. This specification does not assume that Full Disk Access is the final App Store solution.

## 3. Core user journey

1. The user opens Omit from the menu bar.
2. The main panel immediately shows available system status.
3. The user can open Settings from the header.
4. The user can choose System, Light, or Dark appearance; the panel updates immediately and remembers the choice.
5. Optional modules can be enabled or disabled.
6. If Trash is not authorized, only the Trash card shows an authorization state.

## 4. Information contract

### Memory

- Label: Memory / 内存 / メモリ.
- Primary value: estimated used memory.
- Supporting value: `used / physical total`.
- Never label `memoryUsedString` as Active Memory.
- The ring represents the same used-memory percentage shown by the numeric percentage.
- Used memory is Omit's bounded status estimate: active + inactive + speculative + wired + compressed − purgeable − external.
- The estimate is clamped to `0...physicalMemory`, including subtraction and overflow protection, and does not promise byte-for-byte parity with Activity Monitor.

### Storage

- Label: Storage / 磁盘 / ストレージ.
- Primary value: available space.
- Supporting label: Available Space.
- Percentage must explicitly say `Used`; an unlabeled percentage is not acceptable when the primary value is available space.
- The ring represents used capacity.

### CPU

- Show total CPU utilization as one compact percentage.
- Initial/unavailable data is shown as an unavailable state such as `—`, not a fabricated `0%`.

### Battery

- Show battery percentage and charge state when a battery exists.
- The no-battery state must be expressible by the UI shell; detection is deferred to a logic task.

### Network

- Label the module Network, not Download.
- The target presentation has separate receive and transmit rows (`↓` and `↑`).
- Receive and transmit use independent 64-bit counters from the current routed primary interface.
- Interface changes, disconnects, counter resets, and sleep-sized sampling gaps establish a new unavailable baseline instead of emitting a false spike.

### Trash

- States: unauthorized, empty, size available, scanning, error, and clearing confirmation.
- Authorization is local to the Trash card.
- The entire card must not be a destructive tap target.
- Clearing must use a dedicated destructive action and an explicit confirmation.
- Real authorization, sandbox bookmark access, recursive size calculation, and deletion are deferred to later tasks.

## 5. Appearance contract

Omit supports three appearance preferences:

- System: follows the current macOS appearance.
- Light: forces the Omit panel to light appearance.
- Dark: forces the Omit panel to dark appearance.

Requirements:

- The choice lives in Settings under Appearance.
- The selected preference is visible, applies immediately, and persists across launches.
- Light and Dark are equal first-class themes. Neither is a color inversion afterthought.
- Semantic system colors are preferred for text and surfaces; module accent colors remain stable across themes while meeting readable contrast.

## 6. UI shell baseline

- Target panel width: 312 pt unless implementation evidence shows a smaller width is required by `MenuBarExtra`.
- Header keeps the `Omit.` wordmark and one Settings entry point.
- Memory and Storage are primary full-width cards.
- CPU, Battery, Network, and Trash use a two-column secondary grid when enabled.
- Minimum text size is 10 pt.
- Settings control keeps a minimum 28 × 28 pt hit area.
- Decorative colored status dots are not used unless they communicate a real state.
- The reference image is a direction for hierarchy and theme parity, not a pixel-perfect requirement: `doc/assets/omit-ui-light-dark-reference.png`.

## 7. Delivery phases

### Phase 1 — UI shell

- Implement the production-facing SwiftUI shell and fixture-driven previews.
- Implement appearance preference and Settings presentation.
- Express future states without wiring new monitoring, permission, or destructive logic.

### Phase 2 — Metric correctness

- Correct memory semantics, network receive/transmit sampling, no-battery handling, refresh cadence, and error states.

### Phase 3 — Trash sandbox prototype

- Validate folder selection, security-scoped bookmark persistence, relaunch recovery, recursive enumeration, and deletion in a signed sandbox build.

### Phase 4 — App Store readiness

- Enable Sandbox for distribution, add entitlements and privacy declarations, archive, test, localize final strings, and prepare store assets.

## 8. Non-goals

- Charts, history graphs, per-core CPU, temperatures, fan speed, GPU details, top-process lists, and advanced interface selection.
- Reproducing Activity Monitor exactly.
- Requiring Trash permission on first launch.
- Solving App Store sandbox access during the UI-shell task.
