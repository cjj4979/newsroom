package com.example.newsroom

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import android.content.Intent
import android.util.Log
import android.app.PendingIntent

class NewsWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("NewsWidget", "onUpdate called for ${appWidgetIds.size} widgets")
        
        // Create an Intent to launch MainActivity when clicked
        val intent = Intent(context, MainActivity::class.java).apply {
            // Add specific action for widget clicks
            action = "com.example.newsroom.WIDGET_CLICK"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        Log.d("NewsWidget", "Created template intent with action: ${intent.action}")
        
        // Create the pending intent
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        Log.d("NewsWidget", "Created PendingIntent for MainActivity")

        // Update each widget
        appWidgetIds.forEach { appWidgetId ->
            Log.d("NewsWidget", "Updating widget ID: $appWidgetId")
            
            val views = RemoteViews(context.packageName, R.layout.news_widget)
            
            // Set up the RemoteViews object to use a RemoteViews adapter
            views.setRemoteAdapter(R.id.widget_list_view, 
                Intent(context, NewsWidgetService::class.java)
            )
            
            // Set the pending intent template
            views.setPendingIntentTemplate(R.id.widget_list_view, pendingIntent)
            Log.d("NewsWidget", "Set PendingIntent template on widget")
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d("NewsWidget", "Widget $appWidgetId update completed")
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d("NewsWidget", "Widget enabled - First time widget is added to home screen")
        // Force an update when widget is first enabled
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, NewsWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
        onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d("NewsWidget", "Received broadcast intent: ${intent.action}")
        
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            Log.d("NewsWidget", "Received widget update broadcast")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, NewsWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            
            // Notify the widget that the data has changed
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list_view)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            Log.d("NewsWidget", "updateAppWidget called for widget $appWidgetId")
            
            // Create an Intent to launch MainActivity when clicked
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                // Add action to help with debugging
                action = "com.example.newsroom.WIDGET_CLICK"
            }
            Log.d("NewsWidget", "Created main intent with flags: ${intent.flags}")
            
            // Create the pending intent
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            Log.d("NewsWidget", "Created PendingIntent with flags: UPDATE_CURRENT | IMMUTABLE")
            
            val serviceIntent = Intent(context, NewsWidgetService::class.java)
            Log.d("NewsWidget", "Created service intent for NewsWidgetService")
            
            val views = RemoteViews(context.packageName, R.layout.news_widget)
            views.setRemoteAdapter(R.id.widget_list_view, serviceIntent)
            Log.d("NewsWidget", "Set remote adapter for widget list view")
            
            // Set the pending intent template
            views.setPendingIntentTemplate(R.id.widget_list_view, pendingIntent)
            Log.d("NewsWidget", "Set pending intent template for list view")
            
            // Set empty view
            views.setEmptyView(R.id.widget_list_view, android.R.id.empty)
            
            Log.d("NewsWidget", "Updating widget UI with list adapter")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
            Log.d("NewsWidget", "Widget update completed")
        }
    }
}