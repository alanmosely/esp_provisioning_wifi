package io.github.alanmosely.esp_provisioning_wifi

import android.app.Activity
import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.os.Looper
import java.time.Duration
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30, 33])
class BluetoothReadinessTest {
  private val context get() = RuntimeEnvironment.getApplication()
  private var state: Int? = BluetoothAdapter.STATE_OFF
  private var granted = true
  private var permissionCalls = 0
  private var permissionCallback: ((Boolean) -> Unit)? = null
  private var delayPermission = false
  private var launched = mutableListOf<Int>()
  private lateinit var readiness: BluetoothReadiness
  private lateinit var result: RecordingResult

  @Before fun setUp() {
    result = RecordingResult()
    readiness = BluetoothReadiness(context, Boss(), { callback ->
      permissionCalls++
      if (delayPermission) permissionCallback = callback else callback(granted)
    }, { state }, { _, code -> launched.add(code) })
    readiness.attach(Robolectric.buildActivity(Activity::class.java).setup().get())
  }

  @Test fun onCompletesWithoutEnablePrompt() {
    state = BluetoothAdapter.STATE_ON
    readiness.ensureReady(1, true, 1000, result)
    assertEquals(listOf("on"), result.successes)
    assertTrue(launched.isEmpty())
  }

  @Test fun unavailableSkipsPermissionRequest() {
    state = null
    readiness.ensureReady(1, true, 1000, result)
    assertEquals(listOf("unavailable"), result.successes)
    assertEquals(0, permissionCalls)
  }

  @Test fun permissionDenialDoesNotLaunchEnable() {
    granted = false
    readiness.ensureReady(1, true, 1000, result)
    assertEquals(listOf("unauthorized"), result.successes)
    assertTrue(launched.isEmpty())
  }

  @Test fun noEnableOptionReturnsOff() {
    readiness.ensureReady(1, false, 1000, result)
    assertEquals(listOf("off"), result.successes)
    assertTrue(launched.isEmpty())
  }

  @Test fun acceptedDialogWaitsForActualStateOn() {
    readiness.ensureReady(1, true, 1000, result)
    readiness.onActivityResult(launched.single(), Activity.RESULT_OK)
    assertEquals(0, result.resolutionCount)
    state = BluetoothAdapter.STATE_ON
    context.sendBroadcast(Intent(BluetoothAdapter.ACTION_STATE_CHANGED))
    shadowOf(Looper.getMainLooper()).idle()
    assertEquals(listOf("on"), result.successes)
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
    assertEquals(1, result.resolutionCount)
  }

  @Test fun declinedDialogReturnsOffExactlyOnce() {
    readiness.ensureReady(1, true, 1000, result)
    val code = launched.single()
    assertFalse(readiness.onActivityResult(code + 1, Activity.RESULT_CANCELED))
    assertTrue(readiness.onActivityResult(code, Activity.RESULT_CANCELED))
    assertFalse(readiness.onActivityResult(code, Activity.RESULT_OK))
    assertEquals(listOf("off"), result.successes)
  }

  @Test fun deadlineAlsoBoundsPermissionDialogAndDropsLateGrant() {
    delayPermission = true
    readiness.ensureReady(1, true, 20, result)
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(25))
    assertEquals("E_BLUETOOTH_TIMEOUT", result.errors.single().first)
    permissionCallback!!(true)
    assertTrue(launched.isEmpty())
    assertEquals(1, result.resolutionCount)
  }

  @Test fun configDetachKeepsDialogResultAndPermanentDetachCancels() {
    readiness.ensureReady(1, true, 1000, result)
    val code = launched.single()
    readiness.detach(false)
    assertEquals(0, result.resolutionCount)
    readiness.attach(Robolectric.buildActivity(Activity::class.java).setup().get())
    readiness.onActivityResult(code, Activity.RESULT_CANCELED)
    assertEquals(listOf("off"), result.successes)
    val next = RecordingResult()
    readiness.ensureReady(2, true, 1000, next)
    readiness.detach(true)
    assertEquals("E_CANCELLED", next.errors.single().first)
  }

  @Test fun staleCancellationAndActivityResultCannotCompleteSuccessor() {
    readiness.ensureReady(1, true, 1000, result)
    val oldCode = launched.single()
    val next = RecordingResult()
    readiness.ensureReady(2, true, 1000, next)
    assertEquals("E_CANCELLED", result.errors.single().first)
    readiness.cancel(1)
    assertFalse(readiness.onActivityResult(oldCode, Activity.RESULT_CANCELED))
    assertEquals(0, next.resolutionCount)
    readiness.onActivityResult(launched.last(), Activity.RESULT_CANCELED)
    assertEquals(listOf("off"), next.successes)
  }

  @Test fun noActivityFailsWithoutLaunching() {
    readiness.detach(false)
    readiness.ensureReady(1, true, 1000, result)
    assertEquals("E_NO_ACTIVITY", result.errors.single().first)
    assertTrue(launched.isEmpty())
  }

  @Test fun stalePermissionResultCannotLaunchSuccessorPrompt() {
    delayPermission = true
    readiness.ensureReady(1, true, 1000, result)
    val oldCallback = permissionCallback!!
    val next = RecordingResult()
    readiness.ensureReady(2, true, 1000, next)
    oldCallback(true)
    assertTrue(launched.isEmpty())
    assertEquals(0, next.resolutionCount)
    permissionCallback!!(false)
    assertEquals(listOf("unauthorized"), next.successes)
  }

  @Test fun adapterServiceFailureDoesNotEscapeActivityCallback() {
    var failRead = false
    readiness = BluetoothReadiness(context, Boss(), { it(true) }, {
      if (failRead) throw IllegalStateException("adapter service unavailable")
      state
    }, { _, code -> launched.add(code) })
    readiness.attach(Robolectric.buildActivity(Activity::class.java).setup().get())
    readiness.ensureReady(1, true, 1000, result)
    failRead = true
    readiness.onActivityResult(launched.single(), Activity.RESULT_CANCELED)
    assertEquals(listOf("unknown"), result.successes)
    assertEquals(1, result.resolutionCount)
  }

  @Test fun platformEnableFailureIsReported() {
    readiness = BluetoothReadiness(context, Boss(), { it(true) }, { state },
        { _, _ -> throw IllegalStateException("cannot launch") })
    readiness.attach(Robolectric.buildActivity(Activity::class.java).setup().get())
    readiness.ensureReady(1, true, 1000, result)
    assertEquals("E_BLUETOOTH_ENABLE", result.errors.single().first)
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
    assertEquals(1, result.resolutionCount)
  }

  @Test fun revokedPermissionBeforeSystemPromptFailsExactlyOnce() {
    shadowOf(context).denyPermissions(Manifest.permission.BLUETOOTH_CONNECT,
        Manifest.permission.BLUETOOTH_ADMIN)
    readiness = BluetoothReadiness(context, Boss(), { it(true) }, { state })
    readiness.attach(Robolectric.buildActivity(Activity::class.java).setup().get())
    readiness.ensureReady(1, true, 1000, result)
    assertEquals("E_BLUETOOTH_ENABLE", result.errors.single().first)
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
    assertEquals(1, result.resolutionCount)
  }
}
