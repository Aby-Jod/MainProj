import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'sidebar.dart';
import 'taskpage.dart';
import 'package:mainproj/categories.dart' hide HabitCreationPage;
import 'package:mainproj/habit_creation.dart';
import 'timer_stopwatch.dart';
import 'theme_notifier.dart';

class ActivitySearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> habits;
  ActivitySearchDelegate(this.habits);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = "";
          },
        )
      ];

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = habits
        .where((habit) =>
            habit['name'].toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _buildSearchResults(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? habits
        : habits
            .where((habit) =>
                habit['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
    return _buildSearchResults(suggestions);
  }

  Widget _buildSearchResults(List<Map<String, dynamic>> results) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final habit = results[index];
        return ListTile(
          title: Text(habit['name']),
          onTap: () {
            close(context, habit['name']);
          },
        );
      },
    );
  }
}

class ChatbotDialog extends StatelessWidget {
  final ThemeProvider themeProvider;
  const ChatbotDialog({super.key, required this.themeProvider});

  final Map<String, String> _queries = const {
    "How do I add a habit?":
        "To add a habit, tap the 'New Habit' button and follow the guided questions.",
    "How do I track my progress?":
        "Your progress is available in the Statistics section.",
    "What are achievements?":
        "Achievements are milestones you unlock as you complete habits.",
    "How do I contact support?":
        "You can contact support via the 'Contact Us' option in Settings.",
    "How do I customize the app?":
        "Go to Settings > Customize to change themes and layouts.",
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: themeProvider.backgroundColor,
      title: Text("Chatbot", style: TextStyle(color: themeProvider.textColor)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: _queries.keys.map((query) {
            return ListTile(
              title:
                  Text(query, style: TextStyle(color: themeProvider.textColor)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnswerPage(
                      query: query,
                      answer: _queries[query] ?? "",
                      themeProvider: themeProvider,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              Text("Close", style: TextStyle(color: themeProvider.textColor)),
        ),
      ],
    );
  }
}

class AnswerPage extends StatelessWidget {
  final String query;
  final String answer;
  final ThemeProvider themeProvider;
  const AnswerPage({
    super.key,
    required this.query,
    required this.answer,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.backgroundColor,
        title: Text(
          query,
          style: TextStyle(color: themeProvider.textColor),
        ),
        iconTheme: IconThemeData(color: themeProvider.textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          answer,
          style: TextStyle(fontSize: 18, color: themeProvider.textColor),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  const HomeScreen(
      {super.key, required this.userName, required this.userEmail});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Color _convertToColor(dynamic colorData) {
    if (colorData is Color) return colorData;
    if (colorData is int) return Color(colorData);
    if (colorData is String) {
      String hex =
          colorData.startsWith('#') ? colorData.substring(1) : colorData;
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      try {
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        debugPrint("Error parsing color: $e");
        return Colors.blue;
      }
    }
    return Colors.blue;
  }

  Color _getContrastingTextColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  void _showCalendar() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    DateTime focusedDay = DateTime.now();
    DateTime? selectedDay;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.backgroundColor,
        title:
            Text("Calendar", style: TextStyle(color: themeProvider.textColor)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setState) {
              return TableCalendar(
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleTextStyle:
                      TextStyle(color: themeProvider.textColor, fontSize: 18),
                  leftChevronIcon:
                      Icon(Icons.chevron_left, color: themeProvider.textColor),
                  rightChevronIcon:
                      Icon(Icons.chevron_right, color: themeProvider.textColor),
                  decoration: BoxDecoration(
                    color: themeProvider.backgroundColor,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: themeProvider.textColor),
                  weekendStyle: TextStyle(color: themeProvider.textColor),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: themeProvider.textColor,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: themeProvider.textColor),
                ),
                focusedDay: focusedDay,
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                  CalendarFormat.twoWeeks: '2 Weeks',
                  CalendarFormat.week: 'Week',
                },
                selectedDayPredicate: (day) {
                  return isSameDay(selectedDay, day);
                },
                onDaySelected: (selDay, focDay) {
                  setState(() {
                    selectedDay = selDay;
                    focusedDay = focDay;
                  });
                },
                onPageChanged: (newFocusedDay) {
                  setState(() {
                    focusedDay = newFocusedDay;
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openChatbot() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => ChatbotDialog(themeProvider: themeProvider),
    );
  }

  Widget _noHabitsPlaceholder() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_outline, size: 100),
          const SizedBox(height: 16),
          Text('No Habits Added Yet',
              style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tap the "New Habit" button to add a habit!',
              style: TextStyle(
                  color: themeProvider.textColor.withOpacity(0.7),
                  fontSize: 14)),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _habitStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .snapshots();
  }

  Future<void> _addHabitToFirestore(Map<String, dynamic> habitData) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final docRef =
        _firestore.collection('users').doc(userId).collection('habits').doc();
    final Color habitColor = _convertToColor(habitData['color']);

    DateTime? reminder;
    if (habitData['reminderTime'] is String &&
        habitData['reminderTime'].trim().isNotEmpty) {
      try {
        reminder = DateTime.parse(habitData['reminderTime']);
      } catch (e) {
        debugPrint("Invalid reminderTime format: $e");
        reminder = null;
      }
    }

    final habit = {
      'id': docRef.id,
      'name': habitData['name'],
      'description': habitData['description'],
      'days': habitData['days'],
      'color': '#${habitColor.value.toRadixString(16).padLeft(8, '0')}',
      'reminderTime': reminder != null ? Timestamp.fromDate(reminder) : null,
      'completed': false,
      'day': DateTime.now().weekday,
      'motivation': habitData['motivation'] ?? '',
      'frequency': habitData['frequency'] ?? 'Daily',
    };
    try {
      await docRef.set(habit);
    } catch (e) {
      debugPrint("Error adding habit: $e");
    }
  }

  Future<void> _editHabit(Map<String, dynamic> updatedHabit) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      if (updatedHabit['reminderTime'] is String &&
          updatedHabit['reminderTime'].trim().isNotEmpty) {
        try {
          DateTime reminder = DateTime.parse(updatedHabit['reminderTime']);
          updatedHabit['reminderTime'] = Timestamp.fromDate(reminder);
        } catch (e) {
          debugPrint("Invalid reminderTime format during edit: $e");
          updatedHabit['reminderTime'] = null;
        }
      }
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(updatedHabit['id']);
      await docRef.update(updatedHabit);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit updated successfully')),
      );
    } catch (e) {
      debugPrint("Error editing habit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing habit: $e')),
      );
    }
  }

