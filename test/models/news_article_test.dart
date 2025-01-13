import 'package:flutter_test/flutter_test.dart';
import 'package:newsroom/models/news_article.dart';

void main() {
  group('NewsArticle', () {
    test('should create NewsArticle instance from constructor', () {
      final date = DateTime.now();
      final article = NewsArticle(
        title: 'Test Title',
        summary: 'Test Summary',
        imageUrl: 'https://example.com/image.jpg',
        articleUrl: 'https://example.com/article',
        publishedDate: date,
      );

      expect(article.title, 'Test Title');
      expect(article.summary, 'Test Summary');
      expect(article.imageUrl, 'https://example.com/image.jpg');
      expect(article.articleUrl, 'https://example.com/article');
      expect(article.publishedDate, date);
    });

    test('should convert to and from JSON', () {
      final date = DateTime(2024, 1, 1, 12, 0); // Fixed date for consistent testing
      final article = NewsArticle(
        title: 'Test Title',
        summary: 'Test Summary',
        imageUrl: 'https://example.com/image.jpg',
        articleUrl: 'https://example.com/article',
        publishedDate: date,
      );

      // Convert to JSON
      final json = article.toJson();

      // Create new instance from JSON
      final fromJson = NewsArticle.fromJson(json);

      // Verify all properties match
      expect(fromJson.title, article.title);
      expect(fromJson.summary, article.summary);
      expect(fromJson.imageUrl, article.imageUrl);
      expect(fromJson.articleUrl, article.articleUrl);
      expect(fromJson.publishedDate, article.publishedDate);
    });

    test('should handle JSON date format correctly', () {
      final jsonData = {
        'title': 'Test Title',
        'summary': 'Test Summary',
        'imageUrl': 'https://example.com/image.jpg',
        'articleUrl': 'https://example.com/article',
        'publishedDate': '2024-01-01T12:00:00.000',
      };

      final article = NewsArticle.fromJson(jsonData);
      expect(article.publishedDate, DateTime(2024, 1, 1, 12, 0));
    });
  });
} 