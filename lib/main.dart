import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF00897B),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مشاور همراه سینا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
          ),
        );

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WebViewScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00897B), Color(0xFF00695C), Color(0xFF004D40)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.4 * 255).toInt()),
                          blurRadius: 30,
                          spreadRadius: 8,
                          offset: const Offset(0, 15),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withAlpha((0.3 * 255).toInt()),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/sina.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.teal[200],
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'مشاور همراه سینا',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'همراه شما در مسیر آرامش و رشد روانی',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withAlpha((0.95 * 255).toInt()),
                          letterSpacing: 0.5,
                          height: 1.5,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                Column(
                  children: [
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'در حال بارگذاری...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha((0.8 * 255).toInt()),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

void _initializeWebView() {
  _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (WebResourceError error) {
          setState(() {
            _hasError = true;
            _errorMessage =
                '${error.errorCode}\n${error.description}\n${error.errorType}';
            _isLoading = false;
          });
        },
      ),
    )
    ..loadHtmlString('''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Test</title>
</head>
<body>
<h1>Hello WebView</h1>
<p>Test OK</p>
</body>
</html>
''');
}
         
  void _optimizeForMobile() {
    // نمایش عکس مشاوران در جای درست - بدون تداخل با متن
    String optimizeJS = '''
      (function() {
        // تنظیم viewport
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
          meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes');
        } else {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
          document.head.appendChild(meta);
        }
        
        // CSS برای جایگذاری درست عکس‌ها
        var style = document.createElement('style');
        style.id = 'sina-show-images-only';
        style.textContent = `
          /* نمایش عکس‌های مشاوران */
          img[src*="GetPsychologistImageByPsychologistId"] {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            position: relative !important;
            float: none !important;
            clear: both !important;
            margin: 10px auto !important;
          }
        `;
        document.head.appendChild(style);
        
        // JavaScript برای نمایش عکس‌ها بدون تداخل
        function showImages() {
          var imgs = document.querySelectorAll('img[src*="GetPsychologistImageByPsychologistId"]');
          imgs.forEach(function(img) {
            // نمایش عکس
            img.style.display = 'block';
            img.style.visibility = 'visible';
            img.style.opacity = '1';
            img.style.position = 'relative';
            img.style.float = 'none';
            img.style.clear = 'both';
            img.style.margin = '10px auto';
            
            // حذف کلاس‌های مخفی‌کننده از والدین
            var parent = img.parentElement;
            for (var i = 0; i < 5 && parent && parent !== document.body; i++) {
              parent.classList.remove('d-none', 'd-sm-none', 'd-md-none', 'hidden-xs', 'hidden-sm', 'hidden-md');
              // حذف position: absolute که باعث تداخل میشه
              var pStyle = window.getComputedStyle(parent);
              if (pStyle.position === 'absolute') {
                parent.style.position = 'relative';
              }
              parent = parent.parentElement;
            }
          });
        }
        
        showImages();
        setTimeout(showImages, 500);
        setTimeout(showImages, 1000);
        setTimeout(showImages, 2000);
        
        var observer = new MutationObserver(function() {
          setTimeout(showImages, 100);
        });
        observer.observe(document.body, { childList: true, subtree: true });
      })();
    ''';
    _controller.runJavaScript(optimizeJS);
  }

  void _hideHeaderAndFooter() {
    String hideElementsJS = '''
(function() {
  // لیست کلمات برای مخفی‌سازی
  var keywords = [
    'ارتباط با ما',
    'درباره ما',
    'سایر بخش‌های موسسه',
    'سایر بخش های موسسه',
    'کروکی محل',
    'کروکی محل ما',
    'پیوندهای مفید',
    'پیوند های مفید',
    'بازی های شناختی',
    'بازی‌های شناختی',
    'هدایای سینا',
    'دریافت لیست محصولات',
    'دریافت لیست کامل محصولات',
    'راهنمای مشاورین',
    'راهنمای مراجعان',
    'درباره بخش مشاوره',
    'صفحه ورود',
    'سروش',
    'ایتا',
    'بله',
    'روبیکا',
    'ravantajhiz',
    'sp@sinapsycho.com',
    'انجمن صنفی',
    'سازمان نظام روان',
    'ستاد توسعه علوم',
    'آزمایشگاه ملی',
    'معاونت علمی',
    'پایگاه مجلات',
    'مرکز مالکیت معنوی'
  ];
  
  // مخفی کردن المان‌ها بر اساس متن - فقط لینک‌ها و آیتم‌های کوچک
  var allLinks = document.querySelectorAll('a');
  allLinks.forEach(function(el) {
    var text = (el.innerText || el.textContent || '').trim();
    for (var i = 0; i < keywords.length; i++) {
      if (text.indexOf(keywords[i]) !== -1) {
        el.style.cssText = 'display: none !important; visibility: hidden !important;';
        if (el.parentElement && el.parentElement.tagName === 'LI') {
          el.parentElement.style.cssText = 'display: none !important;';
        }
        break;
      }
    }
  });
  
  // مخفی کردن li ها
  var allLi = document.querySelectorAll('li');
  allLi.forEach(function(el) {
    var text = (el.innerText || el.textContent || '').trim();
    for (var i = 0; i < keywords.length; i++) {
      if (text === keywords[i] || (text.indexOf(keywords[i]) !== -1 && text.length < 100)) {
        el.style.cssText = 'display: none !important;';
        break;
      }
    }
  });
  
  // مخفی کردن span و div های کوچک
  var smallElements = document.querySelectorAll('span, div, p, td');
  smallElements.forEach(function(el) {
    var text = (el.innerText || el.textContent || '').trim();
    if (text.length < 50) {
      for (var i = 0; i < keywords.length; i++) {
        if (text.indexOf(keywords[i]) !== -1) {
          el.style.cssText = 'display: none !important;';
          break;
        }
      }
    }
  });
  
  // مخفی کردن لینک‌های خارجی با URL
  var externalSelectors = [
    'a[href*="pcoiran.ir"]',
    'a[href*="cogc.ir"]',
    'a[href*="nbml.ir"]',
    'a[href*="isti.ir"]',
    'a[href*="noormags.ir"]',
    'a[href*="iripo.ssaa.ir"]',
    'a[href*="splus.ir"]',
    'a[href*="eitaa.ir"]',
    'a[href*="rubika.ir"]',
    'a[href*="ble.ir"]',
    'a[href*="ble.com"]',
    'a[href*="eanjoman.ir"]',
    'a[href*="instagram"]',
    'a[href*="facebook"]',
    'a[href*="twitter"]',
    'a[href*="linkedin"]',
    'a[href*="youtube"]',
    'a[href*="telegram."]',
    'a[href*="whatsapp"]',
    'a[href*="aparat"]',
    'a[href*="mailto:sp@sinapsycho"]'
  ];
  
  externalSelectors.forEach(function(selector) {
    var elements = document.querySelectorAll(selector);
    elements.forEach(function(el) {
      el.style.cssText = 'display: none !important;';
      if (el.parentElement) {
        el.parentElement.style.cssText = 'display: none !important;';
      }
    });
  });
  
  // اضافه کردن CSS سراسری
  var style = document.createElement('style');
  style.textContent = `
    a[href*="pcoiran.ir"], a[href*="cogc.ir"], a[href*="nbml.ir"], 
    a[href*="splus.ir"], a[href*="eitaa.ir"], a[href*="rubika.ir"], 
    a[href*="ble.ir"], a[href*="ble.com"], a[href*="eanjoman.ir"],
    a[href*="instagram"], a[href*="facebook"], a[href*="telegram."],
    a[href*="whatsapp"], a[href*="aparat"], a[href*="twitter"],
    a[href*="mailto:sp@sinapsycho"] { 
      display: none !important; 
    }
  `;
  document.head.appendChild(style);
  
  // اجرای مجدد بعد از یک ثانیه برای المان‌های دیرتر لود شده
  setTimeout(function() {
    var allLinks2 = document.querySelectorAll('a');
    allLinks2.forEach(function(el) {
      var text = (el.innerText || el.textContent || '').trim();
      for (var i = 0; i < keywords.length; i++) {
        if (text.indexOf(keywords[i]) !== -1) {
          el.style.cssText = 'display: none !important;';
          if (el.parentElement && el.parentElement.tagName === 'LI') {
            el.parentElement.style.cssText = 'display: none !important;';
          }
          break;
        }
      }
    });
  }, 1000);
})();
''';
    _controller.runJavaScript(hideElementsJS);
  }

  void _retryLoading() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.reload();
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از برنامه'),
        content: const Text('آیا می‌خواهید از برنامه خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('خیر'),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('بله'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (await _controller.canGoBack()) {
            _controller.goBack();
          }
          // دکمه برگشت فقط به صفحه قبلی وب می‌رود، از برنامه خارج نمی‌شود
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'منو',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text(
            'مشاور همراه سینا',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'بارگذاری مجدد',
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: _progress > 0 && _progress < 1.0
                ? LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.teal[50],
                    color: const Color(0xFF00897B),
                    minHeight: 4,
                  )
                : const SizedBox(height: 4),
          ),
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF00897B),
                  child: const Column(
                    children: [
                      Icon(Icons.psychology, size: 60, color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'مشاور همراه سینا',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home, color: Color(0xFF00897B)),
                  title: const Text('صفحه اصلی'),
                  onTap: () {
                    Navigator.pop(context);
                    _controller.loadRequest(Uri.parse('https://www.sinapsycho.com/consult/index'));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Color(0xFF00897B)),
                  title: const Text('بارگذاری مجدد'),
                  onTap: () {
                    Navigator.pop(context);
                    _controller.reload();
                  },
                ),
                const Spacer(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('خروج', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showExitDialog();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (!_hasError) WebViewWidget(controller: _controller),
              if (_hasError) _buildErrorWidget(),
              if (_isLoading && !_hasError)
                Container(
                  color: Colors.white.withOpacity(0.8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Color(0xFF00897B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'در حال بارگذاری...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha((0.1 * 255).toInt()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'خطا در برقراری ارتباط',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'متاسفانه در بارگذاری صفحه خرابی پیش آمد. لطفاً اینترنت خود را بررسی کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _retryLoading,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
