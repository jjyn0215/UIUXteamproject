package com.teamproject.synced_alarm

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LaunchRouteDecisionTest {
    @Test
    fun routesActiveAlarmNotificationLaunchToAlarmActivity() {
        assertTrue(
            LaunchRouteDecision.shouldRouteToAlarmActivity(
                action = LaunchRouteDecision.selectNotificationAction,
                hasPayload = true,
                flags = 0,
            ),
        )
    }

    @Test
    fun routesNotificationLaunchFromRecentHistoryToMainActivity() {
        assertFalse(
            LaunchRouteDecision.shouldRouteToAlarmActivity(
                action = LaunchRouteDecision.selectNotificationAction,
                hasPayload = true,
                flags = LaunchRouteDecision.launchedFromHistoryFlag,
            ),
        )
    }

    @Test
    fun routesNotificationWithoutPayloadToMainActivity() {
        assertFalse(
            LaunchRouteDecision.shouldRouteToAlarmActivity(
                action = LaunchRouteDecision.selectNotificationAction,
                hasPayload = false,
                flags = 0,
            ),
        )
    }
}
