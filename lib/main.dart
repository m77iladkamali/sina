import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';

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

  final url = Uri.parse("https://www.sinapsycho.com/consult/index");

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (controller != null) {
          bool canBack = await controller!.canGoBack();
          if (canBack) {
            controller!.goBack();
            return false;
          }
        }
        return false; // ❌ خروج از برنامه ممنوع
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF00897B),
          title: const Text("مشاور همراه سینا"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                controller?.reload();
              },
            )
          ],
        ),

        body: Stack(
          children: [

            // 🌐 WEB
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(url)),

              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                supportZoom: true,
                useHybridComposition: true,
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
                  error = true;
                  loading = false;
                });
              },

              shouldOverrideUrlLoading: (controller, nav) async {
                return NavigationActionPolicy.ALLOW;
              },
            ),

            // 🔄 LOADING
            if (loading)
              const Center(
                child: CircularProgressIndicator(),
              ),

            // ❌ ERROR SCREEN
            if (error)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 60, color: Colors.red),
                    const SizedBox(height: 10),
                    const Text("ارتباط قطع شد"),
                    ElevatedButton(
                      onPressed: () {
                        controller?.reload();
                      },
                      child: const Text("تلاش مجدد"),
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
