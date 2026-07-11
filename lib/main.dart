import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

// ==============================
// ۱. تعریف Stateها (بدون تغییر)
// ==============================
abstract class RppgState extends Equatable {
  const RppgState();
  @override
  List<Object?> get props => [];
}

class RppgInitial extends RppgState {}

class RppgLoading extends RppgState {}

class RppgMonitoring extends RppgState {
  final int bpm;
  final List<double> signalData;
  final String quality;
  final List<String> alerts;
  final bool faceDetected;
  final Rect? faceRect;
  final Rect? foreheadRect;

  const RppgMonitoring({
    required this.bpm,
    required this.signalData,
    required this.quality,
    this.alerts = const [],
    this.faceDetected = false,
    this.faceRect,
    this.foreheadRect,
  });

  @override
  List<Object?> get props =>
      [bpm, signalData, quality, alerts, faceDetected, faceRect, foreheadRect];

  RppgMonitoring copyWith({
    int? bpm,
    List<double>? signalData,
    String? quality,
    List<String>? alerts,
    bool? faceDetected,
    Rect? faceRect,
    Rect? foreheadRect,
  }) {
    return RppgMonitoring(
      bpm: bpm ?? this.bpm,
      signalData: signalData ?? this.signalData,
      quality: quality ?? this.quality,
      alerts: alerts ?? this.alerts,
      faceDetected: faceDetected ?? this.faceDetected,
      faceRect: faceRect ?? this.faceRect,
      foreheadRect: foreheadRect ?? this.foreheadRect,
    );
  }
}

// ==============================
// ۲. Cubit (منطق اصلی)
// ==============================
class RppgCubit extends Cubit<RppgState> {
  CameraController? _cameraController;
  StreamSubscription<CameraImage>? _imageSubscription;
  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  // ========== بافرهای سیگنال ==========
  static const int bufferSize = 300; // ۳۰۰ فریم ≈ ۱۰ ثانیه با ۳۰ فریم
  final List<double> _signalBuffer = List.filled(bufferSize, 0.0);
  int _bufferIndex = 0;
  bool _bufferFull = false;

  // ========== پارامترهای rPPG ==========
  static const double minBPM = 45;
  static const double maxBPM = 200;
  static const double sampleRate = 30.0; // فریم بر ثانیه

  // ========== آمار کیفیت ==========
  double _snr = 0.0;
  int _motionCounter = 0;
  double _avgBrightness = 0.0;

  RppgCubit() : super(RppgInitial());

  // ==============================================
  // شروع اندازه‌گیری (بدون تغییر)
  // ==============================================
  Future<void> startMonitoring() async {
    try {
      emit(RppgLoading());

      // مجوز دوربین
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        emit(RppgInitial());
        return;
      }

      // راه‌اندازی دوربین جلو
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.locked);
      await _cameraController!.setExposureMode(ExposureMode.locked);

      // مقداردهی اولیه تشخیص چهره (مدل دوربین جلو)
      _faceDetector = FaceDetector();
      await _faceDetector!.initialize(model: FaceDetectionModel.frontCamera);

      // شروع استریم دوربین
      _imageSubscription = _cameraController!.startImageStream((image) {
        _processFrame(image);
      });

