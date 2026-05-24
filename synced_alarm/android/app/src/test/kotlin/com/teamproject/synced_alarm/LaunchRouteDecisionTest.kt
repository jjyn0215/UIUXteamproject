package com.teamproject.synced_alarm

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

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
