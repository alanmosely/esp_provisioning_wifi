import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final service = EspProvisioningService();

  testWidgets('platform channel exposes required baseline methods', (_) async {
    final version = await service.getPlatformVersion();
    expect(version, isNotNull);

    final cancelled = await service.cancelOperations();
    expect(cancelled, isTrue);
  });
}