  Future<void> _deleteHabit(String habitId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(habitId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit deleted successfully')),
      );
    } catch (e) {
      debugPrint("Error deleting habit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting habit: $e')),
      );
    }
  }

  Future<void> _toggleCompletion(Map<String, dynamic> habit) async {
    final int today = DateTime.now().weekday;
    // Treat missing or empty frequency as 'Daily'
    final String freq = (habit['frequency']?.toString().trim() ?? 'Daily');
    bool freqDaily = (freq == 'Daily');
    bool showCompletionIcon =
        freqDaily || (habit['days'] is List && habit['days'].contains(today));
    if (!showCompletionIcon) return;

    bool isCompletedToday =
        (habit['completed'] == true && habit['day'] == today);
    Map<String, dynamic> updatedHabit = Map.from(habit);
    List completions = updatedHabit['completions'] != null
        ? List.from(updatedHabit['completions'])
        : [];

    if (!isCompletedToday) {
      updatedHabit['completed'] = true;
      updatedHabit['day'] = today;
      completions.add(Timestamp.now());
    } else {
      updatedHabit['completed'] = false;
      if (completions.isNotEmpty) {
        DateTime lastCompletion = (completions.last as Timestamp).toDate();
        DateTime now = DateTime.now();
        if (lastCompletion.year == now.year &&
            lastCompletion.month == now.month &&
            lastCompletion.day == now.day) {
          completions.removeLast();
        }
      }
    }
    updatedHabit['completions'] = completions;
    await _editHabit(updatedHabit);
  }

  void _openHabitCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitCreationPage(
          onAddHabit: (Map<String, dynamic> habitData) {
            _addHabitToFirestore(habitData);
          },
          onEditHabit: (Map<String, dynamic> habitData) {},
        ),
      ),
    );
  }

  void _openHabitEditing(Map<String, dynamic> habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitCreationPage(
          habit: habit,
          onAddHabit: (Map<String, dynamic> habitData) {},
          onEditHabit: (Map<String, dynamic> updatedHabitData) {
            _editHabit(updatedHabitData);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Momentum',
              style: TextStyle(color: themeProvider.textColor)),
          backgroundColor: themeProvider.backgroundColor,
        ),
        body: Center(
          child: Text(
            'No user signed in. Please sign in to view your habits.',
            style: TextStyle(color: themeProvider.textColor),
          ),
        ),
      );
    }

    return Scaffold(
      drawer: Sidebar(
        userName: widget.userName,
        userEmail: widget.userEmail,
      ),
      appBar: AppBar(
        title:
            Text('Momentum', style: TextStyle(color: themeProvider.textColor)),
        backgroundColor: themeProvider.backgroundColor,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: themeProvider.textColor),
            onPressed: _showCalendar,
          ),
          IconButton(
            icon: Icon(Icons.search, color: themeProvider.textColor),
            onPressed: () {
              showSearch(
                  context: context, delegate: ActivitySearchDelegate([]));
            },
          ),
          IconButton(
            icon: Icon(Icons.chat, color: themeProvider.textColor),
            onPressed: _openChatbot,
          ),
        ],
      ),
      body: Container(
        color: themeProvider.backgroundColor,
        child: StreamBuilder<QuerySnapshot>(
          stream: _habitStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading habits'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final habitDocs = snapshot.data!.docs;
            if (habitDocs.isEmpty) {
              return _noHabitsPlaceholder();
            }
            return ListView.builder(
              itemCount: habitDocs.length,
              itemBuilder: (context, index) {
                final habit = habitDocs[index].data() as Map<String, dynamic>;
                // Update the check to treat missing/empty frequency as 'Daily'
                final String freq =
                    (habit['frequency']?.toString().trim() ?? 'Daily');
                bool freqDaily = (freq == 'Daily');
                bool showCompletionIcon = freqDaily ||
                    (habit['days'] is List &&
                        habit['days'].contains(DateTime.now().weekday));
                bool isCompletedToday = (habit['completed'] == true &&
                    habit['day'] == DateTime.now().weekday);
                final habitColor = _convertToColor(habit['color']);
                return Card(
                  color: habitColor,
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                habit['name'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getContrastingTextColor(habitColor),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                habit['description'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _getContrastingTextColor(habitColor)
                                      .withOpacity(0.8),
                                ),
                              ),
                              if (habit['motivation'] != null &&
                                  (habit['motivation'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Motivation: ${habit['motivation']}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          _getContrastingTextColor(habitColor)
                                              .withOpacity(0.7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            if (showCompletionIcon)
                              IconButton(
                                icon: Icon(
                                  isCompletedToday
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: _getContrastingTextColor(habitColor),
                                ),
                                onPressed: () => _toggleCompletion(habit),
                              ),
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: _getContrastingTextColor(habitColor)),
                              onPressed: () => _openHabitEditing(habit),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  color: _getContrastingTextColor(habitColor)),
                              onPressed: () => _deleteHabit(habit['id']),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "newHabitFAB",
        onPressed: _openHabitCreation,
        label:
            Text('New Habit', style: TextStyle(color: themeProvider.textColor)),
        icon: Icon(Icons.add, color: themeProvider.textColor),
        backgroundColor: themeProvider.backgroundColor,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: themeProvider.backgroundColor,
          border: const Border(
            top: BorderSide(color: Colors.transparent, width: 0),
          ),
        ),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: themeProvider.textColor,
          unselectedItemColor: themeProvider.textColor.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 0) {
              // Already on HomeScreen.
            } else if (index == 1) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const TaskPage()));
            } else if (index == 2) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => CategoriesPage()));
            } else if (index == 3) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TimerStopwatchScreen()));
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'Tasks',
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
      ),
    );
  }
}
