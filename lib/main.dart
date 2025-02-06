import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'viewmodels/news_viewmodel.dart';
import 'services/news_scraper_service.dart';
import 'services/storage_service.dart';
import 'services/background_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await BackgroundService.initialize();
  runApp(NewsroomApp(prefs: prefs));
}

class NewsroomApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const NewsroomApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NewsViewModel(
        scraperService: NewsScraperService(),
        storageService: StorageService(prefs),
      ),
      child: MaterialApp(
        title: 'Newsroom',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const NewsroomHomePage(),
      ),
    );
  }
}

class NewsroomHomePage extends StatefulWidget {
  const NewsroomHomePage({super.key});

  @override
  State<NewsroomHomePage> createState() => _NewsroomHomePageState();
}

class _NewsroomHomePageState extends State<NewsroomHomePage> {
  late final WebViewController controller;
  bool _isFirstLoad = true;
  static const platform = MethodChannel('com.example.newsroom/widget');

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Only refresh on subsequent loads, not the first one
            if (!_isFirstLoad) {
              context.read<NewsViewModel>().refreshArticles();
            }
            _isFirstLoad = false;
          },
        ),
      );
    
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      // Check if we were launched with an article URL
      final String? articleUrl = await platform.invokeMethod('getInitialArticleUrl');
      
      if (articleUrl != null && articleUrl.isNotEmpty) {
        print('Loading article URL from widget click: $articleUrl');
        await controller.loadRequest(Uri.parse(articleUrl));
      } else {
        print('Loading default newsroom URL');
        await controller.loadRequest(
          Uri.parse('https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C'),
        );
      }
    } catch (e) {
      print('Error initializing controller: $e');
      // Load default URL if there's an error
      await controller.loadRequest(
        Uri.parse('https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Church Newsroom'),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
