package io.github.alanmosely.esp_provisioning_wifi

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30, 33])
class BluetoothReadinessChannelTest {
  private fun pending(): Triple<EspProvisioningWifiPlugin, BluetoothReadiness, RecordingResult> {
    val plugin = EspProvisioningWifiPlugin()
    val bossField = plugin.javaClass.getDeclaredField("boss").apply { isAccessible = true }
    val readiness = BluetoothReadiness(RuntimeEnvironment.getApplication(), bossField.get(plugin) as Boss,
        { it(true) }, { BluetoothAdapter.STATE_OFF }, { _, _ -> })
    readiness.attach(Robolectric.buildActivity(Activity::class.java).setup().get())
    plugin.javaClass.getDeclaredField("bluetooth").apply { isAccessible = true }.set(plugin, readiness)
    val pending = RecordingResult()
    readiness.ensureReady(1, true, 1000, pending)
    return Triple(plugin, readiness, pending)
  }

  @Test fun malformedCancellationMustNotCancelActiveReadiness() {
    val (plugin, readiness, pending) = pending()
    try {
      val invalid = listOf(null, emptyList<Any>(), emptyMap<String, Any>(),
          mapOf("requestId" to "bad"), mapOf("requestId" to true),
          mapOf("requestId" to 1.5), mapOf("requestId" to 0), mapOf("requestId" to -1))
      for (arguments in invalid) {
        val reply = RecordingResult()
        plugin.onMethodCall(MethodCall("cancelBluetoothReadiness", arguments), reply)
        assertEquals("Malformed cancellation must not affect active work", 0, pending.resolutionCount)
        assertEquals("E0", reply.errors.single().first)
        assertEquals(1, reply.resolutionCount)
      }
    } finally { readiness.cancel() }
  }

  @Test fun invalidProvisioningAndReadinessMustNotCancelActiveReadiness() {
    val (plugin, readiness, pending) = pending()
    try {
      val invalid = mutableListOf<MethodCall>()
      for (method in listOf("scanBleDevices", "scanWifiNetworks", "provisionWifi", "fetchCustomData")) {
        invalid.add(MethodCall(method, null))
        invalid.add(MethodCall(method, emptyMap<String, Any>()))
      }
      val valid = mapOf("requestId" to 2, "timeoutMs" to 1000, "requestEnable" to true)
      for ((key, values) in mapOf("requestId" to listOf(0, -1, true, "1", 1.5),
          "timeoutMs" to listOf(0, 120001, true, "1", 1.5), "requestEnable" to listOf(0, 1, "true", null))) {
        for (value in values) invalid.add(MethodCall("ensureBluetoothReady", valid + (key to value)))
      }
      invalid.add(MethodCall("scanWifiNetworks", mapOf("deviceName" to "PROV_1",
          "proofOfPossession" to "pop", "security" to 2)))
      for (call in invalid) {
        val reply = RecordingResult()
        plugin.onMethodCall(call, reply)
        assertEquals("E0", reply.errors.single().first)
        assertEquals(0, pending.resolutionCount)
      }
    } finally { readiness.cancel() }
  }

  @Test fun readOnlyVersionDoesNotCancelAndGlobalCancelDoes() {
    val (plugin, readiness, pending) = pending()
    try {
      val version = RecordingResult()
      plugin.onMethodCall(MethodCall("getPlatformVersion", null), version)
      assertEquals(1, version.successes.size)
      assertEquals(0, pending.resolutionCount)
      val reply = RecordingResult()
      plugin.onMethodCall(MethodCall("cancelBluetoothReadiness", mapOf("requestId" to null)), reply)
      assertEquals("E_CANCELLED", pending.errors.single().first)
      assertEquals(1, reply.resolutionCount)
    } finally { readiness.cancel() }
  }

  @Test fun largeRequestIDsDoNotAliasAndOnlyMatchingCancellationCompletes() {
    val (plugin, readiness, original) = pending()
    val next = RecordingResult()
    readiness.ensureReady(4294967297L, true, 1000, next)
    assertEquals("E_CANCELLED", original.errors.single().first)
    plugin.onMethodCall(MethodCall("cancelBluetoothReadiness", mapOf("requestId" to 1)), RecordingResult())
    assertEquals(0, next.resolutionCount)
    plugin.onMethodCall(MethodCall("cancelBluetoothReadiness", mapOf("requestId" to 4294967297L)), RecordingResult())
    assertEquals("E_CANCELLED", next.errors.single().first)
    readiness.cancel()
    assertEquals(1, next.resolutionCount)
  }

  @Test fun cancelOperationsStillCancelsReadiness() {
    val (plugin, _, pending) = pending()
    val reply = RecordingResult()
    plugin.onMethodCall(MethodCall("cancelOperations", null), reply)
    assertEquals("E_CANCELLED", pending.errors.single().first)
    assertEquals(listOf(true), reply.successes)
  }

  @Test fun unsupportedMethodMustNotCancelActiveReadiness() {
    val (plugin, readiness, pending) = pending()
    try {
      val reply = RecordingResult()
      plugin.onMethodCall(MethodCall("unsupportedMethod", emptyMap<String, Any>()), reply)
      assertEquals(1, reply.notImplementedCalls)
      assertEquals("Unsupported call must not affect active work", 0, pending.resolutionCount)
    } finally { readiness.cancel() }
  }

  @Test fun realPermissionManagerReportsDenialAndAllowsGrantedRetry() {
    val boss = Boss()
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    boss.attachActivity(activity)
    val permissions = PermissionManager(boss)
    val context = RuntimeEnvironment.getApplication()
    shadowOf(context).denyPermissions(*permissions.permissions)
    val readiness = BluetoothReadiness(context, boss, permissions::ensure,
        { BluetoothAdapter.STATE_ON }, { _, _ -> fail("Radio is already on") })
    readiness.attach(activity)
    val denied = RecordingResult()
    readiness.ensureReady(1, true, 1000, denied)
    assertEquals(0, denied.resolutionCount)
    permissions.onRequestPermissionsResult(7309, permissions.permissions,
        IntArray(permissions.permissions.size) { PackageManager.PERMISSION_DENIED })
    assertEquals(listOf("unauthorized"), denied.successes)
    shadowOf(context).grantPermissions(*permissions.permissions)
    val granted = RecordingResult()
    readiness.ensureReady(2, true, 1000, granted)
    assertEquals(listOf("on"), granted.successes)
  }
}
