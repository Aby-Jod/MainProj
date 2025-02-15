import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mainproj/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ------------------ Dummy Theme Provider ------------------
// ------------------ MAIN ------------------
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit App',
      theme: ThemeData.dark(),
      home:  HomePage(),
    );
  }
}

/// ------------------ HOME PAGE ------------------
class HomePage extends StatelessWidget {
   HomePage({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Text("User not logged in",
              style: TextStyle(color: theme.textColor)),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Home", style: TextStyle(color: theme.textColor)),
        backgroundColor: theme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => CategoriesPage()));
            },
          )
        ],
      ),
      backgroundColor: theme.backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('habits')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: theme.textColor));
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
                child: Text("No habits found",
                    style: TextStyle(color: theme.textColor)));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final habit = docs[index].data() as Map<String, dynamic>;
              // Ensure category is not empty or "uncategorized"
              final rawCategory = (habit['category'] as String?)?.trim() ?? "";
              final category = rawCategory.isEmpty ||
                      rawCategory.toLowerCase() == 'uncategorized'
                  ? "Other"
                  : rawCategory;
              return ListTile(
                title: Text(habit['name'] ?? "",
                    style: TextStyle(color: theme.textColor)),
                subtitle: Text(category,
                    style: TextStyle(color: theme.textColor.withOpacity(0.7))),
              );
            },
          );
        },
      ),
    );
  }
}

/// ------------------ CATEGORY MODEL ------------------
class Category {
  final String name;
  final IconData icon;
  Category(this.name, this.icon);
}

/// ------------------ CATEGORIES PAGE ------------------
class CategoriesPage extends StatelessWidget {
  CategoriesPage({super.key});

