package com.adnogpu.newclass.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.adnogpu.newclass.R

class TodayScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_USER_PRESENT,
            Intent.ACTION_SCREEN_ON,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> updateAll(context)
        }
    }

    companion object {
        private const val ACTION_REFRESH =
            "com.adnogpu.newclass.widget.REFRESH_SCHEDULE"
        private const val ALARM_REQUEST_CODE = 1001

        fun update(context: Context, manager: AppWidgetManager, id: Int): Long? {
            val views = RemoteViews(context.packageName, R.layout.widget_today_schedule)
            val nextRefresh = WidgetRenderer.renderSchedule(context, views)
            manager.updateAppWidget(id, views)
            return nextRefresh
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayScheduleWidgetProvider::class.java),
            )
            var nextRefresh: Long? = null
            for (id in ids) {
                val next = update(context, manager, id)
                val current = nextRefresh
                if (next != null && (current == null || next < current)) {
                    nextRefresh = next
                }
            }
            scheduleRefresh(context, nextRefresh)
        }

        private fun scheduleRefresh(context: Context, atMillis: Long?) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TodayScheduleWidgetProvider::class.java)
                .setAction(ACTION_REFRESH)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                flags,
            )
            if (atMillis == null) {
                alarmManager.cancel(pendingIntent)
                return
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    !alarmManager.canScheduleExactAlarms()
                ) {
                    // Exact alarms need a special-access grant on Android 12+.
                    // Inexact idle alarms still refresh near the target time.
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        atMillis,
                        pendingIntent,
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        atMillis,
                        pendingIntent,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        atMillis,
                        pendingIntent,
                    )
                }
            } catch (_: SecurityException) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            atMillis,
                            pendingIntent,
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        alarmManager.set(
                            AlarmManager.RTC_WAKEUP,
                            atMillis,
                            pendingIntent,
                        )
                    }
                } catch (_: SecurityException) {
                    // Fall back to the 30-minute widget update period.
                }
            }
        }
    }
}
