import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final String url = "https://www.sinapsycho.com/consult/index";

  Future<void> openCustomTab(BuildContext context) async {
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: const Color(0xFF00897B),
          ),
          showTitle: true,
        ),
        safariVCOptions: const SafariViewControllerOptions(
          barCollapsingEnabled: true,
        ),
      );
    } catch (e) {
      debugPrint("Error opening Chrome Tab: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مشاور همراه سینا"),
        backgroundColor: const Color(0xFF00897B),
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          onPressed: () => openCustomTab(context),
          child: const Text("ورود به سایت"),
        ),
      ),
    );
  }
}
