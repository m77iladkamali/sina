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
        fontFamily: "Far_Homa",
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}

//////////////////////////////////////////////////////////
/// Welcome Page
//////////////////////////////////////////////////////////

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scale = Tween<double>(
      begin: .90,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
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

          child: Column(

            children: [

              const SizedBox(height: 35),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "به بخش مشاوره غیرحضوری سینا\nخوش آمدید",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),

              const Spacer(),

              ScaleTransition(
                scale: _scale,
                child: SizedBox(
                  width: 300,
                  height: 300,
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: MediaQuery.of(context).size.width * .85,
                height: 58,
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
                      MaterialPageRoute(
                        builder: (_) => const BrowserPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "ورود",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),
            ],
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

                    domStorageEnabled: true,

                    databaseEnabled: true,

                    cacheEnabled: true,

                    supportZoom: false,

                    mediaPlaybackRequiresUserGesture: false,

                    allowsInlineMediaPlayback: true,

                    thirdPartyCookiesEnabled: true,

                    useShouldOverrideUrlLoading: true,

                    useHybridComposition: true,

                    transparentBackground: true,

                    userAgent:
                        "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0 Mobile Safari/537.36",

                  ),

                  onWebViewCreated: (c) {

                    controller = c;

                  },
                                    onProgressChanged: (controller, value) {
                    setState(() {
                      progress = value / 100;
                    });
                  },

                  onLoadStart: (controller, url) {
                    setState(() {
                      hasError = false;
                    });
                  },

                  onLoadStop: (controller, url) async {
                    setState(() {
                      hasError = false;
                      progress = 1;
                    });
                  },

                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame == true) {
                      setState(() {
                        hasError = true;
                      });
                    }
                  },

                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    return NavigationActionPolicy.ALLOW;
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
                          size: 90,
                          color: Colors.red,
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "اتصال اینترنت برقرار نیست",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          "لطفاً اینترنت خود را بررسی کنید.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                          ),
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              hasError = false;
                              progress = 0;
                            });

                            controller?.reload();
                          },
                          child: const Text("تلاش مجدد"),
                        ),
                      ],
                    ),
                  ),
                ),

              if (progress < 1 && !hasError)
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