  final List<Category> categories = [
    Category('Health', Icons.fitness_center),
    Category('Productivity', Icons.work),
    Category('Learning', Icons.book),
    Category('Wellness', Icons.self_improvement),
    Category('Social', Icons.people),
    Category('Hobbies', Icons.music_note),
    Category('Finance', Icons.attach_money),
    Category('Mindfulness', Icons.spa),
    Category('Creativity', Icons.brush),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text("Categories",
            style:
                TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        backgroundColor: theme.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: 1.2,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryCard(
              category: category,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          HabitCreationPage(category: category)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 32, color: theme.textColor),
              const SizedBox(height: 16),
              Text(category.name,
                  style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------ HABIT CREATION PAGE ------------------
class HabitCreationPage extends StatefulWidget {
  final Category category;
  const HabitCreationPage({super.key, required this.category});
  @override
  State<HabitCreationPage> createState() => _HabitCreationPageState();
}

class _HabitCreationPageState extends State<HabitCreationPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _frequency = "daily"; // "daily" or "weekly"
  TimeOfDay? _reminderTime;
  String? _weeklyDay;
  Color _selectedColor = Colors.blue;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _reminderTime = TimeOfDay.now();

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _createHabit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a habit name')));
      return;
    }
    if (_frequency.toLowerCase() == 'weekly' && _weeklyDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a day for your weekly habit')));
      return;
    }
    final user = _auth.currentUser;
    if (user == null) return;
    final habitId = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc()
        .id;
    List<int> days = [];
    if (_frequency.toLowerCase() == 'daily') {
      days = List.generate(7, (index) => index + 1);
    } else if (_frequency.toLowerCase() == 'weekly' && _weeklyDay != null) {
      final Map<String, int> weekdayMap = {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
        'Sunday': 7,
      };
      days = [weekdayMap[_weeklyDay!]!];
    }
    final habit = {
      'id': habitId,
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'days': days,
      'color': _selectedColor.value,
      'reminderTime': _reminderTime?.format(context) ?? '',
      'completed': false,
      'day': DateTime.now().weekday,
      'category': widget.category.name,
    };
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .doc(habitId)
          .set(habit);
      if (_reminderTime != null) {
        await _scheduleNotification(_frequency, _reminderTime!);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Habit Created (${_frequency.capitalize()})')));
      }
    } catch (e) {
      debugPrint("Error saving habit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create habit')));
    }
  }

  Future<void> _scheduleNotification(String frequency, TimeOfDay time) async {
    int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final now = DateTime.now();
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (frequency.toLowerCase() == "daily") {
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Habit Reminder',
        'Time to complete your habit: ${_nameController.text.trim()}',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'Daily Reminders',
            channelDescription: 'Daily habit reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else if (frequency.toLowerCase() == "weekly") {
      if (_weeklyDay != null) {
        Map<String, int> weekdayMap = {
          'Monday': DateTime.monday,
          'Tuesday': DateTime.tuesday,
          'Wednesday': DateTime.wednesday,
          'Thursday': DateTime.thursday,
          'Friday': DateTime.friday,
          'Saturday': DateTime.saturday,
          'Sunday': DateTime.sunday,
        };
        int targetWeekday = weekdayMap[_weeklyDay!]!;
        while (scheduledDate.weekday != targetWeekday) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }
        await flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          'Habit Reminder',
          'Time to complete your habit: ${_nameController.text.trim()}',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'weekly_channel',
              'Weekly Reminders',
              channelDescription: 'Weekly habit reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  void _selectHabitColor() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Habit Color"),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _selectedColor,
              availableColors: const [
                Colors.blue,
                Colors.red,
                Colors.green,
                Colors.orange,
                Colors.purple,
                Colors.teal,
                Colors.amber,
              ],
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  String _getSuggestion(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'health':
        return "Try a 30-minute walk daily or a quick workout.";
      case 'productivity':
        return "Plan your day with a to-do list each morning.";
      case 'learning':
        return "Spend 20 minutes on a new language or course.";
      case 'wellness':
        return "Practice meditation or yoga for 15 minutes.";
      case 'social':
        return "Reach out to a friend or plan a group activity.";
      case 'hobbies':
        return "Dedicate time to your hobby, like playing an instrument.";
      case 'finance':
        return "Review your budget and track expenses weekly.";
      case 'mindfulness':
        return "Take a few minutes daily to reflect and relax.";
      case 'creativity':
        return "Spend time writing, drawing, or engaging in creative work.";
      default:
        return "Stay consistent!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final suggestion = _getSuggestion(widget.category.name);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Habit'),
        backgroundColor: theme.backgroundColor,
      ),
      backgroundColor: theme.backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(widget.category.icon,
                        size: 32, color: theme.textColor),
                    const SizedBox(width: 8),
                    Text(widget.category.name,
                        style: TextStyle(
                            color: theme.textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Suggestion: $suggestion',
                    style: TextStyle(
                        color: theme.textColor.withOpacity(0.7), fontSize: 14)),
                const SizedBox(height: 16),
                _buildInputField('Habit Name', _nameController),
                const SizedBox(height: 16),
                _buildInputField('Description', _descController),
                const SizedBox(height: 16),
                _buildFrequencySelector(),
                if (_frequency.toLowerCase() == 'weekly') ...[
                  const SizedBox(height: 16),
                  _buildWeeklyDaySelector(),
                ],
                const SizedBox(height: 16),
                _buildColorPicker(),
                const SizedBox(height: 16),
                _buildReminderTimePicker(),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _createHabit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.textColor,
                      foregroundColor: theme.backgroundColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Habit',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildInputField(String label, TextEditingController controller) {
    final theme = Provider.of<ThemeProvider>(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textColor),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: theme.textColor)),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey)),
      ),
      style: TextStyle(color: theme.textColor),
    );
  }

  Widget _buildReminderTimePicker() {
    final theme = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminder Time',
            style: TextStyle(color: theme.textColor, fontSize: 16)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (pickedTime != null) {
              setState(() {
                _reminderTime = pickedTime;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_reminderTime?.format(context) ?? 'Select Time',
                    style: TextStyle(color: theme.textColor)),
                const Icon(Icons.access_time, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    final theme = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequency',
            style: TextStyle(color: theme.textColor, fontSize: 16)),
        Row(
          children: [
            Radio<String>(
              value: "daily",
              groupValue: _frequency,
              activeColor: theme.textColor,
              onChanged: (value) {
                setState(() {
                  _frequency = value!;
                  _weeklyDay = null;
                });
              },
            ),
            Text("Daily", style: TextStyle(color: theme.textColor)),
            const SizedBox(width: 20),
            Radio<String>(
              value: "weekly",
              groupValue: _frequency,
              activeColor: theme.textColor,
              onChanged: (value) {
                setState(() {
                  _frequency = value!;
                  _weeklyDay ??= "Monday";
                });
              },
            ),
            Text("Weekly", style: TextStyle(color: theme.textColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyDaySelector() {
    final theme = Provider.of<ThemeProvider>(context);
    return DropdownButtonFormField<String>(
      value: _weeklyDay,
      decoration: InputDecoration(
        labelText: 'Select Day',
        labelStyle: TextStyle(color: theme.textColor),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey)),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: theme.textColor)),
      ),
      items: [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ]
          .map((day) => DropdownMenuItem(
                value: day,
                child: Text(day, style: TextStyle(color: theme.textColor)),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _weeklyDay = value;
        });
      },
    );
  }

  Widget _buildColorPicker() {
    final theme = Provider.of<ThemeProvider>(context);
    return Row(
      children: [
        Text("Habit Color: ",
            style: TextStyle(color: theme.textColor, fontSize: 16)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _selectHabitColor,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _selectedColor,
              border: Border.all(color: theme.textColor),
            ),
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
