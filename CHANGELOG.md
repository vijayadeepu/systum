# Changelog

Notable changes to Systum are recorded here.

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
- Android release builds no longer use the debug signing key. A private
  release signing configuration is still required before distribution.

### Limitations

- Android device-level restart validation and release signing are pending.
- The Android application ID is still `com.example.systum`.
