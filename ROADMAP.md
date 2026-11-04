# Systum Implementation Tracker

Statuses are limited to: **Not Started**, **In Progress**, **Implemented**,
**Automated Tests Passed**, **Physical Validation Pending**, **Verified**, and
**Blocked**. A milestone is never marked Verified without its required
automated and physical acceptance evidence.

Last updated: 2026-11-03.

| ID | Workstream | Status | Dependencies | Evidence and remaining work |
|---|---|---|---|---|
| 0 | Repository audit and baseline | Verified | None | Verified branch `master`, HEAD `b5b05b6`, working tree preserved, 468 tests passing after B7 task hierarchy hardening implementation. |
| A2.5 | Physical Android backup validation | Physical Validation Pending | Android device/emulator | Automated export/restore tests pass. No Android device or AVD is available (`flutter devices`, `adb devices`); manual checklist in README and this tracker remains outstanding. |
| A3.1 | SQLite integrity diagnostics | Automated Tests Passed | Schema v4 | `PRAGMA integrity_check`, `foreign_key_check`, schema version, table/column/index verification, severity classification, record IDs. Tests in `test/core/diagnostics/database_diagnostics_test.dart`. |
| A3.2 | Application consistency diagnostics | Automated Tests Passed | A3.1 | Task orphan/cycle/depth/goal-inheritance checks; focus interval overlap/bounds/open-interval/duration/end-time checks; Pomodoro settings checks. |
| A3.3 | Diagnostics UI | Automated Tests Passed | A3.1, A3.2 | Read-only screen with loading/error/data states, refresh, severity counts, guidance, record IDs. Tests in `test/core/diagnostics/diagnostics_page_test.dart`. |
| A4.1 | Automatic local backup engine | Automated Tests Passed | A3 | `AutomaticBackupService` reuses the verified backup pipeline, runs at startup after restore reconciliation, writes atomically to app-private storage, tracks status, and prevents duplicate runs. Tests in `test/core/backup/automatic_backup_test.dart`. |
| A4.2 | Retention and rotation | Automated Tests Passed | A4.1 | Five-copy default retention, current and previous verified copy protection, safe deletion, temporary-file cleanup, and storage usage. Tests cover rotation and failure preservation. |
| A4.3 | Backup failure management | Automated Tests Passed | A4.1 | Persisted attempt/success/error state, retry backoff, duplicate-run guard, atomic readback verification, and visible Backup-screen failures. Physical disk-full behavior remains unvalidated. |
| A5 | Backup catalogue and management | Automated Tests Passed | A4.1, A4.2 | Catalogue lists time, size, verification, task/goal/focus counts, storage total, confirmed restore, and confirmed delete. Tests cover catalogue, restore, delete, and unreadable files. |
| A6 | Selective data portability | Automated Tests Passed | A5 | Separate `systum-selective-export` format; JSON/CSV export for tasks, goals and Focus history; import preview, conflict/blocker reporting, transactional import, skip-by-default conflicts, append-only Focus history; `/backup/portability` route and UI. Tests in `test/core/backup/selective_portability_test.dart` and `test/core/backup/selective_portability_page_test.dart`. |
| A7 | Privacy and security audit | Implemented | A5, A6 | Storage, logging, import, restore, permission, dependency, journal, destination, and error-message review completed. No justified code defects found. Documented in `A7_PRIVACY_SECURITY_AUDIT.md` (findings, severity, remediation, accepted limitations). Full 351-test suite passes. |
| B1 | Task search | Automated Tests Passed | A7 | Database-backed case-insensitive title/description search with debounced input (300 ms), clear control, loading/empty/error states, deterministic ordering, revision-based race protection. Repository: `searchTasks()` with LIKE matching and wildcard escaping. Provider: `taskSearchProvider` with debounce + revision tracking. UI: inline app-bar search field with clear action and no-results state. 23 new tests (11 repository + 12 provider), all passing. |
| B2 | Task filtering | Automated Tests Passed | B1 | Composable task filters: status (all/active/completed), time (today/upcoming/overdue/custom), priority, goal, parent task, subtask, category. All dimensions intersect logically. Database-backed filtering via `filterTasks()` and `searchAndFilter()`. Clear-all operation. Null-safe handling of optional fields. Local calendar date for Today/Overdue/Upcoming. Provider: `taskFilterProvider` + filter-aware `taskSearchProvider`. UI: app-bar overflow menu with filter bottom sheet, filter chips, clear all. 19 new repository tests, all passing. Full suite: 393 tests after B2. |
| B3 | Task sorting | Automated Tests Passed | B1 | Six sort modes: creation date, updated date, due date, priority, alphabetical title, completion status. Ascending/descending order. Deterministic tie-breaker (createdAt DESC, id ASC). Null due dates sort last. Database-backed via `_applySort()` in repository. `getAll()` accepts optional `TaskSort`. `taskSortProvider` (NotifierProvider) with `setMode()` (toggling same mode reverses order) and `setOrder()`. `taskSearchProvider` and `TaskNotifier` refresh on sort changes. UI: sort option in overflow menu, sort bottom sheet with mode/order chips. Sort persists across search, filter, and mutations. 19 new tests (13 repository + 6 provider), all passing. Full suite: 412 tests after B3. |
| B4 | Task views | Automated Tests Passed | B2, B3 | Eight views: Inbox/All Tasks, Today, Upcoming, Overdue, Completed, By Goal, By Priority, Recently Updated. View constraints intersect with filters and search. Repository: `filterTasks()` and `searchAndFilter()` accept optional `TaskView`. Today/Overdue/Upcoming use local calendar date; null due dates excluded from time-based views. Provider: `taskViewProvider` (NotifierProvider) with `setView()`. `taskSearchProvider` listens to view changes. UI: horizontally scrollable view selector chips in app bar, grouped layouts for By Goal/By Priority, empty states per view, reset button. View persists across search, filters, sort, and mutations. 31 new tests (17 repository + 6 provider + 10 UI), all passing. Full suite: 443 tests after B4. |
| B5 | Task detail screen | Automated Tests Passed | B3 | Complete task detail screen with title, description, category, priority, due date, created/updated timestamps, goal assignment (display/assign/reassign/remove/navigate), parent task navigation, subtask creation, complete/reopen/delete lifecycle, linked Focus session history display. Repository: `getFocusSessionsForTask()`. Provider: `taskDetailProvider` (FutureProvider.family). UI: `TaskDetailPage` with loading/error/missing states, app bar actions (edit/delete), focus history section. Route: `/task/:taskId`. 11 new tests (7 repository/provider + 4 UI), all passing. Full suite: 454 tests. |
| B6 | Task creation and editing | Automated Tests Passed | B5 | Enhanced CreateTaskDialog with category field, loading state during submit, form validation, and save/cancel behavior. Dialog converts task to/from Task model for create and edit flows. Category field added with 80-char validation. Due date picker with clear action. Priority dropdown. All existing tests pass (454 total). |
| B7 | Task hierarchy and lifecycle hardening | Automated Tests Passed | B6 | Hardened hierarchy integrity: self-parent prevention in createSubtask, deep nesting rejection (grandchild), cycle prevention through reassignment, cascading delete with subtask promotion, completion toggle updates updatedAt, null relationships preserved, duplicate ID rejection, large task list performance (no N+1 queries). 14 new repository tests, all passing. Full suite: 468 tests. |
| B8 | Task module integration and final QA | Automated Tests Passed | B5, B6, B7 | Final integration and quality gate complete. All 8 user journeys verified through existing tests. UI consistency verified across task list, detail, creation, editing screens. Complete regression suite: 489 tests pass after D1. Flutter analyze: no errors/warnings (only pre-existing infos). Formatting: clean. Diff check: clean. Debug APK build: successful. |
| D1 | Due-date/time model + countdown | Automated Tests Passed | B7 | Schema v5: adds dueTime (seconds since midnight) and dueTimezone (IANA ID) columns to tasks. Task model updated with dueTime/dueTimezone fields. Backup/restore and selective portability updated for new fields. CountdownProvider computes live countdowns with timezone-aware deadlines using a single shared timer (auto-dispose). TaskTile displays countdown ("Xd Yh Zm", "Due now", "Overdue"). 21 new tests (13 repository + 8 provider), all passing. Full suite: 489 tests. |
| C1–C3 | Recurrence | Automated Tests Passed | D1 | Implemented: daily, weekly selected weekdays, monthly, and custom every-N-days domain rules; task create/edit integration; schema v7 rule/occurrence tables, unique indexes, UTC-midnight normalization, and migration from v6; bounded idempotent generation with 90-day horizon, end date and max occurrence enforcement, stop/resume, occurrence lifecycle, and startup recovery. Repository, provider, widget, migration, diagnostics, and backup tests added; full suite passing after final recurrence QA. |
| D2 | Reminder persistence | Not Started | D1 | No reminder model or migration. |
| D3 | Android notifications | Not Started | D2 | No notification permission, scheduling, or actions. |
| D4 | Notification reconciliation | Not Started | D3 | No notification reconciliation. |
| E1 | Today dashboard | Not Started | B4, D1 | No Today screen. |
| E2 | Daily agenda | Not Started | E1 | No date-grouped agenda or rescheduling. |
| E3 | Calendar | Not Started | E2 | No monthly calendar. |
| E4 | Factual execution summaries | Not Started | E1 | History provides raw totals; dedicated factual summary screen not built. |
| F1 | Physical focus lifecycle validation | Physical Validation Pending | Android device | Existing automated recovery tests pass; process death, restart, clock-change, and background validation not physically executed. |
| F2–F4 | Focus UX, Pomodoro refinements, history | In Progress | F1 | Active controls, Pomodoro settings/cycle, and indexed history exist. Bounded history/date-range loading and large-history measurements remain. |
| G1 | App shortcuts | Not Started | H1 | No Android shortcuts. |
| G2 | Deep links | Not Started | H1 | No external deep-link routes/validation. |
| G3 | Share-to-Systum | Not Started | B5 | No share intent handling. |
| G4 | Home-screen widgets | Not Started | G1, D4 | No widgets. |
| G5 | Quick Settings | Not Started | G1 | No tile. |
| G6 | Lock-screen/notification refinements | Not Started | D3 | No notification integration. |
| H1 | Navigation architecture | Not Started | B4, E1 | Current routes: tasks, goals, focus, history, backup, diagnostics. |
| H2 | Global search | Not Started | B1, H1 | No unified task/goal search. |
| H3 | Interaction refinement | In Progress | H1 | Existing empty/error/destructive flows reviewed; broader refinement pending. |
| H4 | Responsive layouts | Not Started | H1 | No tablet/landscape/large-text validation yet. |
| I1–I4 | Accessibility | Not Started | H1, H4 | Some semantics exist; full screen-reader, scaling, contrast, and focus-traversal work pending. |
| J1–J4 | Performance and benchmarks | Not Started | B4, E3, F4 | No synthetic datasets or recorded baselines yet. |
| K | Architecture audit | Not Started | Major phases | Pending. |
| L | Complete QA and regression | In Progress | All phases | 351 automated tests currently pass; scale, integration, and physical-device suites remain. |
| M1 | Release signing | Blocked | Owner authorization | `android/key.properties` absent; fail-closed configuration. No keystore generated. |
| M2 | Release identity | Implemented | None | `com.systum.app`, label `Systum`, version `0.1.0+1`, launcher icon present; final metadata audit pending. |
| M3 | Production build | Blocked | M1 | Debug APK builds successfully; signed release cannot be produced without owner keystore. |
| M4 | Upgrade testing | Blocked | Physical device | Migration tests pass; device-level upgrade validation unavailable. |
| M5 | Distribution | Not Started | M3, M4 | No release workflow, APK, notes, or changelog publication. |
| M6 | Final acceptance | Not Started | All | Pending. |

## A2.5 manual Android checklist

Automated tests cover staging, publication, readback-unavailable behavior,
checksum mismatch, cancellation, startup reconciliation, and restore. The
following physical checks remain and must not be reported as passed until run
on an Android device:

1. Export to local device storage.
2. Export through Android Storage Access Framework.
3. Export through Google Drive or another document provider.
4. Overwrite an existing destination file and verify the final content.
5. Cancel destination selection and confirm no staged file is left behind.
6. Force-stop during staging, reopen, and verify recovery.
7. Force-stop during publication, reopen, and verify retained staging.
8. Force-stop after destination write but before readback.
9. Force-stop after destination verification but before journal cleanup.
10. Use a provider that refuses readback and verify the reported verification
    level and retained staged copy.
11. Restart repeatedly and verify idempotent cleanup.
12. Restore the exported backup and verify tasks, goals, focus history, and
    Pomodoro settings.

## Current environment limitations

- No Android device and no AVD/emulator are available in this environment.
- `android/key.properties` and a release keystore are absent by design.
- Physical Focus lifecycle and release-upgrade validation therefore remain
  pending or blocked rather than claimed.
