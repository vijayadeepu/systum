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

### Current limitations

* Focus history is currently loaded as one indexed local query; pagination has
  not been added because no measured query problem exists yet.
* Search, filtering, and manual ordering are not implemented.
* Android release signing must be configured with a private key by the release
  owner. The repository does not contain signing credentials.
* The Android application ID remains `com.example.systum`; changing it requires
  an explicit product decision before public distribution.

---

## Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   └── router.dart
├── core/
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

The Android application ID is `com.example.systum`, the displayed app name is
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

In
`android/app/build.gradle.kts`, load `android/key.properties` into a
`java.util.Properties`, use its values to set `storeFile`, `storePassword`,
`keyAlias`, and `keyPassword` in `signingConfigs.create("release")`, and assign
`signingConfigs.getByName("release")` to the `release` build type. Keep both
the keystore and properties file out of source control. The repository
currently has no signing credentials or release config, so do not treat a
debug-signed or unsigned APK as a release.
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

---

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
