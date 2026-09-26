package com.blushy.blushy_love_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home-screen widget for a companion: "today's vibe + golden rule".
 *
 * The Flutter side (CompanionWidgetService) writes three strings into the
 * home_widget shared store; this reads them and paints the widget. When nothing
 * is shared the strings are empty and a neutral placeholder is shown instead of
 * stale data.
 */
class CompanionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val title = prefs.getString("companion_widget_title", "") ?: ""
        val vibe = prefs.getString("companion_widget_vibe", "") ?: ""
        val rule = prefs.getString("companion_widget_golden_rule", "") ?: ""

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.companion_widget)
            if (title.isEmpty() && vibe.isEmpty()) {
                views.setTextViewText(R.id.widget_title, "Blushy")
                views.setTextViewText(R.id.widget_vibe, "Open Blushy to see how to show up today.")
                views.setTextViewText(R.id.widget_golden_rule, "")
            } else {
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_vibe, vibe)
                views.setTextViewText(R.id.widget_golden_rule, rule)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
