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
- Persistent task reminders: schema v8 `reminders` table and indexes with a
  v7→v8 migration; one-time absolute UTC and recurring local wall-clock
  schedules with optional IANA timezone, UTC-midnight dates, interval, weekday
  mask, and occurrence cap; scheduled/cancelled status with retained
  cancellation metadata; transactional cancellation on task completion,
  reactivation on reopen, and cascade on task deletion; repository and
  Riverpod providers.
- Full backup/restore and schema-7 legacy compatibility for reminders, plus
  read-only reminder diagnostics and explicit exclusion from selective task
  exports.
- Android notification delivery for persisted reminders: `flutter_local_notifications`
  scheduler adapter with deterministic FNV-1a notification IDs, notification
  channel, runtime permission request, one-time and repeating schedules, cancel
  and reschedule through stable IDs, and task lifecycle integration through the
  reminder providers. Scheduling and delivery failures are logged without
  modifying persisted reminder state.
- Android notification reconciliation (D4): startup reconciliation from
  persisted SQLite reminders, reboot boot receiver plus startup re-derivation,
  idempotent cancel-and-replace with deterministic IDs, permission-denied
  skip and restored-permission re-schedule.
- Daily planning & calendar (E1–E4): daily agenda projecting persisted tasks
  and recurring task occurrences (Today, previous/next day, date selection,
  overdue and due-on-date sections, completion, quick creation); transient
  per-day task ordering; lightweight monthly calendar with navigation, Today
  shortcut, task-date indicators, and agenda navigation; factual daily summary
  (completed/incomplete/overdue tasks, focus sessions, focused time, tasks
  worked on) derived entirely from persisted data.
- Accessibility (I1–I4): `Semantics` labels on task cards, goal cards, goal
  task tiles, calendar day cells, and Focus controls (pause/resume/complete/
  cancel); dynamic state labels for completion, overdue, active, today, and
  selected states; keyboard dismissal on all dialog submissions (task create/
  edit, goal create/edit, focus start).
- Performance audit (J1–J4): database indexes verified, bounded occurrence
  generation (90-day horizon, 1000 rows/run), bounded Riverpod providers,
  non-blocking startup reconciliations, no polling, no unnecessary retained
  state. No optimization was justified.
- Architecture audit (K): UI→Provider→Repository→SQLite boundary verified,
  migrations/foreign keys/indexes/transactions intact, UTC timestamp and
  date-only UTC midnight conventions consistent, no swallowed exceptions, all
  dependencies actively used, no dead code found.

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
