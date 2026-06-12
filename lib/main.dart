import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebScreen(),
    );
  }
}

class WebScreen extends StatefulWidget {
  const WebScreen({super.key});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  InAppWebViewController? controller;

  bool loading = true;
  bool error = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (controller != null) {
          if (await controller!.canGoBack()) {
            controller!.goBack();
            return false;
          }
        }
        return false; // ❌ خروج از اپ ممنوع
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF00897B),
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

            // 🌐 WEBVIEW
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://www.sinapsycho.com/consult/index"),
              ),

              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useHybridComposition: true,
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
              ),

              onWebViewCreated: (c) {
                controller = c;
              },

              onLoadStart: (c, url) {
                setState(() {
                  loading = true;
                  error = false;
                });
              },

              onLoadStop: (c, url) async {
                setState(() {
                  loading = false;
                });
              },

              onLoadError: (c, url, code, message) {
                setState(() {
                  loading = false;
                  error = true;
                });
              },
            ),

            // 🟢 صفحه برند (بدون دایره لودینگ)
            AnimatedOpacity(
              opacity: loading ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                color: const Color(0xFF00897B),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology, size: 90, color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        "مشاور همراه سینا",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "در حال اتصال...",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ❌ صفحه خطا
            if (error)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Text(
                    "خطا در ارتباط با سرور",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
