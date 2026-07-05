import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بازی‌های شناختی',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Vazir', // در صورت وجود فونت فارسی
      ),
      home: const HomePage(),
    );
  }
}

// ========================= صفحه اصلی =========================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازی‌های شناختی'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildGameCard(
                context,
                title: 'حافظه',
                icon: Icons.memory,
                color: Colors.purple,
                onTap: () => _navigateTo(context, const MemoryGame()),
              ),
              _buildGameCard(
                context,
                title: 'استروپ',
                icon: Icons.color_lens,
                color: Colors.orange,
                onTap: () => _navigateTo(context, const StroopGame()),
              ),
              _buildGameCard(
                context,
                title: 'N-Back',
                icon: Icons.numbers,
                color: Colors.teal,
                onTap: () => _navigateTo(context, const NBackGame()),
              ),
              _buildGameCard(
                context,
                title: 'واکنش',
                icon: Icons.timer,
                color: Colors.blue,
                onTap: () => _navigateTo(context, const ReactionTimeGame()),
              ),
              _buildGameCard(
                context,
                title: 'ترتیب اعداد',
                icon: Icons.sort,
                color: Colors.red,
                onTap: () => _navigateTo(context, const NumberSequenceGame()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
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
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

// ========================= بازی حافظه (Memory Match) =========================
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  // نمونه ساده: ۶ کارت با ۳ جفت
  final List<String> _emojis = ['🍎', '🍎', '🍌', '🍌', '🍇', '🍇'];
  late List<String> _cards;
  List<int> _opened = [];
  List<int> _matched = [];
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    _cards = List.from(_emojis)..shuffle();
    _opened.clear();
    _matched.clear();
    _attempts = 0;
  }

  void _onCardTap(int index) {
    if (_opened.length == 2 || _opened.contains(index) || _matched.contains(index)) return;

    setState(() {
      _opened.add(index);
    });

    if (_opened.length == 2) {
      _attempts++;
      if (_cards[_opened[0]] == _cards[_opened[1]]) {
        setState(() {
          _matched.addAll(_opened);
          _opened.clear();
        });
        if (_matched.length == _cards.length) {
          _showWinDialog();
        }
      } else {
        Future.delayed(const Duration(seconds: 1), () {
          setState(() {
            _opened.clear();
          });
        });
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎉 برنده شدید!'),
        content: Text('تعداد تلاش: $_attempts'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _shuffle();
              });
            },
            child: const Text('بازی دوباره'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بازگشت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازی حافظه'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => setState(() => _shuffle()),
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _cards.length,
          itemBuilder: (ctx, i) {
            final isOpen = _opened.contains(i) || _matched.contains(i);
            return GestureDetector(
              onTap: () => _onCardTap(i),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.white : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isOpen ? _cards[i] : '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ========================= بازی استروپ (Stroop Test) =========================
class StroopGame extends StatefulWidget {
  const StroopGame({super.key});

  @override
  State<StroopGame> createState() => _StroopGameState();
}

class _StroopGameState extends State<StroopGame> {
  final List<String> _colors = ['قرمز', 'آبی', 'سبز', 'زرد', 'بنفش'];
  final List<Color> _colorValues = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple
  ];
  late String _word;
  late Color _textColor;
  int _score = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    final rng = Random();
    final wordIndex = rng.nextInt(_colors.length);
    final colorIndex = rng.nextInt(_colorValues.length);
    setState(() {
      _word = _colors[wordIndex];
      _textColor = _colorValues[colorIndex];
    });
  }

  void _answer(bool isCongruent) {
    final correct = _word == _getColorName(_textColor);
    if ((correct && isCongruent) || (!correct && !isCongruent)) {
      setState(() => _score++);
    }
    setState(() => _total++);
    if (_total >= 10) {
      _showResult();
    } else {
      _nextRound();
    }
  }

  String _getColorName(Color c) {
    if (c == Colors.red) return 'قرمز';
    if (c == Colors.blue) return 'آبی';
    if (c == Colors.green) return 'سبز';
    if (c == Colors.yellow) return 'زرد';
    if (c == Colors.purple) return 'بنفش';
    return '';
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('نتیجه استروپ'),
        content: Text('امتیاز شما: $_score از ۱۰'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _total = 0;
                _nextRound();
              });
            },
            child: const Text('دوباره'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بازگشت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تست استروپ'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _word,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'رنگ کلمه چیست؟ (نه معنی آن!)',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _answer(true),
                  child: const Text('همخوان'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _answer(false),
                  child: const Text('ناهمخوان'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('پیشرفت: $_total / ۱۰'),
          ],
        ),
      ),
    );
  }
}

