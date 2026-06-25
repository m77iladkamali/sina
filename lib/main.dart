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
      theme: ThemeData(fontFamily: "BNazanin"),
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

              const Text(
                "به بخش مشاوره غیرحضوری سینا",
                style: TextStyle(
                  fontSize: 34,
                  color: Color(0xff42E676),
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "خوش آمدید",
                style: TextStyle(
                  fontSize: 40,
                  color: Color(0xff42E676),
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 35),

              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Image.asset(
                    "assets/images/logo.png",
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: MediaQuery.of(context).size.width * .85,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff23C66F),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 50,
              ),

              const SizedBox(height: 12),

              const Text(
                "اینجا محیطی امن و راحت برای یاری شماست",
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
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
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF00897B),
                width: 2,
              ),
            ),
            child: InAppWebView(
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
                allowsInlineMediaPlayback: true,
                thirdPartyCookiesEnabled: true,
                userAgent:
                    "Mozilla/5.0 (Linux; Android 14; SM-A256E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36",
              ),
              onWebViewCreated: (c) {
                controller = c;
              },
            ),
          ),
        ),
      ),
    );
  }
}
