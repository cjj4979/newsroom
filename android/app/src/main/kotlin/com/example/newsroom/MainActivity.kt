package com.example.newsroom

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.newsroom/widget"
    private val fileName = "news_articles.json"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "Configuring Flutter engine and method channel")
        
        // Get the article URL from the intent if it exists
        val articleUrl = intent.getStringExtra("articleUrl")
        if (articleUrl != null) {
            Log.d("MainActivity", "Received article URL: $articleUrl")
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    Log.d("MainActivity", "Received updateWidget method call")
                    updateWidget()
                    result.success(null)
                }
                "getInitialArticleUrl" -> {
                    Log.d("MainActivity", "Returning initial article URL: $articleUrl")
                    result.success(articleUrl)
                }
                else -> {
                    Log.d("MainActivity", "Received unknown method call: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun updateWidget() {
        Log.d("MainActivity", "Starting widget update process")
        // Get the file from the app's internal files directory
        val file = File(applicationContext.filesDir, fileName)
        if (file.exists()) {
            try {
                val articlesJson = file.readText()
                val jsonArray = JSONArray(articlesJson)
                Log.d("MainActivity", "Found ${jsonArray.length()} articles in file")
                for (i in 0 until jsonArray.length()) {
                    val article = jsonArray.getJSONObject(i)
                    Log.d("MainActivity", "Article $i date from file: ${article.optString("date", "NO_DATE")}")
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Error parsing articles JSON: $e")
            }
        } else {
            Log.d("MainActivity", "No articles file found at ${file.absolutePath}")
        }

        // Trigger widget update broadcast
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(applicationContext, NewsWidget::class.java)
        )
        Log.d("MainActivity", "Found ${appWidgetIds.size} widgets to update")
        val intent = Intent(applicationContext, NewsWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        applicationContext.sendBroadcast(intent)
        Log.d("MainActivity", "Broadcast sent to update widgets")
    }
}
