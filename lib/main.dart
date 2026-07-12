import 'package:flutter/material.dart';
import 'package:scppg/scppg.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // دریافت لیست دوربین‌های موجود (برای اطمینان از دسترسی)
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    // اگر دوربین موجود نبود، خطا نشان بده
    runApp(const ErrorApp());
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
        fontFamily: 'Far_Homa', // استفاده از فونت دلخواه شما
      ),
      home: const HeartRateMonitorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// صفحه نمایش خطا در صورت نبود دوربین
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('دوربین دستگاه در دسترس نیست!'),
        ),
      ),
    );
  }
}

class HeartRateMonitorScreen extends StatefulWidget {
  const HeartRateMonitorScreen({super.key});

  @override
  State<HeartRateMonitorScreen> createState() => _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends State<HeartRateMonitorScreen> {
  final Scppg _scppg = Scppg();
  int _heartRate = 0;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _initScppg();
  }

  Future<void> _initScppg() async {
    try {
      await _scppg.initialize();
      // گوش‌سپاری به جریان ضربان قلب
      _scppg.heartRateStream.listen((hr) {
        if (mounted) {
          setState(() {
            _heartRate = hr;
          });
        }
      });
    } catch (e) {
      print('خطا در مقداردهی Scppg: $e');
    }
  }

  void _startMonitoring() {
    if (!_isMonitoring) {
      _scppg.start();
      setState(() {
        _isMonitoring = true;
      });
    }
  }

  void _stopMonitoring() {
    if (_isMonitoring) {
      _scppg.stop();
      setState(() {
        _isMonitoring = false;
        _heartRate = 0;
      });
    }
  }

  @override
  void dispose() {
    _scppg.dispose();
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
              onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
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
