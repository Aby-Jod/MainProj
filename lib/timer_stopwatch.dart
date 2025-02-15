import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mainproj/theme_notifier.dart';
import 'dart:async';
import 'package:provider/provider.dart';

// Import your pages
import 'home.dart'; // Replace with your actual home page
import 'taskpage.dart'; // Replace with your actual habits page
import 'categories.dart'; // Replace with your actual categories page

void main() {
  runApp(const TimerStopwatchApp());
}

class TimerStopwatchApp extends StatelessWidget {
  const TimerStopwatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // The default theme here is a fallback. Global theme values will be used via Provider.
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const TimerStopwatchScreen(),
    );
  }
}

class TimerStopwatchScreen extends StatefulWidget {
  const TimerStopwatchScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TimerStopwatchScreenState createState() => _TimerStopwatchScreenState();
}

class _TimerStopwatchScreenState extends State<TimerStopwatchScreen> {
  // Countdown timer variables
  Timer? _timer;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;
  final TextEditingController _timerController = TextEditingController();

  // Stopwatch variables
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _stopwatchTimer;

  // Bottom navigation bar variables
  int _currentIndex = 3; // Timer page is index 3

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatchTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!_isTimerRunning && _timerSeconds > 0) {
      setState(() => _isTimerRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_timerSeconds > 0) {
            _timerSeconds--;
          } else {
            _timer?.cancel();
            _isTimerRunning = false;
            _notifyTimerCompletion();
          }
        });
      });
    }
  }

  void _stopTimer() {
    if (_isTimerRunning) {
      _timer?.cancel();
      setState(() => _isTimerRunning = false);
    }
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _timerSeconds = 0);
    _timerController.clear();
  }

  void _notifyTimerCompletion() {
    // Vibrate the device
    HapticFeedback.vibrate();
    // Play a sound
    SystemSound.play(SystemSoundType.alert);
  }

  void _startStopwatch() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _stopwatchTimer =
          Timer.periodic(const Duration(milliseconds: 10), (timer) {
        setState(() {});
      });
    }
  }

  void _stopStopwatch() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _stopwatchTimer?.cancel();
    }
  }

  void _resetStopwatch() {
    _stopStopwatch();
    setState(() => _stopwatch.reset());
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatStopwatchTime() {
    int milliseconds = _stopwatch.elapsedMilliseconds;
    int hundredths = (milliseconds % 1000) ~/ 10;
    int seconds = (milliseconds ~/ 1000) % 60;
    int minutes = (milliseconds ~/ 60000) % 60;
    int hours = milliseconds ~/ 3600000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  // Control button that uses global theme values.
  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool isPrimary = true,
    required ThemeProvider themeNotifier,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isPrimary ? themeNotifier.textColor : themeNotifier.backgroundColor,
        foregroundColor:
            isPrimary ? themeNotifier.backgroundColor : themeNotifier.textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: themeNotifier.textColor,
            width: isPrimary ? 0 : 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // Time display that uses global theme values.
  Widget _buildTimeDisplay({
    required String title,
    required String time,
    required ThemeProvider themeNotifier,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeNotifier.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeNotifier.textColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                title == 'Timer' ? Icons.timer : Icons.watch_later,
                color: themeNotifier.textColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeNotifier.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            time,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: themeNotifier.textColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          if (title == 'Timer') ...[
            TextField(
              controller: _timerController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter time in seconds',
                hintStyle:
                    TextStyle(color: themeNotifier.textColor.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeNotifier.textColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeNotifier.textColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeNotifier.textColor),
                ),
              ),
              style: TextStyle(color: themeNotifier.textColor),
              onChanged: (value) {
                setState(() {
                  _timerSeconds = int.tryParse(value) ?? 0;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title == 'Timer') ...[
                _buildControlButton(
                  onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                  icon: _isTimerRunning ? Icons.pause : Icons.play_arrow,
                  label: _isTimerRunning ? 'Pause' : 'Start',
                  themeNotifier: themeNotifier,
                ),
                const SizedBox(width: 12),
                _buildControlButton(
                  onPressed: _resetTimer,
                  icon: Icons.refresh,
                  label: 'Reset',
                  isPrimary: false,
                  themeNotifier: themeNotifier,
                ),
              ] else ...[
                _buildControlButton(
                  onPressed:
                      _stopwatch.isRunning ? _stopStopwatch : _startStopwatch,
                  icon: _stopwatch.isRunning ? Icons.pause : Icons.play_arrow,
                  label: _stopwatch.isRunning ? 'Stop' : 'Start',
                  themeNotifier: themeNotifier,
                ),
                const SizedBox(width: 12),
                _buildControlButton(
                  onPressed: _resetStopwatch,
                  icon: Icons.refresh,
                  label: 'Reset',
                  isPrimary: false,
                  themeNotifier: themeNotifier,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Navigate to the corresponding page.
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(
              userName: '',
              userEmail: '',
            ),
          ),
        );
        break;
      /* Uncomment and update if you have a Habits page.
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HabitsPage()),
        );
        break;
      */
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CategoriesPage()),
        );
        break;
      case 3:
        // Already on the Timer page.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeNotifier.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Timer and Stopwatch',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeNotifier.textColor,
          ),
        ),
        centerTitle: false,
        backgroundColor: themeNotifier.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeNotifier.textColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _buildTimeDisplay(
                  title: 'Timer',
                  time: _formatTime(_timerSeconds),
                  themeNotifier: themeNotifier,
                ),
                const SizedBox(height: 32),
                _buildTimeDisplay(
                  title: 'Stopwatch',
                  time: _formatStopwatchTime(),
                  themeNotifier: themeNotifier,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        backgroundColor: themeNotifier.backgroundColor,
        selectedItemColor: themeNotifier.textColor,
        unselectedItemColor: themeNotifier.textColor.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Habits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
        ],
      ),
    );
  }
}