// ========================= بازی N-Back =========================
class NBackGame extends StatefulWidget {
  const NBackGame({super.key});

  @override
  State<NBackGame> createState() => _NBackGameState();
}

class _NBackGameState extends State<NBackGame> {
  final int _n = 2; // 2-back
  List<int> _sequence = [];
  int _currentIndex = 0;
  int _score = 0;
  int _total = 0;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    setState(() {
      _sequence = List.generate(20, (_) => Random().nextInt(9) + 1);
      _currentIndex = 0;
      _score = 0;
      _total = 0;
      _gameOver = false;
    });
  }

  void _nextNumber() {
    if (_currentIndex >= _sequence.length) {
      setState(() => _gameOver = true);
      _showResult();
      return;
    }
    setState(() {
      _currentIndex++;
    });
  }

  void _checkMatch(bool isMatch) {
    if (_currentIndex <= _n) {
      // نمی‌توانیم در ابتدا قضاوت کنیم
      _nextNumber();
      return;
    }
    final actualMatch = _sequence[_currentIndex] == _sequence[_currentIndex - _n];
    if (isMatch == actualMatch) {
      setState(() => _score++);
    }
    setState(() => _total++);
    _nextNumber();
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('نتیجه N-Back'),
        content: Text('امتیاز شما: $_score از $_total'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text('دوباره'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بازگشت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازی N-Back'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_gameOver && _currentIndex < _sequence.length)
              Text(
                '${_sequence[_currentIndex]}',
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 40),
            if (!_gameOver && _currentIndex < _sequence.length)
              Column(
                children: [
                  Text('آیا این عدد با عدد $_n مرحله قبل یکسان است؟'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _checkMatch(true),
                        child: const Text('بله'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => _checkMatch(false),
                        child: const Text('خیر'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('پیشرفت: ${_currentIndex + 1} / ${_sequence.length}'),
                ],
              ),
            if (_gameOver || _currentIndex >= _sequence.length)
              const Text('پایان بازی'),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بازگشت'),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= بازی واکنش (Reaction Time) =========================
// (کد کامل از فایل قبلی، با اندکی تغییر برای سازگاری)
class ReactionTimeGame extends StatefulWidget {
  const ReactionTimeGame({super.key});

  @override
  State<ReactionTimeGame> createState() => _ReactionTimeGameState();
}

class _ReactionTimeGameState extends State<ReactionTimeGame>
    with SingleTickerProviderStateMixin {
  enum GameStatus {
    idle,
    waiting,
    ready,
    early,
    showingResult,
    finished,
  }

  GameStatus _status = GameStatus.idle;
  int _attemptCount = 0;
  final int _maxAttempts = 5;
  List<int> _reactionTimes = [];
  int? _bestOverall;
  int _bestSession = 0;
  int _lastReactionTime = 0;
  String _ratingMessage = '';
  String _ratingStars = '';

  Timer? _waitTimer;
  final Stopwatch _stopwatch = Stopwatch();
  late AnimationController _colorController;
  Color _circleColor = Colors.grey.shade400;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadBestOverall();
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadBestOverall() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bestOverall = prefs.getInt('reaction_best');
    });
  }

  Future<void> _saveBestOverall(int time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reaction_best', time);
  }

  void _startGame() {
    setState(() {
      _status = GameStatus.waiting;
      _attemptCount = 0;
      _reactionTimes.clear();
      _bestSession = 0;
      _circleColor = Colors.grey.shade400;
    });
    _startTrial();
  }

  void _startTrial() {
    if (_attemptCount >= _maxAttempts) {
      _finishGame();
      return;
    }
    setState(() {
      _status = GameStatus.waiting;
      _circleColor = Colors.grey.shade400;
      _isProcessing = false;
    });
    final delay = Random().nextInt(3000) + 2000;
    _waitTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted && _status == GameStatus.waiting) {
        setState(() {
          _status = GameStatus.ready;
          _circleColor = Colors.green;
          _stopwatch.reset();
          _stopwatch.start();
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  void _handleTap() {
    if (_isProcessing) return;
    switch (_status) {
      case GameStatus.waiting:
        setState(() {
          _status = GameStatus.early;
          _isProcessing = true;
          _circleColor = Colors.red.shade300;
        });
        _waitTimer?.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _isProcessing = false);
            _startTrial();
          }
        });
        break;
      case GameStatus.ready:
        _stopwatch.stop();
        final time = _stopwatch.elapsedMilliseconds;
        _lastReactionTime = time;
        _reactionTimes.add(time);
        if (_bestSession == 0 || time < _bestSession) _bestSession = time;
        if (_bestOverall == null || time < _bestOverall!) {
          _bestOverall = time;
          _saveBestOverall(time);
        }
        final rating = _getRating(time);
        _ratingStars = rating['stars']!;
        _ratingMessage = rating['message']!;
        setState(() {
          _status = GameStatus.showingResult;
          _isProcessing = true;
          _circleColor = Colors.green;
        });
        break;
      default:
        break;
    }
  }

  void _nextAttempt() {
    setState(() {
      _attemptCount++;
      _isProcessing = false;
    });
    if (_attemptCount >= _maxAttempts) {
      _finishGame();
    } else {
      _startTrial();
    }
  }

  void _finishGame() {
    setState(() {
      _status = GameStatus.finished;
      _isProcessing = true;
      _circleColor = Colors.grey.shade400;
    });
  }

  Map<String, String> _getRating(int time) {
    if (time < 200) return {'stars': '⭐⭐⭐⭐⭐', 'message': 'عالی! واکنش فوق‌العاده'};
    if (time < 250) return {'stars': '⭐⭐⭐⭐', 'message': 'بسیار خوب! سریع و دقیق'};
    if (time < 320) return {'stars': '⭐⭐⭐', 'message': 'خوب! می‌توانید بهتر شوید'};
    if (time < 450) return {'stars': '⭐⭐', 'message': 'متوسط، تمرین بیشتر نیاز است'};
    return {'stars': '⭐', 'message': 'نیاز به تمرین جدی دارید'};
  }

  double _getAverage() {
    if (_reactionTimes.isEmpty) return 0;
    return _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length;
  }

  void _resetGame() {
    setState(() {
      _status = GameStatus.idle;
      _attemptCount = 0;
      _reactionTimes.clear();
      _lastReactionTime = 0;
      _circleColor = Colors.grey.shade400;
      _isProcessing = false;
    });
    _waitTimer?.cancel();
  }

  void _goBack() {
    _waitTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('زمان واکنش'),
        centerTitle: true,
        actions: [
          if (_status != GameStatus.idle)
            IconButton(
              onPressed: _resetGame,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case GameStatus.idle:
        return _buildIdleScreen();
      case GameStatus.waiting:
      case GameStatus.ready:
      case GameStatus.early:
        return _buildGameScreen();
      case GameStatus.showingResult:
        return _buildResultScreen();
      case GameStatus.finished:
        return _buildFinalScreen();
    }
  }

  Widget _buildIdleScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'زمان واکنش',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'پس از سبز شدن دایره، در سریع‌ترین زمان ممکن روی آن ضربه بزنید.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_bestOverall != null)
          Text(
            'بهترین رکورد شما: $_bestOverall ms',
            style: const TextStyle(fontSize: 16, color: Colors.green),
          ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
          child: const Text('شروع', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _goBack, child: const Text('بازگشت')),
      ],
    );
  }

  Widget _buildGameScreen() {
    String statusText;
    if (_status == GameStatus.waiting) {
      statusText = 'منتظر بمانید...';
    } else if (_status == GameStatus.ready) {
      statusText = '⚡ سریع لمس کن!';
    } else if (_status == GameStatus.early) {
      statusText = '❌ خیلی زود! دوباره تلاش کنید.';
    } else {
      statusText = '';
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('تلاش ${_attemptCount + 1} از $_maxAttempts'),
        const SizedBox(height: 40),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: _circleColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _circleColor.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _handleTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(statusText, style: const TextStyle(fontSize: 20)),
      ],
    );
  }

  Widget _buildResultScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$_lastReactionTime ms',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Text(_ratingStars, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(_ratingMessage, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _nextAttempt,
              child: Text(_attemptCount + 1 >= _maxAttempts ? 'پایان' : 'تلاش بعدی'),
            ),
            const SizedBox(width: 16),
            OutlinedButton(onPressed: _resetGame, child: const Text('شروع مجدد')),
          ],
        ),
        const SizedBox(height: 16),
        Text('تلاش ${_attemptCount + 1} از $_maxAttempts'),
      ],
    );
  }

  Widget _buildFinalScreen() {
    final avg = _getAverage();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏁 جلسه کامل شد!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildStatRow('میانگین زمان', '${avg.toStringAsFixed(0)} ms'),
        _buildStatRow('بهترین زمان این جلسه', '$_bestSession ms'),
        if (_bestOverall != null) _buildStatRow('بهترین رکورد کلی', '$_bestOverall ms'),
        const SizedBox(height: 32),
        Text(_getOverallRating(avg), style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: _resetGame, child: const Text('دوباره بازی')),
            const SizedBox(width: 16),
            OutlinedButton(onPressed: _goBack, child: const Text('بازگشت')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 18)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }

  String _getOverallRating(double avg) {
    if (avg < 220) return '🌟 شما واکنش‌های بسیار سریعی دارید!';
    if (avg < 280) return '👍 عملکرد خوب، با تمرین بیشتر عالی می‌شوید.';
    if (avg < 350) return '📈 جای پیشرفت دارید، ادامه دهید!';
    return '💪 تمرین منظم به شما کمک می‌کند تا سریع‌تر شوید.';
  }
}

