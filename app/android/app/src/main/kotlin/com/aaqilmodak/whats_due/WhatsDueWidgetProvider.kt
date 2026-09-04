package com.aaqilmodak.whats_due

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Renders everything due in the next week on the home screen.
 *
 * The selection, the ordering, the countdown wording and the urgency colour are
 * all decided in Dart and handed over as flat strings. This class renders them
 * and nothing else. That is deliberate: the widget is meant to be a cut-down
 * view of the Assignments list, and any rule duplicated here would eventually
 * disagree with the list it is supposed to mirror.
 */
class WhatsDueWidgetProvider : HomeWidgetProvider() {

    /** One entry per row in the layout; must match `WidgetBridge.rows`. */
    private data class Row(
        val container: Int,
        val spine: Int,
        val subject: Int,
        val title: Int,
        val count: Int,
        val progress: Int,
    )

    private val rows = listOf(
        Row(R.id.wd_row0, R.id.wd_t0_spine, R.id.wd_t0_subject, R.id.wd_t0_title,
            R.id.wd_t0_count, R.id.wd_t0_progress),
        Row(R.id.wd_row1, R.id.wd_t1_spine, R.id.wd_t1_subject, R.id.wd_t1_title,
            R.id.wd_t1_count, R.id.wd_t1_progress),
        Row(R.id.wd_row2, R.id.wd_t2_spine, R.id.wd_t2_subject, R.id.wd_t2_title,
            R.id.wd_t2_count, R.id.wd_t2_progress),
        Row(R.id.wd_row3, R.id.wd_t3_spine, R.id.wd_t3_subject, R.id.wd_t3_title,
            R.id.wd_t3_count, R.id.wd_t3_progress),
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.whats_due_widget).apply {
                // Falls back rather than rendering a blank card: a widget added
                // before the app has ever run has no data stored yet.
                val empty = widgetData.getString("wd_empty", null) ?: "Open to see this week"
                if (empty.isEmpty()) {
                    setViewVisibility(R.id.wd_empty, View.GONE)
                } else {
                    setViewVisibility(R.id.wd_empty, View.VISIBLE)
                    setTextViewText(R.id.wd_empty, empty)
                }

                rows.forEachIndexed { i, row ->
                    val title = widgetData.getString("wd_t${i}_title", "").orEmpty()
                    if (title.isEmpty()) {
                        setViewVisibility(row.container, View.GONE)
                    } else {
                        setViewVisibility(row.container, View.VISIBLE)
                        setTextViewText(row.title, title)
                        setTextViewText(
                            row.subject,
                            widgetData.getString("wd_t${i}_subject", "").orEmpty(),
                        )
                        setTextViewText(
                            row.count,
                            widgetData.getString("wd_t${i}_count", "").orEmpty(),
                        )
                        setTextViewText(
                            row.progress,
                            widgetData.getString("wd_t${i}_progress", "").orEmpty(),
                        )
                        // Sent as an ARGB int, because RemoteViews cannot set a
                        // colour any other way without a drawable per colour.
                        widgetData.getString("wd_t${i}_spine", null)
                            ?.toIntOrNull()
                            ?.let { setInt(row.spine, "setBackgroundColor", it) }
                    }
                }

                val more = widgetData.getString("wd_more", "0")?.toIntOrNull() ?: 0
                if (more > 0) {
                    setViewVisibility(R.id.wd_more, View.VISIBLE)
                    setTextViewText(R.id.wd_more, "AND $more MORE")
                } else {
                    setViewVisibility(R.id.wd_more, View.GONE)
                }

                setOnClickPendingIntent(
                    R.id.wd_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
