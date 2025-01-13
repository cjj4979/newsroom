import 'package:flutter/foundation.dart';
import '../models/news_article.dart';
import '../services/news_scraper_service.dart';
import '../services/storage_service.dart';

class NewsViewModel extends ChangeNotifier {
  final NewsScraperService _scraperService;
  final StorageService _storageService;
  
  List<NewsArticle> _articles = [];
  String? _error;
  bool _isLoading = false;

  // Duration after which cached data is considered stale
  static const _staleDuration = Duration(minutes: 15);

  NewsViewModel({
    required NewsScraperService scraperService,
    required StorageService storageService,
  })  : _scraperService = scraperService,
        _storageService = storageService {
    _loadArticles();
  }

  List<NewsArticle> get articles => _articles;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> _loadArticles() async {
    try {
      final cachedArticles = await _storageService.getArticles();
      if (cachedArticles.isNotEmpty) {
        _articles = cachedArticles;
        notifyListeners();
      }
      
      if (await _storageService.isDataStale(_staleDuration)) {
        await refreshArticles();
      }
    } catch (e) {
      _error = 'Failed to load cached articles: $e';
      notifyListeners();
    }
  }

  Future<void> refreshArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final articles = await _scraperService.fetchLatestNews();
      _articles = articles;
      await _storageService.saveArticles(articles);
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch articles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 