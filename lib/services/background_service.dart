import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'news_scraper_service.dart';
import 'widget_update_service.dart';
import 'storage_service.dart';

class BackgroundService {
  static const String periodicTaskName = 'com.kncc.newsroom.periodicFetch';
  
  static Future<void> initialize() async {
    print('BackgroundService: Initializing WorkManager');
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    print('BackgroundService: WorkManager initialized and task registered');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print('BackgroundService: Background task started: $taskName');
    try {
      final scraperService = NewsScraperService();
      final prefs = await SharedPreferences.getInstance();
      final storageService = StorageService(prefs);
      
      print('BackgroundService: Fetching latest news');
      final articles = await scraperService.fetchLatestNews();
      
      if (articles.isNotEmpty) {
        print('BackgroundService: Articles fetched successfully. Count: ${articles.length}');
        
        // Save to app storage
        await storageService.saveArticles(articles);
        print('BackgroundService: Articles saved to app storage');
        
        // Update widget
        await WidgetUpdateService.updateWidgetWithArticles(articles);
        print('BackgroundService: Widget updated with new articles');
        return true;
      } else {
        print('BackgroundService: No articles fetched');
      }
    } catch (e) {
      print('BackgroundService: Background task failed with error: $e');
    }
    return false;
  });
} 