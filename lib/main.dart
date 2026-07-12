import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      runApp(const ErrorApp(message: 'دوربین در دسترس نیست!'));
      return;
    }
    runApp(const MyApp());
  } catch (e) {
    runApp(ErrorApp(message: 'خطا در دسترسی به دوربین: $e'));
  }
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
  CameraController? _controller;
  bool _isMonitoring = false;
  int _heartRate = 0;
  final List<int> _brightnessHistory = [];
  Timer? _timer;
  int _frameCount = 0;

  // تنظیمات الگوریتم
  static const int sampleRate = 30; // ۳۰ فریم در ثانیه
  static const int windowSize = 150; // ۵ ثانیه داده (برای دقت بهتر)

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _isMonitoring = true;
    _brightnessHistory.clear();
    _heartRate = 0;
    _frameCount = 0;

    // شروع تحلیل فریم‌ها
    _timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ sampleRate),
      (timer) async {
        if (!_isMonitoring) return;
        await _captureAndAnalyzeFrame();
      },
    );

    setState(() {});
  }

  void _stopMonitoring() {
    _isMonitoring = false;
    _timer?.cancel();
    _timer = null;
    _heartRate = 0;
    setState(() {});
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) return;

      // محاسبه میانگین روشنایی در ناحیه مرکزی (چهره)
      int centerX = decoded.width ~/ 2;
      int centerY = decoded.height ~/ 2;
      int radius = min(decoded.width, decoded.height) ~/ 4;

      int totalBrightness = 0;
      int pixelCount = 0;

      for (int y = centerY - radius; y < centerY + radius; y++) {
        for (int x = centerX - radius; x < centerX + radius; x++) {
          if (x >= 0 && x < decoded.width && y >= 0 && y < decoded.height) {
            final pixel = decoded.getPixel(x, y);
            // تبدیل به روشنایی (Luminance)
            final r = img.getRed(pixel);
            final g = img.getGreen(pixel);
            final b = img.getBlue(pixel);
            final brightness = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
            totalBrightness += brightness;
            pixelCount++;
          }
        }
      }

      if (pixelCount == 0) return;

      final avgBrightness = totalBrightness ~/ pixelCount;
      _brightnessHistory.add(avgBrightness);

      // نگه‌داشتن فقط پنجره زمانی مشخص
      if (_brightnessHistory.length > windowSize) {
        _brightnessHistory.removeAt(0);
      }

      _frameCount++;

      // هر ۵ ثانیه یک بار محاسبه (زمانی که داده کافی داریم)
      if (_frameCount % (sampleRate * 5) == 0 &&
          _brightnessHistory.length >= windowSize) {
        final heartRate = _calculateHeartRate(_brightnessHistory, sampleRate);
        if (mounted) {
          setState(() {
            _heartRate = heartRate;
          });
        }
      }
    } catch (e) {
      print('خطا در پردازش فریم: $e');
    }
  }

  int _calculateHeartRate(List<int> brightnessData, int fps) {
    // الگوریتم ساده: تشخیص قله‌ها در سیگنال (تغییرات روشنایی)
    if (brightnessData.length < 10) return 0;

    // نرمال‌سازی داده‌ها
    double mean = brightnessData.reduce((a, b) => a + b) / brightnessData.length;
    List<double> normalized = brightnessData.map((v) => v - mean).toList();

    // تشخیص قله‌ها (محاسبه تعداد صعود و نزول‌های متوالی)
    List<int> peaks = [];
    for (int i = 1; i < normalized.length - 1; i++) {
      if (normalized[i] > normalized[i - 1] && normalized[i] > normalized[i + 1]) {
        peaks.add(i);
      }
    }

    if (peaks.length < 2) return 0;

    // محاسبه میانگین فاصله بین قله‌ها (بر حسب ثانیه)
    double avgIntervalSeconds = 0;
    int intervalsCount = 0;
    for (int i = 1; i < peaks.length; i++) {
      double interval = (peaks[i] - peaks[i - 1]) / fps; // فاصله بر حسب ثانیه
      if (interval > 0.3 && interval < 2.0) { // محدوده معقول: ۳۰ تا ۲۰۰ ضربه در دقیقه
        avgIntervalSeconds += interval;
        intervalsCount++;
      }
    }

    if (intervalsCount == 0) return 0;
    avgIntervalSeconds /= intervalsCount;

    // محاسبه ضربان در دقیقه
    return (60 / avgIntervalSeconds).round();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
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
            const SizedBox(height: 20),
            // نمایش تصویر دوربین (اختیاری)
            _controller != null && _controller!.value.isInitialized
                ? SizedBox(
                    height: 200,
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: CameraPreview(_controller!),
                    ),
                  )
                : const CircularProgressIndicator(),
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
              onPressed: _controller == null ? null : _toggleMonitoring,
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
