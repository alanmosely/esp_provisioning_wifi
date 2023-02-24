#import "FlutterEspBleProvPlugin.h"
#if __has_include(<flutter_esp_ble_prov/flutter_esp_ble_prov-Swift.h>)
#import <flutter_esp_ble_prov/flutter_esp_ble_prov-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_esp_ble_prov-Swift.h"
#endif

@implementation FlutterEspBleProvPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterEspBleProvPlugin registerWithRegistrar:registrar];
}
@end
