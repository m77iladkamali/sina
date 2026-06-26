import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
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
        useMaterial3: true,
        fontFamily: "Far_Homa",
      ),
      home: const WelcomePage(),
    );
  }
}

//////////////////////////////////////////////////////////
/// صفحه خوش آمدگویی
//////////////////////////////////////////////////////////

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  late Animation<double> _fade;

  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scale = Tween<double>(
      begin: .85,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    Future.delayed(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration:
                const Duration(milliseconds: 700),
            pageBuilder: (_, animation, __) =>
                const BrowserPage(),
            transitionsBuilder:
                (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
    );
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

          child: FadeTransition(

            opacity: _fade,

            child: ScaleTransition(

              scale: _scale,

              child: Column(

                children: [

                  const SizedBox(height: 35),

                  const Padding(

                    padding: EdgeInsets.symmetric(horizontal: 20),

                    child: Text(

                      "به بخش مشاوره غیرحضوری سینا\n.خوش آمدید",

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 30,

                        fontWeight: FontWeight.bold,

                        height: 1.3,

                        shadows: [

                          Shadow(

                            blurRadius: 10,

                            color: Colors.black38,

                            offset: Offset(2,2),

                          ),

                        ],

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),
                                    ScaleTransition(

                    scale: _scale,
child: Container(
  width: 300,
  height: 300,
  decoration: BoxDecoration(
    color: Colors.white,
    shape: BoxShape.circle,
    boxShadow: const [
      BoxShadow(
        color: Colors.black26,
        blurRadius: 20,
        spreadRadius: 2,
        offset: Offset(0, 8),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Image.asset(
      "assets/images/sina.png",
      fit: BoxFit.contain,
    ),
  ),
),

                  ),

                  const Spacer(),

                  const Padding(

                    padding: EdgeInsets.symmetric(horizontal: 20),

                    child: Text(

                      "اینجا محیطی امن و راحت\n.برای یاری شماست",

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        fontSize: 26,

                        fontWeight: FontWeight.bold,

                        color: Colors.white,

                        height: 1.6,

                      ),

                    ),

                  ),

                  const SizedBox(height: 70),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}
//////////////////////////////////////////////////////////
/// Browser Page
//////////////////////////////////////////////////////////

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {

  InAppWebViewController? controller;

  double progress = 0;

  bool hasError = false;

  @override
  Widget build(BuildContext context) {

    return PopScope(

      canPop: false,

      onPopInvokedWithResult: (didPop, result) async {

        if (controller != null &&
            await controller!.canGoBack()) {

          controller!.goBack();

        } else {

          SystemNavigator.pop();

        }

      },

      child: Scaffold(

        backgroundColor: const Color(0xff1565C0),

        body: SafeArea(

          child: Stack(

            children: [

              if (!hasError)

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

                    useHybridComposition: true,

                    transparentBackground: true,

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

                  onProgressChanged:
                      (controller, value) {

                    setState(() {

                      progress = value / 100;

                    });

                  },

                  onLoadStart:
                      (controller, url) {

                    setState(() {

                      hasError = false;

                    });

                  },

                  onLoadStop:
                      (controller, url) async {

                    setState(() {

                      progress = 1;

                    });

                  },

                  shouldOverrideUrlLoading:
                      (controller, action) async {

                    return NavigationActionPolicy.ALLOW;

                  },

                  onReceivedError:
                      (controller, request, error) {

                    setState(() {

                      hasError = true;

                    });

                  },
                ),
                            if (hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 90,
                        ),

                        const SizedBox(height: 25),

                        const Text(
                          "اتصال اینترنت برقرار نیست",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          "لطفاً اتصال اینترنت خود را بررسی کنید.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 35),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff1565C0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 35,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              hasError = false;
                              progress = 0;
                            });

                            controller?.reload();
                          },
                          child: const Text(
                            "تلاش مجدد",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (progress < 1 && !hasError)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
