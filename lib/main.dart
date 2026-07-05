import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ========================= بخش ۱: مدل‌ها و سرویس‌های داده =========================

/// مدل داده برای هر تلاش واکنش
class ReactionAttempt extends Equatable {
  final int timestamp;
  final int reactionTimeMs;
  final bool isEarly;

  const ReactionAttempt({
    required this.timestamp,
    required this.reactionTimeMs,
    this.isEarly = false,
  });

  @override
  List<Object?> get props => [timestamp, reactionTimeMs, isEarly];
}

/// سرویس ذخیره‌سازی با استفاده از SharedPreferences (برای نمونه)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveBestReactionTime(int time) async {
    await _prefs.setInt('reaction_best', time);
  }

  int? getBestReactionTime() {
    return _prefs.getInt('reaction_best');
  }

  // برای تاریخچه می‌توان از sqflite استفاده کرد
}

// ========================= بخش ۲: منطق بازی (Cubit) =========================

/// وضعیت‌های بازی واکنش
enum ReactionStatus {
  idle,
  waiting,
  ready,
  early,
  showingResult,
  finished,
}

/// رویدادهای بازی واکنش
sealed class ReactionEvent {}

class ReactionStarted extends ReactionEvent {}

class ReactionTapped extends ReactionEvent {}

class ReactionNextAttempt extends ReactionEvent {}

class ReactionReset extends ReactionEvent {}

class ReactionGoBack extends ReactionEvent {}

/// وضعیت Cubit
class ReactionState extends Equatable {
  final ReactionStatus status;
  final int attemptCount;
  final int maxAttempts;
  final List<int> times;
  final int? bestOverall;
  final int bestSession;
  final int lastTime;
  final String ratingMessage;
  final String ratingStars;
  final bool isProcessing;

  const ReactionState({
    this.status = ReactionStatus.idle,
    this.attemptCount = 0,
    this.maxAttempts = 5,
    this.times = const [],
    this.bestOverall,
    this.bestSession = 0,
    this.lastTime = 0,
    this.ratingMessage = '',
    this.ratingStars = '',
    this.isProcessing = false,
  });

  double get average =>
      times.isEmpty ? 0 : times.reduce((a, b) => a + b) / times.length;

  ReactionState copyWith({
    ReactionStatus? status,
    int? attemptCount,
    int? maxAttempts,
    List<int>? times,
    int? bestOverall,
    int? bestSession,
    int? lastTime,
    String? ratingMessage,
    String? ratingStars,
    bool? isProcessing,
  }) {
    return ReactionState(
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      times: times ?? this.times,
      bestOverall: bestOverall ?? this.bestOverall,
      bestSession: bestSession ?? this.bestSession,
      lastTime: lastTime ?? this.lastTime,
      ratingMessage: ratingMessage ?? this.ratingMessage,
      ratingStars: ratingStars ?? this.ratingStars,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    attemptCount,
    maxAttempts,
    times,
    bestOverall,
    bestSession,
    lastTime,
    ratingMessage,
    ratingStars,
    isProcessing,
  ];
}

/// Cubit مدیریت بازی واکنش
class ReactionCubit extends Cubit<ReactionState> {
  final StorageService storage;
  Timer? _waitTimer;
  final Stopwatch _stopwatch = Stopwatch();

  ReactionCubit(this.storage) : super(const ReactionState()) {
    _loadBestOverall();
  }

  Future<void> _loadBestOverall() async {
    final best = storage.getBestReactionTime();
    if (best != null) {
      emit(state.copyWith(bestOverall: best));
    }
  }

  void startGame() {
    emit(state.copyWith(
      status: ReactionStatus.waiting,
      attemptCount: 0,
      times: [],
      bestSession: 0,
      isProcessing: false,
    ));
    _startTrial();
  }

  void _startTrial() {
    if (state.attemptCount >= state.maxAttempts) {
      emit(state.copyWith(status: ReactionStatus.finished, isProcessing: true));
      return;
    }
    emit(state.copyWith(
      status: ReactionStatus.waiting,
      isProcessing: false,
    ));
    final delay = Random().nextInt(3000) + 2000;
    _waitTimer = Timer(Duration(milliseconds: delay), () {
      if (!isClosed && state.status == ReactionStatus.waiting) {
        emit(state.copyWith(status: ReactionStatus.ready));
        _stopwatch.reset();
        _stopwatch.start();
        HapticFeedback.lightImpact();
      }
    });
  }

