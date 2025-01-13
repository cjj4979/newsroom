import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:newsroom/services/storage_service.dart';
import 'package:newsroom/models/news_article.dart';

void main() {
  group('StorageService', () {
    late StorageService storageService;
    late SharedPreferences preferences;

    setUp(() async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      storageService = StorageService(preferences);
    });

    test('should save and retrieve articles', () async {
      // Create test articles
      final articles = [
        NewsArticle(
          title: 'Test Article 1',
          summary: 'Summary 1',
          imageUrl: 'https://example.com/image1.jpg',
          articleUrl: 'https://example.com/article1',
          publishedDate: DateTime(2024, 1, 1),
        ),
        NewsArticle(
          title: 'Test Article 2',
          summary: 'Summary 2',
          imageUrl: 'https://example.com/image2.jpg',
          articleUrl: 'https://example.com/article2',
          publishedDate: DateTime(2024, 1, 2),
        ),
      ];

      // Save articles
      await storageService.saveArticles(articles);

      // Retrieve articles
      final retrievedArticles = storageService.getArticles();

      // Verify articles match
      expect(retrievedArticles.length, articles.length);
      expect(retrievedArticles[0].title, articles[0].title);
      expect(retrievedArticles[1].title, articles[1].title);
      expect(retrievedArticles[0].publishedDate, articles[0].publishedDate);
      expect(retrievedArticles[1].publishedDate, articles[1].publishedDate);
    });

    test('should handle empty storage', () {
      final articles = storageService.getArticles();
      expect(articles, isEmpty);
    });

    test('should update last fetch time when saving articles', () async {
      // Save articles
      await storageService.saveArticles([
        NewsArticle(
          title: 'Test Article',
          summary: 'Summary',
          imageUrl: 'https://example.com/image.jpg',
          articleUrl: 'https://example.com/article',
          publishedDate: DateTime.now(),
        ),
      ]);

      // Get last fetch time
      final lastFetch = storageService.getLastFetchTime();
      expect(lastFetch, isNotNull);
      
      // Should be recent (within last second)
      final age = DateTime.now().difference(lastFetch!);
      expect(age.inSeconds, lessThan(1));
    });

    test('should correctly identify stale data', () async {
      // Save articles
      await storageService.saveArticles([
        NewsArticle(
          title: 'Test Article',
          summary: 'Summary',
          imageUrl: 'https://example.com/image.jpg',
          articleUrl: 'https://example.com/article',
          publishedDate: DateTime.now(),
        ),
      ]);

      // Check freshly saved data
      expect(storageService.isDataStale(Duration(minutes: 30)), false);

      // Check with very short duration
      expect(storageService.isDataStale(Duration(microseconds: 1)), true);
    });

    test('should clear all data', () async {
      // Save some data
      await storageService.saveArticles([
        NewsArticle(
          title: 'Test Article',
          summary: 'Summary',
          imageUrl: 'https://example.com/image.jpg',
          articleUrl: 'https://example.com/article',
          publishedDate: DateTime.now(),
        ),
      ]);

      // Clear data
      await storageService.clearData();

      // Verify data is cleared
      expect(storageService.getArticles(), isEmpty);
      expect(storageService.getLastFetchTime(), isNull);
    });
  });
} 