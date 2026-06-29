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

// ===== صفحه خوش‌آمدگویی =====
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: .9, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
            colors: [Color(0xff1565C0), Color(0xff0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 55),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "به بخش مشاوره غیرحضوری سینا\n.خوش آمدید",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, color: Colors.white, height: 1.3),
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Image.asset("assets/images/sina.png", fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "اینجا محیطی امن و راحت\n.برای یاری شماست",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, color: Colors.white, height: 1.5),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: 180,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff23C66F),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const BrowserPage()),
                    );
                  },
                  child: const Text("ورود", style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== مرورگر با InAppWebView (بدون تاریخچه دستی) =====
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
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

    // اگر به صفحه اول رسیدیم، دیالوگ خروج
    final exit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text("خروج از برنامه", textAlign: TextAlign.center),
            content: const Text("آیا مایل به خروج از برنامه هستید؟", textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("خیر")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("بله")),
            ],
          ),
        ) ??
        false;
    return exit;
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
                  // ===== تشخیص حرکات برای لینک‌ها و دکمه‌ها =====
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
                    // ===== تنظیمات کلیدی =====
                    useHybridComposition: true, // ثبت درست تاریخچه
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
                  // ===== مدیریت لینک‌های جدید =====
           
                  // ===== خطاهای JS (فقط در حالت debug) =====
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
