package com.adnogpu.newclass.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.adnogpu.newclass.MainActivity
import com.adnogpu.newclass.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ScheduleViewsFactory(applicationContext)
}

private class ScheduleViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var courses: List<WidgetCourse> = emptyList()

    override fun onCreate() {
        load()
    }

    override fun onDataSetChanged() {
        load()
    }

    private fun load() {
        courses = runCatching {
            WidgetRenderer.upcomingCourses(context)
        }.getOrDefault(emptyList())
    }

    override fun getCount(): Int = courses.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(
            context.packageName,
            R.layout.widget_schedule_item,
        )
        val course = courses.getOrNull(position) ?: return views
        val accent = WidgetRenderer.courseAccents[
            position % WidgetRenderer.courseAccents.size
        ]
        views.setTextViewText(
            R.id.widget_schedule_item_section,
            course.section,
        )
        val start = WidgetRenderer.formatTime(course.startTime)
        val end = WidgetRenderer.formatTime(course.endTime)
        views.setTextViewText(R.id.widget_schedule_item_start, start)
        views.setTextViewText(R.id.widget_schedule_item_end, end)
        views.setViewVisibility(
            R.id.widget_schedule_item_start,
            if (start.isEmpty()) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_schedule_item_end,
            if (end.isEmpty()) View.GONE else View.VISIBLE,
        )
        views.setTextViewText(R.id.widget_schedule_item_name, course.name)
        views.setTextViewText(R.id.widget_schedule_item_room, course.room)
        views.setViewVisibility(
            R.id.widget_schedule_item_room,
            if (course.room.isEmpty()) View.GONE else View.VISIBLE,
        )
        views.setInt(
            R.id.widget_schedule_item_accent,
            "setBackgroundColor",
            accent,
        )
        views.setInt(
            R.id.widget_schedule_item_icon_bg,
            "setBackgroundResource",
            WidgetRenderer.courseIconBg(position),
        )
        views.setImageViewResource(
            R.id.widget_schedule_item_icon,
            WidgetRenderer.courseIcon(position),
        )
        views.setInt(
            R.id.widget_schedule_item_icon,
            "setColorFilter",
            accent,
        )
        views.setOnClickPendingIntent(
            R.id.widget_schedule_item_card,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("newclass://schedule"),
            ),
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun onDestroy() {
        courses = emptyList()
    }
}
