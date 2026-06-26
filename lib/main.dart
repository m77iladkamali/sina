import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: "BNazanin",
      ),
      home: const WelcomePage(),
    );
  }
}

///
/// صفحه خوش آمدگویی
///
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const BrowserPage(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xff1565C0),
                Color(0xff0D47A1),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [

                const SizedBox(height: 35),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "به بخش مشاوره غیرحضوری سینا\nخوش آمدید",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black38,
                          offset: Offset(2, 2),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 20,
                        spreadRadius: 2,
                        color: Colors.black26,
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Image.asset(
                      "assets/images/sina.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const Spacer(),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "اینجا محیطی امن و راحت\nبرای یاری شماست",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
///
/// مرورگر
///
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? controller;

  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (controller != null && await controller!.canGoBack()) {
          controller!.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF00897B),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },

                initialUrlRequest: URLRequest(
                  url: WebUri(
                    "https://www.sinapsycho.com/consultAndroid/index",
                  ),
                ),

                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  supportZoom: false,
                  allowsInlineMediaPlayback: true,
                  mediaPlaybackRequiresUserGesture: false,
                  thirdPartyCookiesEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  transparentBackground: true,
                  useHybridComposition: true,
                  disableContextMenu: false,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  userAgent:
                      "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36",
                ),

                onWebViewCreated: (c) {
                  controller = c;
                },

                onProgressChanged: (controller, p) {
                  setState(() {
                    progress = p / 100;
                  });
                },

                onLoadStop: (controller, url) async {
                  setState(() {
                    progress = 1;
                  });
                },

                onReceivedError: (controller, request, error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error.description),
                    ),
                  );
                },

                shouldOverrideUrlLoading:
                    (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
              ),

              if (progress < 1)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
