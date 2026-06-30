import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:sitepulse_engineer/app.dart";

void main() {
  testWidgets("App boots (smoke test)", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SitePulseAppFoundation());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
