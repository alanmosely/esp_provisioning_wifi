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
    return BlocProvider(
      create: (_) => EspProvisioningBloc(),
      child: const MyAppView(),
    );
  }
}

class MyAppView extends StatefulWidget {
  const MyAppView({super.key});

  @override
  State<MyAppView> createState() => _MyAppViewState();
}

class _MyAppViewState extends State<MyAppView> {
  final defaultPadding = 12.0;
  final defaultDevicePrefix = 'PROV';

  String feedbackMessage = '';

  final prefixController = TextEditingController(text: 'PROV_');
  final proofOfPossessionController = TextEditingController(text: 'abcd1234');
  final passphraseController = TextEditingController();

  pushFeedback(String msg) {
    setState(() {
      feedbackMessage = '$feedbackMessage\n$msg';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EspProvisioningBloc, EspProvisioningState>(
        builder: (context, state) {
      return MaterialApp(
        home: Scaffold(
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
                  }),
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
                    fontWeight: FontWeight.bold, color: Colors.green.shade600),
              ),
            ),
          ),
          body: SafeArea(
            child: Container(
              padding: EdgeInsets.all(defaultPadding),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('Device Prefix'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: prefixController,
                              decoration: const InputDecoration(
                                  hintText: 'enter device prefix'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
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
                                EspProvisioningEventBleSelected(bluetoothDevice,
                                    proofOfPossessionController.text));
                            pushFeedback('Scanning WiFi on $bluetoothDevice');
                          },
                        );
                      },
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('Proof of possession'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: proofOfPossessionController,
                              decoration: const InputDecoration(
                                  hintText: 'enter proof of possession string'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
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
                          onTap: () async {
                            final wifiNetwork = state.wifiNetworks[i];
                            context.read<EspProvisioningBloc>().add(
                                EspProvisioningEventWifiSelected(
                                    state.bluetoothDevice,
                                    proofOfPossessionController.text,
                                    wifiNetwork,
                                    passphraseController.text));
                            pushFeedback(
                                'Provisioning WiFi $wifiNetwork on ${state.bluetoothDevice}');
                          },
                        );
                      },
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('WiFi Passphrase'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: passphraseController,
                              decoration: const InputDecoration(
                                  hintText: 'enter passphrase'),
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
        ),
      );
    });
  }
}
