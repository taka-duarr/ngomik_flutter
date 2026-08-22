import 'package:flutter_test/flutter_test.dart';
import 'package:ngomik_flutter/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const NgomikApp());
    expect(find.byType(NgomikApp), findsOneWidget);
  });
}
