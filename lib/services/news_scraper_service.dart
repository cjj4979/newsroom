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

  /// Prints the HTML content with line numbers for debugging
  void _printResponseBody(String body) {
    print('\nNewsScraperService: Response Body Start ==================');
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      print('${i + 1}: ${lines[i]}');
    }
    print('NewsScraperService: Response Body End ====================\n');
  }

  /// Fetches and parses the latest news articles from the website.
  /// 
  /// Returns a List of [NewsArticle] objects.
  /// Throws [ScrapingException] if the fetch fails.
  Future<List<NewsArticle>> fetchLatestNews() async {
    print('NewsScraperService: Starting to fetch latest news');
    try {
      print('NewsScraperService: Making HTTP request to $_baseUrl');
      final response = await _client.get(Uri.parse(_baseUrl));
      
      if (response.statusCode != 200) {
        print('NewsScraperService: HTTP request failed with status ${response.statusCode}');
        throw ScrapingException('Failed to fetch news: ${response.statusCode}');
      }
      print('NewsScraperService: HTTP request successful');
      
      // Print response body for inspection
      //_printResponseBody(response.body);

      print('NewsScraperService: Parsing HTML document');
      final document = parser.parse(response.body);
      final articles = <NewsArticle>[];

      // Find all article elements in the results container
      final articleElements = document.querySelectorAll('div.results > a.result');
      print('NewsScraperService: Found ${articleElements.length} article elements');

      for (var element in articleElements) {
        try {
          print('NewsScraperService: Parsing article element');
          
          // Get title from h3 element
          final titleElement = element.querySelector('h3');
          if (titleElement == null) {
            print('NewsScraperService: Skipping article - no title element found');
            continue;
          }
          final title = titleElement.text.trim();
          
          // Get article URL from the anchor tag's href attribute
          final articleUrl = element.attributes['href'] ?? '';
          
          // Get summary from the p > span element
          final summaryElement = element.querySelector('p > span');
          final summary = summaryElement?.text.trim() ?? '';
          
          // Get image URL from the thumbnail img element
          final imageElement = element.querySelector('.news-releases-thumbnail img');
          final imageUrl = imageElement?.attributes['src'] ?? '';
          
          // Get date from the date-line span
          final dateElement = element.querySelector('.date-line span');
          final dateStr = dateElement?.text.trim() ?? '';

          print('NewsScraperService: Article data:');
          print('  - Title: $title');
          print('  - URL: $articleUrl');
          print('  - Summary length: ${summary.length}');
          print('  - Image URL: $imageUrl');
          print('  - Date string: $dateStr');

          final publishedDate = _parseDate(dateStr);
          print('  - Published Date: $publishedDate');

          articles.add(NewsArticle(
            title: title,
            summary: summary,
            imageUrl: imageUrl.startsWith('//') ? 'https:$imageUrl' : 
                     imageUrl.startsWith('/') ? 'https://news-kr.churchofjesuschrist.org$imageUrl' : imageUrl,
            articleUrl: articleUrl.startsWith('/') ? 'https://news-kr.churchofjesuschrist.org$articleUrl' : articleUrl,
            publishedDate: publishedDate,
          ));
          print('NewsScraperService: Successfully added article to list');
        } catch (e) {
          print('NewsScraperService: Error parsing article: $e');
          continue;
        }
      }

      print('NewsScraperService: Successfully parsed ${articles.length} articles');
      return articles;
    } catch (e) {
      print('NewsScraperService: Failed to fetch news with error: $e');
      throw ScrapingException('Failed to fetch news: $e');
    }
  }

  /// Parses the date string from the website into a DateTime object.
  DateTime _parseDate(String dateStr) {
    try {
      print('NewsScraperService: Parsing date string: $dateStr');
      // Example date format: "2025년 1월 23일 | 뉴스 보도"
      // First split by '|' and trim to get just the date part
      final datePart = dateStr.split('|')[0].trim();
      
      // Now split by spaces and remove Korean characters
      final year = int.parse(datePart.split('년')[0].trim());
      final month = int.parse(datePart.split('년')[1].split('월')[0].trim());
      final day = int.parse(datePart.split('월')[1].split('일')[0].trim());
      
      print('NewsScraperService: Parsed date - year: $year, month: $month, day: $day');
      return DateTime(year, month, day);
    } catch (e) {
      print('NewsScraperService: Failed to parse date: $e, using current time');
      return DateTime.now();
    }
  }

  /// Closes the HTTP client when the service is no longer needed.
  void dispose() {
    _client.close();
  }
} 