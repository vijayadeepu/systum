# Changelog

Notable changes to Systum are recorded here.

## Unreleased

### Added

- Versioned local backup export/import for tasks, goals, focus sessions,
  intervals, task hierarchy, and Pomodoro settings.
- Pre-restore validation and explicit destructive-replace confirmation.
- Backup integrity checks for relationships, task hierarchy cycles, and focus
  session interval invariants.
- Durable restore journal and startup reconciliation for interrupted
  SQLite/SharedPreferences restores.
- SHA-256 integrity metadata and canonical payload verification for new
  version-1 backups, with legacy version-1 compatibility.
- Staged backup export with destination verification levels and conservative
  interrupted-export recovery.
- Android Storage Access Framework document publication and resumable retained
  staged exports when a provider write or readback is interrupted.
- Read-only data diagnostics for SQLite integrity, foreign keys, schema
  version/columns/indexes, task relationships, focus interval invariants, and
  Pomodoro settings, including affected-record identifiers and recovery
  guidance.
- Automatic app-private backups at startup when the last verified copy is
  older than 24 hours, with verified atomic writes, bounded retention that
  preserves the current and previous copy, persisted failure status, temporary
  file reconciliation, and duplicate-run protection.
- Backup catalogue showing creation time, size, verification level, and
  task/goal/focus counts, with confirmed restore and deletion of selected
  automatic copies.
- Recurring task support: daily, weekly with selected weekdays, monthly, and
  custom every-N-days rules; task create/edit integration; schema v7
  task_recurrence_rules and task_occurrences tables with unique indexes and
  UTC-midnight date normalization from v6; bounded idempotent occurrence
  generation with generation horizon and caps; end date and maximum occurrence
  enforcement; stop/resume semantics that preserve history; independent
  occurrence completion, reopening, rescheduling, and soft deletion.
- Read-only recurrence diagnostics for rules, occurrences, validity, and
  duplicate/orphan records.

### Fixed

- Focus History now uses the injectable Focus system clock for its initial day,
  removing date-coupled behavior and restoring deterministic widget tests.
- Version 7 migration now removes occurrences belonging to discarded duplicate
  legacy rules before deleting those rules, preventing orphaned references.

## 0.1.0 — 2026-10-31 — Early Access preparation

### Added

- Focus History screen with daily summary, date navigation, task totals, and
  terminal session details.
- System dark-mode theme support for the existing design system.
- Recoverable Focus sessions with persisted active intervals and task-title
  snapshots.
- Explicit Pomodoro focus and break segments, with cycle state reconstructed
  from local session history.
- Local-day, task, and daily-task focus-time aggregation from persisted
  intervals.
- Database schema v4 for focus sessions and intervals, including migrations
  from earlier supported schemas.
- Systum-colored native Android launcher icon and app label.

### Reliability

- Focus aggregation excludes cancelled sessions and break segments, counts
  interrupted interval time as focused time, and counts only completed
  sessions in the completed-session total.
- Aggregation splits intervals at local midnight and rejects overlaps across
  sessions.
- Android release builds use a fail-closed signing configuration that reads the
  owner-managed ignored `android/key.properties`; a private release keystore is
  still required before distribution.

### Limitations

- Android device-level restart validation and release signing are pending.
- The Android application ID is `com.systum.app`.
