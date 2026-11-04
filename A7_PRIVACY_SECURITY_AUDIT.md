# Systum — A7 Privacy and Security Audit

**Status:** Complete (documentation-only; no justified code defects found)
**Scope:** Offline-first local data, SQLite source of truth, local backups/export/import
**Date:** 2026-11-03
**Repository state:** `master`, HEAD `b5b05b6`, working tree preserved (A3–A6 uncommitted)

## Audit method

Each of the twelve handover inspection areas was reviewed against the actual
repository implementation. No source-code changes were required because no
justified defect was found. Findings are recorded below with severity,
remediation (where any is warranted), and accepted limitations.

---

## 1. App-private temporary files

### Finding
Automatic backups and export staging both write to app-private directories
returned by `getApplicationSupportDirectory()`:

- Automatic backups: `<appSupport>/systum_backups/` (`LocalAutomaticBackupStore`)
- Export staging: `<appSupport>/systum_backup_exports/` (`LocalExportStorage`)

Temporary/staged files use distinctive prefixes/suffixes (`.systum-auto-*.tmp`,
`systum-export-*.staging`) and are cleaned by `cleanTemporaryFiles()` and
export-reconciliation. Temporary files are never published to a user-selected
destination.

### Severity
None.

### Remediation
None required.

### Accepted limitation
None.

---

## 2. Automatic backup storage and file permissions

### Finding
Files are created with default app-private file permissions on Android
(`MODE_PRIVATE` equivalent via `path_provider`). No `MODE_WORLD_READABLE` /
`MODE_WORLD_WRITABLE` equivalent is used. `android:allowBackup="false"` is set
in the manifest, so ADB backup cannot extract these files.

### Severity
None.

### Remediation
None required.

### Accepted limitation
None.

---

## 3. Exported backup payload exposure

### Finding
Backup / selective-export documents contain the user's full task, goal, and
Focus-history payload in plaintext JSON. The payload is not encrypted. Export
is delivered only to a user-selected destination via the file selector or
Android Storage Access Framework. There is no network upload, no cloud
integration, and no `INTERNET` permission.

### Severity
Low — by design.

