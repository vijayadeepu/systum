import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/hydration/providers/hydration_provider.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('HydrationRepository', () {
    late SystumDatabase database;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('hydrationTotalMsProvider returns 0 for an empty day', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final total = await container.read(
        hydrationTotalMsProvider(DateTime.utc(2026, 8, 11)).future,
      );
      expect(total, 0);
    });

    test(
      'hydrationTotalMsProvider returns cumulative total after logging',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);

        await container
            .read(hydrationRepositoryProvider)
            .logEntry(250, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));
        await container
            .read(hydrationRepositoryProvider)
            .logEntry(500, loggedAt: DateTime.utc(2026, 8, 11, 11, 0));
        await container
            .read(hydrationRepositoryProvider)
            .logEntry(750, loggedAt: DateTime.utc(2026, 8, 11, 12, 0));

        final total = await container.read(
          hydrationTotalMsProvider(DateTime.utc(2026, 8, 11)).future,
        );
        expect(total, 1500);
      },
    );

    test('hydrationEntriesProvider returns entries for the day', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await container
          .read(hydrationRepositoryProvider)
          .logEntry(250, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));
      await container
          .read(hydrationRepositoryProvider)
          .logEntry(500, loggedAt: DateTime.utc(2026, 8, 11, 11, 0));

      final entries = await container.read(
        hydrationEntriesProvider(DateTime.utc(2026, 8, 11)).future,
      );
      expect(entries, hasLength(2));
      expect(entries.map((e) => e.amountMs).toList(), [250, 500]);
    });

    test('hydrationTargetMetProvider returns false below target', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await container
          .read(hydrationRepositoryProvider)
          .logEntry(500, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));
      await container
          .read(hydrationRepositoryProvider)
          .logEntry(750, loggedAt: DateTime.utc(2026, 8, 11, 11, 0));

      final met = await container.read(
        hydrationTargetMetProvider(DateTime.utc(2026, 8, 11)).future,
      );
      expect(met, isFalse);
    });

    test('hydrationTargetMetProvider returns true at target', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await container
          .read(hydrationRepositoryProvider)
          .logEntry(2500, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));

      final met = await container.read(
        hydrationTargetMetProvider(DateTime.utc(2026, 8, 11)).future,
      );
      expect(met, isTrue);
    });

    test(
      'hydrationTargetMetProvider returns true when target exceeded',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);

        await container
            .read(hydrationRepositoryProvider)
            .logEntry(3000, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));

        final met = await container.read(
          hydrationTargetMetProvider(DateTime.utc(2026, 8, 11)).future,
        );
        expect(met, isTrue);
      },
    );

    test(
      'hydrationTargetMetProvider returns false for a different day',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);

        await container
            .read(hydrationRepositoryProvider)
            .logEntry(2500, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));

        final met = await container.read(
          hydrationTargetMetProvider(DateTime.utc(2026, 8, 12)).future,
        );
        expect(met, isFalse);
      },
    );

    test(
      'provider reflects newly logged entries (invalidates after mutation)',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);

        await container.read(
          hydrationTotalMsProvider(DateTime.utc(2026, 8, 11)).future,
        );
        expect(
          await container.read(
            hydrationTotalMsProvider(DateTime.utc(2026, 8, 11)).future,
          ),
          0,
        );

        await container
            .read(hydrationRepositoryProvider)
            .logEntry(1000, loggedAt: DateTime.utc(2026, 8, 11, 10, 0));
        container.refresh(hydrationTotalMsProvider(DateTime.utc(2026, 8, 11)));

        final total = await container.read(
          hydrationTotalMsProvider(DateTime.utc(2026, 8, 11)).future,
        );
        expect(total, 1000);
      },
    );
  });
}
