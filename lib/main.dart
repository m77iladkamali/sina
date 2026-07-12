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

  double _latestBrightness = 0;
  bool _isProcessingFrame = false;
  bool _isStreaming = false;

  // تشخیص چهره + طبقه‌بندی (برای احتمال باز/بسته بودن چشم‌ها)
  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
      enableTracking: false,
    ),
  );
  bool _isDetectingFace = false;
  Rect? _lastFaceRect;
  int _framesSinceFaceSeen = 0;
  bool _faceDetected = false;

  // وضعیت و شمارش پلک زدن
  bool _leftEyeOpen = true;
  bool _rightEyeOpen = true;
  int _leftBlinkCount = 0;
  int _rightBlinkCount = 0;
  static const double _eyeClosedThreshold = 0.3;
  static const double _eyeOpenThreshold = 0.6;

  // بافر نمایش موج زنده (نسخه‌ی AC-coupled سیگنال روشنایی، بدون افت‌وخیز آهسته)
  static const int waveformLength = 90; // ~۳ ثانیه در نرخ ۳۰ نمونه بر ثانیه
  static const int _waveformShortWindow = 30; // ~۱ ثانیه، برای محاسبه‌ی میانگین کوتاه‌مدت
  final List<double> _waveformBuffer = List<double>.filled(waveformLength, 0);
  final List<double> _recentRawSamples = [];
  final ValueNotifier<List<double>> _waveformNotifier =
      ValueNotifier<List<double>>(List<double>.filled(waveformLength, 0));

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // تنظیمات الگوریتم
  static const int sampleRate = 30; // ۳۰ نمونه در ثانیه
  static const int windowSize = 240; // ۸ ثانیه داده (برای دقت بهتر در تشخیص فرکانس)
  static const int recalcIntervalFrames = sampleRate * 3; // هر ۳ ثانیه یک‌بار محاسبه‌ی مجدد

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();

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
    _leftEyeOpen = true;
    _rightEyeOpen = true;
    _leftBlinkCount = 0;
    _rightBlinkCount = 0;
    _recentRawSamples.clear();
    _waveformBuffer.setAll(0, List<double>.filled(waveformLength, 0));
    _waveformNotifier.value = List<double>.from(_waveformBuffer);

    if (!_isStreaming) {
      await _controller!.startImageStream(_onCameraImage);
      _isStreaming = true;
    }

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

    if (!_isDetectingFace) {
      _isDetectingFace = true;
      _detectFaceAndUpdateRoi(image);
    }

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
        faces.sort((a, b) =>
            (b.boundingBox.width * b.boundingBox.height)
                .compareTo(a.boundingBox.width * a.boundingBox.height));
        final face = faces.first;
        _lastFaceRect = face.boundingBox;
        _framesSinceFaceSeen = 0;
        if (!_faceDetected && mounted) {
          setState(() => _faceDetected = true);
        }

        _updateBlinkState(face);
      } else {
        _framesSinceFaceSeen++;
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

  // تشخیص کامل شدن یک پلک با فرضیه‌ی هیسترزیس (آستانه‌ی متفاوت برای بسته و باز شدن)
  // تا نوسانات کوچک احتمال، به اشتباه چند پلک پشت‌سرهم ثبت نکنند
  void _updateBlinkState(Face face) {
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;

    bool changed = false;

    if (leftProb != null) {
      if (_leftEyeOpen && leftProb < _eyeClosedThreshold) {
        _leftEyeOpen = false;
      } else if (!_leftEyeOpen && leftProb > _eyeOpenThreshold) {
        _leftEyeOpen = true;
        _leftBlinkCount++;
        changed = true;
      }
    }

    if (rightProb != null) {
      if (_rightEyeOpen && rightProb < _eyeClosedThreshold) {
        _rightEyeOpen = false;
      } else if (!_rightEyeOpen && rightProb > _eyeOpenThreshold) {
        _rightEyeOpen = true;
        _rightBlinkCount++;
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

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

  _Roi _foreheadRoiFromFace(Rect faceRect, int imageWidth, int imageHeight) {
    final faceWidth = faceRect.width;
    final faceHeight = faceRect.height;

    final left = (faceRect.left + faceWidth * 0.30).clamp(0, imageWidth - 1).toInt();
    final top = (faceRect.top + faceHeight * 0.12).clamp(0, imageHeight - 1).toInt();
    final width = (faceWidth * 0.40).clamp(1, imageWidth - left).toInt();
    final height = (faceHeight * 0.15).clamp(1, imageHeight - top).toInt();

    return _Roi(left, top, width, height);
  }

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

    // توجه: نمونه‌برداری دیگر به موفقیت تشخیص چهره وابسته نیست.
    // اگر چهره شناسایی شود، ناحیه‌ی پیشانی برای دقت بهتر استفاده می‌شود (در _onCameraImage)
    // ولی در نبود آن هم روی ناحیه‌ی مرکزی فریم اندازه‌گیری ادامه پیدا می‌کند.
    _brightnessHistory.add(_latestBrightness.toInt());

    if (_brightnessHistory.length > windowSize) {
      _brightnessHistory.removeAt(0);
    }

    _updateWaveform(_latestBrightness);

    _frameCount++;

    if (_frameCount % recalcIntervalFrames == 0 &&
        _brightnessHistory.length >= windowSize) {
      final computed = _calculateHeartRate(_brightnessHistory, sampleRate);

      if (computed > 0 && mounted) {
        setState(() {
          _heartRate = _heartRate == 0
              ? computed
              : ((_heartRate * 0.6) + (computed * 0.4)).round();
        });
      }
    }
  }

  // میانگین متحرک محلی برای هر نمونه (پنجره‌ی متقارن) - برای حذف روند آهسته (نور محیط، لرزش دست)
  List<double> _detrend(List<double> data, int halfWindow) {
    final n = data.length;
    final result = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final start = max(0, i - halfWindow);
      final end = min(n, i + halfWindow + 1);
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += data[j];
      }
      final localMean = sum / (end - start);
      result[i] = data[i] - localMean;
    }
    return result;
  }

  // میانگین متحرک ساده برای حذف نویز ریز (لرزش پیکسل‌به‌پیکسل)
  List<double> _smooth(List<double> data, int halfWindow) {
    final n = data.length;
    final result = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final start = max(0, i - halfWindow);
      final end = min(n, i + halfWindow + 1);
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += data[j];
      }
      result[i] = sum / (end - start);
    }
    return result;
  }

  double _standardDeviation(List<double> data) {
    final mean = data.reduce((a, b) => a + b) / data.length;
    final variance =
        data.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            data.length;
    return sqrt(variance);
  }

  // نسخه‌ی AC-coupled سیگنال برای نمایش زنده: از مقدار خام، میانگین کوتاه‌مدت اخیر کم می‌شود
  // تا موج به‌جای یک عدد ثابت با افت‌وخیز آهسته، حول محور صفر نوسان کند (شبیه موج پالس واقعی)
  void _updateWaveform(double value) {
    _recentRawSamples.add(value);
    if (_recentRawSamples.length > _waveformShortWindow) {
      _recentRawSamples.removeAt(0);
    }
    final localMean =
        _recentRawSamples.reduce((a, b) => a + b) / _recentRawSamples.length;
    final acValue = value - localMean;

    _waveformBuffer.removeAt(0);
    _waveformBuffer.add(acValue);
    _waveformNotifier.value = List<double>.from(_waveformBuffer);
  }

  int _calculateHeartRate(List<int> brightnessData, int fps) {
    if (brightnessData.length < 30) return 0;

    // مرحله ۱: هموارسازی سبک برای حذف نویز شات‌نویز پیکسل
    final raw = brightnessData.map((v) => v.toDouble()).toList();
    final smoothed = _smooth(raw, 1);

    // مرحله ۲: حذف روند آهسته (baseline drift) با کم کردن میانگین متحرک محلی
    // پنجره‌ی نیمه ~۱ ثانیه؛ فرکانس‌های زیر ~۰.۵ هرتز (۳۰ ضربه در دقیقه) حذف می‌شوند
    final detrended = _detrend(smoothed, fps ~/ 2);

    if (detrended.every((v) => v == 0)) return 0;

    final stdDev = _standardDeviation(detrended);
    if (stdDev == 0) return 0;

    // آستانه‌ی برجستگی: قله باید حداقل این مقدار از صفر فاصله داشته باشد
    // تا نویز کوچک به اشتباه به‌عنوان ضربان شمارش نشود
    final prominenceThreshold = stdDev * 0.35;

    List<int> peaks = [];
    for (int i = 1; i < detrended.length - 1; i++) {
      if (detrended[i] > detrended[i - 1] &&
          detrended[i] > detrended[i + 1] &&
          detrended[i] > prominenceThreshold) {
        peaks.add(i);
      }
    }

    if (peaks.length < 2) return 0;

    double avgIntervalSeconds = 0;
    int intervalsCount = 0;
    for (int i = 1; i < peaks.length; i++) {
      double interval = (peaks[i] - peaks[i - 1]) / fps;
      if (interval > 0.3 && interval < 2.0) {
        avgIntervalSeconds += interval;
        intervalsCount++;
      }
    }

    if (intervalsCount == 0) return 0;
    avgIntervalSeconds /= intervalsCount;

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
    _waveformNotifier.dispose();
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
            const SizedBox(height: 24),
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
            const SizedBox(height: 16),
            // نمایش زنده‌ی موج ضربان
            Container(
              height: 70,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ValueListenableBuilder<List<double>>(
                valueListenable: _waveformNotifier,
                builder: (context, data, _) {
                  return CustomPaint(
                    size: const Size(double.infinity, 70),
                    painter: _WaveformPainter(data),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // شمارنده‌ی پلک زدن هر چشم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(
                      _rightEyeOpen ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 4),
                    Text('پلک چپ: $_rightBlinkCount'),
                  ],
                ),
                Column(
                  children: [
                    Icon(
                      _leftEyeOpen ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 4),
                    Text('پلک راست: $_leftBlinkCount'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),
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

// رسم موج زنده‌ی ضربان روی یک سطح تیره، شبیه مانیتورهای PPG
class _WaveformPainter extends CustomPainter {
  final List<double> data;
  const _WaveformPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // خط پایه‌ی وسط
    final basePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      basePaint,
    );

    if (data.length < 2) return;

    // مقیاس‌بندی خودکار بر اساس بزرگ‌ترین دامنه‌ی فعلی موج، تا موج همیشه در کادر جا شود
    double maxAbs = 0;
    for (final v in data) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    final scale = maxAbs < 0.5 ? 1.0 : (size.height / 2 - 6) / maxAbs;

    final wavePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final dx = size.width / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height / 2 - data[i] * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
