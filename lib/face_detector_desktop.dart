import 'dart:math';
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart' as tfl;
import 'face_detector_interface.dart';
 
/// پیاده‌سازی دسکتاپ (ویندوز/مک/لینوکس) با face_detection_tflite.
/// این پکیج probability باز/بسته بودن چشم را مستقیم نمی‌دهد (برخلاف ML Kit)،
/// پس این کلاس با استفاده از eye mesh (نقاط پلک بالا/پایین) خودش نسبت EAR
/// (Eye Aspect Ratio) را محاسبه و به همان مقیاس ۰ تا ۱ نگاشت می‌کند تا کد
/// بالادستی (تشخیص پلک در main.dart) بدون تغییر با هر دو پلتفرم کار کند.
class DesktopFaceDetectorService implements FaceDetectorService {
  late final tfl.FaceDetector _detector;
 
  @override
  Future<void> initialize() async {
    _detector = await tfl.FaceDetector.create(
      model: tfl.FaceDetectionModel.frontCamera,
    );
  }
 
  @override
  Future<List<FaceResult>> detectFaces(
      CameraImage image, CameraDescription camera) async {
    final faces = await _detector.detectFacesFromCameraImage(
      image,
      mode: tfl.FaceDetectionMode.full, // full برای دسترسی به eyes (لازم برای EAR)
      maxDim: 640,
    );
 
    return faces.map((f) {
      final box = f.boundingBox;
      double? leftProb;
      double? rightProb;
 
      final eyes = f.eyes;
      if (eyes != null) {
        leftProb = _eyeOpenProbabilityFromMesh(eyes.leftEye);
        rightProb = _eyeOpenProbabilityFromMesh(eyes.rightEye);
      }
 
      return FaceResult(
        left: box.topLeft.x,
        top: box.topLeft.y,
        width: box.width,
        height: box.height,
        leftEyeOpenProbability: leftProb,
        rightEyeOpenProbability: rightProb,
      );
    }).toList();
  }
 
  /// محاسبه‌ی EAR (Eye Aspect Ratio) از نقاط کانتور پلک و نگاشت آن به یک مقدار
  /// شبه-probability بین ۰ (کاملاً بسته) و ۱ (کاملاً باز)، هم‌مقیاس با خروجی ML Kit.
  double? _eyeOpenProbabilityFromMesh(tfl.Eye? eye) {
    if (eye == null || eye.contour.length < 15) return null;
 
    final contour = eye.contour;
    // نقاط تقریبی بالا/پایین و گوشه‌های چپ/راست پلک بر اساس چیدمان استاندارد
    // خروجی این پکیج (۱۵ نقطه‌ی کانتور پلک)
    final leftCorner = contour[0];
    final rightCorner = contour[8];
    final topMid = contour[4];
    final bottomMid = contour[12];
 
    final horizontalDist = _distance(leftCorner.x, leftCorner.y, rightCorner.x, rightCorner.y);
    final verticalDist = _distance(topMid.x, topMid.y, bottomMid.x, bottomMid.y);
 
    if (horizontalDist == 0) return null;
    final ear = verticalDist / horizontalDist;
 
    // مقادیر مرجع تجربی: EAR ~0.28-0.35 برای چشم کاملاً باز، ~0.05-0.1 برای بسته.
    // نگاشت خطی به بازه‌ی ۰..۱ با کلمپ کردن، مشابه دامنه‌ی probability در ML Kit.
    const earClosed = 0.08;
    const earOpen = 0.30;
    final normalized = (ear - earClosed) / (earOpen - earClosed);
    return normalized.clamp(0.0, 1.0);
  }
 
  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }
 
  @override
  Future<void> dispose() async {
    await _detector.dispose();
  }
}
 
