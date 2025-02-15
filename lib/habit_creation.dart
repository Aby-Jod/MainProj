import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class HabitCreationPage extends StatefulWidget {
  final Map<String, dynamic>? habit;
  final Function? onAddHabit;
  final Function? onEditHabit;

  const HabitCreationPage({
    Key? key,
    this.habit,
    this.onAddHabit,
    this.onEditHabit,
  }) : super(key: key);

  @override
  State<HabitCreationPage> createState() => _HabitCreationPageState();
}

class _HabitCreationPageState extends State<HabitCreationPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  String _name = "";
  String _description = "";
  List<int> _days = [];
  TimeOfDay _reminderTime = TimeOfDay.now();
  String _motivation = "";
  Color _selectedColor = Colors.blue;
  String _category = "Health";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  // Predefined list of colors for the picker.
  final List<Color> _availableColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _initializeHabitData();
  }

  void _initializeNotifications() async {
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: settings),
      onDidReceiveNotificationResponse: (details) {},
    );
  }

  void _initializeHabitData() {
    if (widget.habit != null) {
      final data = widget.habit!;
      _name = data['name'] ?? "";
      _description = data['description'] ?? "";
      _days = List<int>.from(data['days'] ?? []);
      _motivation = data['motivation'] ?? "";
      _category = data['category'] ?? "Health";
      if (data['reminderTime'] != null) {
        // Now assuming reminderTime is stored as an ISO string.
        _reminderTime =
            TimeOfDay.fromDateTime(DateTime.parse(data['reminderTime']));
      }
      if (data['color'] != null) {
        _selectedColor = Color(data['color']);
      }
      setState(() {});
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: Colors.grey[850],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _saveHabitToFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');
      if (_days.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day')),
        );
        return;
      }
      final habitId = widget.habit != null
          ? widget.habit!['id']
          : _firestore.collection('users/$userId/habits').doc().id;

      // Convert the selected TimeOfDay to a DateTime (using today's date)
      final now = DateTime.now();
      final reminderDate = DateTime(now.year, now.month, now.day,
          _reminderTime.hour, _reminderTime.minute);

      final habit = {
        'id': habitId,
        'name': _name,
        'description': _description,
        'days': _days,
        'color': _selectedColor.value,
        // Save reminderTime as an ISO string.
        'reminderTime': reminderDate.toIso8601String(),
        'motivation': _motivation,
        'category': _category,
        'lastUpdated': FieldValue.serverTimestamp(),
        if (widget.habit == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final habitRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(habitId);
      if (widget.habit != null) {
        await habitRef.update(habit);
      } else {
        await habitRef.set(habit);
      }
      await _scheduleNotifications(habitId, _reminderTime, _days);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.habit != null
                ? 'Habit updated successfully'
                : 'Habit created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save habit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scheduleNotifications(
      String habitId, TimeOfDay reminderTime, List<int> days) async {
    final now = tz.TZDateTime.now(tz.local);
    for (final day in days) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + (day - now.weekday) % 7,
        reminderTime.hour,
        reminderTime.minute,
      );
      await _notificationsPlugin.zonedSchedule(
        day,
        'Habit Reminder',
        "Don't forget to $_name!",
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habit_reminder',
            'Habit Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: habitId,
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && !_formKey.currentState!.validate()) return;
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _finishCreation() {
    if (_formKey.currentState!.validate()) _saveHabitToFirestore();
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Basic Info',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        content: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: _inputDecoration('Habit Name'),
                initialValue: _name,
                onChanged: (value) => _name = value,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: _inputDecoration('Description'),
                initialValue: _description,
                onChanged: (value) => _description = value,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: Colors.black,
                items: ['Health', 'Fitness', 'Work', 'Personal']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value,
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
                decoration: _inputDecoration('Category'),
              ),
              const SizedBox(height: 20),
              const Text('Select Color:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey[850],
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: BlockPicker(
                    pickerColor: _selectedColor,
                    availableColors: _availableColors,
                    onColorChanged: (color) =>
                        setState(() => _selectedColor = color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Schedule',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Days:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1;
                return ChoiceChip(
                  label: Text(_weekDays[index],
                      style: const TextStyle(color: Colors.white)),
                  selected: _days.contains(day),
                  selectedColor: Colors.blueGrey,
                  backgroundColor: Colors.grey[800],
                  onSelected: (selected) {
                    setState(() {
                      selected ? _days.add(day) : _days.remove(day);
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.grey[800],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: const Text('Reminder Time',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              subtitle: Text(_reminderTime.format(context),
                  style: const TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.access_time, color: Colors.white70),
              onTap: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.blueGrey,
                          onPrimary: Colors.white,
                          surface: Colors.black,
                          onSurface: Colors.white70,
                        ),
                        timePickerTheme: const TimePickerThemeData(
                          dialBackgroundColor: Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (selected != null) setState(() => _reminderTime = selected);
              },
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Motivation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        content: TextFormField(
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: _inputDecoration('Motivation'),
          initialValue: _motivation,
          onChanged: (value) => _motivation = value,
          maxLines: 3,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.habit != null ? 'Edit Habit' : 'Create Habit',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: Colors.black,
      body: Stepper(
        currentStep: _currentStep,
        steps: steps,
        type: StepperType.vertical,
        onStepContinue:
            _currentStep < steps.length - 1 ? _nextStep : _finishCreation,
        onStepCancel: _prevStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                      _currentStep == steps.length - 1 ? 'Finish' : 'Next'),
                ),
                const SizedBox(width: 16),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
