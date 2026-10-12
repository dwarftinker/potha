# Potha Constitution

Potha is a cross-platform reading app (Android, iOS, web) focused on PDF reading with
instant dictionary lookup.

## Core Principles

### I. One Codebase, Three Platforms (NON-NEGOTIABLE)

- Every user-facing feature MUST work on Android, iOS and web from a single shared codebase.
- Platform-specific code is allowed only behind an interface, and only where a platform
  capability genuinely differs (for example file storage or sharing).
- A feature is not done until it has been verified on Android and on web, including a
  mobile web browser.
- iOS remains a supported target: code MUST NOT knowingly break iOS, and any
  iOS-specific code MUST sit behind the same interfaces as other platform code. iOS is
  not verified before merge until a Mac, iOS device or cloud CI is available.

Rationale: users read on whichever device is at hand; a feature missing on one platform
breaks that promise, and divergent code paths multiply maintenance cost. iOS
verification is deferred because the project currently has no way to build or test on
iOS; a shared Flutter codebase keeps the risk of iOS-only defects low.

### II. Offline-First

- Reading, navigation, highlights and dictionary lookup MUST work with no network
  connection.
- Network features (online dictionary fallback, sync) are optional enhancements and MUST
  degrade gracefully, never blocking the reading experience.

Rationale: reading happens on planes, trains and in poor coverage; the core experience
cannot depend on connectivity.

### III. Format-Agnostic Core

- Features such as dictionary lookup, highlights, progress and search MUST depend on a
  shared document abstraction, never on a specific file format.
- Adding a new format (for example EPUB) MUST NOT require changes to those features.

Rationale: PDF is first, EPUB follows; coupling features to one format would force a
rewrite of every feature when the second format arrives.

### IV. Test-First for Core Logic

- Pure logic (word extraction from text, word normalisation, dictionary lookup, progress
  calculation) MUST have unit tests written before implementation, and those tests MUST
  fail before the code is written.
- UI flows for each user story MUST have at least one widget or integration test covering
  the primary path.

Rationale: the dictionary feature lives or dies on correct word extraction and
normalisation; these are cheap to test and costly to get wrong.

### V. Reading Comes First (Performance)

- Opening a previously opened book MUST show content in under 2 seconds on a mid-range
  phone.
- An offline dictionary definition MUST appear in under 300 ms.
- Page turns and scrolling MUST show no visible stutter at 60 fps on mid-range devices.
- Any change that regresses these targets MUST be justified in the plan.

Rationale: "instant" lookup and a smooth page are the product; slowness is a functional
defect, not a polish item.

### VI. Privacy by Default

- User books, highlights, notes and lookup history MUST stay on the device.
- No analytics, tracking or data upload unless the user explicitly opts in.
- No account is required to read.

Rationale: what someone reads and looks up is personal; trust is earned by not collecting
it.

### VII. Accessible and Calm

- All controls MUST have screen-reader labels.
- UI text MUST respect the system text-size setting.
- Colour contrast MUST meet WCAG AA.
- The reading screen MUST keep chrome minimal so the content is the focus.
- Dark and light themes MUST be supported from the start.

Rationale: a reading app should serve every reader and stay out of the way of the text.

### VIII. Simplicity

- Choose the simplest solution that meets the spec. No speculative abstractions, features
  or dependencies.
- Every new third-party dependency MUST be justified in the plan with its licence,
  maintenance status and platform support.

Rationale: a small team shipping to three platforms cannot afford complexity or
dependencies it does not need.

## Platform and Quality Constraints

- Target platforms: Android, iOS and web (desktop and mobile browsers).
- Bundled data (for example dictionary databases) MUST have a licence compatible with
  distribution, and any required attribution MUST be shown in the app.
- Known platform limitations (for example scanned PDFs without a text layer) MUST be
  detected and explained to the user rather than failing silently.
- Performance targets in Principle V apply to every feature and are checked during
  verification.

## Development Workflow

- Development follows spec-driven development with GitHub Spec Kit: specify → clarify →
  plan → tasks → analyze → implement.
- Specifications describe what and why only; technology choices belong in the plan.
- Each feature lives on its own branch (`NNN-feature-name`) and MUST be verified on
  Android and web (including a mobile browser) before merging, as Principle I requires.
- Every plan MUST include a Constitution Check that lists each principle and confirms
  compliance or documents a justified exception.

## Governance

- This constitution supersedes all other practices. Where guidance conflicts, the
  constitution wins.
- Amendments require a written rationale and a version bump using semantic versioning:
  MAJOR for removing or redefining a principle, MINOR for adding a principle or materially
  expanding guidance, PATCH for wording and clarifications.
- Compliance is reviewed at plan time (Constitution Check) and again before merge.
  Exceptions MUST be recorded in the plan's Complexity Tracking section with a justification.

**Version**: 2.0.0 | **Ratified**: 2026-10-11 | **Last Amended**: 2026-10-11
