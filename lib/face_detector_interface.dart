import 'package:camera/camera.dart';
 
/// نتیجه‌ی ساده و یکسان تشخیص چهره، مستقل از اینکه پشت‌صحنه از ML Kit
/// (موبایل) استفاده شده باشد یا face_detection_tflite (دسکتاپ).
class FaceResult {
  final double left;
  final double top;
  final double width;
  final double height;
 
  /// احتمال باز بودن چشم چپ/راست (۰ تا ۱). اگر پلتفرم این مقدار را ندهد، null است
  /// و لایه‌ی بالاتر باید با EAR (نسبت تناسب چشم) خودش این مقدار را تخمین بزند.
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
 
  const FaceResult({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });
}
 
/// اینترفیس مشترک تشخیص چهره. دو پیاده‌سازی دارد:
/// - MobileFaceDetectorService (lib/face_detector_mobile.dart) با ML Kit، فقط اندروید/iOS
/// - DesktopFaceDetectorService (lib/face_detector_desktop.dart) با face_detection_tflite،
///   برای ویندوز/مک/لینوکس (و در صورت نیاز اندروید/iOS هم پشتیبانی می‌کند)
abstract class FaceDetectorService {
  Future<void> initialize();
  Future<List<FaceResult>> detectFaces(CameraImage image, CameraDescription camera);
  Future<void> dispose();
}
 
