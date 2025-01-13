import 'package:flutter/foundation.dart';
import '../models/news_article.dart';
import '../services/news_scraper_service.dart';

/// ViewModel responsible for managing news article data and state.
class NewsViewModel extends ChangeNotifier {
  final NewsScraperService _scraperService;
  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  String? _error;

  /// Indicates whether data is currently being loaded
  bool get isLoading => _isLoading;
  
  /// List of currently loaded news articles
  List<NewsArticle> get articles => List.unmodifiable(_articles);
  
  /// Current error message, if any
  String? get error => _error;

  NewsViewModel({NewsScraperService? scraperService})
      : _scraperService = scraperService ?? NewsScraperService();

  /// Fetches the latest news articles from the service.
  Future<void> fetchNews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _articles = await _scraperService.fetchLatestNews();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _articles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scraperService.dispose();
    super.dispose();
  }
} 