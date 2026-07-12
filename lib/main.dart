import 'package:flutter/material.dart';
import 'package:flutter_ppg/flutter_ppg.dart';

class HeartRateMonitorScreen extends StatefulWidget {
  @override
  _HeartRateMonitorScreenState createState() => _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends State<HeartRateMonitorScreen> {
  // نمونه‌گیری از سرویس اصلی پردازش سیگنال
  final FlutterPPGService _ppgService = FlutterPPGService();
  
  int _heartRate = 0;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _initPPG();
  }

  // ۱. مقداردهی اولیه الگوریتم (تنظیم نرخ نمونه‌برداری و کیفیت دوربین)
  Future<void> _initPPG() async {
    await _ppgService.initialize();
    
    // گوش‌سپاری به جریان داده‌های خروجی (خروجی بر حسب BPM)
    _ppgService.heartRateStream.listen((heartRate) {
      setState(() {
        _heartRate = heartRate;
      });
    });
  }

  // ۲. شروع فرایند علمی (شروع دریافت فریم‌ها و اعمال فیلترهای سیگنال)
  void _startMonitoring() {
    if (!_isMonitoring) {
      _ppgService.start();
      setState(() => _isMonitoring = true);
    }
  }

  // ۳. توقف و آزادسازی منابع
  void _stopMonitoring() {
    if (_isMonitoring) {
      _ppgService.stop();
      setState(() {
        _isMonitoring = false;
        _heartRate = 0;
      });
    }
  }

  @override
  void dispose() {
    _ppgService.dispose(); // آزادسازی حافظه و بستن دوربین
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اندازه‌گیری ضربان قلب با rPPG')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_heartRate BPM',
              style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'لطفاً در جای ثابت بنشینید و دوربین را رو به صورت خود بگیرید',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(_isMonitoring ? 'توقف پایش' : 'شروع پایش'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
