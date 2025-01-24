package com.example.newsroom

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import android.content.SharedPreferences
import android.content.Intent
import android.util.Log
import android.widget.RemoteViewsService
import android.widget.RemoteViewsService.RemoteViewsFactory
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class NewsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return NewsWidgetItemFactory(applicationContext)
    }
}

class NewsWidgetItemFactory(private val context: Context) : RemoteViewsFactory {
    private var newsItems: List<NewsItem> = listOf()
    
    override fun onCreate() {}
    
    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("flutter.news_articles", "[]")
        
        try {
            val jsonArray = JSONArray(jsonStr)
            newsItems = (0 until jsonArray.length()).map { i ->
                val item = jsonArray.getJSONObject(i)
                NewsItem(
                    title = item.getString("title"),
                    content = item.getString("content"),
                    imageUrl = item.getString("imageUrl"),
                    date = parseDate(item.getString("date"))
                )
            }
            Log.d("NewsWidget", "Loaded ${newsItems.size} items from SharedPreferences")
        } catch (e: Exception) {
            Log.e("NewsWidget", "Error parsing news items: ${e.message}")
            newsItems = listOf()
        }
    }
    
    override fun onDestroy() {}
    
    override fun getCount(): Int = newsItems.size
    
    override fun getViewAt(position: Int): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.news_item)
        val item = newsItems[position]
        
        rv.setTextViewText(R.id.news_title, item.title)
        rv.setTextViewText(R.id.news_summary, item.content)
        rv.setTextViewText(R.id.news_date, formatDate(item.date))
        
        // TODO: Load image using Glide or similar library
        // For now, we'll just show a placeholder
        rv.setImageViewResource(R.id.news_image, android.R.drawable.ic_menu_report_image)
        
        return rv
    }
    
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
    
    private fun parseDate(dateStr: String): Date {
        return try {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).parse(dateStr) ?: Date()
        } catch (e: Exception) {
            Date()
        }
    }
    
    private fun formatDate(date: Date): String {
        return SimpleDateFormat("yyyy년 MM월 dd일", Locale.KOREA).format(date)
    }
}

data class NewsItem(
    val title: String,
    val content: String,
    val imageUrl: String,
    val date: Date
)

class NewsWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("NewsWidget", "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
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
            
            val intent = Intent(context, NewsWidgetService::class.java)
            val views = RemoteViews(context.packageName, R.layout.news_widget)
            views.setRemoteAdapter(R.id.widget_list_view, intent)
            
            // Set empty view
            views.setEmptyView(R.id.widget_list_view, android.R.id.empty)
            
            Log.d("NewsWidget", "Updating widget UI with list adapter")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
        }
    }
} 