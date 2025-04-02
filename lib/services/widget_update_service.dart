import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/news_article.dart';

class WidgetUpdateService {
  static const platform = MethodChannel('com.example.newsroom/widget');
  static const int maxArticles = 10; // Maximum number of articles to store
  static const String fileName = "news_articles.json";

  static Future<void> updateWidgetWithArticles(List<NewsArticle> articles) async {
    try {
      print('WidgetUpdateService: Updating widget with ${articles.length} articles');
      
      // Print dates for all articles
      for (var i = 0; i < articles.length; i++) {
        print('WidgetUpdateService: Article $i date: ${articles[i].publishedDate}');
      }
      
      // Save to file storage (limited to maxArticles)
      final List<Map<String, dynamic>> articlesList = articles.take(maxArticles).map((article) => {
        'title': article.title,
        'content': article.summary,
        'imageUrl': article.imageUrl,
        'articleUrl': article.articleUrl,
        'date': article.publishedDate.toIso8601String()
      }).toList();

      // Get the application files directory
      final directory = await getApplicationDocumentsDirectory();
      final filesDir = '${directory.parent.path}/files';
      final file = File('$filesDir/$fileName');

      // Create the directory if it doesn't exist
      await Directory(filesDir).create(recursive: true);

      // Write JSON data to the file
      final jsonString = jsonEncode(articlesList);
      await file.writeAsString(jsonString);
      print('WidgetUpdateService: Successfully wrote articles to ${file.path}');

      // Verify the save by reading it back
      final savedData = await file.readAsString();
      print('WidgetUpdateService: Verification - Data in file: $savedData');
      
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