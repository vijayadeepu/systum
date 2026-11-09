import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/hydration/repository/hydration_repository.dart';

void main() {
  group('HydrationRepository', () {
    late SystumDatabase database;
    late HydrationRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = HydrationRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('logEntry stores a hydration entry', () async {
      final loggedAt = DateTime.utc(2026, 8, 11, 10, 0);

      await repository.logEntry(250, loggedAt: loggedAt);

      final entries = await repository.getEntriesForDate(DateTime(2026, 8, 11));
      expect(entries, hasLength(1));
      expect(entries.single.amountMs, 250);
      expect(entries.single.loggedAtMs, loggedAt.millisecondsSinceEpoch);
    });

    test('getEntriesForDate returns entries in chronological order', () async {
      final earlier = DateTime.utc(2026, 8, 11, 10, 0);
      final later = DateTime.utc(2026, 8, 11, 11, 0);

      await repository.logEntry(250, loggedAt: later);
      await repository.logEntry(500, loggedAt: earlier);

      final entries = await repository.getEntriesForDate(DateTime(2026, 8, 11));
      expect(entries, hasLength(2));
      expect(entries.first.loggedAtMs, earlier.millisecondsSinceEpoch);
      expect(entries.last.loggedAtMs, later.millisecondsSinceEpoch);
    });

    test('getEntriesForDate excludes entries from other days', () async {
      await repository.logEntry(
        250,
        loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
      );
      await repository.logEntry(
        500,
        loggedAt: DateTime.utc(2026, 8, 12, 10, 0),
      );

      final entries = await repository.getEntriesForDate(DateTime(2026, 8, 11));
      expect(entries, hasLength(1));
      expect(entries.single.amountMs, 250);
    });

    test(
      'getEntriesForDate returns empty list for a day with no entries',
      () async {
        await repository.logEntry(
          250,
          loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
        );

        final entries = await repository.getEntriesForDate(
          DateTime(2026, 8, 12),
        );
        expect(entries, isEmpty);
      },
    );

    test('getDailyTotalMs sums all entries for a day', () async {
      await repository.logEntry(
        250,
        loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
      );
      await repository.logEntry(
        500,
        loggedAt: DateTime.utc(2026, 8, 11, 11, 0),
      );
      await repository.logEntry(
        750,
        loggedAt: DateTime.utc(2026, 8, 11, 12, 0),
      );

      final total = await repository.getDailyTotalMs(DateTime(2026, 8, 11));
      expect(total, 1500);
    });

    test('getDailyTotalMs returns 0 for a day with no entries', () async {
      await repository.logEntry(
        250,
        loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
      );

      final total = await repository.getDailyTotalMs(DateTime(2026, 8, 12));
      expect(total, 0);
    });

    test('isTargetMet returns true when total meets target', () async {
      await repository.logEntry(
        250,
        loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
      );
      await repository.logEntry(
        500,
        loggedAt: DateTime.utc(2026, 8, 11, 11, 0),
      );
      await repository.logEntry(
        750,
        loggedAt: DateTime.utc(2026, 8, 11, 12, 0),
      );
      await repository.logEntry(
        1000,
        loggedAt: DateTime.utc(2026, 8, 11, 13, 0),
      );

      final met = await repository.isTargetMet(DateTime(2026, 8, 11), 2500);
      expect(met, isTrue);
    });

    test('isTargetMet returns false when total is below target', () async {
      await repository.logEntry(
        500,
        loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
      );
      await repository.logEntry(
        750,
        loggedAt: DateTime.utc(2026, 8, 11, 11, 0),
      );

      final met = await repository.isTargetMet(DateTime(2026, 8, 11), 2500);
      expect(met, isFalse);
    });

    test(
      'entries are stored in UTC and read back in local calendar date',
      () async {
        final loggedAt = DateTime.utc(2026, 8, 11, 10, 0);

        await repository.logEntry(250, loggedAt: loggedAt);

        // Stored value is the UTC epoch ms, not shifted.
        final stored = await database
            .select(database.hydrationEntries)
            .getSingle();
        expect(stored.loggedAtMs, loggedAt.millisecondsSinceEpoch);

        // Querying the same local date finds the entry.
        final aug11 = await repository.getEntriesForDate(DateTime(2026, 8, 11));
        expect(aug11, hasLength(1));
        expect(aug11.single.loggedAtMs, loggedAt.millisecondsSinceEpoch);

        // Querying a different day finds nothing.
        final aug10 = await repository.getEntriesForDate(DateTime(2026, 8, 10));
        expect(aug10, isEmpty);
        final aug12 = await repository.getEntriesForDate(DateTime(2026, 8, 12));
        expect(aug12, isEmpty);
      },
    );

    test('deleteEntry removes only the matching entry', () async {
      final loggedAt = DateTime.utc(2026, 8, 11, 10, 0);
      await repository.logEntry(250, loggedAt: loggedAt);
      await repository.logEntry(
        500,
        loggedAt: DateTime.utc(2026, 8, 11, 11, 0),
      );

      final entries = await repository.getEntriesForDate(DateTime(2026, 8, 11));
      await repository.deleteEntry(entries.first.id);

      final remaining = await repository.getEntriesForDate(
        DateTime(2026, 8, 11),
      );
      expect(remaining, hasLength(1));
      expect(remaining.single.amountMs, 500);
    });

    test('deleteEntry for a missing id is a no-op', () async {
      await repository.logEntry(
        250,
        loggedAt: DateTime.utc(2026, 8, 11, 10, 0),
      );

      await repository.deleteEntry('nonexistent-id');

      final entries = await repository.getEntriesForDate(DateTime(2026, 8, 11));
      expect(entries, hasLength(1));
    });
  });
}
