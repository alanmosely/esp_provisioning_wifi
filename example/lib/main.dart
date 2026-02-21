import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
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
      feedbackMessage = '$feedbackMessage\n$msg';
    });
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
    return BlocBuilder<EspProvisioningBloc, EspProvisioningState>(
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
                  pushFeedback('Scanning BLE devices');
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
                            final String bluetoothDevice =
                                state.bluetoothDevices[i];
                            context.read<EspProvisioningBloc>().add(
                                  EspProvisioningEventBleSelected(
                                    bluetoothDevice,
                                    proofOfPossessionController.text,
                                  ),
                                );
                            pushFeedback('Scanning WiFi on $bluetoothDevice');
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
                            final String wifiNetwork = state.wifiNetworks[i];
                            context.read<EspProvisioningBloc>().add(
                                  EspProvisioningEventWifiSelected(
                                    state.bluetoothDevice,
                                    proofOfPossessionController.text,
                                    wifiNetwork,
                                    passphraseController.text,
                                  ),
                                );
                            pushFeedback(
                              'Provisioning WiFi $wifiNetwork on ${state.bluetoothDevice}',
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
