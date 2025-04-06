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
  bool _canGoBack = false;
  bool _isLoadMoreOperation = false;
  String _currentListUrl = 'https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C'; // Store the current list URL

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
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1')
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('Received message from JavaScript: ${message.message}');
          if (message.message == 'loadMoreClicked') {
            print('Load More button was clicked');
            // We'll need to clear history after load more is clicked
            _isLoadMoreOperation = true;
          } else if (message.message == 'loadMoreCompleted') {
            print('Load More operation completed');
            // Now it's safe to clear history
            if (_isLoadMoreOperation) {
              _clearWebViewHistory();
              _isLoadMoreOperation = false;
            }
          } else if (message.message == 'transformationComplete') {
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
            
            // If URL completely changes (not from "Load More"), clear the flag
            controller.runJavaScript("if(!window.location.href.includes('page=')) { sessionStorage.removeItem('isLoadMoreOperation'); }");
            
            // Update back button state
            _updateCanGoBack();
          },
          onPageStarted: (String url) {
            print('Page started loading: $url');
            // Apply basic hiding styles immediately
            _applyInitialStyles();
            // Update back button state
            _updateCanGoBack();
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            
            // Apply the complete styling to all pages
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
            
            // Update the stored list URL if this is a list page
            if (_isNewsListPage(url)) {
              setState(() {
                _currentListUrl = url;
                print('Updated _currentListUrl to: $_currentListUrl');
              });
            }
            
            // Ensure content is visible after styling
            controller.runJavaScript('''
              (function() {
                try {
                  const content = document.getElementById('content');
                  if (content) content.style.opacity = '1';
                } catch (e) {
                  console.error('Error ensuring content visibility:', e);
                }
              })();
            ''');
            
            // Force display content (now primarily ensures visibility)
            _forceDisplayContent();
            
            // Update back button state
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
      _isControllerInitialized = true;
    });
    
    _loadInitialUrl();
  }

  Future<void> _applyInitialStyles() async {
    try {
      await controller.runJavaScript('''
        (function() {
          // Create a style element to hide unwanted content immediately
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
          
          // Immediately append the style to the head (or create a head if needed)
          (document.head || document.documentElement).appendChild(initialStyle);
        })();
      ''');
    } catch (e) {
      print('Error applying initial styles: $e');
    }
  }

  Future<void> _injectCustomCSS() async {
    final String javascript = r'''
      (function() {
        console.log("Applying full styling with enhanced button");
        
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
          
          /* Add more space above the year dropdown */
          .submenus-holder {
            display: block !important;
            text-align: right;
            margin-top: 50px !important;
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
        
        // Scroll to top only if this is the app launch (first page load)
        // We detect this using URL or a flag stored in sessionStorage
        if (!sessionStorage.getItem('appInitialized')) {
          console.log('First app load: Scrolling to top');
          window.scrollTo(0, 0);
          sessionStorage.setItem('appInitialized', 'true');
        } else {
          console.log('Not first load, preserving scroll position');
        }
        
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
              
              // Prevent default behavior (stops navigation/history change)
              e.preventDefault();
              
              // Mark this as a Load More operation (though we won't use it for scrolling)
              window.isLoadMoreClicked = true; 
              
              // Apply loading state
              this.classList.add('loading');
              this.textContent = '로딩 중...'; // "Loading..." in Korean
              
              // Call the original click handler to fetch content
              if (originalClick) {
                originalClick.call(this, e);
              }
              
              // Notify Flutter that "Load More" was clicked
              if (window.FlutterChannel) {
                window.FlutterChannel.postMessage('loadMoreClicked');
              }
              
              // Function to simply reset the button state
              const resetButtonState = () => {
                console.log('[Load More Restore] Resetting button state');
                this.classList.remove('loading');
                this.textContent = '더 로드하기'; // Restore to "Load More" text
                
                // Clear the flag
                window.isLoadMoreClicked = false;
                
                // Notify Flutter
                if (window.FlutterChannel) {
                  window.FlutterChannel.postMessage('loadMoreCompleted');
                }
              };
              
              // Watch for new content being added using a simple observer
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
                    // Use a short delay to ensure DOM is stable before restoring
                    setTimeout(() => {
                      resetButtonState();
                      observer.disconnect(); // Stop observing
                    }, 100); // Small delay
                  }
                });
                
                // Start observing the results container for direct children additions
                observer.observe(resultsContainer, { childList: true });
              }
              
              // Safety timeout to restore state if observer fails
              setTimeout(() => {
                if (window.isLoadMoreClicked) { // Check flag again in case it was already restored
                  console.log('[Load More Timeout] Safety timeout reached - restoring state');
                  resetButtonState();
                }
              }, 5000); // Restore after 5 seconds if stuck
              
              return false;  // Prevent default behavior
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

  // Helper method to force content to display when things go wrong
  Future<void> _forceDisplayContent() async {
    try {
      await controller.runJavaScript('''
        (function() {
          console.log("Ensuring content is visible");
          
          // This function's main role is to ensure visibility and correct basic styling
          
          // Ensure basic positioning is correct
          document.body.style.position = "relative";
          document.body.style.top = "0";
          document.body.style.overflow = "";
          
          const content = document.getElementById('content');
          if (content) {
            content.style.position = "relative";
            content.style.top = "0";
            content.style.paddingTop = "0";
            content.style.marginTop = "0";
            // Ensure opacity is set for visibility
            content.style.opacity = "1"; 
          }
          
          console.log("[_forceDisplayContent] Ensured basic positioning and visibility");
          
          // Remove any potential lingering overlays
          const overlay = document.getElementById('loading-overlay');
          if (overlay) overlay.remove();
          
          // Make the page interactive and visible
          document.body.style.pointerEvents = "auto";
          document.body.style.visibility = "visible";
          
          // Fade in the body (if not already visible)
          if (document.body.style.opacity !== '1') {
            setTimeout(() => {
              document.body.style.opacity = "1";
            }, 50);
          }
          
          // Signal that transformation is complete
          setTimeout(() => {
            if (window.FlutterChannel) {
              window.FlutterChannel.postMessage('transformationComplete');
            }
          }, 100);
        })();
      ''');
      
      // Add a slight delay before removing the loading overlay
      // This ensures the webpage is fully visible before removing our overlay
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print("Error in force display content: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to check if the URL is a news list page (main or year-specific)
  bool _isNewsListPage(String url) {
    // List pages contain the base path but not '/article/'
    return url.contains('/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C') && 
           !url.contains('/article/');
  }

  // Navigate to the home page
  Future<void> _goToHomePage() async {
    try {
      print('Navigating back to last list page: $_currentListUrl');
      setState(() {
        _isLoading = true; // Show loading indicator during navigation
      });
      // Load the stored list URL instead of the default one
      await controller.loadRequest(
        Uri.parse(_currentListUrl),
      );
    } catch (e) {
      print('Error navigating to home page: $e');
    }
  }

  // Update to check if we should show the home button
  Future<void> _updateButtonVisibility() async {
    try {
      final currentUrl = await controller.currentUrl();
      final isMainPage = _isNewsListPage(currentUrl ?? '');
      
      setState(() {
        // Show home button on all pages except the main news list page
        _canGoBack = !isMainPage;
      });
    } catch (e) {
      print('Error checking current URL: $e');
      setState(() {
        _canGoBack = false;
      });
    }
  }

  // Clear WebView navigation history
  Future<void> _clearWebViewHistory() async {
    try {
      // Use JavaScript to clear the history
      await controller.runJavaScript('''
        window.history.pushState(null, "", window.location.href);
        window.history.replaceState(null, "", window.location.href);
      ''');
      
      // Update button visibility
      await _updateButtonVisibility();
    } catch (e) {
      print('Error clearing WebView history: $e');
    }
  }

  Future<void> _updateCanGoBack() async {
    // Replace this method with the new button visibility check
    await _updateButtonVisibility();
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
      
      // Clear the initialization flag to ensure proper scrolling behavior
      await controller.runJavaScript('sessionStorage.removeItem("appInitialized")');
      
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        // Navigate to home page instead of going back
        await _goToHomePage();
      },
      child: Scaffold(
        body: _isControllerInitialized 
          ? WebViewWidget(controller: controller)
          : const Center(child: Text('초기화 중...')), // "Initializing..." in Korean
          
        // Change FAB to a home button
        floatingActionButton: _canGoBack 
          ? Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: FloatingActionButton(
                onPressed: _goToHomePage,
                backgroundColor: const Color(0xFFC2356E), // Match with the "Load More" button color
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
    // Clean up any resources if needed
    super.dispose();
  }
}
