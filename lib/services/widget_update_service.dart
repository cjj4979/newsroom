import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';

class WidgetUpdateService {
  static const platform = MethodChannel('com.example.newsroom/widget');
  static const int maxArticles = 10; // Maximum number of articles to store

  static Future<void> updateWidgetWithArticles(List<NewsArticle> articles) async {
    try {
      print('WidgetUpdateService: Updating widget with ${articles.length} articles');
      final prefs = await SharedPreferences.getInstance();
      
      // Save to widget storage (limited to maxArticles)
      final List<Map<String, dynamic>> articlesList = articles.take(maxArticles).map((article) => {
        'title': article.title,
        'content': article.summary,
        'imageUrl': article.imageUrl,
        'date': article.publishedDate.toIso8601String(),
      }).toList();

      await prefs.setString('flutter.news_articles', jsonEncode(articlesList));
      print('WidgetUpdateService: Widget storage updated with ${articlesList.length} articles');
      
      try {
        // Try to update through platform channel regardless of context
        print('WidgetUpdateService: Requesting widget update through platform channel');
        await platform.invokeMethod('updateWidget');
        print('WidgetUpdateService: Widget update requested successfully');
      } catch (e) {
        // If platform channel fails (e.g., in background), just log it
        print('WidgetUpdateService: Could not update through platform channel (might be in background): $e');
      }
    } catch (e) {
      print('WidgetUpdateService: Failed to update widget: $e');
      rethrow;
    }
  }
} 