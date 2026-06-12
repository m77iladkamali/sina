import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
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

  bool loading = true;
  bool error = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      // مهم‌ترین بخش bypass
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36",
      )

      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              loading = true;
              error = false;
            });
          },
          onPageFinished: (url) {
            setState(() {
              loading = false;
            });

            _injectFixes();
          },
          onWebResourceError: (e) {
            setState(() {
              error = true;
              loading = false;
            });
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )

      // مهم: cookie + localStorage
      ..enableZoom(true)
      ..loadRequest(Uri.parse("https://www.sinapsycho.com/consult/index"));
  }

  void _injectFixes() {
    const js = """
      (function () {
        // رفع viewport
        var meta = document.querySelector('meta[name=viewport]');
        if (!meta) {
          meta = document.createElement('meta');
          document.head.appendChild(meta);
        }
        meta.content = "width=device-width, initial-scale=1.0";

        // اجازه اجرای iframe ها
        var iframes = document.querySelectorAll('iframe');
        iframes.forEach(function(i){
          i.style.display = "block";
        });

        // حذف overlay های بلاک کننده
        document.querySelectorAll('*').forEach(function(el){
          if (el.style && (el.style.position === 'fixed')) {
            el.style.pointerEvents = 'auto';
          }
        });
      })();
    """;

    _controller.runJavaScript(js);
  }

  void _retry() {
    setState(() {
      loading = true;
      error = false;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WebView"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (loading)
            const Center(child: CircularProgressIndicator()),

          if (error)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("خطا در لود"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text("تلاش مجدد"),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
