package com.example.newsroom

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.newsroom/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d("MainActivity", "Configuring Flutter engine and method channel")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    Log.d("MainActivity", "Received updateWidget method call")
                    updateWidget()
                    result.success(null)
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
        val context: Context = applicationContext

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val articles = prefs.getString("flutter.news_articles", "[]")
        Log.d("MainActivity", "Current articles in SharedPreferences: $articles")
        
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, NewsWidget::class.java)
        )
        Log.d("MainActivity", "Found ${appWidgetIds.size} widgets to update")
        
        // Trigger widget update
        val intent = Intent(context, NewsWidget::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        context.sendBroadcast(intent)
        Log.d("MainActivity", "Broadcast sent to update widgets")
    }
}
