import 'package:flutter/foundation.dart';
import '../models/news_article.dart';
import '../services/news_scraper_service.dart';
import '../services/storage_service.dart';
import '../services/widget_update_service.dart';

class NewsViewModel extends ChangeNotifier {
  final NewsScraperService _scraperService;
  final StorageService _storageService;
  
  List<NewsArticle> _articles = [];
  String? _error;
  bool _isLoading = false;

  static const _staleDuration = Duration(minutes: 15);

  NewsViewModel({
    required NewsScraperService scraperService,
    required StorageService storageService,
  })  : _scraperService = scraperService,
        _storageService = storageService {
    print('NewsViewModel: Initializing');
    _loadArticles();
  }

  List<NewsArticle> get articles => _articles;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Loads articles from cache if available and not stale
  /// Otherwise fetches fresh articles
  Future<void> _loadArticles() async {
    print('NewsViewModel: Loading articles');
    try {
      final cachedArticles = _storageService.getArticles();
      print('NewsViewModel: Loaded ${cachedArticles.length} cached articles');
      
      if (cachedArticles.isNotEmpty && !_storageService.isDataStale(_staleDuration)) {
        // Use cached data if available and fresh
        _articles = cachedArticles;
        await WidgetUpdateService.updateWidgetWithArticles(_articles);
        notifyListeners();
      } else {
        // Fetch fresh data if cache is empty or stale
        await refreshArticles();
      }
    } catch (e) {
      print('NewsViewModel: Failed to load cached articles: $e');
      _error = 'Failed to load cached articles: $e';
      notifyListeners();
    }
  }

  /// Fetches fresh articles and updates both storage and widget
  Future<void> refreshArticles() async {
    print('NewsViewModel: Refreshing articles');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('NewsViewModel: Fetching latest news');
      final articles = await _scraperService.fetchLatestNews();
      print('NewsViewModel: Fetched ${articles.length} articles');
      
      _articles = articles;
      
      // Save to app storage
      await _storageService.saveArticles(articles);
      print('NewsViewModel: Articles saved to storage');
      
      // Update widget
      if (articles.isNotEmpty) {
        print('NewsViewModel: Updating widget with new articles');
        await WidgetUpdateService.updateWidgetWithArticles(articles);
      }
      _error = null;
    } catch (e) {
      print('NewsViewModel: Failed to fetch articles: $e');
      _error = 'Failed to fetch articles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 