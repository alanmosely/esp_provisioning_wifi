import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProvisioningService extends FlutterEspBleProv {
  @override
  Future<bool> cancelOperations() async => true;
}

void main() {
  test('a consumer can import, construct, and close the provisioning bloc',
      () async {
    final bloc =
        EspProvisioningBloc(provisioningService: _ProvisioningService());

    expect(bloc.state.status, EspProvisioningStatus.initial);
    await bloc.close();
    expect(bloc.isClosed, isTrue);
  });
}
