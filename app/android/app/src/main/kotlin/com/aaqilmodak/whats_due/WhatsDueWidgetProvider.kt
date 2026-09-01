package com.aaqilmodak.whats_due

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Renders today's plan on the home screen.
 *
 * The plan itself is computed in Dart and handed over as flat strings, so this
 * class holds no scheduling logic at all. That is deliberate: the ranking is
 * the opinionated part of the app and it must not exist in two places, where
 * the widget and the Today tab could quietly disagree.
 */
class WhatsDueWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // Row ids are laid out flat rather than in a list, because RemoteViews
        // cannot inflate a collection without a RemoteViewsService, and three
        // lines is all this size shows legibly anyway.
        val rows = arrayOf(
            Triple(R.id.wd_row0, R.id.wd_t0_text, R.id.wd_t0_meta),
            Triple(R.id.wd_row1, R.id.wd_t1_text, R.id.wd_t1_meta),
            Triple(R.id.wd_row2, R.id.wd_t2_text, R.id.wd_t2_meta),
        )

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.whats_due_widget).apply {
                setTextViewText(
                    R.id.wd_headline,
                    // Falls back rather than rendering an empty card: a widget
                    // added before the app has ever run has no data yet.
                    widgetData.getString("wd_headline", null) ?: "Open to see today",
                )

                rows.forEachIndexed { i, (rowId, textId, metaId) ->
                    val text = widgetData.getString("wd_t${i}_text", "").orEmpty()
                    if (text.isEmpty()) {
                        setViewVisibility(rowId, View.GONE)
                    } else {
                        setViewVisibility(rowId, View.VISIBLE)
                        setTextViewText(textId, text)
                        setTextViewText(
                            metaId,
                            widgetData.getString("wd_t${i}_meta", "").orEmpty(),
                        )
                    }
                }

                // Says how much is not shown, so the three visible lines are not
                // mistaken for the whole day.
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
