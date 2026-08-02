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

**Project Stage:** Engineering Foundation

### Completed

* Flutter project initialization
* Development environment setup
* Feature-first project structure
* Application bootstrap
* GoRouter-based navigation
* Material 3 design system foundation
* Drift database infrastructure
* Riverpod dependency composition
* Task database schema
* Task repository implementation
* Repository unit tests

### Next Milestones

* Riverpod task state management
* Task list UI
* Create/Edit task workflow
* Search & filtering
* Logging infrastructure
* Global error handling
* Settings infrastructure

---

## Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   └── router.dart
├── core/
│   ├── constants/
│   ├── database/
│   ├── errors/
│   ├── logging/
│   ├── theme/
│   └── utils/
├── features/
│   ├── home/
│   └── tasks/
├── shared/
│   ├── extensions/
│   ├── providers/
│   └── widgets/
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

### Verify the Project

```bash
dart analyze
flutter test
```

Both commands should complete successfully before contributing changes.

---

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
* [x] Repository unit tests

### Current Focus

* [ ] Riverpod task state management
* [ ] Task list UI
* [ ] Create/Edit task flow
* [ ] Search & filtering

### Future

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
