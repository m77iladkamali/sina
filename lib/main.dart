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
// ۱. State‌ها
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

  @override
  List<Object?> get props =>
      [bpm, signalData, quality, alerts, faceDetected, faceRect, foreheadRect];
}

// ==============================
// ۲. Cubit
// ==============================
class RppgCubit extends Cubit<RppgState> {
  CameraController? _cameraController;
  StreamSubscription<CameraImage>? _imageSubscription;
  final StreamController<CameraImage> _imageStreamController =
      StreamController<CameraImage>.broadcast();
  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  static const int bufferSize = 256;
  final List<double> _signalBuffer = List.filled(bufferSize, 0.0);
  int _bufferIndex = 0;
  bool _bufferFull = false;

  static const double minBPM = 45;
  static const double maxBPM = 200;
  static const double sampleRate = 30.0;

  double _snr = 0.0;
  int _motionCounter = 0;
  double _avgBrightness = 0.0;

  RppgCubit() : super(RppgInitial());

  // =========================== شروع ===========================
  Future<void> startMonitoring() async {
    try {
      emit(RppgLoading());

      final status = await Permission.camera.request();
      if (!status.isGranted) {
        emit(RppgInitial());
        return;
      }

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

      _faceDetector = FaceDetector();
      await _faceDetector!.initialize(model: FaceDetectionModel.frontCamera);

      // راه‌اندازی استریم تصاویر از دوربین
      _cameraController!.startImageStream((image) {
        _imageStreamController.add(image);
      });

      _imageSubscription = _imageStreamController.stream.listen((image) {
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

  // =========================== پردازش فریم ===========================
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _faceDetector == null) return;
    _isProcessing = true;

    try {
      final rgbData = _convertYUVtoRGB(image);
      if (rgbData == null) return;

      // استفاده از detectFromImage (نسخه ۴)
      final detections = await _faceDetector!.detectFromImage(
        rgbData,
        image.width,
        image.height,
      );

      if (detections.isEmpty) {
        if (state is RppgMonitoring) {
          final current = state as RppgMonitoring;
          emit(current.copyWith(
            faceDetected: false,
            alerts: ['😔 چهره‌ای تشخیص داده نشد'],
          ));
        }
        return;
      }

      final detection = detections.first;
      final bbox = detection.boundingBox; // List<double> [x1, y1, x2, y2]
      final faceRect = Rect.fromLTRB(
        bbox[0] * image.width,
        bbox[1] * image.height,
        bbox[2] * image.width,
        bbox[3] * image.height,
      );

      final foreheadRect = Rect.fromLTRB(
        faceRect.left + faceRect.width * 0.15,
        faceRect.top,
        faceRect.right - faceRect.width * 0.15,
        faceRect.top + faceRect.height * 0.20,
      );

      final signal = _extractSignal(rgbData, image.width, image.height, foreheadRect);
      _addToBuffer(signal);

      _calculateQuality(detection, image.width, image.height);

      int bpm = 0;
      List<double> chartData = [];
      if (_bufferFull) {
        bpm = _calculateBPM();
        chartData = _getSignalForChart();
      }

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

  // =========================== تبدیل YUV -> RGB ===========================
  Uint8List? _convertYUVtoRGB(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel!;

      final Uint8List rgba = Uint8List(width * height * 4);
      int rgbaIndex = 0;

      for (int y = 0; y < height; y++) {
        final int yIndex = y * yRowStride;
        final int uvIndex = (y ~/ 2) * uvRowStride;

        for (int x = 0; x < width; x++) {
          final int yValue = yBytes[yIndex + x];
          final int uvX = (x ~/ 2) * uvPixelStride;
          final int u = uBytes[uvIndex + uvX] - 128;
          final int v = vBytes[uvIndex + uvX] - 128;

          int r = (yValue + 1.402 * v).round();
          int g = (yValue - 0.344 * u - 0.714 * v).round();
          int b = (yValue + 1.772 * u).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          rgba[rgbaIndex++] = r;
          rgba[rgbaIndex++] = g;
          rgba[rgbaIndex++] = b;
          rgba[rgbaIndex++] = 255;
        }
      }
      return rgba;
    } catch (e) {
      debugPrint('YUV conversion error: $e');
      return null;
    }
  }

  // =========================== استخراج سیگنال POS ===========================
  double _extractSignal(
    Uint8List rgbData,
    int width,
    int height,
    Rect forehead,
  ) {
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
    final posSignal = avgG - alpha * avgB;
    _avgBrightness = (avgR + avgG + avgB) / 3;

    return posSignal;
  }

  // =========================== بافر ===========================
  void _addToBuffer(double signal) {
    _signalBuffer[_bufferIndex] = signal;
    _bufferIndex = (_bufferIndex + 1) % bufferSize;
    if (_bufferIndex == 0) _bufferFull = true;
  }

  // =========================== محاسبه BPM با FFT ===========================
  int _calculateBPM() {
    if (!_bufferFull) return 0;

    final n = bufferSize;
    final signal = Float32List(n);

    for (int i = 0; i < n; i++) {
      final idx = (_bufferIndex + i) % n;
      signal[i] = _signalBuffer[idx];
    }

    // حذف DC
    double mean = 0;
    for (int i = 0; i < n; i++) mean += signal[i];
    mean /= n;
    for (int i = 0; i < n; i++) signal[i] -= mean;

    // پنجره هانینگ
    for (int i = 0; i < n; i++) {
      final double hann = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      signal[i] *= hann;
    }

    // FFT
    final List<Complex> complexSignal = List.generate(n, (i) => Complex(signal[i], 0.0));
    final fftResult = fft(complexSignal);
    final magnitudes = fftResult.map((c) => c.magnitude()).toList();

    final minFreq = minBPM / 60.0;
    final maxFreq = maxBPM / 60.0;
    final minBin = (minFreq * n / sampleRate).round();
    final maxBin = (maxFreq * n / sampleRate).round();

    int peakBin = -1;
    double maxMag = -1;
    for (int i = minBin; i <= maxBin && i < n ~/ 2; i++) {
      if (magnitudes[i] > maxMag) {
        maxMag = magnitudes[i];
        peakBin = i;
      }
    }

    if (peakBin == -1) return 0;

    final dominantFreq = (peakBin * sampleRate) / n;
    final bpm = (dominantFreq * 60).round();

    // محاسبه SNR
    double totalPower = 0;
    double signalPower = 0;
    for (int i = 0; i < n ~/ 2; i++) {
      final mag = magnitudes[i];
      totalPower += mag * mag;
      if ((i - peakBin).abs() <= 2) {
        signalPower += mag * mag;
      }
    }
    final noisePower = totalPower - signalPower;
    if (noisePower > 0) {
      _snr = 10 * log(signalPower / noisePower) / ln10;
    } else {
      _snr = 20.0;
    }

    return bpm.clamp(0, 250);
  }

  // =========================== داده‌های نمودار ===========================
  List<double> _getSignalForChart() {
    const int chartSize = 150;
    final List<double> data = [];

    for (int i = 0; i < chartSize; i++) {
      final idx = (_bufferIndex - chartSize + i) % bufferSize;
      if (idx < 0) continue;
      data.add(_signalBuffer[idx]);
    }

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

  // =========================== کیفیت و هشدارها ===========================
  void _calculateQuality(dynamic detection, int width, int height) {
    final bbox = detection.boundingBox as List<double>;
    final centerX = (bbox[0] + bbox[2]) / 2;
    final centerY = (bbox[1] + bbox[3]) / 2;

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
    if (_motionCounter > 10) alerts.add('⚠️ حرکت زیاد سر');
    if (_avgBrightness < 40) alerts.add('💡 نور محیط کم است');
    if (_avgBrightness > 230) alerts.add('☀️ نور محیط زیاد است');
    if (_snr < 2 && _bufferFull) alerts.add('📶 سیگنال ضعیف');
    return alerts;
  }

  // =========================== توقف ===========================
  void stopMonitoring() {
    _imageSubscription?.cancel();
    _imageStreamController.close();
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
// ۳. کلاس Complex و FFT
// ==============================
class Complex {
  final double real;
  final double imag;
  Complex(this.real, this.imag);

  Complex operator +(Complex other) => Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) => Complex(real - other.real, imag - other.imag);
  Complex operator *(Complex other) => Complex(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  double magnitude() => sqrt(real * real + imag * imag);
}

List<Complex> fft(List<Complex> input) {
  final n = input.length;
  if (n <= 1) return input;
  if (n % 2 != 0) throw ArgumentError('FFT length must be power of 2');

  final even = fft(List.generate(n ~/ 2, (i) => input[2 * i]));
  final odd = fft(List.generate(n ~/ 2, (i) => input[2 * i + 1]));

  final result = List<Complex>.filled(n, Complex(0, 0));
  for (int k = 0; k < n ~/ 2; k++) {
    final angle = -2 * pi * k / n;
    final twiddle = Complex(cos(angle), sin(angle));
    final oddPart = odd[k] * twiddle;
    result[k] = even[k] + oddPart;
    result[k + n ~/ 2] = even[k] - oddPart;
  }
  return result;
}

// ==============================
// ۴. ویجت‌های UI (بدون تغییر)
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
              if (state is RppgMonitoring)
                _buildCameraPreview(context)
              else
                Container(color: Colors.black),

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
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
