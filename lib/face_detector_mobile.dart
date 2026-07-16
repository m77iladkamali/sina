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
  late final FaceDetector _detector;
 
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
 
  @override
  Future<List<FaceResult>> detectFaces(
      CameraImage image, CameraDescription camera) async {
    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return [];
 
    final faces = await _detector.processImage(inputImage);
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
      // توجه: در این نسخه‌ی ساده‌شده، وضعیت دستگاه از بیرون پاس داده نمی‌شود؛
      // در main.dart نسخه‌ی کامل، مقدار واقعی deviceOrientation از کنترلر خوانده می‌شود.
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
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
 
    int offset = 0;
    for (int row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }
 
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
 
  @override
  Future<void> dispose() async {
    await _detector.close();
  }
}
 
