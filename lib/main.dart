import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'viewmodels/news_viewmodel.dart';
import 'services/news_scraper_service.dart';
import 'services/storage_service.dart';
import 'services/background_service.dart';

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
      )
      ..loadRequest(
        Uri.parse('https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C'),
      );
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
