import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/hydration/providers/hydration_provider.dart';
import 'package:systum/features/hydration/widgets/hydration_summary.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  final testDate = DateTime.utc(2026, 8, 11);

  Future<void> pumpHydrationSummary(
    WidgetTester tester, {
    int totalMs = 0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          hydrationTotalMsProvider(
            testDate,
          ).overrideWith((ref) async => totalMs),
          hydrationTargetMsProvider.overrideWithValue(2500),
          hydrationTargetMetProvider(
            testDate,
          ).overrideWithValue(AsyncValue.data(totalMs >= 2500)),
        ],
        child: MaterialApp(home: HydrationSummary(date: testDate)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows zero intake and target when nothing logged', (
    tester,
  ) async {
    await pumpHydrationSummary(tester, totalMs: 0);

    expect(find.textContaining('0.0 L / 2.5 L'), findsOneWidget);
  });

  testWidgets('displays cumulative intake after logging entries', (
    tester,
  ) async {
    await pumpHydrationSummary(tester, totalMs: 750);

    expect(find.textContaining('0.8 L / 2.5 L'), findsOneWidget);
  });

  testWidgets('displays target reached when intake meets target', (
    tester,
  ) async {
    await pumpHydrationSummary(tester, totalMs: 2500);

    expect(find.textContaining('2.5 L / 2.5 L'), findsOneWidget);
    expect(find.textContaining('Target reached'), findsOneWidget);
  });

  testWidgets('shows target exceeded when intake is above target', (
    tester,
  ) async {
    await pumpHydrationSummary(tester, totalMs: 3000);

    expect(find.textContaining('3.0 L / 2.5 L'), findsOneWidget);
    expect(find.textContaining('Target reached'), findsOneWidget);
  });

  testWidgets('has quick-log button for 250ml', (tester) async {
    await pumpHydrationSummary(tester);

    expect(find.text('250 ml'), findsOneWidget);
  });

  testWidgets('fits a narrow screen without hydration overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHydrationSummary(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows zero on a new day', (tester) async {
    await pumpHydrationSummary(tester, totalMs: 0);

    expect(find.textContaining('0.0 L / 2.5 L'), findsOneWidget);
  });
}
