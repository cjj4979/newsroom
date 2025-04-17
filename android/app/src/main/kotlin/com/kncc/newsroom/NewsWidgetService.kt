package com.kncc.newsroom

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.widget.RemoteViewsService.RemoteViewsFactory
import com.bumptech.glide.Glide
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class NewsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return NewsWidgetItemFactory(applicationContext)
    }
}

class NewsWidgetItemFactory(private val context: Context) : RemoteViewsFactory {
    private var newsItems: List<NewsItem> = listOf()
    private val fileName = "news_articles.json"
    
    override fun onCreate() {}
    
    override fun onDataSetChanged() {
        try {
            // Read from the file in app's internal storage
            val file = File(context.filesDir, fileName)
            Log.d("NewsWidget", "Attempting to read from file at: ${file.absolutePath}")
            
            if (!file.exists()) {
                Log.e("NewsWidget", "Articles file not found at ${file.absolutePath}")
                // List all files in the directory for debugging
                context.filesDir.listFiles()?.forEach { 
                    Log.d("NewsWidget", "Found file in directory: ${it.name}")
                }
                newsItems = listOf()
                return
            }

            val jsonStr = file.readText()
            Log.d("NewsWidget", "Successfully read ${jsonStr.length} characters from file")
            
            val jsonArray = JSONArray(jsonStr)
            newsItems = (0 until jsonArray.length()).map { i ->
                val item = jsonArray.getJSONObject(i)
                val dateStr = item.optString("date", "")
                Log.d("NewsWidget", "Article $i date string from JSON: $dateStr")
                
                NewsItem(
                    title = item.getString("title"),
                    content = item.getString("content"),
                    imageUrl = item.getString("imageUrl"),
                    articleUrl = item.getString("articleUrl"),
                    date = parseDate(dateStr)
                )
            }
            Log.d("NewsWidget", "Loaded ${newsItems.size} items from file")
        } catch (e: Exception) {
            Log.e("NewsWidget", "Error reading news items from file: ${e.message}")
            Log.e("NewsWidget", "Stack trace: ${e.stackTrace.joinToString("\n")}")
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
        
        try {
            // Load image using Glide with size limit and timeout
            val bitmap = Glide.with(context)
                .asBitmap()
                .load(item.imageUrl)
                .override(300, 300) // Limit image size
                .timeout(3000) // 3 second timeout
                .submit()
                .get(5, java.util.concurrent.TimeUnit.SECONDS) // Add explicit timeout
            
            if (bitmap != null) {
                rv.setImageViewBitmap(R.id.news_image, bitmap)
            } else {
                Log.e("NewsWidget", "Failed to load image for article $position: Bitmap is null")
                rv.setImageViewResource(R.id.news_image, android.R.drawable.ic_menu_report_image)
            }
        } catch (e: Exception) {
            Log.e("NewsWidget", "Failed to load image for article $position: ${e.message}")
            rv.setImageViewResource(R.id.news_image, android.R.drawable.ic_menu_report_image)
        }

        // Create the fill-in intent
        val fillInIntent = Intent().apply {
            putExtra("articleUrl", item.articleUrl)
            action = "com.kncc.newsroom.WIDGET_CLICK"
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        // Set the fill-in intent on both the container and individual views
        rv.setOnClickFillInIntent(R.id.news_item_container, fillInIntent)
        rv.setOnClickFillInIntent(R.id.news_title, fillInIntent)
        rv.setOnClickFillInIntent(R.id.news_summary, fillInIntent)
        rv.setOnClickFillInIntent(R.id.news_image, fillInIntent)
        
        return rv
    }
    
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
    
    private fun parseDate(dateStr: String): Date {
        try {
            Log.d("NewsWidget", "Parsing date string: $dateStr")
            // First try with milliseconds format
            return try {
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.KOREA).apply {
                    timeZone = TimeZone.getTimeZone("Asia/Seoul")
                }.parse(dateStr) ?: throw Exception("Failed to parse with milliseconds")
            } catch (e: Exception) {
                // If that fails, try without milliseconds
                try {
                    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.KOREA).apply {
                        timeZone = TimeZone.getTimeZone("Asia/Seoul")
                    }.parse(dateStr) ?: throw Exception("Failed to parse without milliseconds")
                } catch (e2: Exception) {
                    // Finally, try just the date part
                    SimpleDateFormat("yyyy-MM-dd", Locale.KOREA).apply {
                        timeZone = TimeZone.getTimeZone("Asia/Seoul")
                    }.parse(dateStr.split("T")[0]) ?: throw Exception("Failed to parse date part")
                }
            }
        } catch (e: Exception) {
            Log.e("NewsWidget", "Failed to parse date '$dateStr': ${e.message}")
            // Create a date object for today at midnight Korean time
            val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Seoul"))
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.time
        }
    }
    
    private fun formatDate(date: Date): String {
        return SimpleDateFormat("yyyy년 MM월 dd일", Locale.KOREA).apply {
            timeZone = TimeZone.getTimeZone("Asia/Seoul")
        }.format(date)
    }
} 