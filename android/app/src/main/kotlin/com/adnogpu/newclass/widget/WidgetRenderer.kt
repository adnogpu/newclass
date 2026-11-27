package com.adnogpu.newclass.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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

data class WidgetCourse(
    val name: String,
    val room: String,
    val start: Int,
    val section: String,
    val startTime: LocalTime?,
    val endTime: LocalTime?,
)

data class ScheduleSnapshot(
    val synced: Boolean,
    val todays: List<WidgetCourse>,
    val upcoming: List<WidgetCourse>,
    val nextRefresh: Long?,
)

object WidgetRenderer {
    private const val SCHEDULE_KEY = "today_schedule_json"
    private const val ELECTRICITY_KEY = "electricity_json"
    private val weekdayLabels = arrayOf(
        "周一", "周二", "周三", "周四", "周五", "周六", "周日",
    )
    private val timeFormatter = DateTimeFormatter.ofPattern("H:mm")
    private val displayTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    val courseAccents = intArrayOf(
        0xFF4F8FDE.toInt(),
        0xFFD2779B.toInt(),
        0xFF67A879.toInt(),
        0xFFCD9447.toInt(),
        0xFF8777CE.toInt(),
    )
    private val courseIconBgs = intArrayOf(
        R.drawable.widget_course_icon_blue,
        R.drawable.widget_course_icon_pink,
        R.drawable.widget_course_icon_green,
        R.drawable.widget_course_icon_amber,
    )
    private val courseIcons = intArrayOf(
        R.drawable.ic_widget_code,
        R.drawable.ic_widget_book,
        R.drawable.ic_widget_science,
        R.drawable.ic_widget_calc,
    )

    fun courseIcon(index: Int): Int = courseIcons[index % courseIcons.size]

    fun courseIconBg(index: Int): Int = courseIconBgs[index % courseIconBgs.size]

    fun formatTime(time: LocalTime?): String =
        time?.format(displayTimeFormatter).orEmpty()

    fun loadSchedule(context: Context): ScheduleSnapshot {
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
                        val section = item.optString("section")
                            .ifBlank { item.optString("time") }
                        todays.add(
                            WidgetCourse(
                                name = item.optString("name"),
                                room = item.optString("room"),
                                start = item.optInt("start"),
                                section = section,
                                startTime = parseTime(item.optString("startTime")),
                                endTime = parseTime(item.optString("endTime")),
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

        var nextRefresh: Long? = null
        val nowMillis = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
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

        return ScheduleSnapshot(synced, todays, upcoming, nextRefresh)
    }

    fun upcomingCourses(context: Context): List<WidgetCourse> =
        loadSchedule(context).upcoming

    /** Renders the static header/empty state; courses are provided by the RemoteViews list. */
    fun renderSchedule(context: Context, views: RemoteViews): Long? {
        val snapshot = loadSchedule(context)
        val today = LocalDate.now()
        var header =
            "${today.monthValue}/${today.dayOfMonth} " +
                weekdayLabels[today.dayOfWeek.value - 1]
        if (snapshot.synced && snapshot.upcoming.isNotEmpty()) {
            header += " · ${snapshot.upcoming.size}节"
        }
        views.setTextViewText(R.id.widget_schedule_date, header)

        val emptyMessage = when {
            !snapshot.synced -> context.getString(R.string.widget_schedule_unsynced)
            snapshot.todays.isEmpty() -> context.getString(R.string.widget_schedule_empty)
            snapshot.upcoming.isEmpty() -> context.getString(R.string.widget_schedule_ended)
            else -> null
        }
        if (emptyMessage != null) {
            views.setTextViewText(R.id.widget_schedule_empty_text, emptyMessage)
            views.setViewVisibility(R.id.widget_schedule_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_schedule_empty, View.GONE)
        }

        views.setOnClickPendingIntent(
            R.id.widget_schedule_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("newclass://schedule"),
            ),
        )
        return snapshot.nextRefresh
    }

    fun renderElectricity(context: Context, views: RemoteViews) {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(ELECTRICITY_KEY, null)
        var degree = context.getString(R.string.widget_value_placeholder)
        var build = ""
        var floor = ""
        var roomName = ""
        var updated = context.getString(R.string.widget_electricity_none)

        if (raw != null) {
            runCatching {
                val data = JSONObject(raw)
                if (data.optString("state") == "ok") {
                    degree = data.optString("degree", degree)
                    val combined = data.optString("room")
                    val parts = combined.split("·").map { it.trim() }
                    build = data.optString("build")
                        .ifBlank { parts.getOrNull(0).orEmpty() }
                    floor = data.optString("floor")
                        .ifBlank { parts.getOrNull(1).orEmpty() }
                    roomName = data.optString("roomName")
                        .ifBlank { parts.getOrNull(2).orEmpty() }
                    if (roomName.isEmpty()) {
                        roomName = parts.lastOrNull().orEmpty()
                    }
                    val time = data.optString("updated")
                    if (time.isNotEmpty()) {
                        updated = context.getString(
                            R.string.widget_electricity_updated,
                            time,
                        )
                    }
                }
            }
        }

        views.setTextViewText(R.id.widget_electricity_degree, degree)
        views.setTextViewText(
            R.id.widget_electricity_build,
            build.ifEmpty { "—" },
        )
        views.setTextViewText(
            R.id.widget_electricity_floor,
            floor.ifEmpty { "—" },
        )
        views.setTextViewText(
            R.id.widget_electricity_room,
            roomName.ifEmpty { "—" },
        )
        views.setTextViewText(R.id.widget_electricity_updated, updated)
        views.setOnClickPendingIntent(
            R.id.widget_electricity_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("newclass://electricity"),
            ),
        )
        val refreshIntent = Intent(
            context,
            ElectricityWidgetProvider::class.java,
        ).setAction(ElectricityWidgetProvider.ACTION_REFRESH)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            PendingIntent.FLAG_IMMUTABLE
        views.setOnClickPendingIntent(
            R.id.widget_electricity_refresh,
            PendingIntent.getBroadcast(context, 2002, refreshIntent, flags),
        )
    }

    private fun parseTime(text: String): LocalTime? = runCatching {
        LocalTime.parse(text, timeFormatter)
    }.getOrNull()

    private fun matchesWeek(weeks: JSONArray?, week: Int): Boolean {
        if (weeks == null || weeks.length() == 0) return true
        for (index in 0 until weeks.length()) {
            if (weeks.optInt(index) == week) return true
        }
        return false
    }
}
