import 'package:flutter_test/flutter_test.dart';
import 'package:sprint_wash/main.dart';

void main() {
  testWidgets('SprintWashApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SprintWashApp());
    expect(find.byType(SprintWashApp), findsOneWidget);
  });
}
