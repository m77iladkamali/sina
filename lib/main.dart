import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? controller;
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
            ),

            onWebViewCreated: (ctrl) {
              controller = ctrl;
            },

            onProgressChanged: (ctrl, p) {
              setState(() {
                progress = p / 100;
              });
            },

            onLoadStart: (ctrl, url) {},

            onLoadStop: (ctrl, url) {
              setState(() {
                progress = 0;
              });
            },

            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.ALLOW;
            },
          ),

          if (progress < 1.0)
            LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }
}
