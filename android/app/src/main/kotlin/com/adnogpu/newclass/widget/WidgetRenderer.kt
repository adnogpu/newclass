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
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Date
import java.util.Locale

object WidgetRenderer {
    private const val SCHEDULE_KEY = "today_schedule_json"
    private const val ELECTRICITY_KEY = "electricity_json"

    private val scheduleRowIds = intArrayOf(
        R.id.widget_schedule_row_1,
        R.id.widget_schedule_row_2,
        R.id.widget_schedule_row_3,
        R.id.widget_schedule_row_4,
    )
    private val scheduleTimeIds = intArrayOf(
        R.id.widget_schedule_time_1,
        R.id.widget_schedule_time_2,
        R.id.widget_schedule_time_3,
        R.id.widget_schedule_time_4,
    )
    private val scheduleNameIds = intArrayOf(
        R.id.widget_schedule_name_1,
        R.id.widget_schedule_name_2,
        R.id.widget_schedule_name_3,
        R.id.widget_schedule_name_4,
    )
    private val scheduleRoomIds = intArrayOf(
        R.id.widget_schedule_room_1,
        R.id.widget_schedule_room_2,
        R.id.widget_schedule_room_3,
        R.id.widget_schedule_room_4,
    )

    fun renderSchedule(context: Context, views: RemoteViews) {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(SCHEDULE_KEY, null)
        val today = LocalDate.now()
        val dateText = SimpleDateFormat("M月d日 EEEE", Locale.CHINA).format(Date())
        var synced = false
        val courses = mutableListOf<WidgetCourse>()

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
                        courses.add(
                            WidgetCourse(
                                name = item.optString("name"),
                                room = item.optString("room"),
                                start = item.optInt("start"),
                                time = item.optString("time"),
                            ),
                        )
                    }
                    courses.sortBy { it.start }
                }
            }
        }

        views.setTextViewText(R.id.widget_schedule_date, dateText)
        if (!synced) {
            views.setViewVisibility(R.id.widget_schedule_empty, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_schedule_empty,
                context.getString(R.string.widget_schedule_unsynced),
            )
        } else if (courses.isEmpty()) {
            views.setViewVisibility(R.id.widget_schedule_empty, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_schedule_empty,
                context.getString(R.string.widget_schedule_empty),
            )
        } else {
            views.setViewVisibility(R.id.widget_schedule_empty, View.GONE)
            if (courses.size > scheduleRowIds.size) {
                views.setTextViewText(
                    R.id.widget_schedule_date,
                    "$dateText · +${courses.size - scheduleRowIds.size}",
                )
            }
        }

        for (index in scheduleRowIds.indices) {
            val visible = synced && index < courses.size
            views.setViewVisibility(
                scheduleRowIds[index],
                if (visible) View.VISIBLE else View.GONE,
            )
            if (visible) {
                val course = courses[index]
                views.setTextViewText(scheduleTimeIds[index], course.time)
                views.setTextViewText(scheduleNameIds[index], course.name)
                views.setTextViewText(scheduleRoomIds[index], course.room)
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
    )
}
