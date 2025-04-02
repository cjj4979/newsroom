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
  bool _isLoading = true;
  bool _isControllerInitialized = false;  // Track initialization state
  static const platform = MethodChannel('com.example.newsroom/widget');
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    // Delayed initialization to ensure the loading overlay is shown first
    Future.microtask(() {
      _initializeWebView();
      _setupMethodChannel();
      
      // Safety check: if content doesn't appear within 10 seconds, force it to be visible
      Future.delayed(const Duration(seconds: 10), () {
        if (_isLoading) {
          print("Emergency timeout reached - forcing content display");
          _forceDisplayContent();
        }
      });
    });
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'updateArticleUrl') {
        final String url = call.arguments as String;
        print('Received new article URL: $url');
        setState(() {
          _isLoading = true;  // Show loading overlay immediately
        });
        await controller.loadRequest(Uri.parse(url));
      }
    });
  }

  void _initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('Message from JavaScript: ${message.message}');
          if (message.message == 'transformationComplete') {
            setState(() {
              _isLoading = false;
            });
          } else if (message.message.startsWith('debug:')) {
            print('Debug from JavaScript: ${message.message.substring(6)}');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            print('URL changed to: ${change.url}');
          },
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            
            // Apply the same styling to all pages
            // We don't need separate styling for articles and lists anymore
            _injectCustomCSS();
            
            if (!_isFirstLoad) {
              final now = DateTime.now();
              if (_lastFetchTime == null || 
                  now.difference(_lastFetchTime!).inMinutes >= 5) {
                context.read<NewsViewModel>().refreshArticles();
                _lastFetchTime = now;
              }
            }
            _isFirstLoad = false;
            
            // Always force display content after page loads
            _forceDisplayContent();
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
            _forceDisplayContent();
          },
        ),
      );
    
    setState(() {
      _isControllerInitialized = true;
    });
    
    _loadInitialUrl();
  }

  Future<void> _injectCustomCSS() async {
    final String javascript = r'''
      (function() {
        console.log("Applying minimal styling with enhanced button");
        
        // Scroll to top when page loads
        window.scrollTo(0, 0);
        
        // Hide headers, footers, and navigation but keep the content structure
        const hideStyle = document.createElement('style');
        hideStyle.textContent = `
          /* Hide headers, footers, navigation, etc. */
          platform-header, #navigation, .navigation, platform-footer, footer, #footer,
          #drawer-whole, #language-select-list, #country-language-list, 
          .new-lang-list, .new-lang-list2, .new-lang-list3, 
          .nav-wrapper, #skipToMainContent, #lightningjs-usabilla_live,
          .search, .search-trigger, #yir-banner, div[data-render-view="navigation"], 
          div[data-render-view="header"], div[data-render-view="footer"], 
          section[data-render-view="header"], .consent-section, .modal-holder, 
          .international.language {
            display: none !important;
          }
          
          /* Basic body styling */
          body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f9f9f9;
            pointer-events: auto !important;
          }
          
          /* Content area styling */
          #content {
            padding-top: 0 !important;
            margin-top: 0 !important;
            pointer-events: auto !important;
          }
          
          /* Keep year dropdown visible */
          .submenus-holder {
            margin-bottom: 20px;
            text-align: right;
            display: block !important;
          }
          
          .year-select-menu, .submenu-trigger {
            display: block !important;
          }
          
          /* Enhanced Load More button styling while keeping original color */
          .news-releases-load-more {
            display: inline-block;
            padding: 12px 28px !important;
            font-size: 16px;
            font-weight: 600 !important;
            background-color: #c2356e; /* Original color */
            color: white;
            text-decoration: none;
            border-radius: 8px;
            border: none;
            margin: 28px 0;
            cursor: pointer;
            transition: all 0.2s ease;
            box-shadow: 0 2px 4px rgba(194, 53, 110, 0.3);
            min-width: 120px;
            max-width: 180px;
            text-align: center;
            letter-spacing: 0.3px;
            position: relative;
          }
          
          .news-releases-load-more:hover {
            background-color: #b02d60;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(194, 53, 110, 0.4);
          }
          
          .news-releases-load-more:active {
            transform: translateY(0);
            box-shadow: 0 1px 2px rgba(194, 53, 110, 0.3);
          }
          
          /* Disabled state */
          .news-releases-load-more.loading {
            background-color: #9e9e9e !important;
            color: rgba(255, 255, 255, 0.8);
            cursor: not-allowed !important;
            pointer-events: none !important;
            transform: none !important;
            box-shadow: none !important;
          }
          
          #full-fill {
            text-align: center;
            margin: 28px 0;
          }
          
          /* News releases header styling */
          #news-releases-header {
            margin-bottom: 20px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
          }
          
          #news-releases-header h1 {
            margin: 0;
            padding: 0;
            color: #333;
          }
          
          /* Ensure all elements are clickable */
          * {
            pointer-events: auto !important;
          }
        `;
        document.head.appendChild(hideStyle);
        
        // Make sure the page is interactive
        document.body.style.opacity = '1';
        document.body.style.pointerEvents = 'auto';
        document.body.style.visibility = 'visible';
        document.body.style.marginTop = '0';
        
        // Remove any overlays that might exist
        const overlays = document.querySelectorAll('#loading-overlay');
        overlays.forEach(overlay => overlay.remove());
        
        // Add click handling to the Load More button
        function setupLoadMoreButton() {
          const loadMoreButton = document.querySelector('.news-releases-load-more');
          if (loadMoreButton && !loadMoreButton.hasAttribute('data-handler-attached')) {
            loadMoreButton.setAttribute('data-handler-attached', 'true');
            
            const originalClick = loadMoreButton.onclick;
            loadMoreButton.onclick = function(e) {
              // If already loading, prevent additional clicks
              if (this.classList.contains('loading')) {
                return false;
              }
              
              // Apply loading state
              this.classList.add('loading');
              this.textContent = '로딩 중...'; // "Loading..." in Korean
              
              // Call original handler
              if (originalClick) {
                originalClick.call(this, e);
              }
              
              // Watch for new content being added
              const resultsContainer = document.querySelector('.results');
              if (resultsContainer) {
                const observer = new MutationObserver((mutations) => {
                  // If new content is added, enable the button
                  mutations.forEach((mutation) => {
                    if (mutation.addedNodes.length > 0) {
                      this.classList.remove('loading');
                      this.textContent = '더 로드하기'; // Restore original text
                      observer.disconnect(); // Stop observing once content is added
                    }
                  });
                });
                
                // Start observing the results container for added nodes
                observer.observe(resultsContainer, { childList: true });
              }
              
              // Safety timeout to reset button if loading takes too long
              setTimeout(() => {
                this.classList.remove('loading');
                this.textContent = '더 로드하기'; // Restore original text
              }, 10000);
              
              return true;
            };
          }
        }
        
        // Setup initially and also observe for future changes
        setupLoadMoreButton();
        
        // Create a MutationObserver to watch for DOM changes
        const observer = new MutationObserver(() => {
          setupLoadMoreButton();
        });
        
        observer.observe(document.body, { 
          childList: true, 
          subtree: true 
        });
        
        // Signal that styling is complete
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage('transformationComplete');
        }
        
        // Ensure page is scrolled to top after loading completes
        setTimeout(function() {
          window.scrollTo(0, 0);
        }, 100);
      })();
    ''';
    
    try {
      await controller.runJavaScript(javascript);
    } catch (e) {
      print("Error injecting styling: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _injectMinimalStyling() async {
    final String javascript = r'''
      (function() {
        console.log("Applying minimal styling to article page");
        
        try {
          // No overlays or spinners, just apply styling
          
          const articleStyle = document.createElement('style');
          articleStyle.textContent = `
            platform-header, #navigation, .navigation, .submenu-holder, 
            .submenus-holder, .search, .search-trigger, .modal-holder,
            #lightningjs-usabilla_live, div[data-render-view="navigation"], 
            div[data-render-view="header"], div[data-render-view="footer"],
            .consent-section {
              display: none !important;
            }
            
            platform-footer, footer, #footer {
              display: none !important;
            }
            
            body {
              margin: 0;
              padding: 0;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              overflow-x: hidden; /* Prevent horizontal scroll */
              pointer-events: auto !important;
              overflow-y: auto !important;
              opacity: 1 !important; /* Ensure the body is visible */
            }
            
            #content {
              margin-top: 0 !important;
              padding-top: 16px !important;
              pointer-events: auto !important;
              opacity: 1 !important;
              visibility: visible !important;
            }
            
            .news-article {
              padding: 16px;
              pointer-events: auto !important;
              opacity: 1 !important;
              visibility: visible !important;
            }
            
            img {
              max-width: 100%;
              height: auto;
            }
            
            /* Critical fix to ensure everything is clickable */
            html, body, * {
              pointer-events: auto !important;
            }
            
            /* Ensure the document is fully visible */
            html, body, #content, .news-article {
              opacity: 1 !important;
              visibility: visible !important;
            }
          `;
          document.head.appendChild(articleStyle);
          
          // Make page interactive immediately
          document.body.style.opacity = '1';
          document.body.style.pointerEvents = 'auto';
          document.body.style.visibility = 'visible';
          
          // Remove any leftover loading overlays
          const overlay = document.getElementById('loading-overlay');
          if (overlay) {
            overlay.remove();
          }
          
          const earlyBlocker = document.getElementById('early-blocker');
          if (earlyBlocker) {
            earlyBlocker.remove();
          }
          
          // Ensure all content is visible
          const importantElements = ['body', '#content', '.news-article', 'article'];
          importantElements.forEach(selector => {
            const elements = document.querySelectorAll(selector);
            elements.forEach(el => {
              if (el) {
                el.style.opacity = '1';
                el.style.visibility = 'visible';
                el.style.pointerEvents = 'auto';
                el.style.display = el.tagName.toLowerCase() === 'article' ? 'block' : el.style.display;
              }
            });
          });
          
          // Signal that the transformation is complete
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage('transformationComplete');
          }
          
          console.log("Article page styling complete");
        } catch (error) {
          console.error("Error styling article page:", error);
          // Ensure page is visible even if styling fails
          document.body.style.opacity = '1';
          document.body.style.visibility = 'visible';
          
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage('transformationComplete');
          }
        }
      })();
    ''';
    
    try {
      await controller.runJavaScript(javascript);
    } catch (e) {
      print("Error injecting minimal styling: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInitialUrl() async {
    try {
      // We'll apply our blocking strategy differently
      final String? articleUrl = await platform.invokeMethod('getInitialArticleUrl');
      print('Checking for initial article URL: $articleUrl');
      
      // Always show loading overlay while URLs are loading
      setState(() {
        _isLoading = true;
      });
      
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
      print('Error loading initial URL: $e');
      await controller.loadRequest(
        Uri.parse('https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C'),
      );
    }
  }

  bool _isMainNewsListPage(String url) {
    try {
      final Uri uri = Uri.parse(url);
      final String path = uri.path;
      
      if (path.contains('/news-releases/') || 
          path.contains('/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C/') ||
          path.contains('/보도-자료/')) {
        return false;
      }
      
      return (url.endsWith('%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C') || 
              url.endsWith('보도-자료') ||
              path.endsWith('/보도-자료') ||
              path == '/보도-자료/' ||
              path == '/news-releases' ||
              path == '/news-releases/' ||
              (uri.queryParameters.containsKey('year') && 
               (path.contains('보도-자료') || path.contains('news-releases'))));
    } catch (e) {
      print('Error parsing URL: $e');
      return false;
    }
  }

  // Helper method to force content to display when things go wrong
  Future<void> _forceDisplayContent() async {
    try {
      await controller.runJavaScript('''
        (function() {
          console.log("Ensuring content is visible");
          document.body.style.opacity = "1";
          document.body.style.visibility = "visible";
          document.body.style.pointerEvents = "auto";
          
          const overlay = document.getElementById('loading-overlay');
          if (overlay) overlay.remove();
          
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage('transformationComplete');
          }
        })();
      ''');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error in force display content: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Church Newsroom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              final mainUrl = 'https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C';
              print('Returning to main page: $mainUrl');
              
              try {
                await controller.loadRequest(Uri.parse(mainUrl));
              } catch (e) {
                print("Error navigating to home: $e");
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              print('Refreshing current page');
              
              try {
                await controller.reload();
              } catch (e) {
                print("Error refreshing: $e");
              }
            },
          ),
        ],
      ),
      body: _isControllerInitialized 
        ? WebViewWidget(controller: controller)
        : const Center(child: Text('초기화 중...')) // "Initializing..." in Korean
    );
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
