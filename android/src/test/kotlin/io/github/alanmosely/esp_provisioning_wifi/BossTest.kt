package io.github.alanmosely.esp_provisioning_wifi

import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class BossTest {
  private lateinit var boss: Boss
  private lateinit var result: RecordingResult

  @Before
  fun setUp() {
    boss = Boss()
    result = RecordingResult()
  }

  private fun trackedResolver(): OperationResolver {
    val resolver = OperationResolver(boss, boss.startOperation(), result)
    boss.trackResolver(resolver)
    return resolver
  }

  @Test
  fun startOperationInvalidatesPreviousTokens() {
    val first = boss.startOperation()
    assertTrue(boss.isOperationActive(first))
    val second = boss.startOperation()
    assertFalse(boss.isOperationActive(first))
    assertTrue(boss.isOperationActive(second))
  }

  @Test
  fun startOperationResolvesTheTrackedResolverWithCancelled() {
    val resolver = trackedResolver()
    boss.startOperation()
    assertEquals(ErrorCodes.CANCELLED, result.errors.single().first)
    // A late listener callback on the superseded operation must be dropped.
    resolver.success("late")
    assertEquals(0, result.successes.size)
    assertEquals(1, result.resolutionCount)
  }

  @Test
  fun cancelOperationsResolvesTheTrackedResolverAndReturnsTrue() {
    trackedResolver()
    assertTrue(boss.cancelOperations())
    assertEquals(ErrorCodes.CANCELLED, result.errors.single().first)
  }

  @Test
  fun supersessionInvokesTheTrackedConnectCancelExactlyOnce() {
    var cancelInvocations = 0
    boss.trackConnectCancel { cancelInvocations++ }
    boss.startOperation()
    boss.startOperation()
    assertEquals(1, cancelInvocations)
  }

  @Test
  fun cancelOperationsInvokesTheTrackedConnectCancelExactlyOnce() {
    var cancelInvocations = 0
    boss.trackConnectCancel { cancelInvocations++ }
    boss.cancelOperations()
    boss.cancelOperations()
    assertEquals(1, cancelInvocations)
  }

  @Test
  fun connectCancelRunsAfterTheResolverIsCancelled() {
    // The connect attempt's cancelAttempt resolves through the (already
    // cancelled) resolver; the resolver cancellation must win so the Dart
    // future sees E_CANCELLED exactly once.
    val resolver = trackedResolver()
    var resolutionsWhenCancelRan = -1
    boss.trackConnectCancel {
      resolutionsWhenCancelRan = result.resolutionCount
      resolver.error(ErrorCodes.CANCELLED, "Operation cancelled", null)
    }
    boss.startOperation()
    assertEquals(1, resolutionsWhenCancelRan)
    assertEquals(1, result.resolutionCount)
  }

  @Test
  fun unknownMethodsResolveNotImplementedWithoutThePermissionGate() {
    boss.call(MethodCall("noSuchMethod", null), result)
    assertEquals(1, result.notImplementedCalls)
    assertEquals(1, result.resolutionCount)
  }

  @Test
  fun selfInitiatedDisconnectCreditsAreConsumedOneForOne() {
    assertFalse(boss.consumeSelfInitiatedDisconnect())
    boss.noteSelfInitiatedDisconnect()
    boss.noteSelfInitiatedDisconnect()
    assertTrue(boss.consumeSelfInitiatedDisconnect())
    assertTrue(boss.consumeSelfInitiatedDisconnect())
    assertFalse(boss.consumeSelfInitiatedDisconnect())
  }
}
