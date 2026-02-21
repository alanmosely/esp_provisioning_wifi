import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocProvider(
        create: (_) => EspProvisioningBloc(),
        child: const MyAppView(),
      ),
    );
  }
}

class MyAppView extends StatefulWidget {
  const MyAppView({super.key});

  @override
  State<MyAppView> createState() => _MyAppViewState();
}

class _MyAppViewState extends State<MyAppView> {
  final double defaultPadding = 12.0;

  String feedbackMessage = '';

  final TextEditingController prefixController =
      TextEditingController(text: 'PROV_');
  final TextEditingController proofOfPossessionController =
      TextEditingController(text: 'abcd1234');
  final TextEditingController passphraseController = TextEditingController();

  void pushFeedback(String msg) {
    setState(() {
      feedbackMessage =
          feedbackMessage.isEmpty ? msg : '$feedbackMessage\n$msg';
    });
  }

  String _statusLabel(EspProvisioningStatus status) {
    switch (status) {
      case EspProvisioningStatus.initial:
        return 'initial';
      case EspProvisioningStatus.bleScanned:
        return 'bleScanned';
      case EspProvisioningStatus.deviceChosen:
        return 'deviceChosen';
      case EspProvisioningStatus.wifiScanned:
        return 'wifiScanned';
      case EspProvisioningStatus.networkChosen:
        return 'networkChosen';
      case EspProvisioningStatus.wifiProvisioned:
        return 'wifiProvisioned';
      case EspProvisioningStatus.error:
        return 'error';
    }
  }

  String _failureLabel(EspProvisioningFailure failure) {
    switch (failure) {
      case EspProvisioningFailure.none:
        return 'none';
      case EspProvisioningFailure.permissionDenied:
        return 'permissionDenied';
      case EspProvisioningFailure.timeout:
        return 'timeout';
      case EspProvisioningFailure.cancelled:
        return 'cancelled';
      case EspProvisioningFailure.deviceNotFound:
        return 'deviceNotFound';
      case EspProvisioningFailure.invalidResponse:
        return 'invalidResponse';
      case EspProvisioningFailure.platform:
        return 'platform';
      case EspProvisioningFailure.unknown:
        return 'unknown';
    }
  }

  void _onStateChanged(EspProvisioningState state) {
    switch (state.status) {
      case EspProvisioningStatus.bleScanned:
        pushFeedback(
          'BLE scan complete: ${state.bluetoothDevices.length} device(s)',
        );
        break;
      case EspProvisioningStatus.wifiScanned:
        pushFeedback(
          'Wi-Fi scan complete: ${state.wifiNetworks.length} network(s)',
        );
        break;
      case EspProvisioningStatus.wifiProvisioned:
        pushFeedback(
          state.wifiProvisioned
              ? 'Wi-Fi provisioned successfully'
              : 'Wi-Fi provisioning failed',
        );
        break;
      case EspProvisioningStatus.error:
        final details = state.errorMsg.isEmpty ? 'No details' : state.errorMsg;
        pushFeedback('Error (${_failureLabel(state.failure)}): $details');
        break;
      case EspProvisioningStatus.initial:
      case EspProvisioningStatus.deviceChosen:
      case EspProvisioningStatus.networkChosen:
        break;
    }
  }

  @override
  void dispose() {
    prefixController.dispose();
    proofOfPossessionController.dispose();
    passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EspProvisioningBloc, EspProvisioningState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure ||
          previous.errorMsg != current.errorMsg,
      listener: (_, state) => _onStateChanged(state),
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ESP BLE Provisioning Example'),
            actions: [
              IconButton(
                icon: const Icon(Icons.bluetooth),
                onPressed: () {
                  context
                      .read<EspProvisioningBloc>()
                      .add(EspProvisioningEventStart(prefixController.text));
                  pushFeedback('Scanning BLE devices...');
                },
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  setState(() {
                    feedbackMessage = '';
                  });
                },
              ),
            ],
          ),
          bottomSheet: SafeArea(
            child: Container(
              width: double.infinity,
              color: Colors.black87,
              padding: EdgeInsets.all(defaultPadding),
              child: Text(
                feedbackMessage,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(defaultPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${_statusLabel(state.status)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('Failure: ${_failureLabel(state.failure)}'),
                          if (state.errorMsg.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              state.errorMsg,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Row(
                        children: [
                          const Flexible(
                            child: Text('Device Prefix'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: prefixController,
                              decoration: const InputDecoration(
                                hintText: 'enter device prefix',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: const Text('BLE devices'),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.bluetoothDevices.length,
                      itemBuilder: (context, i) {
                        return ListTile(
                          title: Text(
                            state.bluetoothDevices[i],
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            final bluetoothDevice = state.bluetoothDevices[i];
                            context.read<EspProvisioningBloc>().add(
                                  EspProvisioningEventBleSelected(
                                    bluetoothDevice,
                                    proofOfPossessionController.text,
                                  ),
                                );
                            pushFeedback(
                                'Scanning Wi-Fi on $bluetoothDevice...');
                          },
                        );
                      },
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Row(
                        children: [
                          const Flexible(
                            child: Text('Proof of possession'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: proofOfPossessionController,
                              decoration: const InputDecoration(
                                hintText: 'enter proof of possession string',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: const Text('WiFi networks'),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.wifiNetworks.length,
                      itemBuilder: (context, i) {
                        return ListTile(
                          title: Text(
                            state.wifiNetworks[i],
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            final wifiNetwork = state.wifiNetworks[i];
                            context.read<EspProvisioningBloc>().add(
                                  EspProvisioningEventWifiSelected(
                                    state.bluetoothDevice,
                                    proofOfPossessionController.text,
                                    wifiNetwork,
                                    passphraseController.text,
                                  ),
                                );
                            pushFeedback(
                              'Provisioning $wifiNetwork on ${state.bluetoothDevice}...',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Row(
                        children: [
                          const Flexible(
                            child: Text('WiFi Passphrase'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: passphraseController,
                              decoration: const InputDecoration(
                                hintText: 'enter passphrase',
                              ),
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