// ========================= بازی ترتیب اعداد (Number Sequence) =========================
class NumberSequenceGame extends StatefulWidget {
  const NumberSequenceGame({super.key});

  @override
  State<NumberSequenceGame> createState() => _NumberSequenceGameState();
}

class _NumberSequenceGameState extends State<NumberSequenceGame> {
  List<int> _sequence = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _sequence = List.generate(8, (_) => Random().nextInt(100) + 1);
    _sequence.shuffle();
    _currentIndex = 0;
    _score = 0;
    _gameOver = false;
  }

  void _checkNumber(int number) {
    if (_gameOver) return;
    if (number == _sequence[_currentIndex]) {
      setState(() {
        _score++;
        _currentIndex++;
        if (_currentIndex == _sequence.length) {
          _gameOver = true;
          _showResult();
        }
      });
    } else {
      setState(() {
        _gameOver = true;
        _showResult();
      });
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('نتیجه ترتیب اعداد'),
        content: Text('امتیاز شما: $_score از ${_sequence.length}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            child: const Text('دوباره'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بازگشت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ترتیب اعداد'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'اعداد را به ترتیب صحیح لمس کنید:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _sequence.map((num) {
                final index = _sequence.indexOf(num);
                final isDone = index < _currentIndex;
                return GestureDetector(
                  onTap: isDone ? null : () => _checkNumber(num),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDone ? Colors.grey : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$num',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            Text('پیشرفت: $_currentIndex از ${_sequence.length}'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بازگشت'),
            ),
          ],
        ),
      ),
    );
  }
}
