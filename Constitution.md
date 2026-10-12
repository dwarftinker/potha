/speckit.constitution Create the constitution for "Potha", a cross-platform reading app
(Android, iOS, web) focused on PDF reading with instant dictionary lookup. Principles:

I. One Codebase, Three Platforms (NON-NEGOTIABLE)
Every user-facing feature MUST work on Android, iOS and web from a single shared codebase.
Platform-specific code is allowed only behind an interface, and only where a platform
capability genuinely differs (file storage, sharing). A feature is not done until it has
been verified on all three platforms, including a mobile web browser.

II. Offline-First
Reading, navigation, highlights and dictionary lookup MUST work with no network connection.
Network features (online dictionary fallback, sync) are optional enhancements and MUST
degrade gracefully, never blocking the reading experience.

III. Format-Agnostic Core
Features such as dictionary lookup, highlights, progress and search MUST depend on a shared
document abstraction, never on a specific file format. Adding a new format (e.g. EPUB) must
not require changes to those features.

IV. Test-First for Core Logic
Pure logic (word extraction from text, word normalisation, dictionary lookup, progress
calculation) MUST have unit tests written before implementation, and those tests MUST fail
before the code is written. UI flows for each user story MUST have at least one widget or
integration test covering the primary path.

V. Reading Comes First (Performance)
Opening a book the user has opened before MUST show content in under 2 seconds on a
mid-range phone. A dictionary definition MUST appear in under 300 ms for offline lookups.
Page turns and scrolling MUST feel smooth (no visible stutter at 60 fps on mid-range
devices). Any change that regresses these targets must be justified in the plan.

VI. Privacy by Default
User books, highlights, notes and lookup history stay on the device. No analytics,
tracking or data upload unless the user explicitly opts in. No account is required to
read.

VII. Accessible and Calm
All controls have screen-reader labels, UI text respects the system text-size setting,
colour contrast meets WCAG AA, and the reading screen keeps chrome minimal so the content
is the focus. Dark and light themes are supported from the start.

VIII. Simplicity
Choose the simplest solution that meets the spec. No speculative abstractions, features
or dependencies. Every new third-party dependency must be justified in the plan with its
licence, maintenance status and platform support.

Governance: the constitution supersedes other practices. Every plan must include a
constitution check that lists each principle and confirms compliance or documents a
justified exception. Amendments require a written rationale and a version bump (semantic
versioning: MAJOR for removing or redefining a principle, MINOR for adding one, PATCH for
wording).