      emit(const RppgMonitoring(
        bpm: 0,
        signalData: [],
        quality: '--',
        alerts: [],
        faceDetected: false,
      ));
    } catch (e) {
      debugPrint('Error: $e');
      emit(RppgInitial());
    }
  }

  // ==============================================
  // پردازش هر فریم (بدون تغییر ساختار)
  // ==============================================
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _faceDetector == null) return;
    _isProcessing = true;

    try {
      // ۱. تبدیل YUV به RGB با استفاده از کد Dart خالص
      final rgbData = _convertYUVtoRGB(image);
      if (rgbData == null) return;

      // ۲. تشخیص چهره و استخراج ناحیه پیشانی
      final result = await _faceDetector!.runAll(rgbData);
      final detections = result.detections;

      if (detections.isEmpty) {
        // چهره‌ای تشخیص داده نشد
        if (state is RppgMonitoring) {
          final current = state as RppgMonitoring;
          emit(current.copyWith(
            faceDetected: false,
            alerts: ['😔 چهره‌ای تشخیص داده نشد'],
          ));
        }
        return;
      }

      // اولین چهره را انتخاب کن
      final detection = detections.first;
      final faceRect = detection.bbox.toRect(
        Size(image.width.toDouble(), image.height.toDouble()),
      );

      // ۳. محاسبه ناحیه پیشانی (۲۵٪ بالای صورت)
      final foreheadRect = Rect.fromLTRB(
        faceRect.left + faceRect.width * 0.15,
        faceRect.top,
        faceRect.right - faceRect.width * 0.15,
        faceRect.top + faceRect.height * 0.20,
      );

      // ۴. استخراج سیگنال rPPG از ناحیه پیشانی
      final signal = _extractSignal(rgbData, image.width, image.height, foreheadRect);

      // ۵. اضافه کردن به بافر و پردازش
      _addToBuffer(signal);

      // ۶. محاسبه کیفیت و هشدارها
      _calculateQuality(detection, foreheadRect);

      // ۷. اگر بافر پر شد، BPM را محاسبه کن
      int bpm = 0;
      List<double> chartData = [];
      if (_bufferFull) {
        bpm = _calculateBPM();
        chartData = _getSignalForChart();
      }

      // ۸. به‌روزرسانی UI
      if (state is RppgMonitoring) {
        final current = state as RppgMonitoring;
        emit(RppgMonitoring(
          bpm: bpm,
          signalData: chartData,
          quality: _getQualityString(),
          alerts: _getAlerts(),
          faceDetected: true,
          faceRect: faceRect,
          foreheadRect: foreheadRect,
        ));
      }
    } catch (e) {
      debugPrint('Process error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ==============================================
  // تبدیل YUV به RGB (با فرمول‌های استاندارد - بدون نیاز به yuv_ffi)
  // ==============================================
  Uint8List? _convertYUVtoRGB(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      // استخراج پلن‌ها
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;

      // پارامترهای stride
      final yRowStride = yPlane.bytesPerRow;
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 2;

      // خروجی RGB (RGBA)
      final rgba = Uint8List(width * height * 4);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          // موقعیت در پلن Y
          final yIndex = y * yRowStride + x;
          // موقعیت در پلن‌های UV
          final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          final yVal = yBytes[yIndex];
          final uVal = uBytes[uvIndex];
          final vVal = vBytes[uvIndex];

          // تبدیل YUV به RGB (فرمول استاندارد)
          int r = (yVal + 1.402 * (vVal - 128)).round();
          int g = (yVal - 0.344 * (uVal - 128) - 0.714 * (vVal - 128)).round();
          int b = (yVal + 1.772 * (uVal - 128)).round();

          // محدود کردن به 0-255
          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          final idx = (y * width + x) * 4;
          rgba[idx] = r;
          rgba[idx + 1] = g;
          rgba[idx + 2] = b;
          rgba[idx + 3] = 255; // alpha
        }
      }
      return rgba;
    } catch (e) {
      debugPrint('YUV conversion error: $e');
      return null;
    }
  }

  // ==============================================
  // استخراج سیگنال rPPG با الگوریتم POS (بدون تغییر)
  // ==============================================
  double _extractSignal(
    Uint8List rgbData,
    int width,
    int height,
    Rect forehead,
  ) {
    // محدود کردن ناحیه به اندازه تصویر
    final x1 = forehead.left.clamp(0, width - 1).toInt();
    final y1 = forehead.top.clamp(0, height - 1).toInt();
    final x2 = forehead.right.clamp(0, width - 1).toInt();
    final y2 = forehead.bottom.clamp(0, height - 1).toInt();

    if (x1 >= x2 || y1 >= y2) return 0.0;

    double sumR = 0, sumG = 0, sumB = 0;
    int count = 0;

    for (int y = y1; y < y2; y++) {
      for (int x = x1; x < x2; x++) {
        final index = (y * width + x) * 4;
        sumR += rgbData[index];
        sumG += rgbData[index + 1];
        sumB += rgbData[index + 2];
        count++;
      }
    }

    if (count == 0) return 0.0;

    final avgR = sumR / count;
    final avgG = sumG / count;
    final avgB = sumB / count;

    const double alpha = 0.5;
    double posSignal = avgG - alpha * avgB;

    _avgBrightness = (avgR + avgG + avgB) / 3;

    return posSignal;
  }

  // ==============================================
  // مدیریت بافر سیگنال (بدون تغییر)
  // ==============================================
  void _addToBuffer(double signal) {
    _signalBuffer[_bufferIndex] = signal;
    _bufferIndex = (_bufferIndex + 1) % bufferSize;

    if (_bufferIndex == 0) {
      _bufferFull = true;
    }
  }

  // ==============================================
  // محاسبه BPM با FFT (پیاده‌سازی ساده بدون کتابخانه خارجی)
  // ==============================================
  int _calculateBPM() {
    if (!_bufferFull) return 0;

    // ۱. آماده‌سازی داده
    final n = bufferSize;
    final signal = Float32List(n);

    // کپی کردن داده‌ها از بافر (به ترتیب)
    for (int i = 0; i < n; i++) {
      final idx = (_bufferIndex + i) % n;
      signal[i] = _signalBuffer[idx].toFloat();
    }

    // ۲. حذف DC (میانگین‌گیری)
    double mean = 0;
    for (int i = 0; i < n; i++) mean += signal[i];
    mean /= n;
    for (int i = 0; i < n; i++) signal[i] -= mean;

    // ۳. پنجره هانینگ (کاهش نشتی طیفی)
    for (int i = 0; i < n; i++) {
      final double hann = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      signal[i] *= hann;
    }

    // ۴. اجرای FFT (حقیقی) با استفاده از تابع custom
    final freqData = _fftReal(signal);

    // ۵. پیدا کردن فرکانس غالب در محدوده BPM
    double maxMagnitude = 0;
    int maxIndex = -1;

    // محدوده فرکانس: ۰.۷۵ تا ۳.۳ هرتز (۴۵ تا ۲۰۰ BPM)
    final minFreq = minBPM / 60.0;
    final maxFreq = maxBPM / 60.0;
    final minBin = (minFreq * n / sampleRate).round();
    final maxBin = (maxFreq * n / sampleRate).round();

    final halfN = n ~/ 2;
    for (int i = minBin; i < maxBin && i < halfN; i++) {
      final real = freqData[2 * i];
      final imag = freqData[2 * i + 1];
      final mag = sqrt(real * real + imag * imag);

      if (mag > maxMagnitude) {
        maxMagnitude = mag;
        maxIndex = i;
      }
    }

    if (maxIndex == -1) return 0;

    // ۶. محاسبه BPM از فرکانس غالب
    final dominantFreq = (maxIndex * sampleRate) / n;
    final bpm = (dominantFreq * 60).round();

    // ۷. محاسبه SNR (نسبت سیگنال به نویز)
    double totalPower = 0;
    double signalPower = 0;
    final peakBin = maxIndex;

    for (int i = 0; i < halfN; i++) {
      final real = freqData[2 * i];
      final imag = freqData[2 * i + 1];
      final mag = sqrt(real * real + imag * imag);
      totalPower += mag * mag;

      if ((i - peakBin).abs() <= 2) {
        signalPower += mag * mag;
      }
    }

    _snr = 10 * log10(signalPower / max(totalPower - signalPower, 1e-10));

    return bpm.clamp(0, 250);
  }

  // ==============================================
  // پیاده‌سازی FFT برای اعداد حقیقی (Cooley-Tukey)
  // ==============================================
  Float32List _fftReal(Float32List real) {
    final n = real.length;
    if (n < 2) return Float32List(2); // بازگشت با اندازه ۲ برای پوشش

    // تبدیل به عدد مختلط (با قسمت موهومی صفر)
    final complex = Float32List(2 * n);
    for (int i = 0; i < n; i++) {
      complex[2 * i] = real[i];
      complex[2 * i + 1] = 0.0;
    }

    // اجرای FFT مختلط
    _fft(complex, n);

    // بازگشت داده مختلط
    return complex;
  }

  void _fft(Float32List data, int n) {
    if (n <= 1) return;

    // تقسیم به زوج و فرد
    final even = Float32List(n ~/ 2 * 2);
    final odd = Float32List(n ~/ 2 * 2);
    for (int i = 0; i < n ~/ 2; i++) {
      even[2 * i] = data[4 * i];
      even[2 * i + 1] = data[4 * i + 1];
      odd[2 * i] = data[4 * i + 2];
      odd[2 * i + 1] = data[4 * i + 3];
    }

    // بازگشت
    _fft(even, n ~/ 2);
    _fft(odd, n ~/ 2);

    // ترکیب
    for (int k = 0; k < n ~/ 2; k++) {
      final theta = -2 * pi * k / n;
      final cosTheta = cos(theta);
      final sinTheta = sin(theta);

      final realOdd = odd[2 * k];
      final imagOdd = odd[2 * k + 1];

      final realTwiddle = realOdd * cosTheta - imagOdd * sinTheta;
      final imagTwiddle = realOdd * sinTheta + imagOdd * cosTheta;

      final realEven = even[2 * k];
      final imagEven = even[2 * k + 1];

      data[2 * k] = realEven + realTwiddle;
      data[2 * k + 1] = imagEven + imagTwiddle;

      data[2 * (k + n ~/ 2)] = realEven - realTwiddle;
      data[2 * (k + n ~/ 2) + 1] = imagEven - imagTwiddle;
    }
  }

  // ==============================================
  // گرفتن داده برای نمودار (بدون تغییر)
  // ==============================================
  List<double> _getSignalForChart() {
    const int chartSize = 150;
    final List<double> data = [];

    for (int i = 0; i < chartSize; i++) {
      final idx = (_bufferIndex - chartSize + i) % bufferSize;
      if (idx < 0) continue;
      data.add(_signalBuffer[idx]);
    }

    // نرمال‌سازی برای نمایش بهتر
    if (data.isEmpty) return [];
    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    final range = maxVal - minVal;

    if (range > 0.001) {
      for (int i = 0; i < data.length; i++) {
        data[i] = ((data[i] - minVal) / range) * 2 - 1;
      }
    }

    return data;
  }

  // ==============================================
  // محاسبه کیفیت و هشدارها (بدون تغییر)
  // ==============================================
  void _calculateQuality(FaceDetectionResult detection, Rect foreheadRect) {
    final centerX = detection.bbox.center.dx;
    final centerY = detection.bbox.center.dy;

    if (centerX < 0.1 || centerX > 0.9 || centerY < 0.1 || centerY > 0.9) {
      _motionCounter++;
    } else {
      _motionCounter = max(0, _motionCounter - 1);
    }
  }

  String _getQualityString() {
    if (_snr > 8 && _motionCounter < 5 && _avgBrightness > 50 && _avgBrightness < 220) {
      return 'Good';
    } else if (_snr > 4 && _motionCounter < 15 && _avgBrightness > 30 && _avgBrightness < 240) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  List<String> _getAlerts() {
    final List<String> alerts = [];

    if (_motionCounter > 10) {
      alerts.add('⚠️ حرکت زیاد سر');
    }

    if (_avgBrightness < 40) {
      alerts.add('💡 نور محیط کم است');
    } else if (_avgBrightness > 230) {
      alerts.add('☀️ نور محیط زیاد است');
    }

    if (_snr < 2 && _bufferFull) {
      alerts.add('📶 سیگنال ضعیف');
    }

    return alerts;
  }

  // ==============================================
  // توقف اندازه‌گیری (بدون تغییر)
  // ==============================================
  void stopMonitoring() {
    _imageSubscription?.cancel();
    _cameraController?.dispose();
    _faceDetector?.dispose();
    emit(RppgInitial());
  }

  @override
  Future<void> close() {
    stopMonitoring();
    return super.close();
  }
}

