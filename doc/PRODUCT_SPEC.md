# Omit Product Specification

Last updated: 2026-08-27
Status: current

## 1. Product position

Omit is a lightweight macOS menu-bar status app. Its promise is: open the panel, understand the Mac's current condition within three seconds, and close it.

The product competes through restraint rather than metric count. The main panel must remain a compact status surface, not evolve into a dashboard of charts, per-core tables, process lists, or configuration-heavy diagnostics.

## 2. Release variants

Omit has two distribution variants built from a shared product core:

- **App Store**: sandboxed distribution with Memory, Storage, CPU, Battery, Network, and system Thermal State. It does not scan or clear the user's global Trash.
- **GitHub Direct**: Developer ID / direct-download distribution for the owner and users who intentionally install it outside the App Store. It may add the global Trash utility and deeper thermal information after their permission and safety models are independently validated.

The variants should share monitoring, localization, appearance, card components, and adaptive layout. Distribution-only capabilities must be selected by an explicit build configuration or product capability, not by Debug assertions or runtime guesswork.

Git branches may track the two release lines, but ordinary shared fixes should land in the common source first. The App Store branch must not contain an enabled global-Trash capability, Trash entitlement promise, or UI entry point.

## 3. Core user journey

1. The user opens Omit from the menu bar.
2. The main panel immediately shows available system status.
3. The user can open Settings from the header.
4. The user can choose System, Light, or Dark appearance; the panel updates immediately and remembers the choice.
5. Optional modules can be enabled or disabled.
6. In GitHub Direct, optional Trash authorization affects only the Trash card. The App Store variant has no global-Trash card.

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

- Distribution: GitHub Direct only.
- States: unauthorized, empty, size available, scanning, error, and clearing confirmation.
- Authorization is local to the Trash card.
- The entire card must not be a destructive tap target.
- Clearing must use a dedicated destructive action and an explicit confirmation.
- Real authorization, sandbox bookmark access, recursive size calculation, and deletion are deferred to later tasks.

### Thermal State

- App Store shows the system thermal state only; it must not fabricate a temperature.
- Required states are nominal, fair, serious, critical, and unavailable, localized into user-facing copy.
- State remains understandable without color; color is supplementary.
- A numeric temperature is a separate GitHub Direct capability and is not part of the App Store contract.

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
- Memory and Storage remain independent full-width Large cards when enabled.
- CPU, Battery, Network, and Thermal use the shared Adaptive Compact layout: `4 -> 2+2`, `3 -> 1+2`, `2 -> 2`, `1 -> 1`, `0 -> none`.
- For three Compact cards, the full-width card appears above the pair. PO-approved Wide priority is Network, Thermal, Battery, then CPU.
- GitHub Direct places Trash in a dedicated full-width Wide Utility card between Large cards and Adaptive Compact cards. Trash does not participate in Compact parity.
- A Mac with no battery automatically omits Battery from the dashboard. A temporary unavailable reading remains visible as unavailable and must not cause layout churn.
- Header, Settings entry, empty-dashboard state, and footer remain stable across module combinations.
- The approved App Store dashboard shell omits a persistent last-updated footer; removing that footer must not change sampling cadence or observability in tests.
- Thermal uses concise localized state labels and a state indicator; it never displays a numeric temperature.
- Battery status copy must come from typed power-source facts. A numeric value of `100%` alone is not evidence that the Mac is connected to external power or fully charged.
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

### Phase 3 — Distribution split

- Establish explicit App Store and GitHub Direct build capabilities from the shared source.
- Remove global Trash from the App Store product surface and retain it only for the GitHub Direct line.
- Add system Thermal State and the deterministic Adaptive Compact layout to both variants.

### Phase 3D — GitHub Direct Trash

- Validate the direct-distribution permission model, recursive enumeration, relaunch behavior, clear confirmation, and fixture-only deletion tests.

### Phase 4 — App Store readiness

- Enable Sandbox for distribution, add entitlements and privacy declarations, archive, test, localize final strings, and prepare store assets.

## 8. Non-goals

- Charts, history graphs, per-core CPU, temperatures, fan speed, GPU details, top-process lists, and advanced interface selection.
- Reproducing Activity Monitor exactly.
- Requiring Trash permission on first launch.
- Scanning or clearing the global user Trash in the App Store variant.
- Displaying a fabricated temperature in either variant.
