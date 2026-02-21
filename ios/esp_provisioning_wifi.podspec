#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_esp_ble_prov.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'esp_provisioning_wifi'
  s.version          = '0.0.7'
  s.summary          = 'Provision ESP32 WiFi over BLE from Flutter.'
  s.description      = <<-DESC
Flutter plugin and BLoC wrapper for provisioning ESP32 devices over BLE
using Espressif provisioning libraries.
                       DESC
  s.homepage         = 'https://github.com/alanmosely/esp_provisioning_wifi'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Alan Mosely' => 'alanmosely@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.2'
  s.dependency 'ESPProvision'
end
