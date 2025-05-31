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
  WebViewController? _controller;
  bool _isFirstLoad = true;
  bool _isLoading = true;
  bool _isControllerInitialized = false;
  bool _isStyleApplied = false;
  static const platform = MethodChannel('com.kncc.newsroom/widget');
  DateTime? _lastFetchTime;
  bool _canGoBack = false;
  bool _isLoadMoreOperation = false;
  String _currentListUrl = 'https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C';
  
  // Store pending URL to load from widget clicks
  String? _pendingArticleUrl;
  // SharedPreferences instance for persistent storage
  SharedPreferences? _prefs;
  // Key for storing the pending URL
  static const String _pendingUrlKey = 'pending_article_url';

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoading = true;
      _isControllerInitialized = false;
      _isStyleApplied = false;
    });
    
    // Initialize both the WebView and SharedPreferences
    _initializeSharedPreferences();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
      _setupMethodChannel();
      
      // Safety check timeout
      Future.delayed(const Duration(seconds: 15), () {
        if (_isLoading) {
          print("Emergency timeout reached - forcing content display");
          _forceDisplayContent();
        }
      });
    });
  }

  Future<void> _initializeSharedPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      // Check if there's a stored pending URL from a previous widget click
      final storedUrl = _prefs?.getString(_pendingUrlKey);
      if (storedUrl != null && storedUrl.isNotEmpty) {
        print('Found stored pending URL: $storedUrl');
        setState(() {
          _pendingArticleUrl = storedUrl;
        });
      }
    } catch (e) {
      print('Error initializing SharedPreferences: $e');
    }
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'updateArticleUrl') {
        final String url = call.arguments as String;
        print('Received new article URL via method channel: $url');
        
        // Store the URL in SharedPreferences for persistence across app restarts
        await _prefs?.setString(_pendingUrlKey, url);
        
        // Set the pending URL
        setState(() {
          _pendingArticleUrl = url;
          _isLoading = true;
        });
        
        // Only load the URL if controller is already initialized
        if (_isControllerInitialized && _controller != null) {
          print('Controller is initialized, loading URL immediately: $url');
          await _loadUrl(url);
        } else {
          print('Controller not initialized yet, URL will be loaded when ready');
        }
      }
    });
  }

  void _initializeWebView() {
    try {
      final controller = WebViewController();
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1')
        ..setBackgroundColor(const Color(0xFFF5F5F5))
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: (JavaScriptMessage message) {
            print('Received message from JavaScript: ${message.message}');
            if (message.message == 'loadMoreClicked') {
              print('Load More button was clicked');
              _isLoadMoreOperation = true;
            } else if (message.message == 'loadMoreCompleted') {
              print('Load More operation completed');
              if (_isLoadMoreOperation) {
                _clearWebViewHistory();
                _isLoadMoreOperation = false;
              }
            } else if (message.message == 'transformationComplete') {
              setState(() {
                _isLoading = false;
                _isStyleApplied = true;
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
              
              controller.runJavaScript("if(!window.location.href.includes('page=')) { sessionStorage.removeItem('isLoadMoreOperation'); }");
              
              _updateCanGoBack();
            },
            onPageStarted: (String url) {
              print('Page started loading: $url');
              setState(() {
                _isStyleApplied = false;
                _isLoading = true;
              });
              
              _applyInitialStyles();
              
              _updateCanGoBack();
            },
            onPageFinished: (String url) async {
              print('Page finished loading: $url');
              
              _injectCustomCSS();
              
              if (!_isFirstLoad) {
                final now = DateTime.now();
                if (_lastFetchTime == null || 
                    now.difference(_lastFetchTime!).inMinutes >= 5) {
                  if (!mounted) return;
                  context.read<NewsViewModel>().refreshArticles();
                  _lastFetchTime = now;
                }
              }
              _isFirstLoad = false;
              
              if (_isNewsListPage(url)) {
                setState(() {
                  _currentListUrl = url;
                  print('Updated _currentListUrl to: $_currentListUrl');
                });
              }
              
              if (_controller != null) {
                await _controller!.runJavaScript('''
                  (function() {
                    try {
                      const content = document.getElementById('content');
                      if (content) content.style.opacity = '1';
                      
                      if (${_isArticlePage(url)}) {
                        console.log('Article page detected - scrolling to top');
                        window.scrollTo(0, 0);
                      } else {
                        console.log('List page - preserving scroll position');
                      }
                    } catch (e) {
                      console.error('Error ensuring content visibility:', e);
                    }
                  })();
                ''');
              }
              
              _forceDisplayContent(url);
              
              _updateCanGoBack();
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
        _controller = controller;
        _isControllerInitialized = true;
        print("WebViewController successfully initialized");
      });
      
      // Now that controller is initialized, handle initial URL loading
      _handleInitialUrlLoading();
    } catch (e) {
      print("Error initializing WebViewController: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New method to handle initial URL loading with proper sequencing
  Future<void> _handleInitialUrlLoading() async {
    try {
      print('Handling initial URL loading');
      
      // Clear the initialization flag for proper scrolling behavior
      if (_controller != null) {
        await _controller!.runJavaScript('sessionStorage.removeItem("appInitialized")');
      }
      
      // Three possible cases in order of priority:
      // 1. Pending URL from method channel during this session
      // 2. Stored URL from SharedPreferences (from previous widget click)
      // 3. Initial URL from platform method channel (from current launch intent)
      // 4. Default newsroom URL
      
      if (_pendingArticleUrl != null && _pendingArticleUrl!.isNotEmpty) {
        print('Loading pending URL from current session: $_pendingArticleUrl');
        await _loadUrl(_pendingArticleUrl!);
        // Clear the pending URL after loading
        _pendingArticleUrl = null;
        await _prefs?.remove(_pendingUrlKey);
      } else {
        // Check if there's an initial URL from the launch intent
        final String? articleUrl = await platform.invokeMethod('getInitialArticleUrl');
        print('Checking for initial article URL from intent: $articleUrl');
        
        if (articleUrl != null && articleUrl.isNotEmpty) {
          print('Loading article URL from launch intent: $articleUrl');
          await _loadUrl(articleUrl);
        } else {
          print('Loading default newsroom URL');
          await _loadUrl('https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C');
        }
      }
    } catch (e) {
      print('Error in _handleInitialUrlLoading: $e');
      // Fallback to default URL if anything fails
      if (_controller != null) {
        await _loadUrl('https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C');
      }
    }
  }

  // Centralized URL loading function with proper error handling
  Future<void> _loadUrl(String url) async {
    if (_controller == null) {
      print('Cannot load URL: WebViewController is null');
      // Store the URL to be loaded when controller is initialized
      setState(() {
        _pendingArticleUrl = url;
        _isLoading = true;
      });
      // Persist the URL
      await _prefs?.setString(_pendingUrlKey, url);
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
        _isStyleApplied = false;
      });
      
      print('Loading URL: $url');
      await _controller!.loadRequest(Uri.parse(url));
      
      // Clear the pending URL from SharedPreferences after successful load
      await _prefs?.remove(_pendingUrlKey);
    } catch (e) {
      print('Error loading URL $url: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update the home page navigation to use the centralized URL loading
  Future<void> _goToHomePage() async {
    try {
      print('Navigating back to last list page: $_currentListUrl');
      await _loadUrl(_currentListUrl);
    } catch (e) {
      print('Error navigating to home page: $e');
    }
  }

  Future<void> _applyInitialStyles() async {
    if (_controller == null) return;
    
    try {
      await _controller!.runJavaScript('''
        (function() {
          const initialStyle = document.createElement('style');
          initialStyle.textContent = `
            /* Hide all headers, navigation, footer immediately */
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
            
            /* Set initial body styles to ensure correct positioning */
            body {
              margin: 0 !important;
              padding: 0 !important;
              position: relative !important;
              top: 0 !important;
            }
            
            /* Make content visible immediately but hidden until fully styled */
            #content {
              padding-top: 0 !important;
              margin-top: 0 !important;
              opacity: 0;
              transition: opacity 0.2s ease;
            }
          `;
          
          (document.head || document.documentElement).appendChild(initialStyle);
        })();
      ''');
    } catch (e) {
      print('Error applying initial styles: $e');
    }
  }

  Future<void> _injectCustomCSS() async {
    if (_controller == null) return;
    
    final String javascript = r'''
      (function() {
        console.log("Applying full styling with enhanced button");
        
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
            margin: 0 !important;
            padding: 0 !important;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f9f9f9;
            pointer-events: auto !important;
            position: relative !important;
            top: 0 !important;
          }
          
          /* Content area styling */
          #content {
            padding-top: 0 !important;
            margin-top: 0 !important;
            pointer-events: auto !important;
            opacity: 1;
          }
          
          /* News releases header styling - keep original spacing */
          #news-releases-header {
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
          }
          
          #news-releases-header h1 {
            margin: 0;
            padding: 0;
            color: #333;
          }
          
          /* Make date text pink */
          .date-line, .date-line span, .date, .date span {
            color: #c2356e !important;
            font-weight: 500 !important;
          }
          
          /* Article date styling for article detail pages */
          .article-content .date-line, 
          .article-content time, 
          .article-header time,
          .article-header .date {
            color: #c2356e !important;
            font-weight: 500 !important;
            font-size: 0.9em !important;
          }
          
          /* Hide the year dropdown completely */
          .submenus-holder,
          .submenu.year-select-menu,
          .submenu-trigger,
          .year-select-menu-wrap {
            display: none !important;
            height: 0 !important;
            visibility: hidden !important;
            margin: 0 !important;
            padding: 0 !important;
          }
          
          /* Enhanced Load More button styling while keeping original color */
          .news-releases-load-more {
            display: inline-block;
            padding: 12px 28px !important;
            font-size: 16px;
            font-weight: 600 !important;
            background-color: #c2356e;
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
          
          /* Ensure all elements are clickable */
          * {
            pointer-events: auto !important;
          }
        `;
        document.head.appendChild(hideStyle);
        
        const yearSelectors = document.querySelectorAll('.submenus-holder, .submenu.year-select-menu, .submenu-trigger, .year-select-menu-wrap');
        yearSelectors.forEach(element => {
          if (element) {
            element.style.display = 'none';
            element.style.height = '0';
            element.style.visibility = 'hidden';
          }
        });
        
        document.body.style.opacity = '1';
        document.body.style.pointerEvents = 'auto';
        document.body.style.visibility = 'visible';
        document.body.style.marginTop = '0';
        
        const overlays = document.querySelectorAll('#loading-overlay');
        overlays.forEach(overlay => overlay.remove());
        
        if (!sessionStorage.getItem('appInitialized')) {
          console.log('First app load: Scrolling to top');
          window.scrollTo(0, 0);
          sessionStorage.setItem('appInitialized', 'true');
        } else {
          console.log('Not first load, preserving scroll position');
        }
        
        function setupLoadMoreButton() {
          const loadMoreButton = document.querySelector('.news-releases-load-more');
          if (loadMoreButton && !loadMoreButton.hasAttribute('data-handler-attached')) {
            loadMoreButton.setAttribute('data-handler-attached', 'true');
            
            const originalClick = loadMoreButton.onclick;
            loadMoreButton.onclick = function(e) {
              if (this.classList.contains('loading')) {
                return false;
              }
              
              e.preventDefault();
              
              window.isLoadMoreClicked = true; 
              
              this.classList.add('loading');
              this.textContent = '로딩 중...';
              
              if (originalClick) {
                originalClick.call(this, e);
              }
              
              if (window.FlutterChannel) {
                window.FlutterChannel.postMessage('loadMoreClicked');
              }
              
              const resetButtonState = () => {
                console.log('[Load More Restore] Resetting button state');
                this.classList.remove('loading');
                this.textContent = '더 로드하기';
                
                window.isLoadMoreClicked = false;
                
                if (window.FlutterChannel) {
                  window.FlutterChannel.postMessage('loadMoreCompleted');
                }
              };
              
              const resultsContainer = document.querySelector('.results');
              if (resultsContainer) {
                const observer = new MutationObserver((mutations) => {
                  let hasNewContent = false;
                  mutations.forEach((mutation) => {
                    if (mutation.addedNodes.length > 0) {
                      hasNewContent = true;
                    }
                  });
                  
                  if (hasNewContent) {
                    console.log('[Load More Observer] New content detected');
                    setTimeout(() => {
                      resetButtonState();
                      observer.disconnect();
                    }, 100);
                  }
                });
                
                observer.observe(resultsContainer, { childList: true });
              }
              
              setTimeout(() => {
                if (window.isLoadMoreClicked) {
                  console.log('[Load More Timeout] Safety timeout reached - restoring state');
                  resetButtonState();
                }
              }, 8000);
              
              return false;
            };
          }
        }
        
        setupLoadMoreButton();
        
        const observer = new MutationObserver(() => {
          setupLoadMoreButton();
        });
        
        observer.observe(document.body, { 
          childList: true, 
          subtree: true 
        });
        
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage('transformationComplete');
        }
      })();
    ''';
    
    try {
      await _controller!.runJavaScript(javascript);
    } catch (e) {
      print("Error injecting styling: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceDisplayContent([String? url]) async {
    if (_controller == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      final currentUrl = url ?? (await _controller!.currentUrl() ?? '');
      final isArticle = _isArticlePage(currentUrl);
      
      await _controller!.runJavaScript('''
        (function() {
          console.log("Ensuring content is visible");
          
          document.body.style.position = "relative";
          document.body.style.top = "0";
          document.body.style.overflow = "";
          
          const content = document.getElementById('content');
          if (content) {
            content.style.position = "relative";
            content.style.top = "0";
            content.style.paddingTop = "0";
            content.style.marginTop = "0";
            content.style.opacity = "1"; 
          }
          
          console.log("[_forceDisplayContent] Ensured basic positioning and visibility");
          
          const overlay = document.getElementById('loading-overlay');
          if (overlay) overlay.remove();
          
          document.body.style.pointerEvents = "auto";
          document.body.style.visibility = "visible";
          
          if (${isArticle}) {
            console.log("[_forceDisplayContent] Article page - forcing scroll to top");
            window.scrollTo(0, 0);
          } else {
            console.log("[_forceDisplayContent] List page - preserving scroll position");
          }
          
          if (document.body.style.opacity !== '1') {
            setTimeout(() => {
              document.body.style.opacity = "1";
            }, 50);
          }
          
          setTimeout(() => {
            if (window.FlutterChannel) {
              window.FlutterChannel.postMessage('transformationComplete');
            }
          }, 100);
        })();
      ''');
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print("Error in force display content: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isNewsListPage(String url) {
    return url.contains('/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C') && 
           !url.contains('/article/');
  }

  bool _isArticlePage(String url) {
    return url.contains('/article/');
  }

  Future<void> _updateButtonVisibility() async {
    if (_controller == null) return;
    
    try {
      final currentUrl = await _controller!.currentUrl();
      final isMainPage = _isNewsListPage(currentUrl ?? '');
      
      setState(() {
        _canGoBack = !isMainPage;
      });
    } catch (e) {
      print('Error checking current URL: $e');
      setState(() {
        _canGoBack = false;
      });
    }
  }

  Future<void> _clearWebViewHistory() async {
    if (_controller == null) return;
    
    try {
      await _controller!.runJavaScript('''
        window.history.pushState(null, "", window.location.href);
        window.history.replaceState(null, "", window.location.href);
      ''');
      
      await _updateButtonVisibility();
    } catch (e) {
      print('Error clearing WebView history: $e');
    }
  }

  Future<void> _updateCanGoBack() async {
    await _updateButtonVisibility();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _goToHomePage();
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (_isControllerInitialized && _controller != null)
              Opacity(
                opacity: _isStyleApplied ? 1.0 : 0.0,
                child: WebViewWidget(controller: _controller!),
              ),
            
            if (_isLoading || !_isStyleApplied || !_isControllerInitialized)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFC2356E)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        !_isControllerInitialized
                            ? '초기화 중...'
                            : '콘텐츠를 준비하는 중...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
          
        floatingActionButton: _canGoBack 
          ? Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: FloatingActionButton(
                onPressed: _goToHomePage,
                backgroundColor: const Color(0xFFC2356E),
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: const Icon(
                  Icons.list,
                  color: Colors.white,
                ),
              ),
            )
          : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }

  @override
  void dispose() {
    // Clean up resources
    _controller = null;
    super.dispose();
  }
}
