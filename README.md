# Systum

> An offline-first personal productivity app for tasks, goals, and focus sessions.

## Overview

Systum stores tasks, goals, Focus sessions, and Pomodoro progression locally. SQLite is the source of truth, so core workflows do not require an internet connection.

---

## Vision

The current release focuses on task and goal management, recoverable focus sessions, and explicit Pomodoro cycles. It does not include cloud services or require network access for its core workflows.

---

## Engineering Goals

This project emphasizes:

* Evolutionary architecture
* Offline-first development
* Maintainable and readable code
* Feature-first organization
* Modular design
* Strong testing practices
* Professional Git workflow
* Continuous refactoring
* Documentation that reflects reality
* Production-quality engineering habits

---

## Technology Stack

| Technology        | Purpose                                 |
| ----------------- | --------------------------------------- |
| Flutter           | Cross-platform UI framework             |
| Dart              | Programming language                    |
| Riverpod          | State management & dependency injection |
| GoRouter          | Declarative navigation                  |
| Drift             | Type-safe SQLite persistence            |
| SQLite            | Offline-first local database            |
| SharedPreferences | Lightweight application settings        |
| Logger            | Structured application logging          |
| Git & GitHub      | Version control                         |
| GitHub Actions    | Continuous Integration (planned)        |

---

## Current Status

**Project Stage:** v0.1.0 Early Access — release validation

### Completed

* Flutter project initialization
* Development environment setup
* Feature-first project structure
* Application bootstrap
* GoRouter-based navigation
* Material 3 design system foundation
* Drift database infrastructure
* Riverpod dependency composition
* Task database schema and repository
* Task creation, editing, completion, reopening, and deletion
* Goal schema and `GoalRepository` CRUD
* Task-to-goal assignment and retrieval by goal
* One-level subtasks with inherited goals
* Transactional parent deletion that promotes direct subtasks
* Riverpod task state management and hierarchy UI
* Goal progress calculation foundation
* Goal list and goal detail screens
* Goal creation, editing, and safe deletion UI
* Task-to-goal assignment and removal flows
* Derived goal lifecycle states (active, completed, overdue)
* Target dates with local calendar-day handling
* Recurrence rules, bounded occurrence generation, occurrence lifecycle, and
  task create/edit integration
* Reminder scheduling intent persistence with one-time and recurring schedules,
  task-lifecycle cancellation/reactivation, and full backup integration
* Repository, provider, and widget tests
* Focus session domain model and interval-based duration calculations
* Focus schema v4 with transactional upgrade and migration coverage
* Transactional focus session lifecycle persistence and task snapshots
* Riverpod focus session/history state, injectable system clock, and foreground
  elapsed-time display derived from persisted intervals
* Focus setup, active-session controls, recovery, and task navigation entry
* Pomodoro settings stored locally and cycle progression reconstructed from
  persisted session history
* Focus time aggregation from persisted intervals, including local-day splits,
  task snapshots, interruption policy, and overlap validation
* Versioned local backup and restore for SQLite data and Pomodoro settings
* Backup validation for malformed documents, relationships, task cycles, and
  focus interval invariants
* Durable restore recovery journal with startup reconciliation across SQLite
  and SharedPreferences
* Read-only SQLite and application diagnostics from the Backup screen, with
  schema, relationship, focus-interval, and Pomodoro checks
* Automatic app-private backups at startup when the last successful copy is
  older than 24 hours, with verified writes, bounded retention, failure status,
  and a catalogue for restore or deletion

### Current limitations

* Focus history is currently loaded as one indexed local query; pagination has
  not been added because no measured query problem exists yet.
* Search, filtering, sorting, and task views are implemented; manual ordering
  remains limited to daily planning.
* Automatic backups are lifecycle-triggered at startup or manually; Systum does
  not run a background backup service. Retention keeps five copies by default
  and always preserves the current and previous verified copy.
* Automatic backup files are not encrypted. They remain in app-private storage
  and are removed when the application's private data is cleared.
