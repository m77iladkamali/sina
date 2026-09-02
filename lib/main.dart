import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
      theme: ThemeData(useMaterial3: true, fontFamily: "Far_Homa"),
      home: const WelcomePage(),
    );
  }
}

// ===== صفحه خوش‌آمدگویی (لوگو در وسط) =====
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _logoScale = Tween<double>(begin: .85, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, .55, curve: Curves.easeOutBack),
      ),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.35, 1, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.35, 1, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width * .55).clamp(200.0, 320.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff1976D2), Color(0xff0D47A1), Color(0xff0A3880)],
            stops: [0, .55, 1],
          ),
        ),
        child: Stack(
          children: [
            // تزئین: دایره‌های نرم پس‌زمینه برای عمق بیشتر
            Positioned(
              top: -60,
              right: -40,
              child: _glowCircle(180, Colors.white.withOpacity(.05)),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: _glowCircle(220, Colors.white.withOpacity(.04)),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "به بخش مشاوره غیر حضوری سینا\nخوش آمدید",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.25),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            "assets/images/sina.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          "برای بهتر شدن، خود را بهتر بشناسید",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: SizedBox(
                        width: 200,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff23C66F),
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: const Color(0xff23C66F).withOpacity(.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                                pageBuilder: (_, anim, __) =>
                                    const BrowserPage(),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("ورود", style: TextStyle(fontSize: 20)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ===== مرورگر با InAppWebView (بدون تغییر) =====
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  DateTime? _lastBackPressed;
  InAppWebViewController? controller;
  double progress = 0;
  bool hasInternet = true;
  late final StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final connected = !results.contains(ConnectivityResult.none);
      if (mounted) {
        setState(() => hasInternet = connected);
        if (connected) controller?.reload();
      }
    });
  }

  Future<void> _checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => hasInternet = !result.contains(ConnectivityResult.none));
    }
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (controller != null) {
      final canGoBack = await controller!.canGoBack();
      if (canGoBack) {
        await controller!.goBack();
        return false;
      }
    }

    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            ".برای خروج، دوباره دکمه بازگشت را بزنید",
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              if (hasInternet)
                InAppWebView(
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                    Factory<OneSequenceGestureRecognizer>(
                      () => TapGestureRecognizer()..onTap = () {},
                    ),
                  },
                  initialUrlRequest: URLRequest(
                    url: WebUri("https://www.sinapsycho.com/consultAndroid/index"),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    cacheEnabled: true,
                    supportZoom: false,
                    allowsInlineMediaPlayback: true,
                    mediaPlaybackRequiresUserGesture: false,
                    thirdPartyCookiesEnabled: true,
                    useHybridComposition: true,
                    transparentBackground: false,
                    disableContextMenu: true,
                    supportMultipleWindows: false,
                    javaScriptCanOpenWindowsAutomatically: true,
                    useShouldOverrideUrlLoading: false,
                  ),
                  onWebViewCreated: (c) async {
                    controller = c;
                    await c.setSettings(
                      settings: InAppWebViewSettings(
                        userAgent:
                            "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36",
                      ),
                    );
                  },
                  onLoadStart: (controller, url) {
                    if (!mounted) return;
                    setState(() => progress = 0);
                  },
                  onProgressChanged: (controller, value) {
                    if (!mounted) return;
                    setState(() => progress = value / 100);
                  },
                  onLoadStop: (controller, url) async {
                    await controller.evaluateJavascript(source: """
                      document.querySelectorAll('a,button').forEach(function(e){
                        if(e.innerText.trim().includes('بازگشت')){
                          e.onclick = function(event){
                            event.preventDefault();
                            window.location.href='https://www.sinapsycho.com/Consult/index';
                          }
                        }
                      });
                    """);
                    if (!mounted) return;
                    setState(() => progress = 1);
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    debugPrint(consoleMessage.message);
                  },
                ),
              if (!hasInternet)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 90, color: Colors.red),
                        const SizedBox(height: 25),
                        const Text("اتصال اینترنت برقرار نیست", style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 15),
                        const Text("لطفاً اتصال اینترنت خود را بررسی کنید.", style: TextStyle(fontSize: 20)),
                        const SizedBox(height: 35),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _checkConnection();
                            if (hasInternet) controller?.reload();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("تلاش مجدد"),
                        ),
                      ],
                    ),
                  ),
                ),
              if (progress < 1 && hasInternet)
                LinearProgressIndicator(value: progress, minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
