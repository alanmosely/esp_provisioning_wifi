/// Default BLE connect timeout applied to native scan/provision calls.
const Duration kEspDefaultConnectTimeout = Duration(seconds: 15);

/// Default additional budget allowed for the post-connect phase of an
/// operation (WiFi scan, provisioning exchange, custom data read).
const Duration kEspDefaultOperationBudget = Duration(seconds: 20);