* The full local backup payload includes tasks, goals, recurrence rules and
  occurrences, reminders, hydration, and Focus history, so recurring tasks,
  reminders, and hydration data
  survive a verified restore; legacy versions without recurrence or reminder
  payload lists remain accepted as legacy/unverified and restore with those
  datasets empty.
* Selective task exports intentionally omit recurrence rules, generated
  occurrences, and reminders. Importing a selective task export restores
  standalone task templates without recurring behavior or reminder scheduling
  intent; use full backup/restore when those datasets must round trip.
* Reminder persistence stores scheduling intent only. Android notification
  delivery is implemented for scheduled reminders; when runtime notification
  permission is denied, no notification is delivered and the persisted reminder
  row remains intact. Android-side reconciliation is implemented; physical
  device validation remains outstanding.
* SQLite and SharedPreferences remain separate persistence systems. Restore
  uses a durable journal and startup reconciliation to guarantee that an
  interrupted restore is not reported as complete; it does not provide a
  single cross-store atomic commit.
* Diagnostics are automated and read-only. They have not been validated on a
  physical Android device; no Android device or emulator was available in the
  development environment.
* Android release signing must be configured with a private key by the release
  owner. The repository does not contain signing credentials.
* The permanent Android application ID is `com.systum.app`.

---

## Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   └── router.dart
├── core/
│   ├── backup/
│   ├── database/
│   └── theme/
├── features/
│   ├── goals/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── repository/
│   │   ├── screens/
│   │   └── widgets/
│   ├── home/
│   ├── reminders/
│   │   ├── models/
│   │   ├── providers/
│   │   └── repository/
│   ├── focus/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── repository/
│   │   ├── screens/
│   │   └── widgets/
│   └── tasks/
│       ├── models/
│       ├── providers/
│       ├── repository/
│       ├── screens/
│       └── widgets/
├── shared/
│   ├── providers/
│   └── utils/
└── main.dart
```

The project follows a feature-first architecture. Additional architectural layers are introduced only when justified by increasing product complexity.

---

## Development Principles

* Build simple solutions before introducing abstractions.
* Prefer composition over inheritance.
* Keep responsibilities focused and explicit.
* Favor readability over cleverness.
* Minimize technical debt.
* Keep features isolated and modular.
* Design for long-term maintainability.
* Test meaningful behavior, not implementation details.

---

## Getting Started

### Prerequisites

* Flutter (Stable)
* Dart SDK
* Android SDK
* Git

### Clone the Repository

```bash
git clone <repository-url>
cd systum
```

### Install Dependencies

```bash
flutter pub get
```

### Run the Application

```bash
flutter run
```

Use `flutter devices` to list available targets, then pass one explicitly when
needed, for example `flutter run -d linux` or `flutter run -d <android-device>`.

### Android builds and installation

The Android application ID is `com.systum.app`, the displayed app name is
`Systum`, the launcher icon follows the app's blue theme, and the current
version is `0.1.0+1`. Minimum and target SDK values follow the installed Flutter
SDK defaults in `android/app/build.gradle.kts` (min SDK 24, target SDK 36 with
Flutter 3.44.7).

Build a local debug APK with:

```bash
flutter build apk --debug
```

Install it on a connected device with:

```bash
flutter install
```

A distributable release requires an owner-managed Android release keystore.
Create `android/key.properties` (already ignored by Git) with these four
properties, using the path to the keystore on the build machine:

```properties
storeFile=/absolute/path/to/systum-release.jks
storePassword=<keystore-password>
keyAlias=<key-alias>
keyPassword=<key-password>
```

If a keystore does not exist yet, generate one outside the repository:

```bash
keytool -genkeypair -v -keystore /absolute/path/to/systum-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias <key-alias>
```

The checked-in Gradle configuration loads these values automatically and
assigns them only to the release build type. Keep both the keystore and
properties file out of source control. If `android/key.properties` is absent,
release builds fail closed instead of falling back to debug signing. The
repository currently has no signing credentials, so a release APK cannot yet
be produced.

Back up the keystore and its passwords in separate encrypted, access-controlled
locations. The same keystore must be retained for every future compatible app
update; losing it prevents Android upgrades for existing users.
After configuring signing, build with:

```bash
flutter build apk --release --build-name=0.1.0 --build-number=1
```

The APK is written under `build/app/outputs/flutter-apk/`.

### Verify the Project

```bash
dart format lib test
flutter analyze
flutter test
```

Run a focused test file while iterating:

```bash
flutter test test/features/tasks/providers/task_provider_test.dart
```

All commands should complete successfully before contributing changes.

### Local backup and restore

Open **Backup and restore** from the Tasks toolbar. Export creates a versioned
JSON file through the platform file picker. Import validates the complete file
before showing an explicit replace-data confirmation; current data is not
modified when validation fails or the dialog is cancelled. Backups remain on
the device or destination chosen by the user and are never uploaded by Systum.

Systum also creates automatic backups in app-private storage. At startup, after
restore reconciliation completes, it creates one only when the last successful
automatic backup is at least 24 hours old. Each backup is written to a temporary
file, renamed into place, read back, and integrity verified before it becomes
eligible for retention. Automatic backup failures are not silently ignored:
status, age, and the actionable error appear on the Backup screen. Retention keeps five
automatic copies by default and preserves the current and previous verified
copy, so rotation never deletes the only recoverable automatic backup. The
catalogue lists creation time, size, verification level, task/goal/focus counts,
and supports confirmed restore or deletion of a selected copy. Restoring an
automatic copy uses the same validated replace-data path as an imported backup.
There is no background service; use **Back up now** or an export when the
startup policy is not sufficient.

New version-1 backups include an integrity envelope with the application
version, completion state, UTF-8 payload length, and SHA-256 checksum. The
checksum covers canonical UTF-8 JSON containing exactly `data` and
`preferences`; object keys are recursively sorted, list order is preserved,
and JSON number, null, Unicode, and escaping behavior follows Dart's JSON
encoder. The envelope timestamp is not part of the checksum. Existing version
1 backups without integrity metadata remain importable as legacy/unverified.
SHA-256 detects corruption or modification but does not authenticate the
creator or encrypt the exported file.

Exports are generated and verified in app-private staging storage before the
platform document provider is asked to publish them. Systum reports three
verification levels: staging verified, destination write accepted, and
destination verified after readback. Some Android document providers accept a
write but do not expose a reopenable path, so destination verification and
atomic replacement cannot be guaranteed universally. Interrupted staging and
publication operations are journaled separately from restore operations;
startup verifies retained staging files and removes only strictly-owned
abandoned `.staging` files. On Android, Systum uses the platform
`ACTION_CREATE_DOCUMENT` Storage Access Framework flow because the supported
`file_selector_android` version does not implement save-document selection.
When a verified staged backup is retained after interruption, the next export
action can resume publication after the user selects a destination.

---

### Data diagnostics

Open **Backup and restore → Run data diagnostics**. Diagnostics execute
read-only checks for SQLite integrity, foreign keys, schema version, required
tables/columns/indexes, task relationships, focus session/interval invariants,
reminder schedules, and Pomodoro settings. Results are classified as healthy,
warning, error, or inconclusive, and list affected record identifiers. Systum
never repairs or deletes data automatically. If a check is inconclusive,
restart the app and run it again; preserve the current data and restore only a
verified backup after reviewing the findings.

## Recurring Tasks and Occurrences

Systum supports recurring tasks with an SQLite source of truth:

* Recurrence types are daily, weekly (selected weekdays), monthly, and a
  custom every-N-days interval where supported. The weekly type stores a
  weekday bitmask and applies the interval in week units; the monthly type
  anchors on the start day and clamps to the last valid day of shorter months,
  including month-end and leap-year boundaries.
* The parent task stores the template and the recurrence tables store the
  rule plus generated occurrences. A rule keeps its parent task in a separate
  row and every occurrence has a stable `occ:<ruleId>:<YYYY-MM-DD>` identifier.
* Recurrence dates are stored as UTC midnight epoch milliseconds. Occurrences
  keep the parent task's due time and timezone, and the occurrence due date is
  the occurrence calendar date.
* Generation is bounded (90-day default horizon, 1000 rows per run, 10000
  iteration guard) and idempotent. It resumes after the latest persisted
  occurrence, ignores existing dates, and runs missed-date recovery after
  startup. Stops and edits never regenerate dates that already exist.
* End dates and maximum occurrence counts are validated and enforced. Editing
  an existing recurrence preserves prior occurrences and does not backfill
  before the latest occurrence; saving an empty edit stops future generation.
* Occurrences can be completed, reopened, rescheduled, or soft-deleted. Deleted
  occurrences stay stored so generation cannot recreate them, and completion
  history is preserved.
* Stopping a recurrence sets the rule inactive and keeps every stored
  occurrence and completion; resuming continues after the latest occurrence.

These semantics are covered by repository, provider, and widget tests in
`test/features/tasks/` and migration coverage for schema version 7.

## Task Reminders

Reminder persistence is the SQLite source of truth for future notification
delivery. Schema version 8 adds the `reminders` table and indexes, and reminder
rows are tied to their task with a cascading foreign key.

* One-time reminders store an absolute UTC instant. Recurring reminders store a
  local wall-clock time, an optional IANA timezone (null means device-local),
  UTC-midnight start/end dates, an interval, weekly weekday bits, and an
  optional maximum occurrence count. This keeps the user's intended local time
  stable across timezone and daylight-saving changes.
* Status is `scheduled` or `cancelled`; cancelled rows are retained with a
  reason (`user` or `taskCompleted`) and timestamp for history and diagnostics.
* Completing a task cancels its scheduled reminders in the same transaction.
  Reopening the task reactivates only reminders cancelled by task completion;
  explicit user cancellations remain cancelled. Deleting a task cascades to its
  reminders.
* Reminder writes reject missing or completed tasks. Full backups include
  reminder rows; selective task exports intentionally exclude them.

Reminder persistence is covered by domain, repository, provider, migration,
backup, diagnostics, and selective-portability tests.

## Android Notification Delivery (D3)

`lib/features/reminders/notifications/` isolates the Android scheduler behind a
small interface, so the reminder domain never touches plugin types directly.

* Notification IDs are deterministic FNV-1a digests of the persisted reminder ID
  and are reused across restarts, reschedules, and edits.
* One-time reminders schedule their absolute UTC instant; recurring reminders
  reuse the persisted recurrence projection for an exact daily or weekly repeat
  and fall back to the next occurrence for shapes Android cannot repeat exactly.
* Cancellation replaces the prior schedule before installing the new intent.
* Task completion, reopen, and deletion mirror persisted reminder state through
  the existing reminder providers.
* Runtime notification permission is requested through the scheduler; denial
  leaves the persisted reminder scheduled without an Android schedule.

Physical validation of Android reboot, timezone-change, permission-state,
duplicate-job, and missing-notification repair remains outstanding.

## Android Notification Reconciliation (D4)

D4 adds an idempotent reconciliation layer on top of the D3 scheduling path.

* Startup reconciliation derives the desired Android state from persisted
  SQLite reminders and applies it through the scheduler.
* Reboot re-arms via the boot receiver and the next startup reconciliation
  re-derives the same desired state, keeping cancel-and-replace idempotent.
* Permission denied during reconciliation leaves the persisted reminder intact
  without an Android schedule; a later reconciliation schedules again once the
  permission is restored.

## Task Hierarchy and Goal Rules

Systum supports exactly one level of nesting:

* A subtask must be created beneath an existing top-level task.
* A subtask cannot have its own subtasks.
* A subtask always inherits its parent's goal.
* A subtask cannot independently assign or remove a goal.
* Reassigning or removing a parent's goal updates all of its direct subtasks in
  the same database transaction; a failure rolls every assignment back.
* Deleting a parent promotes its direct subtasks to standalone tasks. The
  promotion and deletion run in one database transaction; a failure rolls both
  back.
* The task provider keeps one flat list of task rows. The UI derives the
  parent/child grouping from `parentTaskId`, so there is no second list that
  can drift from the database.

### Goal Progress Counting Rule

Goal progress counts actionable leaf tasks only:

* A leaf is a task with no direct children.
* A parent with children is a heading and is not counted alongside its
  children.
* Only tasks assigned to the goal are counted; tasks without a goal are
  ignored.
* A goal with no actionable tasks reports `0/0`, a fraction of `0.0`, and is
  not considered complete.
* A completed parent with incomplete children does not complete the goal.
* Promoted children become leaves and count normally.

The calculation lives in `GoalProgress` and is pure: it never mutates task
data and is independent of widgets and timers.

### Goal Lifecycle

The lifecycle is derived, never stored. `GoalStatus` evaluates a goal from its
`GoalProgress` and target date:

* **Completed** — the goal has at least one actionable leaf task and all of
  them are complete.
* **Overdue** — the goal is incomplete, has remaining actionable work, and its
  target calendar day is before today. Overdue means attention is needed, not
  that the goal failed.
* **Active** — every other incomplete goal, including goals with no target date
  and empty goals past their target date. An empty goal has no outstanding work
  to be overdue and is never considered complete automatically.

Completion never writes completion to tasks. A goal becomes complete because
its tasks are complete, and it becomes active again when a task is reopened.

Goal target dates are stored as integer days from 1970-01-01. They represent
calendar dates rather than instants, so formatting and overdue comparisons do
not shift when the device timezone changes. Existing timestamp-based target
dates are migrated by preserving the local calendar date they display in the
timezone active during migration; the original timezone and intended date
cannot be recovered from legacy values.

### Goal Assignment and Deletion

* A task may exist with or without a goal. Creating a task never requires a
  goal.
* A goal may exist with no tasks. Its detail screen remains actionable.
* Only top-level tasks can be assigned to or removed from a goal. The
  repository enforces this; the UI does not expose goal actions on subtasks.
* Assigning or removing a parent's goal propagates atomically to its direct
  subtasks.
* Deleting a goal preserves every task. The `ON DELETE SET NULL` foreign key
  clears the goal assignment; parent/subtask relationships are untouched.
* The goal list and goal detail screens refresh task state after goal deletion,
  and progress always derives from the canonical task provider.

## Roadmap

### Foundation

* [x] Flutter project initialization
* [x] Development environment setup
* [x] Core dependencies
* [x] Application bootstrap
* [x] Navigation infrastructure
* [x] Design system foundation
* [x] Drift database infrastructure
* [x] Riverpod dependency composition
* [x] Task schema
* [x] Task repository
* [x] Task state management and list UI
* [x] Create/Edit/Complete/Delete task flows
* [x] Goal schema and repository
* [x] Task-to-goal assignment
* [x] One-level subtasks and hierarchy UI
* [x] Transactional child promotion on parent deletion
* [x] Goal progress calculation
* [x] Goal list and goal detail screens
* [x] Goal create/edit/delete flows
* [x] Task assignment and removal flows
* [x] Goal lifecycle and target dates
* [x] Repository, provider, and widget tests
* [x] Focus interval persistence, recoverable session lifecycle, and Pomodoro
  progression
* [x] Pure daily and task focus-time aggregation with documented status policy

### Release follow-up

* [ ] Configure release signing outside the repository and validate on Android
* [ ] Confirm the public Android application ID before distribution
* [ ] Add device-level process-kill, device-restart, rotation, and small-screen
  verification
* [ ] Consider search and filtering after release reliability is established

---

## Engineering Philosophy

Systum is intended to demonstrate engineering maturity rather than framework knowledge.

Every architectural decision is evaluated against:

* Correctness
* Readability
* Maintainability
* Extensibility
* Testability
* Performance
* Developer Experience
* Portfolio value

The repository evolves through small, reviewable milestones with focused commits, continuous testing, and documentation that accurately reflects the current implementation.

---

## Contributing

The project is currently under active development. Contribution guidelines will be added once the architecture stabilizes.

---

## License

A project license will be added before the repository is made public.
