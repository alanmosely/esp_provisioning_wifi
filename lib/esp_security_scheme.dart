/// Provisioning security schemes supported by Espressif BLE provisioning.
enum EspSecurityScheme {
  /// Security 1: X25519 key exchange with AES-CTR encryption, authenticated
  /// by a proof-of-possession string.
  security1,

  /// Security 2: SRP6a-based authentication with AES-GCM encryption.
  /// Requires a `username` in addition to the proof-of-possession string,
  /// matching the firmware's `sec2` configuration.
  security2;

  /// The integer value sent over the platform channel.
  int get channelValue => this == EspSecurityScheme.security2 ? 2 : 1;
}