### Remediation
None required. The product scope explicitly rules out introducing encryption or
key-management systems ("Do not introduce unnecessary encryption or key-management
systems"), so plaintext local-only export is the accepted model.

### Accepted limitation
A backup file written to a user-chosen destination (e.g. a shared Downloads
folder or a document provider) is protected only by the operating system's file
permissions at that destination, not by Systum encryption. Users are advised to
store backups in locations they control. Documented in README.

---

## 4. Sensitive logging

### Finding
No `print` or `debugPrint` calls exist in `lib` or `test`. The `logger` package
provider is defined (`lib/shared/providers/logger_provider.dart`) but is never
invoked anywhere in the application, so no log output is produced and no
sensitive data can be leaked through logs.

### Severity
None.

### Remediation
None required.

### Accepted limitation
If diagnostic logging is added later, it must avoid logging user task/goal/Focus
content, file contents, or file paths that could identify a user's backup
destinations.

---

## 5. Selective import validation

### Finding
`SelectivePortabilityService` validates imports defensively:

- Format (`systum-selective-export`) and version gating.
- Schema-version equality with the current database.
- 64 MB document-size ceiling before JSON decoding (`maxImportBytes`).
- SHA-256 + length integrity verification of the payload.
- Per-row type validation (required strings/ints/bools, optional fields, enum
  membership for mode/status).
- Duplicate-ID rejection.
- Missing parent/goal/interval reference rejection (blockers).
- Task-cycle prevention.
- Single unresolved Focus-session limit (running/paused).
- Conflict reporting with skip-by-default task/goal behavior; Focus history is
  append-only, never overwritten.
- All mutations run inside a single database transaction.

### Severity
None.

### Remediation
None required.

### Accepted limitation
None.

---

## 6. Full restore validation and attack surfaces

### Finding
`BackupService.restore` validates the complete document before touching the
database:

- Document size ceiling (64 MB).
- Format/version/schema-version checks.
- Integrity envelope validation (legacy backups allowed as unverified).
- SHA-256 + length integrity verification.
- Unique-ID, referential-integrity, cycle, Focus-session transition, and
  Pomodoro-settings validation.
- Restore requires explicit `overwriteExisting: true` consent.
- All SQLite changes run in one transaction.
- Restore journal records a content fingerprint (hash, not raw data) and
  preferences; startup reconciliation compares fingerprints and clears stale
  journals without re-applying data.

### Severity
None.

### Remediation
None required.

### Accepted limitation
A malicious or corrupt backup is rejected at validation before any database
write, so there is no injection path into SQLite via restore.

---

## 7. Android manifest permissions

### Finding
`android/app/src/main/AndroidManifest.xml` declares zero `uses-permission`
tags. There is no production `INTERNET` permission. The only declaration is a
`<queries>` entry for `android.intent.action.PROCESS_TEXT` (package visibility
for text sharing), which is not a permission and is required for the share
intent surface. `android:allowBackup="false"` is set.

### Severity
None.

### Remediation
None required.

### Accepted limitation
Any future Android integration requiring a permission (notifications, widgets,
shortcuts) must be added explicitly and reviewed; permissions remain
fail-closed/minimal by principle.

---

## 8. Dependency necessity

### Finding
Declared dependencies: `flutter_riverpod`, `go_router`, `cupertino_icons`,
`drift`, `drift_flutter`, `logger`, `shared_preferences`, `file_selector`,
`crypto`, `path_provider`. All are runtime-justified for state management,
routing, local SQLite persistence, settings, file selection, hashing, and app
storage. No network, analytics, cloud, Firebase, or social SDKs are present.

### Severity
Low observation.

### Remediation
None required. `logger` is declared but never invoked; it introduces no data
leakage because no logging calls exist. Retaining it is acceptable as a future
structured diagnostic-logging facility; removing it is speculative and out of
scope for this audit.

### Accepted limitation
If `logger` remains unused long-term, it may be removed in a future
dependency-hygiene pass. It does not affect the security posture.

---

## 9. Export and restore journal contents

### Finding
Journals are persisted in `SharedPreferences` and contain operational metadata
only:

- Export journal: operation ID, schema version, status, staging path, expected
  byte length, expected SHA-256, destination path. No user task/goal/Focus data.
- Restore journal: operation ID, schema version, status, database content
  fingerprint (FNV-1a hash of serialized rows — not raw data), incoming and
  previous preferences (Pomodoro settings and dismissed cycle IDs only).

Preferences are app settings, not personal user content. No journal exposes row
contents, task text, or file contents.

### Severity
None.

### Remediation
None required.

### Accepted limitation
Destination paths recorded in the export journal are app-internal paths plus
the user-selected destination path; neither is sensitive personal data.

---

## 10. Temporary-file ownership and cleanup

### Finding
Temporary files are owned by the app (`systum-auto-*.tmp`) and cleaned by
`cleanTemporaryFiles()`, which runs on every automatic backup attempt and on
export reconciliation. Orphan staging files are removed when no journal
references them; verified staged files are intentionally retained for recovery
and clearly surfaced in the UI.

### Severity
None.

### Remediation
None required.

### Accepted limitation
Temporary cleanup is best-effort at app startup/backup runs; a crash mid-write
may leave a `.tmp` file until the next launch. This is non-destructive and
does not expose user data.

---

## 11. User-selected destination handling

### Finding
The export destination is always user-selected via `file_selector` or the
Android Storage Access Framework (`AndroidExportPublisher`). Systum never
chooses, hard-codes, or silently uploads to a destination. Readback is
attempted; providers that refuse readback yield a documented `stagedOnly`
outcome with the verified staging file retained.

### Severity
None.

### Remediation
None required.

### Accepted limitation
Destination readback may be unavailable for some document providers (documented
`ExportReadbackStatus.unavailable`). The user retains the verified staging copy
in app-private storage for manual recovery.

---

## 12. Error messages and diagnostics for possible data leakage

### Finding
Error messages are generic and operational ("Backup integrity verification
failed", "Backup file is too large to import safely", etc.). No error message
embeds task/goal/Focus content or payload bytes. `AutomaticBackupService._describe`
includes a file path only for `FileSystemException` paths, which are app-private
paths, not user data. Diagnostics (A3) is read-only and reports record IDs and
severity, never row contents.

### Severity
None.

### Remediation
None required.

### Accepted limitation
File paths surface in `FileSystemException` diagnostics. These are
app-internal storage paths, not user-identifying data.

---

## Summary

| Area | Finding | Severity | Action |
|------|---------|----------|--------|
| Temp files | App-private, cleaned | None | None |
| Backup storage/permissions | App-private, allowBackup=false | None | None |
| Payload exposure | Plaintext, local-only, user-chosen destination | Low (by design) | Accepted limitation |
| Sensitive logging | No logging calls; logger unused | None | None |
| Selective import validation | Strong validation, transactional, size-limited | None | None |
| Restore validation | Full validation before write, journal reconciliation | None | None |
| Manifest permissions | Zero permissions, no INTERNET | None | None |
| Dependencies | All justified; logger unused observation | Low | None |
| Journal contents | Operational metadata only | None | None |
| Temp cleanup | Owned by app, reconciled | None | None |
| Destination handling | User-selected only | None | None |
| Error/diagnostic leakage | Generic messages, no payload exposure | None | None |

## Conclusion

No justified code defect was identified. Systum's backup, export, import,
restore, logging, permission, and dependency surface conforms to the offline-first,
local-data-ownership, minimal-permission principles. The only accepted
limitation is that backup files are plaintext and rely on OS file permissions at
the user-chosen destination, consistent with the explicit decision not to
introduce encryption or key management.

## Physical validation

Automated export/restore/interruption tests pass (351 tests). Physical Android
device validation of backup export through the Storage Access Framework remains
pending because no Android device or emulator is available in this environment
(see ROADMAP.md A2.5 and F1).
