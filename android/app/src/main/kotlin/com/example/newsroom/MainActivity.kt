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
    private var initialArticleUrl: String? = null
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "Configuring Flutter engine and method channel")
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    Log.d("MainActivity", "Received updateWidget method call")
                    updateWidget()
                    result.success(null)
                }
                "getInitialArticleUrl" -> {
                    Log.d("MainActivity", "Returning initial article URL: $initialArticleUrl")
                    result.success(initialArticleUrl)
                }
                else -> {
                    Log.d("MainActivity", "Received unknown method call: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent triggered with intent extras: ${intent.extras}")
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        Log.d("MainActivity", "Handling intent with action: ${intent.action}")
        
        // Check if this is a widget click
        if (intent.action == "com.example.newsroom.WIDGET_CLICK") {
            Log.d("MainActivity", "Handling widget click intent")
            // Get the article URL from the fill-in intent extras
            var newUrl = intent.getStringExtra("articleUrl")
            
            // If URL is empty or null, check the extras bundle
            if (newUrl.isNullOrEmpty() && intent.extras != null) {
                val fillInIntent = intent.extras?.get("fillInIntent") as? Intent
                newUrl = fillInIntent?.getStringExtra("articleUrl")
            }

            if (!newUrl.isNullOrEmpty()) {
                Log.d("MainActivity", "Notifying Flutter of new URL: $newUrl")
                initialArticleUrl = newUrl
                // Notify Flutter of the new URL
                runOnUiThread {
                    methodChannel.invokeMethod("updateArticleUrl", newUrl)
                }
            }
        }
    }

    private fun updateWidget() {
        Log.d("MainActivity", "Starting widget update process")
        
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