  void handleTap() {
    if (state.isProcessing) return;
    switch (state.status) {
      case ReactionStatus.waiting:
        _waitTimer?.cancel();
        emit(state.copyWith(
          status: ReactionStatus.early,
          isProcessing: true,
        ));
        Future.delayed(const Duration(seconds: 1), () {
          if (!isClosed) {
            emit(state.copyWith(isProcessing: false));
            _startTrial();
          }
        });
        break;
      case ReactionStatus.ready:
        _stopwatch.stop();
        final time = _stopwatch.elapsedMilliseconds;
        final newTimes = [...state.times, time];
        final newBestSession = state.bestSession == 0 || time < state.bestSession
            ? time
            : state.bestSession;
        final newBestOverall = state.bestOverall == null || time < state.bestOverall!
            ? time
            : state.bestOverall;
        if (newBestOverall != state.bestOverall) {
          storage.saveBestReactionTime(newBestOverall!);
        }
        final rating = _getRating(time);
        emit(state.copyWith(
          status: ReactionStatus.showingResult,
          times: newTimes,
          bestSession: newBestSession,
          bestOverall: newBestOverall,
          lastTime: time,
          ratingMessage: rating['message']!,
          ratingStars: rating['stars']!,
          isProcessing: true,
        ));
        break;
      default:
        break;
    }
  }

  Map<String, String> _getRating(int time) {
    if (time < 200) return {'stars': '⭐⭐⭐⭐⭐', 'message': 'عالی!'};
    if (time < 250) return {'stars': '⭐⭐⭐⭐', 'message': 'بسیار خوب'};
    if (time < 320) return {'stars': '⭐⭐⭐', 'message': 'خوب'};
    if (time < 450) return {'stars': '⭐⭐', 'message': 'متوسط'};
    return {'stars': '⭐', 'message': 'نیاز به تمرین'};
  }

  void nextAttempt() {
    final newCount = state.attemptCount + 1;
    emit(state.copyWith(
      attemptCount: newCount,
      isProcessing: false,
    ));
    if (newCount >= state.maxAttempts) {
      emit(state.copyWith(status: ReactionStatus.finished, isProcessing: true));
    } else {
      _startTrial();
    }
  }

  void reset() {
    _waitTimer?.cancel();
    emit(const ReactionState());
    _loadBestOverall();
  }

  void goBack() {
    _waitTimer?.cancel();
    // خروج از بازی (توسط Navigator مدیریت می‌شود)
  }

