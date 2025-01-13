/// Represents a news article with its essential information.
class NewsArticle {
  /// The title or headline of the article
  final String title;
  
  /// A brief summary or excerpt of the article content
  final String summary;
  
  /// The URL of the article's thumbnail image
  final String imageUrl;
  
  /// The URL to the full article
  final String articleUrl;
  
  /// The publication date of the article
  final DateTime publishedDate;

  NewsArticle({
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.articleUrl,
    required this.publishedDate,
  });

  /// Creates a NewsArticle from JSON data
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] as String,
      summary: json['summary'] as String,
      imageUrl: json['imageUrl'] as String,
      articleUrl: json['articleUrl'] as String,
      publishedDate: DateTime.parse(json['publishedDate'] as String),
    );
  }

  /// Converts the NewsArticle to JSON format
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'imageUrl': imageUrl,
      'articleUrl': articleUrl,
      'publishedDate': publishedDate.toIso8601String(),
    };
  }
} 