import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';

/// Service responsible for storing and retrieving data from local storage.
class StorageService {
  /// Key for storing the list of articles
  static const String _articlesKey = 'news_articles';
  
  /// Key for storing the last fetch timestamp
  static const String _lastFetchKey = 'last_fetch_time';
  
  /// Instance of SharedPreferences for data persistence
  final SharedPreferences _prefs;

  /// Constructor that takes a SharedPreferences instance
  StorageService(this._prefs);

  /// Creates a StorageService instance by initializing SharedPreferences
  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  /// Saves a list of articles to local storage
  Future<void> saveArticles(List<NewsArticle> articles) async {
    // Convert articles to JSON format
    final jsonList = articles.map((article) => article.toJson()).toList();
    
    // Save the JSON string to SharedPreferences
    await _prefs.setString(_articlesKey, jsonEncode(jsonList));
    
    // Update the last fetch timestamp
    await _prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
  }

  /// Retrieves the list of saved articles from local storage
  List<NewsArticle> getArticles() {
    // Get the JSON string from SharedPreferences
    final jsonString = _prefs.getString(_articlesKey);
    
    if (jsonString == null) {
      return [];
    }

    try {
      // Decode the JSON string to a list of maps
      final jsonList = jsonDecode(jsonString) as List;
      
      // Convert each map to a NewsArticle object
      return jsonList
          .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error parsing stored articles: $e');
      return [];
    }
  }

  /// Gets the timestamp of the last successful fetch
  DateTime? getLastFetchTime() {
    final timeString = _prefs.getString(_lastFetchKey);
    if (timeString == null) {
      return null;
    }

    try {
      return DateTime.parse(timeString);
    } catch (e) {
      print('Error parsing last fetch time: $e');
      return null;
    }
  }

  /// Checks if the cached data is stale (older than the specified duration)
  bool isDataStale(Duration maxAge) {
    final lastFetch = getLastFetchTime();
    if (lastFetch == null) {
      return true;
    }

    final age = DateTime.now().difference(lastFetch);
    return age > maxAge;
  }

  /// Clears all stored data
  Future<void> clearData() async {
    await _prefs.remove(_articlesKey);
    await _prefs.remove(_lastFetchKey);
  }
} 