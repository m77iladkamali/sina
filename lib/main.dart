import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00897B),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
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
  InAppWebViewController? controller;

  bool isLoading = true;
  bool hasError = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (controller != null) {
          if (await controller!.canGoBack()) {
            controller!.goBack();
            return;
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("مشاور همراه سینا"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller?.reload(),
            )
          ],
        ),

        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://www.sinapsycho.com/consult/index"),
              ),

              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                userAgent:
                    "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Safari/537.36",
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                useHybridComposition: true,
              ),

              onWebViewCreated: (ctrl) {
                controller = ctrl;
              },

              onLoadStart: (controller, url) {
                setState(() {
                  isLoading = true;
                  hasError = false;
                });
              },

              onLoadStop: (controller, url) async {
                setState(() {
                  isLoading = false;
                });

                // optional JS tweaks
                await controller.evaluateJavascript(source: """
                  document.querySelectorAll('header, footer').forEach(e => e.remove());
                """);
              },

              onLoadError: (controller, url, code, message) {
                setState(() {
                  hasError = true;
                  isLoading = false;
                });
              },
            ),

            // Loading indicator
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00897B),
                ),
              ),

            // Error UI
            if (hasError)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 70, color: Colors.red),
                      SizedBox(height: 10),
                      Text(
                        "خطا در اتصال",
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
