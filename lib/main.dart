import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

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

// ناحیه‌ی مستطیلی ساده برای مشخص کردن محدوده‌ی نمونه‌برداری روشنایی روی فریم خام دوربین
class _Roi {
  final int left;
  final int top;
  final int width;
  final int height;
  const _Roi(this.left, this.top, this.width, this.height);
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

  // تشخیص چهره
  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableTracking: false,
    ),
  );
  bool _isDetectingFace = false;
  Rect? _lastFaceRect;
  int _framesSinceFaceSeen = 0;
  bool _faceDetected = false;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

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
      // nv21/bgra8888 تنها فرمت‌هایی هستند که ML Kit روی هر پلتفرم می‌پذیرد
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();

    // قفل کردن اکسپوژر و فوکوس؛ در غیر این صورت تنظیم خودکار نور توسط دوربین
    // سیگنال روشنایی را نویزی می‌کند و تشخیص ضربان را مختل می‌کند.
    try {
      await _controller!.setFocusMode(FocusMode.locked);
    } catch (_) {}
    try {
      await _controller!.setExposureMode(ExposureMode.locked);
    } catch (_) {}

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
    _lastFaceRect = null;
    _framesSinceFaceSeen = 0;
    _faceDetected = false;

    if (!_isStreaming) {
      await _controller!.startImageStream(_onCameraImage);
      _isStreaming = true;
    }

    // نمونه‌برداری با نرخ ثابت از آخرین مقدار روشنایی محاسبه‌شده
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
    if (!_isMonitoring) return;

    // تشخیص چهره سنگین‌تر است و async اجرا می‌شود؛ اگر فریم قبلی هنوز پردازش نشده رد می‌شود
    if (!_isDetectingFace) {
      _isDetectingFace = true;
      _detectFaceAndUpdateRoi(image);
    }

    // محاسبه‌ی روشنایی روی ناحیه‌ی پیشانی (یا مرکز فریم در نبود چهره) - این کار سریع و سنکرون است
    if (!_isProcessingFrame) {
      _isProcessingFrame = true;
      try {
        final roi = _lastFaceRect != null
            ? _foreheadRoiFromFace(_lastFaceRect!, image.width, image.height)
            : _centerRoi(image.width, image.height);

        _latestBrightness = Platform.isAndroid
            ? _averageBrightnessYUV(image, roi)
            : _averageBrightnessBGRA(image, roi);
      } catch (e) {
        print('خطا در پردازش فریم: $e');
      } finally {
        _isProcessingFrame = false;
      }
    }
  }

  Future<void> _detectFaceAndUpdateRoi(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        // بزرگ‌ترین چهره‌ی شناسایی‌شده در تصویر انتخاب می‌شود
        faces.sort((a, b) =>
            (b.boundingBox.width * b.boundingBox.height)
                .compareTo(a.boundingBox.width * a.boundingBox.height));
        _lastFaceRect = faces.first.boundingBox;
        _framesSinceFaceSeen = 0;
        if (!_faceDetected && mounted) {
          setState(() => _faceDetected = true);
        }
      } else {
        _framesSinceFaceSeen++;
        // اگر حدود ۱ ثانیه چهره دیده نشد، ناحیه‌ی قبلی کنار گذاشته می‌شود
        if (_framesSinceFaceSeen > sampleRate) {
          _lastFaceRect = null;
          if (_faceDetected && mounted) {
            setState(() => _faceDetected = false);
          }
        }
      }
    } catch (e) {
      print('خطا در تشخیص چهره: $e');
    } finally {
      _isDetectingFace = false;
    }
  }

  // ساخت InputImage برای ML Kit از فریم خام دوربین (طبق الگوی رسمی google_mlkit_commons)
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _controller?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  _Roi _centerRoi(int imageWidth, int imageHeight) {
    final radius = min(imageWidth, imageHeight) ~/ 4;
    return _Roi(
      (imageWidth ~/ 2 - radius).clamp(0, imageWidth - 1),
      (imageHeight ~/ 2 - radius).clamp(0, imageHeight - 1),
      radius * 2,
      radius * 2,
    );
  }

  // ناحیه‌ی پیشانی: بخش بالای کادر چهره، کمی پایین‌تر از خط مو و بالاتر از ابروها
  _Roi _foreheadRoiFromFace(Rect faceRect, int imageWidth, int imageHeight) {
    final faceWidth = faceRect.width;
    final faceHeight = faceRect.height;

    final left = (faceRect.left + faceWidth * 0.30).clamp(0, imageWidth - 1).toInt();
    final top = (faceRect.top + faceHeight * 0.12).clamp(0, imageHeight - 1).toInt();
    final width = (faceWidth * 0.40).clamp(1, imageWidth - left).toInt();
    final height = (faceHeight * 0.15).clamp(1, imageHeight - top).toInt();

    return _Roi(left, top, width, height);
  }

  // استخراج روشنایی مستقیم از صفحه‌ی Y (luminance) در فرمت nv21 اندروید - بدون نیاز به دیکد JPEG
  double _averageBrightnessYUV(CameraImage image, _Roi roi) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final xEnd = (roi.left + roi.width).clamp(0, image.width);
    final yEnd = (roi.top + roi.height).clamp(0, image.height);

    double total = 0;
    int count = 0;
    for (int y = roi.top; y < yEnd; y++) {
      final rowOffset = y * bytesPerRow;
      for (int x = roi.left; x < xEnd; x++) {
        total += bytes[rowOffset + x];
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  // استخراج روشنایی از فرمت BGRA8888 (iOS)
  double _averageBrightnessBGRA(CameraImage image, _Roi roi) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final xEnd = (roi.left + roi.width).clamp(0, image.width);
    final yEnd = (roi.top + roi.height).clamp(0, image.height);

    double total = 0;
    int count = 0;
    for (int y = roi.top; y < yEnd; y++) {
      final rowOffset = y * bytesPerRow;
      for (int x = roi.left; x < xEnd; x++) {
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

    // اگر چهره شناسایی نشده، این نمونه را نادیده می‌گیریم تا سیگنال با نویز پس‌زمینه آلوده نشود
    if (!_faceDetected) return;

    _brightnessHistory.add(_latestBrightness.toInt());

    if (_brightnessHistory.length > windowSize) {
      _brightnessHistory.removeAt(0);
    }

    _frameCount++;

    if (_frameCount % (sampleRate * 5) == 0 &&
        _brightnessHistory.length >= windowSize) {
      final computed = _calculateHeartRate(_brightnessHistory, sampleRate);

      // اگر سیگنال ضعیف بود و محاسبه نامعتبر شد (۰)، مقدار قبلی حفظ می‌شود
      // به‌جای این‌که عدد روی صفحه یک‌دفعه صفر بشود
      if (computed > 0 && mounted) {
        setState(() {
          _heartRate = _heartRate == 0
              ? computed
              : ((_heartRate * 0.6) + (computed * 0.4)).round();
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
    _faceDetector.close();
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
                ? Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        height: 200,
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: CameraPreview(_controller!),
                        ),
                      ),
                      if (_isMonitoring && !_faceDetected)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'چهره شناسایی نشد',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
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
