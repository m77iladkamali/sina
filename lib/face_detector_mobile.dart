import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'face_detector_interface.dart';

/// پیاده‌سازی موبایل (اندروید/iOS) با Google ML Kit.
/// این فایل فقط زمانی import و استفاده می‌شود که برنامه روی اندروید یا iOS اجرا شود
/// (تصمیم‌گیری در main.dart با بررسی Platform.isAndroid/isIOS انجام می‌گیرد).
class MobileFaceDetectorService implements FaceDetectorService {
  // به‌صورت nullable نگه می‌داریم (به‌جای late final) تا اگر initialize شکست
  // بخورد یا اصلاً صدا زده نشود، dispose بی‌خطر بماند و LateInitializationError
  // نگیرد.
  FaceDetector? _detector;

  // آخرین جهت دستگاه که از بیرون به‌روزرسانی شده. برای محاسبه‌ی درست
  // rotationCompensation در اندروید ضروری است. پیش‌فرض portraitUp چون
  // برنامه‌های سلامت معمولاً در این حالت استفاده می‌شوند.
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  Future<void> initialize() async {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableTracking: false,
      ),
    );
  }

  /// از main.dart باید هر بار که جهت دستگاه تغییر می‌کند صدا زده شود، مثلاً
  /// در NativeDeviceOrientationCommunicator یا با گوش دادن به تغییرات
  /// _controller.value.deviceOrientation. اگر صدا زده نشود، پیش‌فرض
  /// portraitUp استفاده می‌شود که برای اکثر موارد کافی است.
  void updateDeviceOrientation(DeviceOrientation orientation) {
    _deviceOrientation = orientation;
  }

  @override
  Future<List<FaceResult>> detectFaces(
      CameraImage image, CameraDescription camera) async {
    final detector = _detector;
    if (detector == null) return const [];

    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return const [];

    final faces = await detector.processImage(inputImage);
    return faces
        .map((f) => FaceResult(
              left: f.boundingBox.left,
              top: f.boundingBox.top,
              width: f.boundingBox.width,
              height: f.boundingBox.height,
              leftEyeOpenProbability: f.leftEyeOpenProbability,
              rightEyeOpenProbability: f.rightEyeOpenProbability,
            ))
        .toList();
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // فرمول استاندارد ML Kit برای اندروید:
      //   Front:  (sensorOrientation + deviceRotation) % 360
      //   Back:   (sensorOrientation - deviceRotation + 360) % 360
      // نسخه‌ی قبلی این‌جا rotationCompensation = 0 گذاشته بود که کل معادله را
      // به sensorOrientation ساده می‌کرد و روی چرخش دستگاه از کار می‌افتاد.
      final deviceRotation = _orientations[_deviceOrientation] ?? 0;
      int rotationCompensation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + deviceRotation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - deviceRotation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

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
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height ~/ 2));

    // کپی صفحه‌ی Y
    int offset = 0;
    for (int row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    // برای NV21 لازم است V و U به‌ترتیب (V اول، بعد U) در هم بافته شوند.
    // stride را برای هر پلن جداگانه می‌خوانیم چون روی بعضی دستگاه‌های اندروید
    // U و V می‌توانند stride متفاوت داشته باشند - استفاده از stride یکی از آن‌ها
    // برای هر دو، روی آن دستگاه‌ها تصویر خراب می‌کند.
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final chromaHeight = height ~/ 2;
    final chromaWidth = width ~/ 2;

    for (int row = 0; row < chromaHeight; row++) {
      for (int col = 0; col < chromaWidth; col++) {
        final vIndex = row * vRowStride + col * vPixelStride;
        final uIndex = row * uRowStride + col * uPixelStride;
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

  @override
  Future<void> dispose() async {
    // اگر initialize شکست خورده باشد یا صدا زده نشده باشد، _detector همچنان
    // null است و این‌جا هیچ کاری انجام نمی‌شود - جلوگیری از LateInitializationError.
    await _detector?.close();
    _detector = null;
  }
}