  @override
  Future<void> close() {
    _waitTimer?.cancel();
    return super.close();
  }
}

// ========================= بخش ۳: ویجت‌های رابط کاربری =========================

/// صفحه اصلی با منوی بازی‌ها
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 شناخت‌یار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              // نمایش آمار کلی
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              // تغییر تم
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _gameCard(context, 'حافظه', Icons.memory, const Color(0xFF7C4DFF),
                  () => _navigateTo(context, const MemoryGame())),
              _gameCard(context, 'استروپ', Icons.color_lens, const Color(0xFFFF6F00),
                  () => _navigateTo(context, const StroopGame())),
              _gameCard(context, 'N-Back', Icons.numbers, const Color(0xFF00897B),
                  () => _navigateTo(context, const NBackGame())),
              _gameCard(context, 'واکنش', Icons.timer, const Color(0xFF1976D2),
                  () => _navigateTo(context, BlocProvider.value(
                        value: ReactionCubit(StorageService()),
                        child: const ReactionGame(),
                      ))),
              _gameCard(context, 'ترتیب اعداد', Icons.sort, const Color(0xFFC62828),
                  () => _navigateTo(context, const NumberSequenceGame())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameCard(BuildContext context, String title, IconData icon, Color color,
      VoidCallback onTap) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// بازی واکنش (با استفاده از Cubit)
class ReactionGame extends StatelessWidget {
  const ReactionGame({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReactionCubit(StorageService()),
      child: const _ReactionView(),
    );
  }
}

class _ReactionView extends StatelessWidget {
  const _ReactionView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ReactionCubit>();
    final state = cubit.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('زمان واکنش'),
        centerTitle: true,
        actions: [
          if (state.status != ReactionStatus.idle)
            IconButton(
              onPressed: cubit.reset,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: _buildBody(context, state, cubit),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ReactionState state, ReactionCubit cubit) {
    switch (state.status) {
      case ReactionStatus.idle:
        return _IdleScreen(state: state, onStart: cubit.startGame);
      case ReactionStatus.waiting:
      case ReactionStatus.ready:
      case ReactionStatus.early:
        return _GameScreen(state: state, onTap: cubit.handleTap);
      case ReactionStatus.showingResult:
        return _ResultScreen(state: state, onNext: cubit.nextAttempt, onReset: cubit.reset);
      case ReactionStatus.finished:
        return _FinishScreen(state: state, onReset: cubit.reset, onBack: cubit.goBack);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ویجت‌های فرعی (ساده‌سازی شده برای اختصار)
class _IdleScreen extends StatelessWidget {
  final ReactionState state;
  final VoidCallback onStart;

  const _IdleScreen({required this.state, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('⏱ زمان واکنش', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('پس از سبز شدن دایره، در سریع‌ترین زمان ممکن ضربه بزنید.'),
        const SizedBox(height: 24),
        if (state.bestOverall != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text('🏆 بهترین رکورد: ${state.bestOverall} ms'),
          ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label: const Text('شروع', style: TextStyle(fontSize: 20)),
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
        ),
      ],
    );
  }
}

class _GameScreen extends StatelessWidget {
  final ReactionState state;
  final VoidCallback onTap;

  const _GameScreen({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String statusText;
    Color statusColor;
    if (state.status == ReactionStatus.waiting) {
      statusText = '⏳ منتظر بمانید...';
      statusColor = Colors.grey;
    } else if (state.status == ReactionStatus.ready) {
      statusText = '⚡ سریع لمس کن!';
      statusColor = Colors.green;
    } else {
      statusText = '❌ خیلی زود!';
      statusColor = Colors.red;
    }
    final color = state.status == ReactionStatus.ready
        ? Colors.green
        : state.status == ReactionStatus.early
            ? Colors.red.shade300
            : Colors.grey.shade400;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('تلاش ${state.attemptCount + 1} از ${state.maxAttempts}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 30, spreadRadius: 10),
            ],
          ),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 40),
        Text(statusText, style: TextStyle(fontSize: 20, color: statusColor)),
      ],
    );
  }
}

class _ResultScreen extends StatelessWidget {
  final ReactionState state;
  final VoidCallback onNext;
  final VoidCallback onReset;

  const _ResultScreen({
    required this.state,
    required this.onNext,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: state.lastTime.toDouble()),
          duration: const Duration(milliseconds: 500),
          builder: (_, value, __) => Text(
            '${value.toInt()} ms',
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        Text(state.ratingStars, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(state.ratingMessage, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: onNext,
              icon: Icon(state.attemptCount + 1 >= state.maxAttempts ? Icons.flag : Icons.arrow_forward),
              label: Text(state.attemptCount + 1 >= state.maxAttempts ? 'پایان' : 'تلاش بعدی'),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('شروع مجدد'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinishScreen extends StatelessWidget {
  final ReactionState state;
  final VoidCallback onReset;
  final VoidCallback onBack;

  const _FinishScreen({
    required this.state,
    required this.onReset,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final avg = state.average;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏁 جلسه کامل شد!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _statRow('میانگین', '${avg.toStringAsFixed(0)} ms'),
                _statRow('بهترین جلسه', '${state.bestSession} ms'),
                if (state.bestOverall != null) _statRow('رکورد کلی', '${state.bestOverall} ms'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(_getOverallRating(avg)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.replay),
              label: const Text('دوباره'),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.home),
              label: const Text('خانه'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getOverallRating(double avg) {
    if (avg < 220) return '🌟 عالی!';
    if (avg < 280) return '👍 خوب';
    if (avg < 350) return '📈 قابل قبول';
    return '💪 نیاز به تمرین';
  }
}

// ===================== سایر بازی‌ها (ساده‌سازی شده) =====================

// بازی حافظه (نمونه)
class MemoryGame extends StatelessWidget {
  const MemoryGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بازی حافظه')),
      body: const Center(child: Text('حافظه - در حال توسعه')),
    );
  }
}

class StroopGame extends StatelessWidget {
  const StroopGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تست استروپ')),
      body: const Center(child: Text('استروپ - در حال توسعه')),
    );
  }
}

class NBackGame extends StatelessWidget {
  const NBackGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بازی N-Back')),
      body: const Center(child: Text('N-Back - در حال توسعه')),
    );
  }
}

class NumberSequenceGame extends StatelessWidget {
  const NumberSequenceGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ترتیب اعداد')),
      body: const Center(child: Text('ترتیب اعداد - در حال توسعه')),
    );
  }
}

// ========================= بخش ۴: برنامه اصلی =========================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  runApp(MyApp(storage: storage));
}

class MyApp extends StatelessWidget {
  final StorageService storage;
  const MyApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شناخت‌یار',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Far_Homa',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6CF7)),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ReactionCubit(storage)),
        ],
        child: const HomePage(),
      ),
    );
  }
}
