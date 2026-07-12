import 'package:flutter/material.dart';
import 'package:heart_rate/heart_rate.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // بررسی دسترسی به دوربین
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      runApp(const ErrorApp(message: 'دوربین در دسترس نیست!'));
      return;
    }
  } catch (e) {
    runApp(ErrorApp(message: 'خطا در دسترسی به دوربین: $e'));
    return;
  }

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
      home: const HeartRateMonitorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class HeartRateMonitorScreen extends StatefulWidget {
  const HeartRateMonitorScreen({super.key});

  @override
  State<HeartRateMonitorScreen> createState() =>
      _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends State<HeartRateMonitorScreen> {
  late final HeartRateDetector _detector;
  int _heartRate = 0;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _detector = HeartRateDetector();

    // گوش‌سپاری به جریان ضربان قلب
    _detector.heartRateStream.listen((heartRate) {
      if (mounted) {
        setState(() {
          _heartRate = heartRate;
        });
      }
    });
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _detector.stop();
    } else {
      _detector.start();
    }
    setState(() {
      _isMonitoring = !_isMonitoring;
    });
  }

  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اندازه‌گیری ضربان قلب'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'لطفاً در جای ثابت بنشینید\nو دوربین را به سمت صورت خود بگیرید',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Text(
              '$_heartRate',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Text(
              'ضربه در دقیقه (BPM)',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(_isMonitoring ? 'توقف پایش' : 'شروع پایش'),
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
    );
  }
}
