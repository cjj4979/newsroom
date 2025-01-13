import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/news_article.dart';
import '../utils/exceptions.dart';

/// Service responsible for scraping news articles from the Church newsroom website.
class NewsScraperService {
  /// The base URL of the Church newsroom website
  static const String _baseUrl = 'https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C';
  
  /// HTTP client for making requests
  final http.Client _client;

  NewsScraperService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches and parses the latest news articles from the website.
  /// 
  /// Returns a List of [NewsArticle] objects.
  /// Throws [ScrapingException] if the fetch fails.
  Future<List<NewsArticle>> fetchLatestNews() async {
    try {
      final response = await _client.get(Uri.parse(_baseUrl));
      
      if (response.statusCode != 200) {
        throw ScrapingException('Failed to fetch news: ${response.statusCode}');
      }

      final document = parser.parse(response.body);
      final articles = <NewsArticle>[];

      // Find all article elements on the page
      final articleElements = document.querySelectorAll('article.article-item');

      for (var element in articleElements) {
        try {
          final titleElement = element.querySelector('.article-title a');
          final summaryElement = element.querySelector('.article-summary');
          final imageElement = element.querySelector('img');
          final dateElement = element.querySelector('.article-date');

          if (titleElement == null) continue;

          final title = titleElement.text.trim();
          final articleUrl = titleElement.attributes['href'] ?? '';
          final summary = summaryElement?.text.trim() ?? '';
          final imageUrl = imageElement?.attributes['src'] ?? '';
          final dateStr = dateElement?.text.trim() ?? '';

          final publishedDate = _parseDate(dateStr);

          articles.add(NewsArticle(
            title: title,
            summary: summary,
            imageUrl: imageUrl,
            articleUrl: articleUrl,
            publishedDate: publishedDate,
          ));
        } catch (e) {
          print('Error parsing article: $e');
          continue;
        }
      }

      return articles;
    } catch (e) {
      throw ScrapingException('Failed to fetch news: $e');
    }
  }

  /// Parses the date string from the website into a DateTime object.
  DateTime _parseDate(String dateStr) {
    try {
      // Implement date parsing logic based on the website's date format
      return DateTime.now(); // Placeholder
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Closes the HTTP client when the service is no longer needed.
  void dispose() {
    _client.close();
  }
} 