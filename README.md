# Systum

> An offline-first personal productivity operating system built with Flutter.

## Overview

Systum is a long-term software engineering project focused on building a production-quality, offline-first productivity platform rather than a simple to-do application.

The primary objective is to demonstrate modern Flutter engineering practices, evolutionary architecture, maintainable code, and professional development workflows. Every architectural decision is introduced only when it provides measurable value, allowing the codebase to evolve naturally as the application grows.

This repository prioritizes engineering quality, developer experience, and long-term maintainability over rapid feature development.

---

## Vision

Systum is designed to evolve into a modular productivity operating system that helps users manage work, learning, and personal growth.

Planned capabilities include:

* Task Management
* Subtasks
* Projects & Categories
* Dashboard
* Habit Tracking
* Pomodoro Timer
* Countdown Timers
* Hydration Tracking
* Learning Tracker
* Statistics & Analytics
* Search & Filtering
* Notifications
* Calendar Integration
* AI Assistant
* Cloud Synchronization
* Plugin Architecture
* Cross-platform Support

Features will be introduced incrementally on top of a stable engineering foundation.

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

**Project Stage:** Goal Management

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

### Next Milestones

* Search & filtering
* Focus sessions
* Logging infrastructure
* Global error handling
* Settings infrastructure
* Dark theme

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

## Known Limitations

* There is no dark theme yet; the app currently ships a single light theme.
* There is no dedicated full-screen task detail route. Tapping a task in a goal
  opens the existing edit flow.
* Focus sessions, search, filtering, and notifications are not implemented.
* Goal ordering is newest-first; manual reordering is not implemented.

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

### Current Focus

* [ ] Search & filtering
* [ ] Focus sessions
* [ ] Dark theme

### Future

* [ ] Logging infrastructure
* [ ] Global error handling
* [ ] Settings infrastructure
* [ ] Habit tracking
* [ ] Dashboard
* [ ] Productivity modules
* [ ] Notifications
* [ ] Backup & Restore
* [ ] Calendar integration
* [ ] Cloud synchronization
* [ ] AI assistant
* [ ] Plugin architecture

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
