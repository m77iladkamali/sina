import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
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
  int _frameCount = 0;

  bool _isProcessingFrame = false;
  bool _isStreaming = false;

  // وضعیت راه‌اندازی دوربین
  String? _initError;

  // === واچ‌داگ: تشخیص قطعی این‌که آیا استریم دوربین اصلاً فریمی می‌رساند یا نه ===
  Timer? _watchdogTimer;
  int _lastWatchdogFrameCount = -1;
  static const int _watchdogTimeoutSeconds = 3;

  // تشخیص چهره + طبقه‌بندی (برای احتمال باز/بسته بودن چشم‌ها)
  // توجه: این ویژگی کاملاً اختیاری است؛ اگر فرمت تصویر با آن سازگار نباشد
  // (مثلاً روی فرمت پشتیبان yuv420)، بی‌سروصدا غیرفعال می‌ماند و
  // اندازه‌گیری ضربان قلب و موج بدون آن هم کار می‌کنند.
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
  // growable: true ضروری است چون بعداً با removeAt/add به آن عنصر اضافه و حذف می‌کنیم؛
  // خروجی List<double>.filled(...) به‌صورت پیش‌فرض fixed-length است و اجازه‌ی
  // removeAt نمی‌دهد (همان خطای "Cannot remove from a fixed-length list").
  final List<double> _waveformBuffer =
      List<double>.filled(waveformLength, 0, growable: true);
  final List<double> _recentRawSamples = [];
  final ValueNotifier<List<double>> _waveformNotifier =
      ValueNotifier<List<double>>(List<double>.filled(waveformLength, 0));
  final ValueNotifier<String> _debugNotifier = ValueNotifier<String>('');

  // فیلدهای دیباگ - برای تشخیص این‌که مسیر پردازش فریم دقیقاً کجا متوقف می‌شود
  int _cameraFrameCount = 0;
  String? _debugError;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // تنظیمات الگوریتم
  static const int sampleRate = 30; // ۳۰ نمونه در ثانیه (تقریبی - نرخ واقعی فریم دوربین است)
  static const int windowSize = 240; // ~۸ ثانیه داده (برای دقت بهتر در تشخیص فرکانس)
  static const int recalcIntervalFrames = sampleRate * 3; // هر ~۳ ثانیه یک‌بار محاسبه‌ی مجدد

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // راه‌اندازی دوربین با افت خودکار (fallback) بین فرمت‌های تصویر:
  // ابتدا فرمت سازگار با تشخیص چهره امتحان می‌شود؛ اگر دستگاه آن را پشتیبانی نکند
  // (initialize شکست بخورد)، به فرمت پایه‌ای‌تر که مطمئناً کار می‌کند برمی‌گردیم.
  // در هر دو حالت، اندازه‌گیری ضربان قلب و موج کار می‌کند - فقط تشخیص چهره ممکن است غیرفعال شود.
  Future<void> _initCamera() async {
    setState(() {
      _initError = null;
    });

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (mounted) setState(() => _initError = 'خطا در دسترسی به دوربین‌ها: $e');
      return;
    }

    if (cameras.isEmpty) {
      if (mounted) setState(() => _initError = 'هیچ دوربینی پیدا نشد');
      return;
    }

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // نکته‌ی مهم: روی برخی دستگاه‌های اندروید ترکیب nv21 + ResolutionPreset.low
    // باعث شکست خاموش initialize یا عدم رسیدن فریم از پلتفرم چنل می‌شود.
    // yuv420 پایدارترین فرمت روی تقریباً همه‌ی دستگاه‌های اندروید است، برای همین
    // آن را هم به‌عنوان گزینه‌ی اول امتحان می‌کنیم (چهره‌یابی چندپلین را غیرفعال می‌کند
    // ولی اندازه‌گیری ضربان قلب کاملاً مستقل از آن کار می‌کند).
    final formatsToTry = Platform.isAndroid
        ? [ImageFormatGroup.yuv420, ImageFormatGroup.nv21]
        : [ImageFormatGroup.bgra8888];

    Object? lastError;
    for (final format in formatsToTry) {
      try {
        final controller = CameraController(
          frontCamera,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: format,
        );
        await controller.initialize();

        try {
          await controller.setFocusMode(FocusMode.locked);
        } catch (_) {}
        try {
          await controller.setExposureMode(ExposureMode.locked);
        } catch (_) {}

        if (!mounted) {
          await controller.dispose();
          return;
        }

        _controller = controller;

        setState(() {
          _initError = null;
        });
        return; // موفق شد - از تابع خارج می‌شویم
      } catch (e) {
        lastError = e;
        debugPrint('خطا در راه‌اندازی دوربین با فرمت $format: $e');
      }
    }

    // اگر همه‌ی فرمت‌های ممکن شکست خوردند
    if (mounted) {
      setState(() {
        _initError = 'راه‌اندازی دوربین ناموفق بود.\n$lastError';
      });
    }
  }

  void _toggleMonitoring() {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دوربین هنوز آماده نیست، چند لحظه صبر کنید')),
      );
      return;
    }
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _isMonitoring = true;
      _brightnessHistory.clear();
      _heartRate = 0;
      _frameCount = 0;
      _lastFaceRect = null;
      _framesSinceFaceSeen = 0;
      _faceDetected = false;
      _leftEyeOpen = true;
      _rightEyeOpen = true;
      _leftBlinkCount = 0;
      _rightBlinkCount = 0;
      _recentRawSamples.clear();
      _filteredAcValue = 0;
      _filterInitialized = false;
      _recentFilteredSamples.clear();
      _samplesSinceLastBeat = 999;
      _pulsePhase = 1.0;
      _pulseStepPerSample = 0.05;
      _waveformBuffer.setAll(0, List<double>.filled(waveformLength, 0));
      _waveformNotifier.value = List<double>.from(_waveformBuffer);
      _cameraFrameCount = 0;
      _debugError = null;
      _debugNotifier.value = 'در حال شروع دریافت فریم از دوربین...';

      if (!_isStreaming) {
        await _controller!.startImageStream(_onCameraImage);
        _isStreaming = true;
      }

      // واچ‌داگ: هر چند ثانیه بررسی می‌کند که آیا شمارنده‌ی فریم واقعاً پیش می‌رود.
      // اگر پیش نرود یعنی startImageStream روی این دستگاه فریمی نمی‌رساند
      // (معمولاً به‌خاطر مجوز دوربین، اشغال بودن دوربین توسط برنامه‌ی دیگر، یا
      // ناسازگاری فرمت تصویر روی آن دستگاه‌ی خاص).
      _lastWatchdogFrameCount = -1;
      _watchdogTimer?.cancel();
      _watchdogTimer = Timer.periodic(
        const Duration(seconds: _watchdogTimeoutSeconds),
        (_) => _checkStreamHealth(),
      );

      if (mounted) setState(() {});
    } catch (e) {
      _debugError = 'خطا در شروع پایش: $e';
      _isMonitoring = false;
      _debugNotifier.value = _debugError!;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_debugError!)),
        );
      }
    }
  }

  void _checkStreamHealth() {
    if (!_isMonitoring) return;
    if (_cameraFrameCount == _lastWatchdogFrameCount) {
      // در ۳ ثانیه‌ی اخیر حتی یک فریم هم از دوربین نرسیده است.
      _debugError = 'هیچ فریمی از دوربین دریافت نمی‌شود.\n'
          'دوربین ممکن است توسط برنامه‌ی دیگری در حال استفاده باشد،\n'
          'یا مجوز دوربین به‌درستی اعطا نشده باشد.';
      _debugNotifier.value = _debugError!;
      if (mounted) setState(() {});
    }
    _lastWatchdogFrameCount = _cameraFrameCount;
  }

  Future<void> _stopMonitoring() async {
    _isMonitoring = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _heartRate = 0;

    if (_isStreaming && _controller != null) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {}
      _isStreaming = false;
    }

    if (mounted) setState(() {});
  }

  // نمونه‌برداری اکنون مستقیماً داخل کال‌بک استریم دوربین انجام می‌شود، نه یک
  // Timer.periodic جدا. این تضمین می‌کند که نرخ نمونه‌برداری دقیقاً با نرخ
  // واقعی فریم دوربین هماهنگ باشد و اگر فریمی نرسد، ما هم منتظر آن نمی‌مانیم
  // (به‌جای این‌که تایمر جدا هر بار روی همان مقدار قدیمی brightness کار کند).
  void _onCameraImage(CameraImage image) {
    if (!_isMonitoring) return;

    _cameraFrameCount++;

    // تشخیص چهره برای هر دو فرمت nv21 (تک‌پلین) و yuv420 (سه‌پلین) امتحان می‌شود؛
    // تبدیل لازم داخل _inputImageFromCameraImage انجام می‌گیرد.
    if (!_isDetectingFace) {
      _isDetectingFace = true;
      _detectFaceAndUpdateRoi(image);
    }

    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    double brightness = 0;
    try {
      final roi = _lastFaceRect != null
          ? _foreheadRoiFromFace(_lastFaceRect!, image.width, image.height)
          : _centerRoi(image.width, image.height);

      brightness = Platform.isAndroid
          ? _averageBrightnessYPlane(image, roi)
          : _averageBrightnessBGRA(image, roi);

      _handleNewBrightnessSample(brightness);
    } catch (e) {
      _debugError = 'خطا در پردازش فریم: $e';
      debugPrint(_debugError);
      _debugNotifier.value = _debugError!;
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleNewBrightnessSample(double brightness) {
    _brightnessHistory.add(brightness.toInt());
    if (_brightnessHistory.length > windowSize) {
      _brightnessHistory.removeAt(0);
    }

    _updateWaveform(brightness);

    _frameCount++;

    if (_frameCount % 10 == 0) {
      _debugNotifier.value = _debugError ??
          'فریم دوربین: $_cameraFrameCount | نمونه: ${_brightnessHistory.length}/$windowSize | روشنایی: ${brightness.toStringAsFixed(1)}';
    }

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
      // تشخیص چهره اختیاری است؛ خطای آن نباید اندازه‌گیری اصلی را متوقف کند
      debugPrint('خطا در تشخیص چهره (نادیده گرفته شد): $e');
    } finally {
      _isDetectingFace = false;
    }
  }

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
      final deviceOrientation = _controller?.value.deviceOrientation;
      var rotationCompensation = _orientations[deviceOrientation] ?? 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // حالت ۱: فرمت تک-پلین (nv21 روی اندروید، یا bgra8888 روی iOS) - مستقیم قابل استفاده است.
    if (image.planes.length == 1) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
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

    // حالت ۲: yuv420 سه‌پلین (رایج‌ترین فرمت روی اندروید). ML Kit روی این پکیج
    // فرمت‌های چندپلین را مستقیم نمی‌پذیرد، پس آن را به یک بافر تک‌پلین nv21
    // تبدیل می‌کنیم (Y کامل + VU به‌صورت interleaved). این تبدیل استاندارد و
    // تنها راه شناخته‌شده برای این‌که تشخیص چهره روی فرمت yuv420 کار کند.
    if (image.planes.length == 3) {
      try {
        final nv21Bytes = _yuv420ToNv21(image);
        return InputImage.fromBytes(
          bytes: nv21Bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      } catch (e) {
        debugPrint('خطا در تبدیل yuv420 به nv21: $e');
        return null;
      }
    }

    return null;
  }

  // تبدیل فریم سه‌پلینِ yuv420 (پلین‌های Y، U، V که ممکن است pixelStride و
  // rowStride متفاوتی داشته باشند) به یک بافر تک‌پلین nv21 استاندارد:
  // ابتدا کل صفحه‌ی Y بدون padding، سپس بایت‌های V و U به‌صورت interleaved.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height ~/ 2));

    // کپی صفحه‌ی Y، ردیف به ردیف، برای حذف padding احتمالی بین ردیف‌ها
    int offset = 0;
    for (int row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    // کپی V و U به‌صورت interleaved (VUVUVU...) که فرمت nv21 انتظار دارد
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;
    final chromaHeight = height ~/ 2;
    final chromaWidth = width ~/ 2;

    for (int row = 0; row < chromaHeight; row++) {
      for (int col = 0; col < chromaWidth; col++) {
        final vIndex = row * uvRowStride + col * uvPixelStride;
        final uIndex = row * uvRowStride + col * uvPixelStride;
        if (vIndex < vPlane.bytes.length) {
          nv21[offset++] = vPlane.bytes[vIndex];
        } else {
          offset++;
        }
        if (uIndex < uPlane.bytes.length) {
          nv21[offset++] = uPlane.bytes[uIndex];
        } else {
          offset++;
        }
      }
    }

    return nv21;
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

  // استخراج روشنایی مستقیم از صفحه‌ی Y (luminance) - کار می‌کند چه فرمت nv21 (تک-پلین)
  // باشد چه yuv420 (سه-پلین)، چون در هر دو حالت plane نخست همان صفحه‌ی Y است
  double _averageBrightnessYPlane(CameraImage image, _Roi roi) {
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
        final index = rowOffset + x;
        if (index < 0 || index >= bytes.length) continue;
        total += bytes[index];
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
        if (pixelOffset + 2 >= bytes.length) continue;
        final b = bytes[pixelOffset];
        final g = bytes[pixelOffset + 1];
        final r = bytes[pixelOffset + 2];
        total += 0.299 * r + 0.587 * g + 0.114 * b;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  // ثابت‌زمانی فیلتر پایین‌گذر: مقدار آلفا طوری انتخاب شده که فرکانس قطع تقریباً
  // ۳.۵ هرتز (معادل ۲۱۰ ضربه در دقیقه، بالاترین حد فیزیولوژیک قلب) باشد.
  // فرمول: alpha = dt / (RC + dt) که در آن RC = 1 / (2*pi*fc)
  static const double _lowPassCutoffHz = 3.5;
  double _filteredAcValue = 0;
  bool _filterInitialized = false;

  // === تشخیص لحظه‌ای قله (real-time peak detection) ===
  // به‌جای رسم مستقیم سیگنال خام فیلترشده (که دامنه‌اش نویزی و نامنظم است)،
  // هر ضربان واقعی را که در سیگنال رخ می‌دهد شناسایی می‌کنیم و یک شکل‌موج
  // استاندارد PPG (صعود تند + فرود نرم، با ارتفاع همیشه یکسان) را دقیقاً در
  // همان لحظه‌ی زمانی واقعی رسم می‌کنیم. این یعنی فاصله‌ی افقی قله‌ها همیشه
  // صادقانه از زمان‌بندی واقعی ضربان می‌آید، ولی ارتفاعشان یکنواخت و خوانا است.
  final List<double> _recentFilteredSamples = [];
  static const int _peakDetectWindow = 5; // نیم‌پنجره برای تشخیص کمینه/بیشینه‌ی محلی
  int _samplesSinceLastBeat = 999;
  static const int _minSamplesBetweenBeats =
      (sampleRate * 60) ~/ 220; // حداقل فاصله معادل سقف فیزیولوژیک ۲۲۰ BPM

  // فاز پالس مصنوعی در حال رسم (۰ = شروع صعود، ۱ = پایان یک سیکل کامل)
  double _pulsePhase = 1.0;
  double _pulseStepPerSample = 0.05;

  void _updateWaveform(double value) {
    _recentRawSamples.add(value);
    if (_recentRawSamples.length > _waveformShortWindow) {
      _recentRawSamples.removeAt(0);
    }
    final localMean =
        _recentRawSamples.reduce((a, b) => a + b) / _recentRawSamples.length;
    final acValue = value - localMean;

    // فیلتر پایین‌گذر تک‌قطبی (one-pole low-pass) برای حذف نویز فرکانس‌بالا
    // (لرزش دست، نویز حسگر) بدون از بین بردن شکل قله‌های ضربان قلب
    final dt = 1.0 / sampleRate;
    final rc = 1.0 / (2 * pi * _lowPassCutoffHz);
    final alpha = dt / (rc + dt);

    if (!_filterInitialized) {
      _filteredAcValue = acValue;
      _filterInitialized = true;
    } else {
      _filteredAcValue = _filteredAcValue + alpha * (acValue - _filteredAcValue);
    }

    // --- تشخیص قله‌ی محلی روی سیگنال فیلترشده ---
    _recentFilteredSamples.add(_filteredAcValue);
    if (_recentFilteredSamples.length > _peakDetectWindow * 2 + 1) {
      _recentFilteredSamples.removeAt(0);
    }
    _samplesSinceLastBeat++;

    bool beatDetected = false;
    if (_recentFilteredSamples.length == _peakDetectWindow * 2 + 1) {
      final mid = _recentFilteredSamples[_peakDetectWindow];
      bool isLocalMax = true;
      for (int i = 0; i < _recentFilteredSamples.length; i++) {
        if (i == _peakDetectWindow) continue;
        if (_recentFilteredSamples[i] > mid) {
          isLocalMax = false;
          break;
        }
      }
      // حداقل دامنه‌ی قابل‌قبول برای رد کردن نویز تخت (بدون سیگنال معنادار)
      final hasMeaningfulAmplitude = mid.abs() > 0.05;

      if (isLocalMax &&
          hasMeaningfulAmplitude &&
          _samplesSinceLastBeat >= _minSamplesBetweenBeats) {
        beatDetected = true;
        _samplesSinceLastBeat = 0;
      }
    }

    if (beatDetected) {
      // فاصله‌ی زمانی واقعی بین دو ضربان اخیر، سرعت رسم پالس بعدی را تعیین می‌کند
      // تا شکل قله همیشه یک اندازه بماند اما فاصله‌ی افقی صادقانه از زمان واقعی بیاید.
      final beatIntervalSamples = _samplesSinceLastBeat > 0
          ? _samplesSinceLastBeat
          : (sampleRate * 60 / (_heartRate > 0 ? _heartRate : 75)).round();
      _pulseStepPerSample =
          1.0 / max(6, min(60, beatIntervalSamples)).toDouble();
      _pulsePhase = 0.0;
    }

    // پیش‌بردن فاز پالس مصنوعی؛ وقتی به انتها برسد صاف (خط پایه) می‌ماند تا ضربان بعدی
    final pulseValue = _pulseShape(_pulsePhase);
    if (_pulsePhase < 1.0) {
      _pulsePhase = min(1.0, _pulsePhase + _pulseStepPerSample);
    }

    _waveformBuffer.removeAt(0);
    _waveformBuffer.add(pulseValue);
    _waveformNotifier.value = List<double>.from(_waveformBuffer);
  }

  // شکل استاندارد یک پالس PPG: صعود سریع تا قله، سپس فرود نرم‌تر با یک دندانه‌ی
  // کوچک ثانویه (dicrotic notch) شبیه موج واقعی نبض - ارتفاع همیشه ثابت (بین ۰ و ۱).
  double _pulseShape(double phase) {
    if (phase >= 1.0) return 0.0;
    if (phase < 0.18) {
      // صعود تند تا قله
      final t = phase / 0.18;
      return _easeOutCubic(t);
    } else if (phase < 0.45) {
      // فرود اولیه‌ی سریع بعد از قله
      final t = (phase - 0.18) / 0.27;
      return 1.0 - _easeInCubic(t) * 0.65;
    } else if (phase < 0.60) {
      // دندانه‌ی کوچک ثانویه (dicrotic notch) - مشخصه‌ی موج واقعی نبض
      final t = (phase - 0.45) / 0.15;
      return 0.35 + sin(t * pi) * 0.12;
    } else {
      // بازگشت نرم به خط پایه
      final t = (phase - 0.60) / 0.40;
      return (0.35 + sin(0.0)) * (1.0 - _easeOutCubic(t));
    }
  }

  double _easeOutCubic(double t) => 1 - pow(1 - t, 3).toDouble();
  double _easeInCubic(double t) => pow(t, 3).toDouble();

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

  int _calculateHeartRate(List<int> brightnessData, int fps) {
    if (brightnessData.length < 30) return 0;

    final raw = brightnessData.map((v) => v.toDouble()).toList();
    final smoothed = _smooth(raw, 1);
    final detrended = _detrend(smoothed, fps ~/ 2);

    if (detrended.every((v) => v == 0)) return 0;

    final stdDev = _standardDeviation(detrended);
    if (stdDev == 0) return 0;

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
    _watchdogTimer?.cancel();
    if (_isStreaming) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    _faceDetector.close();
    _waveformNotifier.dispose();
    _debugNotifier.dispose();
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'لطفاً در جای ثابت بنشینید\nو دوربین را به سمت صورت خود بگیرید',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildCameraPreview(),
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
              const SizedBox(height: 6),
              ValueListenableBuilder<String>(
                valueListenable: _debugNotifier,
                builder: (context, text, _) {
                  return Text(
                    text,
                    style: TextStyle(
                      fontSize: 11,
                      color: _debugError != null ? Colors.red : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 18),
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
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_initError != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(
            _initError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _initCamera,
            child: const Text('تلاش دوباره'),
          ),
        ],
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const CircularProgressIndicator();
    }

    return Stack(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }
}

// رسم موج زنده‌ی ضربان روی یک سطح تیره، شبیه مانیتورهای PPG
class _WaveformPainter extends CustomPainter {
  final List<double> data;
  const _WaveformPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      basePaint,
    );

    if (data.length < 2) return;

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

