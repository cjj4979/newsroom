/// Exception thrown when scraping operations fail.
class ScrapingException implements Exception {
  final String message;

  ScrapingException(this.message);

  @override
  String toString() => 'ScrapingException: $message';
} 