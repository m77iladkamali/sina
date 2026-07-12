import 'package:flutter/material.dart';
import 'package:heart_rate/heart_rate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سینا - مشاور همراه',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Far_Homa',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاور همراه سینا'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'اندازه‌گیری ضربان قلب',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'برای شروع، دکمه زیر را بزنید و دوربین را به سمت صورت خود بگیرید.\nلطفاً در جای ثابت بنشینید و تا پایان اندازه‌گیری حرکت نکنید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () async {
                  final int? heartRate = await HeartRateDialog.show(context);
                  if (heartRate != null) {
                    _showResultDialog(context, heartRate);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('اندازه‌گیری لغو شد.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('شروع اندازه‌گیری'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, int heartRate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نتیجه اندازه‌گیری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(
              '$heartRate',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Text(
              'ضربه در دقیقه (BPM)',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
}
