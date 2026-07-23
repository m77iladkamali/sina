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
  // به‌صورت nullable نگه می‌داریم (به‌جای late final) تا اگر initialize شکست
  // بخورد یا اصلاً صدا زده نشود، dispose بی‌خطر بماند و LateInitializationError
  // نگیرد. late final وقتی که ممکن است initialize شکست بخورد امن نیست.
  tfl.FaceDetector? _detector;

  // حداقل تعداد نقاط لازم برای محاسبه‌ی EAR: باید بزرگ‌ترین شاخصی که استفاده
  // می‌کنیم (topMid یا bottomMid) در بازه‌ی معتبر قرار بگیرد.
  static const int _leftCornerIdx = 0;
  static const int _rightCornerIdx = 8;
  static const int _topMid1Idx = 3;
  static const int _topMid2Idx = 5;
  static const int _bottomMid1Idx = 11;
  static const int _bottomMid2Idx = 13;
  static const int _minContourPoints = _bottomMid2Idx + 1; // ۱۴

  // نگاشت خطی EAR به بازه‌ی ۰..۱ (مشابه probability در ML Kit)
  static const double _earClosed = 0.08;
  static const double _earOpen = 0.30;

  @override
  Future<void> initialize() async {
    _detector = await tfl.FaceDetector.create(
      model: tfl.FaceDetectionModel.frontCamera,
    );
  }

  @override
  Future<List<FaceResult>> detectFaces(
      CameraImage image, CameraDescription camera) async {
    final detector = _detector;
    if (detector == null) return const [];

    final faces = await detector.detectFacesFromCameraImage(
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
  ///
  /// از فرمول استاندارد EAR استفاده می‌شود که میانگین دو فاصله‌ی عمودی را
  /// می‌گیرد - این نسبت به داشتن یک فاصله‌ی عمودی، در برابر کج بودن سر و نویز
  /// نقاط landmark مقاوم‌تر است:
  ///
  ///   EAR = (|p_top1 - p_bot1| + |p_top2 - p_bot2|) / (2 * |p_left - p_right|)
  double? _eyeOpenProbabilityFromMesh(tfl.Eye? eye) {
    if (eye == null || eye.contour.length < _minContourPoints) return null;

    final contour = eye.contour;
    final leftCorner = contour[_leftCornerIdx];
    final rightCorner = contour[_rightCornerIdx];
    final topMid1 = contour[_topMid1Idx];
    final topMid2 = contour[_topMid2Idx];
    final bottomMid1 = contour[_bottomMid1Idx];
    final bottomMid2 = contour[_bottomMid2Idx];

    final horizontalDist = _distance(
        leftCorner.x, leftCorner.y, rightCorner.x, rightCorner.y);
    if (horizontalDist == 0) return null;

    final v1 = _distance(topMid1.x, topMid1.y, bottomMid1.x, bottomMid1.y);
    final v2 = _distance(topMid2.x, topMid2.y, bottomMid2.x, bottomMid2.y);
    final ear = (v1 + v2) / (2 * horizontalDist);

    // مقادیر مرجع تجربی: EAR ~0.28-0.35 برای چشم کاملاً باز، ~0.05-0.1 برای بسته.
    final normalized = (ear - _earClosed) / (_earOpen - _earClosed);
    return normalized.clamp(0.0, 1.0);
  }

  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  Future<void> dispose() async {
    // اگر initialize شکست خورده باشد یا صدا زده نشده باشد، _detector همچنان
    // null است و این‌جا هیچ کاری انجام نمی‌شود - جلوگیری از LateInitializationError.
    await _detector?.dispose();
    _detector = null;
  }
}
