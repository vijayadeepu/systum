import 'package:flutter_test/flutter_test.dart';
import 'package:systum/app/app.dart';

void main() {
  testWidgets('shows home page', (WidgetTester tester) async {
    await tester.pumpWidget(const SystumApp());
    await tester.pump();

    expect(find.text('Systum'), findsOneWidget);
    expect(find.text('Welcome to Systum'), findsOneWidget);
  });
}
