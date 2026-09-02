package io.github.alanmosely.esp_provisioning_wifi

import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class OperationResolverTest {
  private lateinit var boss: Boss
  private lateinit var result: RecordingResult

  @Before
  fun setUp() {
    boss = Boss()
    result = RecordingResult()
  }

  private fun activeResolver(): OperationResolver =
      OperationResolver(boss, boss.startOperation(), result)

  @Test
  fun successResolvesExactlyOnceAndDropsLaterResolutions() {
    val resolver = activeResolver()
    resolver.success("first")
    resolver.success("second")
    resolver.error("E_X", "later error", null)
    assertEquals(listOf<Any?>("first"), result.successes)
    assertEquals(0, result.errors.size)
  }

  @Test
  fun errorDeliversCodeMessageAndDetails() {
    val resolver = activeResolver()
    resolver.error("E_X", "boom", "details")
    assertEquals(Triple<String, String?, Any?>("E_X", "boom", "details"), result.errors.single())
    assertEquals(1, result.resolutionCount)
  }

  @Test
  fun cancelledResolvesWithTheCancelledContractCode() {
    val resolver = activeResolver()
    resolver.cancelled()
    assertEquals(ErrorCodes.CANCELLED, result.errors.single().first)
  }

  @Test
  fun backgroundResolutionIsDeliveredOnTheMainLooper() {
    val resolver = activeResolver()
    val thread = Thread { resolver.success("bg") }
    thread.start()
    thread.join()
    assertEquals(0, result.resolutionCount)
    shadowOf(Looper.getMainLooper()).idle()
    assertEquals(listOf<Any?>("bg"), result.successes)
  }

  @Test
  fun resolutionDeliveredAfterSupersessionDowngradesToCancelled() {
    val resolver = activeResolver()
    val thread = Thread { resolver.success("stale") }
    thread.start()
    thread.join()
    // Supersede before the queued delivery runs on the main looper.
    boss.startOperation()
    shadowOf(Looper.getMainLooper()).idle()
    assertEquals(0, result.successes.size)
    assertEquals(ErrorCodes.CANCELLED, result.errors.single().first)
  }

  @Test
  fun cancelledIfInactiveIsANoOpWhileTheOperationIsActive() {
    val resolver = activeResolver()
    assertFalse(resolver.cancelledIfInactive())
    assertEquals(0, result.resolutionCount)
  }

  @Test
  fun cancelledIfInactiveResolvesCancelledOnceSuperseded() {
    val resolver = activeResolver()
    boss.startOperation()
    assertTrue(resolver.cancelledIfInactive())
    assertEquals(ErrorCodes.CANCELLED, result.errors.single().first)
    assertEquals(1, result.resolutionCount)
  }
}
