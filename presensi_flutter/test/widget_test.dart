import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PresensiApp());
    expect(find.byType(PresensiApp), findsOneWidget);
  });
}
