import 'package:esp_provisioning_wifi_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders initial provisioning state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('ESP BLE Provisioning Example'), findsOneWidget);
    expect(find.text('Status: initial'), findsOneWidget);
    expect(find.text('Failure: none'), findsOneWidget);
  });
}
