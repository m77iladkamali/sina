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
      title: 'بازی‌های شناختی حرفه‌ای',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.light,
        ),
        fontFamily: 'Vazir',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ===================== صفحه اصلی با طراحی کارت‌های زیبا =====================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 تمرین‌های شناختی'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
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
              _buildGameCard(
                context,
                title: 'حافظه',
                icon: Icons.memory,
                color: const Color(0xFF7C4DFF),
                onTap: () => _navigateTo(context, const MemoryGame()),
              ),
              _buildGameCard(
                context,
                title: 'استروپ',
                icon: Icons.color_lens,
                color: const Color(0xFFFF6F00),
                onTap: () => _navigateTo(context, const StroopGame()),
              ),
              _buildGameCard(
                context,
                title: 'N-Back',
                icon: Icons.numbers,
                color: const Color(0xFF00897B),
                onTap: () => _navigateTo(context, const NBackGame()),
              ),
              _buildGameCard(
                context,
                title: 'واکنش',
                icon: Icons.timer,
                color: const Color(0xFF1976D2),
                onTap: () => _navigateTo(context, const ReactionTimeGame()),
              ),
              _buildGameCard(
                context,
                title: 'ترتیب اعداد',
                icon: Icons.sort,
                color: const Color(0xFFC62828),
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
                  shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
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
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// ===================== بازی حافظه (پیشرفته) =====================
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> with TickerProviderStateMixin {
  // سطوح دشواری
  enum Difficulty { easy, medium, hard }
  Difficulty _difficulty = Difficulty.easy;

  late List<String> _cards;
  final List<int> _opened = [];
  final List<int> _matched = [];
  int _attempts = 0;
  int _pairsFound = 0;
  late AnimationController _flipController;
  bool _isProcessing = false;

  // پیکربندی کارت‌ها بر اساس دشواری
  List<String> get _emojis {
    switch (_difficulty) {
      case Difficulty.easy:
        return ['🍎', '🍎', '🍌', '🍌', '🍇', '🍇']; // 3 جفت
      case Difficulty.medium:
        return ['🍎', '🍎', '🍌', '🍌', '🍇', '🍇', '🍒', '🍒', '🍊', '🍊']; // 5 جفت
      case Difficulty.hard:
        return [
          '🍎', '🍎', '🍌', '🍌', '🍇', '🍇',
          '🍒', '🍒', '🍊', '🍊', '🍉', '🍉', '🍓', '🍓'
        ]; // 7 جفت
    }
  }

  int get _gridColumns {
    switch (_difficulty) {
      case Difficulty.easy:
        return 3;
      case Difficulty.medium:
        return 4;
      case Difficulty.hard:
        return 4;
    }
  }

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initGame();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _initGame() {
    final list = _emojis;
    _cards = List.from(list)..shuffle();
    _opened.clear();
    _matched.clear();
    _attempts = 0;
    _pairsFound = 0;
    _isProcessing = false;
  }

  void _onCardTap(int index) {
    if (_isProcessing) return;
    if (_opened.length == 2 || _opened.contains(index) || _matched.contains(index)) return;

    setState(() {
      _opened.add(index);
      _flipController.forward(from: 0);
    });

    if (_opened.length == 2) {
      _isProcessing = true;
      _attempts++;
      if (_cards[_opened[0]] == _cards[_opened[1]]) {
        setState(() {
          _matched.addAll(_opened);
          _pairsFound++;
          _opened.clear();
          _isProcessing = false;
        });
        HapticFeedback.lightImpact();
        if (_pairsFound == _cards.length ~/ 2) {
          _showWinDialog();
        }
      } else {
        Future.delayed(const Duration(milliseconds: 700), () {
          setState(() {
            _opened.clear();
            _isProcessing = false;
          });
          HapticFeedback.heavyImpact();
        });
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎉 تبریک!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('همه جفت‌ها را پیدا کردید!'),
            const SizedBox(height: 8),
            Text('تعداد تلاش: $_attempts'),
            const SizedBox(height: 8),
            Text('سطح: ${_difficulty.name}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _initGame());
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
        title: const Text('بازی حافظه'),
        centerTitle: true,
        actions: [
          DropdownButton<Difficulty>(
            value: _difficulty,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.settings, color: Colors.white),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _difficulty = value;
                  _initGame();
                });
              }
            },
            items: Difficulty.values.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(d.name, style: const TextStyle(color: Colors.black)),
              );
            }).toList(),
          ),
          IconButton(
            onPressed: () => setState(() => _initGame()),
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تلاش: $_attempts', style: const TextStyle(fontSize: 18)),
                Text('جفت‌ها: $_pairsFound/${_cards.length ~/ 2}',
                    style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _cards.length,
                itemBuilder: (ctx, i) {
                  final isOpen = _opened.contains(i) || _matched.contains(i);
                  return GestureDetector(
                    onTap: () => _onCardTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.white : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            isOpen ? _cards[i] : '?',
                            key: ValueKey(isOpen),
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== بازی استروپ (پیشرفته) =====================
class StroopGame extends StatefulWidget {
  const StroopGame({super.key});

  @override
  State<StroopGame> createState() => _StroopGameState();
}

class _StroopGameState extends State<StroopGame> {
  final List<String> _colorNames = ['قرمز', 'آبی', 'سبز', 'زرد', 'بنفش'];
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
  int _rounds = 10;
  bool _isAnswered = false;
  final List<bool> _history = [];

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    if (_total >= _rounds) {
      _showResult();
      return;
    }
    final rng = Random();
    final wordIndex = rng.nextInt(_colorNames.length);
    final colorIndex = rng.nextInt(_colorValues.length);
    setState(() {
      _word = _colorNames[wordIndex];
      _textColor = _colorValues[colorIndex];
      _isAnswered = false;
    });
  }

  void _answer(bool isCongruent) {
    if (_isAnswered) return;
    _isAnswered = true;
    final correct = _word == _getColorName(_textColor);
    final userCorrect = (correct && isCongruent) || (!correct && !isCongruent);
    if (userCorrect) {
      setState(() => _score++);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    _history.add(userCorrect);
    setState(() => _total++);
    Future.delayed(const Duration(milliseconds: 500), _nextRound);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('امتیاز: $_score از $_rounds'),
            const SizedBox(height: 8),
            Text('دقت: ${(_score / _rounds * 100).toStringAsFixed(0)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _total = 0;
                _history.clear();
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
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _score = 0;
                _total = 0;
                _history.clear();
                _nextRound();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_total < _rounds) ...[
              Text(
                _word,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  shadows: [const Shadow(blurRadius: 4, color: Colors.black26)],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'رنگ کلمه چیست؟ (نه معنی آن!)',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _answer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('همخوان'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _answer(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('ناهمخوان'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('پیشرفت: $_total / $_rounds'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _total / _rounds,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Colors.blue),
              ),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ===================== بازی N-Back (پیشرفته) =====================
class NBackGame extends StatefulWidget {
  const NBackGame({super.key});

  @override
  State<NBackGame> createState() => _NBackGameState();
}

class _NBackGameState extends State<NBackGame> {
  int _n = 2;
  List<int> _sequence = [];
  int _currentIndex = 0;
  int _score = 0;
  int _total = 0;
  bool _gameOver = false;
  int _correct = 0;
  int _incorrect = 0;

  final List<int> _sequenceLengths = [15, 20, 25];

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    final length = _sequenceLengths[_n - 1];
    setState(() {
      _sequence = List.generate(length, (_) => Random().nextInt(9) + 1);
      _currentIndex = 0;
      _score = 0;
      _total = 0;
      _gameOver = false;
      _correct = 0;
      _incorrect = 0;
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
    if (_currentIndex < _n) {
      _nextNumber();
      return;
    }
    final actualMatch = _sequence[_currentIndex] == _sequence[_currentIndex - _n];
    final userCorrect = (isMatch == actualMatch);
    if (userCorrect) {
      setState(() {
        _score++;
        _correct++;
      });
      HapticFeedback.lightImpact();
    } else {
      setState(() => _incorrect++);
      HapticFeedback.heavyImpact();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('امتیاز: $_score از $_total'),
            const SizedBox(height: 8),
            Text('درست: $_correct | غلط: $_incorrect'),
            const SizedBox(height: 8),
            Text('دقت: ${_total > 0 ? (_score / _total * 100).toStringAsFixed(0) : 0}%'),
          ],
        ),
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
        actions: [
          DropdownButton<int>(
            value: _n,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.settings, color: Colors.white),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _n = value;
                  _startGame();
                });
              }
            },
            items: [1, 2, 3].map((n) {
              return DropdownMenuItem(
                value: n,
                child: Text('${n}-Back', style: const TextStyle(color: Colors.black)),
              );
            }).toList(),
          ),
          IconButton(
            onPressed: _startGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_gameOver && _currentIndex < _sequence.length)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  '${_sequence[_currentIndex]}',
                  key: ValueKey(_currentIndex),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              )
            else
              const Text('پایان بازی', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 40),
            if (!_gameOver && _currentIndex < _sequence.length) ...[
              Text('آیا این عدد با عدد $_n مرحله قبل یکسان است؟'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _checkMatch(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('بله'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _checkMatch(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('خیر'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('پیشرفت: ${_currentIndex + 1} / ${_sequence.length}'),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _sequence.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Colors.blue),
              ),
            ],
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

// ===================== بازی واکنش (کاملاً حرفه‌ای) =====================
// تعریف enum در سطح بالا
enum GameStatus {
  idle,
  waiting,
  ready,
  early,
  showingResult,
  finished,
}

class ReactionTimeGame extends StatefulWidget {
  const ReactionTimeGame({super.key});

  @override
  State<ReactionTimeGame> createState() => _ReactionTimeGameState();
}

class _ReactionTimeGameState extends State<ReactionTimeGame>
    with SingleTickerProviderStateMixin {
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
  late AnimationController _pulseController;
  Color _circleColor = Colors.grey.shade400;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadBestOverall();
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _pulseController.dispose();
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
          _pulseController.forward(from: 0);
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
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIdleScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '⏱ زمان واکنش',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'پس از سبز شدن دایره، در سریع‌ترین زمان ممکن ضربه بزنید.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        if (_bestOverall != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '🏆 بهترین رکورد شما: $_bestOverall ms',
              style: const TextStyle(fontSize: 18, color: Colors.green),
            ),
          ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _startGame,
          icon: const Icon(Icons.play_arrow),
          label: const Text('شروع', style: TextStyle(fontSize: 20)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 56),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('بازگشت'),
        ),
      ],
    );
  }

  Widget _buildGameScreen() {
    String statusText;
    Color statusColor;
    if (_status == GameStatus.waiting) {
      statusText = '⏳ منتظر بمانید...';
      statusColor = Colors.grey;
    } else if (_status == GameStatus.ready) {
      statusText = '⚡ سریع لمس کن!';
      statusColor = Colors.green;
    } else if (_status == GameStatus.early) {
      statusText = '❌ خیلی زود! دوباره تلاش کنید.';
      statusColor = Colors.red;
    } else {
      statusText = '';
      statusColor = Colors.grey;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'تلاش ${_attemptCount + 1} از $_maxAttempts',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) {
            final scale = 1 + 0.05 * _pulseController.value;
            return Transform.scale(
              scale: _status == GameStatus.ready ? scale : 1.0,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: _circleColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _circleColor.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
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
            );
          },
        ),
        const SizedBox(height: 40),
        Text(
          statusText,
          style: TextStyle(fontSize: 20, color: statusColor),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: _lastReactionTime.toDouble()),
          duration: const Duration(milliseconds: 500),
          builder: (_, value, __) {
            return Text(
              '${value.toInt()} ms',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(_ratingStars, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(_ratingMessage, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _nextAttempt,
              icon: Icon(_attemptCount + 1 >= _maxAttempts ? Icons.flag : Icons.arrow_forward),
              label: Text(_attemptCount + 1 >= _maxAttempts ? 'پایان' : 'تلاش بعدی'),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: _resetGame,
              icon: const Icon(Icons.refresh),
              label: const Text('شروع مجدد'),
            ),
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
        const Text('🏁 جلسه کامل شد!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatRow('میانگین زمان', '${avg.toStringAsFixed(0)} ms'),
                _buildStatRow('بهترین زمان این جلسه', '$_bestSession ms'),
                if (_bestOverall != null) _buildStatRow('بهترین رکورد کلی', '$_bestOverall ms'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _getOverallRating(avg),
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _resetGame,
              icon: const Icon(Icons.replay),
              label: const Text('دوباره بازی'),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.home),
              label: const Text('خانه'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
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

// ===================== بازی ترتیب اعداد (پیشرفته) =====================
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
  int _mistakes = 0;
  int _count = 8;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _sequence = List.generate(_count, (_) => Random().nextInt(100) + 1);
    _sequence.shuffle();
    _currentIndex = 0;
    _score = 0;
    _gameOver = false;
    _mistakes = 0;
  }

  void _checkNumber(int number) {
    if (_gameOver) return;
    if (number == _sequence[_currentIndex]) {
      setState(() {
        _score++;
        _currentIndex++;
        HapticFeedback.lightImpact();
        if (_currentIndex == _sequence.length) {
          _gameOver = true;
          _showResult();
        }
      });
    } else {
      setState(() {
        _gameOver = true;
        _mistakes++;
        HapticFeedback.heavyImpact();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('امتیاز: $_score از ${_sequence.length}'),
            const SizedBox(height: 8),
            Text('تعداد اشتباه: $_mistakes'),
          ],
        ),
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
        actions: [
          DropdownButton<int>(
            value: _count,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.settings, color: Colors.white),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _count = value;
                  _newGame();
                });
              }
            },
            items: [6, 8, 10, 12].map((n) {
              return DropdownMenuItem(
                value: n,
                child: Text('$n عدد', style: const TextStyle(color: Colors.black)),
              );
            }).toList(),
          ),
          IconButton(
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green : Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
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
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _currentIndex / _sequence.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Colors.blue),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('بازگشت'),
            ),
          ],
        ),
      ),
    );
  }
}
