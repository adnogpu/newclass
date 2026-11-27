package com.adnogpu.newclass.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import com.adnogpu.newclass.R
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.UNIQUE_NAME_KEY

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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            updateAll(context)
            enqueueRefresh(context)
        }
    }

    companion object {
        const val ACTION_REFRESH =
            "com.adnogpu.newclass.widget.REFRESH_ELECTRICITY"
        private const val MANUAL_REFRESH_WORK = "newclass.electricity.manual"

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

        private fun enqueueRefresh(context: Context) {
            try {
                val input = Data.Builder()
                    .putString(
                        BackgroundWorker.DART_TASK_KEY,
                        "electricity-refresh",
                    )
                    .putString(UNIQUE_NAME_KEY, MANUAL_REFRESH_WORK)
                    .build()
                val request = OneTimeWorkRequest.Builder(
                    BackgroundWorker::class.java,
                )
                    .setInputData(input)
                    .setConstraints(
                        Constraints.Builder()
                            .setRequiredNetworkType(NetworkType.CONNECTED)
                            .build(),
                    )
                    .build()
                WorkManager.getInstance(context).enqueueUniqueWork(
                    MANUAL_REFRESH_WORK,
                    ExistingWorkPolicy.REPLACE,
                    request,
                )
            } catch (_: Throwable) {
                // The periodic refresh remains available if this enqueue fails.
            }
        }
    }
}
