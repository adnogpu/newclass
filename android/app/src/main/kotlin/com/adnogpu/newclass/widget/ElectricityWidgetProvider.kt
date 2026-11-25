package com.adnogpu.newclass.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import com.adnogpu.newclass.R

class ElectricityWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            update(context, appWidgetManager, id)
        }
    }

    companion object {
        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_electricity)
            WidgetRenderer.renderElectricity(context, views)
            manager.updateAppWidget(id, views)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ElectricityWidgetProvider::class.java),
            )
            for (id in ids) update(context, manager, id)
        }
    }
}
