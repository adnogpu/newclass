package com.adnogpu.newclass.widget

import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.adnogpu.newclass.MainActivity
import com.adnogpu.newclass.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

object WidgetRenderer {
    private const val SCHEDULE_KEY = "today_schedule_json"
    private const val ELECTRICITY_KEY = "electricity_json"
    private val weekdayLabels = arrayOf(
        "周一", "周二", "周三", "周四", "周五", "周六", "周日",
    )
    private val timeFormatter = DateTimeFormatter.ofPattern("H:mm")

    private val scheduleRowIds = intArrayOf(
        R.id.widget_schedule_row_1,
        R.id.widget_schedule_row_2,
    )
    private val scheduleTimeIds = intArrayOf(
        R.id.widget_schedule_time_1,
        R.id.widget_schedule_time_2,
    )
    private val scheduleNameIds = intArrayOf(
        R.id.widget_schedule_name_1,
        R.id.widget_schedule_name_2,
    )
    private val scheduleRoomIds = intArrayOf(
        R.id.widget_schedule_room_1,
        R.id.widget_schedule_room_2,
    )

    /** Renders the schedule widget and returns the next epoch millis to refresh. */
    fun renderSchedule(context: Context, views: RemoteViews): Long? {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(SCHEDULE_KEY, null)
        val today = LocalDate.now()
        val nowTime = LocalTime.now()
        var synced = false
        val todays = mutableListOf<WidgetCourse>()

        if (raw != null) {
            runCatching {
                val data = JSONObject(raw)
                if (data.optString("state") == "synced") {
                    synced = true
                    val start = runCatching {
                        LocalDate.parse(data.optString("semesterStart"))
                    }.getOrNull()
                    val week = if (start != null) {
                        (ChronoUnit.DAYS.between(start, today).toInt() / 7) + 1
                    } else {
                        data.optInt("week", 1)
                    }
                    val array = data.optJSONArray("courses") ?: JSONArray()
                    for (index in 0 until array.length()) {
                        val item = array.optJSONObject(index) ?: continue
                        if (item.optInt("day") != today.dayOfWeek.value) continue
                        if (!matchesWeek(item.optJSONArray("weeks"), week)) continue
                        val endText = item.optString("endTime")
                        val endTime = runCatching {
                            LocalTime.parse(endText, timeFormatter)
                        }.getOrNull()
                        todays.add(
                            WidgetCourse(
                                name = item.optString("name"),
                                room = item.optString("room"),
                                start = item.optInt("start"),
                                time = item.optString("time"),
                                endTime = endTime,
                            ),
                        )
                    }
                    todays.sortBy { it.start }
                }
            }
        }

        val upcoming = todays.filter { course ->
            course.endTime == null || nowTime.isBefore(course.endTime)
        }

        var header =
            "${today.monthValue}月${today.dayOfMonth}日 " +
                weekdayLabels[today.dayOfWeek.value - 1]
        if (synced && upcoming.size > scheduleRowIds.size) {
            header += " · +${upcoming.size - scheduleRowIds.size}"
        }
        views.setTextViewText(R.id.widget_schedule_date, header)

        val emptyMessage = when {
            !synced -> context.getString(R.string.widget_schedule_unsynced)
            todays.isEmpty() -> context.getString(R.string.widget_schedule_empty)
            upcoming.isEmpty() -> context.getString(R.string.widget_schedule_ended)
            else -> null
        }
        if (emptyMessage != null) {
            views.setViewVisibility(R.id.widget_schedule_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_schedule_empty, emptyMessage)
        } else {
            views.setViewVisibility(R.id.widget_schedule_empty, View.GONE)
        }

        for (index in scheduleRowIds.indices) {
            val visible = emptyMessage == null && index < upcoming.size
            views.setViewVisibility(
                scheduleRowIds[index],
                if (visible) View.VISIBLE else View.GONE,
            )
            if (visible) {
                val course = upcoming[index]
                views.setTextViewText(scheduleTimeIds[index], course.time)
                views.setTextViewText(scheduleNameIds[index], course.name)
                views.setTextViewText(scheduleRoomIds[index], course.room)
                views.setViewVisibility(
                    scheduleRoomIds[index],
                    if (course.room.isEmpty()) View.GONE else View.VISIBLE,
                )
            }
        }

        views.setOnClickPendingIntent(
            R.id.widget_schedule_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("newclass://schedule"),
            ),
        )

        var nextRefresh: Long? = null
        val nowMillis = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()

        // Refresh at midnight even when the last course of the day ended hours
        // ago. Relying only on ACTION_DATE_CHANGED can leave yesterday's
        // timetable on screen after the clock rolls over.
        val nextMidnight = today.plusDays(1)
            .atStartOfDay(zone)
            .toInstant()
            .toEpochMilli() + 1_000L
        if (nextMidnight > nowMillis) {
            nextRefresh = nextMidnight
        }

        for (course in upcoming) {
            val end = course.endTime ?: continue
            val endMillis = today.atTime(end)
                .atZone(zone)
                .toInstant()
                .toEpochMilli() + 1_000L
            val current = nextRefresh
            if (endMillis > nowMillis &&
                (current == null || endMillis < current)
            ) {
                nextRefresh = endMillis
            }
        }
        return nextRefresh
    }

    fun renderElectricity(context: Context, views: RemoteViews) {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(ELECTRICITY_KEY, null)
        var degree = context.getString(R.string.widget_value_placeholder)
        var room = ""
        var updated = context.getString(R.string.widget_electricity_none)

        if (raw != null) {
            runCatching {
                val data = JSONObject(raw)
                if (data.optString("state") == "ok") {
                    degree = data.optString("degree", degree)
                    room = data.optString("room")
                    val time = data.optString("updated")
                    if (time.isNotEmpty()) {
                        updated = context.getString(R.string.widget_electricity_updated, time)
                    }
                }
            }
        }

        views.setTextViewText(R.id.widget_electricity_degree, degree)
        views.setTextViewText(R.id.widget_electricity_room, room)
        views.setTextViewText(R.id.widget_electricity_updated, updated)
        views.setOnClickPendingIntent(
            R.id.widget_electricity_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("newclass://electricity"),
            ),
        )
    }

    private fun matchesWeek(weeks: JSONArray?, week: Int): Boolean {
        if (weeks == null || weeks.length() == 0) return true
        for (index in 0 until weeks.length()) {
            if (weeks.optInt(index) == week) return true
        }
        return false
    }

    private data class WidgetCourse(
        val name: String,
        val room: String,
        val start: Int,
        val time: String,
        val endTime: LocalTime?,
    )
}