// ==============================
// ۳. ویجت‌های UI (بدون تغییر)
// ==============================
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
      ),
      home: BlocProvider(
        create: (_) => RppgCubit(),
        child: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<RppgCubit, RppgState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is RppgLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              // دوربین
              if (state is RppgMonitoring)
                _buildCameraPreview(context)
              else
                Container(color: Colors.black),

              // لایه رویی
              if (state is RppgMonitoring) ...[
                if (state.faceDetected && state.faceRect != null)
                  Positioned(
                    left: state.faceRect!.left,
                    top: state.faceRect!.top,
                    width: state.faceRect!.width,
                    height: state.faceRect!.height,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (state.faceDetected && state.foreheadRect != null)
                  Positioned(
                    left: state.foreheadRect!.left,
                    top: state.foreheadRect!.top,
                    width: state.foreheadRect!.width,
                    height: state.foreheadRect!.height,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                _buildOverlay(context, state),
              ],
              if (state is RppgInitial)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.read<RppgCubit>().startMonitoring(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('شروع اندازه‌گیری ضربان'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPreview(BuildContext context) {
    final cubit = context.read<RppgCubit>();
    if (cubit._cameraController == null ||
        !cubit._cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(cubit._cameraController!);
  }

  Widget _buildOverlay(BuildContext context, RppgMonitoring state) {
    return SafeArea(
      child: Column(
        children: [
          if (state.alerts.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                children: state.alerts
                    .map((alert) => Text(alert, style: const TextStyle(fontSize: 14)))
                    .toList(),
              ),
            ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      state.bpm > 0 ? state.bpm.toString() : '--',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        shadows: [
                          Shadow(
                              blurRadius: 20,
                              color: Colors.redAccent,
                              offset: Offset(0, 0))
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16, left: 4),
                      child: Text('BPM', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.quality == 'Good'
                        ? Colors.green
                        : state.quality == 'Fair'
                            ? Colors.orange
                            : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'کیفیت: ${state.quality}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                if (state.signalData.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: state.signalData
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: true,
                            color: Colors.redAccent,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.redAccent.withOpacity(0.2),
                            ),
                          ),
                        ],
                        minX: 0,
                        maxX: state.signalData.length - 1.toDouble(),
                        minY: -1.2,
                        maxY: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: ElevatedButton.icon(
              onPressed: () => context.read<RppgCubit>().stopMonitoring(),
              icon: const Icon(Icons.stop),
              label: const Text('توقف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
