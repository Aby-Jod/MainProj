import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentQuestionIndex = 0;
  final List<int> _selectedScores = [];
  bool _quizCompleted = false;
  Map<String, dynamic> _quizResults = {};

  // Categories for questions
  final Map<String, String> _categories = {
    'physical': 'Physical Health',
    'mental': 'Mental Wellbeing',
    'nutrition': 'Nutrition',
    'productivity': 'Productivity',
    'lifestyle': 'Lifestyle Balance'
  };

  // Expanded list of questions to fully understand the user.
  final List<Map<String, dynamic>> _questions = [
    {
      'category': 'physical',
      'question': 'How often do you engage in physical exercise?',
      'description':
          'Include any activity that increases your heart rate significantly.',
      'options': [
        {'text': 'Daily (30+ minutes)', 'score': 3},
        {'text': '3-4 times a week', 'score': 2},
        {'text': '1-2 times a week', 'score': 1},
        {'text': 'Rarely or never', 'score': 0},
      ],
    },
    {
      'category': 'physical',
      'question': 'What\'s your typical sleep pattern?',
      'description':
          'Consider your average sleep duration and quality over the past month.',
      'options': [
        {'text': '7-9 hours consistently', 'score': 3},
        {'text': '6-7 hours usually', 'score': 2},
        {'text': 'Irregular sleep patterns', 'score': 1},
        {'text': 'Less than 6 hours', 'score': 0},
      ],
    },
    {
      'category': 'mental',
      'question': 'How do you manage stress throughout your day?',
      'description':
          'Think about techniques like mindfulness, meditation, or breathing exercises you use.',
      'options': [
        {'text': 'Practice meditation or mindfulness daily', 'score': 3},
        {'text': 'Use stress-relief techniques occasionally', 'score': 2},
        {'text': 'Rarely manage my stress actively', 'score': 1},
        {'text': 'I ignore stress until it becomes overwhelming', 'score': 0},
      ],
    },
    {
      'category': 'nutrition',
      'question': 'How balanced is your daily diet?',
      'description':
          'Reflect on whether you include fruits, vegetables, proteins, and whole grains in your meals.',
      'options': [
        {'text': 'Very balanced and nutritious', 'score': 3},
        {'text': 'Mostly balanced but room for improvement', 'score': 2},
        {'text': 'Somewhat unbalanced', 'score': 1},
        {'text': 'Poor, lacking essential nutrients', 'score': 0},
      ],
    },
    {
      'category': 'productivity',
      'question': 'How effectively do you manage your daily tasks?',
      'description':
          'Consider if you use planners, to-do lists, or other time-management strategies.',
      'options': [
        {'text': 'Highly organized and productive', 'score': 3},
        {'text': 'Mostly organized with minor delays', 'score': 2},
        {'text': 'Sometimes struggle with productivity', 'score': 1},
        {'text': 'Often feel overwhelmed and unproductive', 'score': 0},
      ],
    },
    {
      'category': 'lifestyle',
      'question': 'How well do you balance work and leisure?',
      'description':
          'Reflect on the amount of quality time you dedicate to relaxation and hobbies versus work.',
      'options': [
        {'text': 'Excellent balance', 'score': 3},
        {'text': 'Good balance but can improve', 'score': 2},
        {'text': 'Often work too much with little leisure', 'score': 1},
        {'text': 'No clear balance; work dominates my life', 'score': 0},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectOption(int score) async {
    await _animationController.reverse();
    setState(() {
      _selectedScores.add(score);
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _completeQuiz();
      }
    });
    await _animationController.forward();
  }

  Map<String, dynamic> _calculateCategoryScores() {
    Map<String, List<int>> categoryScores = {};
    for (int i = 0; i < _questions.length; i++) {
      String category = _questions[i]['category'];
      categoryScores.putIfAbsent(category, () => []);
      categoryScores[category]!.add(_selectedScores[i]);
    }

    Map<String, dynamic> results = {};
    categoryScores.forEach((category, scores) {
      double average = scores.reduce((a, b) => a + b) / scores.length;
      results[category] = average;
    });
    return results;
  }

  String _generateDetailedSuggestions(Map<String, dynamic> categoryScores) {
    Map<String, List<String>> suggestions = {
      'physical': [
        'Maintain your active routine and quality sleep.',
        'Consider fine-tuning your workout and sleep habits.',
        'Focus on establishing a regular exercise schedule and better sleep hygiene.'
      ],
      'mental': [
        'Excellent stress management—keep up your mindfulness practices!',
        'You’re doing well; try incorporating a bit more daily relaxation.',
        'Consider daily meditation or breathing exercises to manage stress.'
      ],
      'nutrition': [
        'Your diet is well-balanced. Continue your healthy eating habits!',
        'There is room for improvement—try adding more fruits and vegetables.',
        'Focus on planning balanced meals to include essential nutrients.'
      ],
      'productivity': [
        'Fantastic task management! Keep using your planning strategies.',
        'Good progress; refine your scheduling for even better productivity.',
        'Consider structured planning to overcome productivity challenges.'
      ],
      'lifestyle': [
        'Great balance between work and leisure. Enjoy your downtime!',
        'You have a decent balance; a bit more personal time could help.',
        'Work on setting clear boundaries to improve your work-life balance.'
      ],
    };

    StringBuffer result = StringBuffer();
    categoryScores.forEach((category, score) {
      result.writeln('\n${_categories[category]}:');
      if (score >= 2.5) {
        result.writeln(suggestions[category]![0]);
      } else if (score >= 1.5) {
        result.writeln(suggestions[category]![1]);
      } else {
        result.writeln(suggestions[category]![2]);
      }
    });

    return result.toString();
  }

  void _completeQuiz() async {
    Map<String, dynamic> categoryScores = _calculateCategoryScores();
    String detailedSuggestions = _generateDetailedSuggestions(categoryScores);

    setState(() {
      _quizCompleted = true;
      _quizResults = {
        'categoryScores': categoryScores,
        'suggestions': detailedSuggestions,
        'totalScore': _selectedScores.reduce((a, b) => a + b),
      };
    });

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quizResponses')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'responses': _selectedScores,
        'categoryScores': categoryScores,
        'suggestions': detailedSuggestions,
      });
    }
  }

  void _shareResults() {
    String shareText = 'My Momentum Quiz Results:\n\n';
    _quizResults['categoryScores'].forEach((category, score) {
      shareText += '${_categories[category]}: ${(score * 33.33).round()}%\n';
    });
    Share.share(shareText);
  }

  Widget _buildResultsView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Your Momentum Results',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ..._quizResults['categoryScores'].entries.map<Widget>((entry) {
              return Column(
                children: [
                  Text(
                    _categories[entry.key]!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FAProgressBar(
                    currentValue: entry.value * 33.33,
                    displayText: '%',
                    progressColor: Colors.blueAccent,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[850],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personalized Suggestions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _quizResults['suggestions'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _shareResults,
              icon: const Icon(Icons.share),
              label: const Text('Share Results'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView() {
    final currentQuestion = _questions[_currentQuestionIndex];
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
              const SizedBox(height: 16),
              Text(
                "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _categories[currentQuestion['category']]!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                currentQuestion['question'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (currentQuestion['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  currentQuestion['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ...currentQuestion['options'].map<Widget>((option) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _selectOption(option['score']),
                    child: Text(
                      option['text'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            Text(_quizCompleted ? "Your Results" : "Momentum Lifestyle Quiz"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: _quizCompleted ? _buildResultsView() : _buildQuestionView(),
      ),
    );
  }
}
