import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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

  // آخرین مقدار روشنایی محاسبه‌شده از فریم دوربین (توسط استریم تصویر به‌روزرسانی می‌شود)
  double _latestBrightness = 0;
  bool _isProcessingFrame = false;
  bool _isStreaming = false;

  // تنظیمات الگوریتم
  static const int sampleRate = 30; // ۳۰ نمونه در ثانیه
  static const int windowSize = 150; // ۵ ثانیه داده (برای دقت بهتر)

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // ترجیح با دوربین جلو؛ اگر پیدا نشد، اولین دوربین موجود استفاده می‌شود
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.low, // برای این کاربرد فقط میانگین روشنایی لازم است؛ رزولوشن پایین سریع‌تر است
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();

    // قفل کردن اکسپوژر و فوکوس؛ در غیر این صورت تنظیم خودکار نور توسط دوربین
    // سیگنال روشنایی را نویزی می‌کند و تشخیص ضربان را مختل می‌کند.
    try {
      await _controller!.setFocusMode(FocusMode.locked);
    } catch (_) {
      // برخی دستگاه‌ها این حالت را پشتیبانی نمی‌کنند
    }
    try {
      await _controller!.setExposureMode(ExposureMode.locked);
    } catch (_) {
      // برخی دستگاه‌ها این حالت را پشتیبانی نمی‌کنند
    }

    if (mounted) setState(() {});
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _isMonitoring = true;
    _brightnessHistory.clear();
    _heartRate = 0;
    _frameCount = 0;
    _latestBrightness = 0;

    // شروع دریافت فریم‌های خام دوربین (بدون ذخیره فایل، مستقیم در حافظه)
    if (!_isStreaming) {
      await _controller!.startImageStream(_onCameraImage);
      _isStreaming = true;
    }

    // نمونه‌برداری با نرخ ثابت از آخرین مقدار روشنایی محاسبه‌شده
    // (این کار نرخ ذخیره‌ی داده را از نرخ متغیر فریم دوربین جدا می‌کند)
    _timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ sampleRate),
      (timer) => _sampleBrightness(),
    );

    setState(() {});
  }

  Future<void> _stopMonitoring() async {
    _isMonitoring = false;
    _timer?.cancel();
    _timer = null;
    _heartRate = 0;

    if (_isStreaming && _controller != null) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {}
      _isStreaming = false;
    }

    setState(() {});
  }

  void _onCameraImage(CameraImage image) {
    if (!_isMonitoring || _isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final radius = min(image.width, image.height) ~/ 4;

      final brightness = Platform.isAndroid
          ? _averageBrightnessYUV(image, centerX, centerY, radius)
          : _averageBrightnessBGRA(image, centerX, centerY, radius);

      _latestBrightness = brightness;
    } catch (e) {
      print('خطا در پردازش فریم: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // استخراج روشنایی مستقیم از صفحه Y (luminance) در فرمت YUV420 اندروید - بدون نیاز به دیکد JPEG
  double _averageBrightnessYUV(
      CameraImage image, int centerX, int centerY, int radius) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final xStart = (centerX - radius).clamp(0, image.width - 1);
    final xEnd = (centerX + radius).clamp(0, image.width - 1);
    final yStart = (centerY - radius).clamp(0, image.height - 1);
    final yEnd = (centerY + radius).clamp(0, image.height - 1);

    double total = 0;
    int count = 0;
    for (int y = yStart; y < yEnd; y++) {
      final rowOffset = y * bytesPerRow;
      for (int x = xStart; x < xEnd; x++) {
        total += bytes[rowOffset + x];
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  // استخراج روشنایی از فرمت BGRA8888 (iOS)
  double _averageBrightnessBGRA(
      CameraImage image, int centerX, int centerY, int radius) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final xStart = (centerX - radius).clamp(0, image.width - 1);
    final xEnd = (centerX + radius).clamp(0, image.width - 1);
    final yStart = (centerY - radius).clamp(0, image.height - 1);
    final yEnd = (centerY + radius).clamp(0, image.height - 1);

    double total = 0;
    int count = 0;
    for (int y = yStart; y < yEnd; y++) {
      final rowOffset = y * bytesPerRow;
      for (int x = xStart; x < xEnd; x++) {
        final pixelOffset = rowOffset + x * 4;
        final b = bytes[pixelOffset];
        final g = bytes[pixelOffset + 1];
        final r = bytes[pixelOffset + 2];
        total += 0.299 * r + 0.587 * g + 0.114 * b;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  void _sampleBrightness() {
    if (!_isMonitoring) return;

    _brightnessHistory.add(_latestBrightness.toInt());

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
    if (_isStreaming) {
      _controller?.stopImageStream();
    }
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
