import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مشاور همراه سینا',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      // مهم: بعضی سایت‌ها با موبایل بلاک می‌کنند
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36',
      )

      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      )

      ..loadRequest(
        Uri.parse('https://www.sinapsycho.com/consult/index'),
      );
  }

  Future<bool> _onWillPop() async {
    // ❌ خروج از برنامه ممنوع
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return false;
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مشاور همراه سینا'),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _retry,
            )
          ],
        ),

        body: Stack(
          children: [
            // WEBVIEW
            if (!_hasError)
              WebViewWidget(controller: _controller),

            // LOADING (خیلی ساده و بدون گیر)
            if (_isLoading && !_hasError)
              const Center(
                child: CircularProgressIndicator(),
              ),

            // ERROR SCREEN
            if (_hasError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 60, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'خطا در لود صفحه',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('تلاش مجدد'),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
