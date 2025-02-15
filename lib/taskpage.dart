import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;

  // New: Task priority and filtering
  String _priority = 'Medium'; // Default priority for new tasks.
  final List<String> _priorityOptions = ['High', 'Medium', 'Low'];
  String _taskFilter = 'All'; // Options: All, Completed, Pending

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Adds a new task to Firestore as an element in the user's "tasks" array.
  Future<void> _addTask() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || _dueDate == null || _dueTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // Combine the date and time into a single DateTime.
    final dueDateTime = DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _dueTime!.hour,
      _dueTime!.minute,
    );

    final task = {
      'id': _firestore.collection('users/$userId/tasks').doc().id,
      'title': title,
      'description': description,
      'dueDate': dueDateTime,
      'isCompleted': false,
      'priority': _priority,
      'createdAt': DateTime.now(),
    };

    try {
      await _firestore.collection('users').doc(userId).update({
        'tasks': FieldValue.arrayUnion([task]),
      });

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _dueDate = null;
        _dueTime = null;
        _priority = 'Medium'; // Reset priority after adding.
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add task: $e')),
      );
    }
  }

  /// Edits an existing task.
  Future<void> _editTask(String userId, String taskId, String title,
      String description, DateTime dueDateTime, String priority) async {
    final updatedTask = {
      'id': taskId,
      'title': title,
      'description': description,
      'dueDate': dueDateTime,
      'isCompleted': false,
      'priority': priority,
      'createdAt': DateTime.now(),
    };

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final tasks = List<Map<String, dynamic>>.from(userDoc['tasks'] ?? []);

      final updatedTasks = tasks.map((task) {
        return task['id'] == taskId ? updatedTask : task;
      }).toList();

      await _firestore.collection('users').doc(userId).update({
        'tasks': updatedTasks,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
    }
  }

  /// Deletes a task.
  Future<void> _deleteTask(String userId, String taskId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final tasks = List<Map<String, dynamic>>.from(userDoc['tasks'] ?? []);

      final updatedTasks = tasks.where((task) => task['id'] != taskId).toList();

      await _firestore.collection('users').doc(userId).update({
        'tasks': updatedTasks,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete task: $e')),
      );
    }
  }

  /// Toggles the completion status of a task.
  Future<void> _toggleTaskCompletion(
      String userId, String taskId, bool isCompleted) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final tasks = List<Map<String, dynamic>>.from(userDoc['tasks'] ?? []);

      final updatedTasks = tasks.map((task) {
        if (task['id'] == taskId) {
          return {...task, 'isCompleted': !isCompleted};
        }
        return task;
      }).toList();

      await _firestore.collection('users').doc(userId).update({
        'tasks': updatedTasks,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle task completion: $e')),
      );
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() => _dueDate = pickedDate);
    }
  }

  Future<void> _selectDueTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() => _dueTime = pickedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Tasks',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Filter popup menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _taskFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Completed', child: Text('Completed')),
              const PopupMenuItem(value: 'Pending', child: Text('Pending')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Task Form
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Priority dropdown
            Row(
              children: [
                const Text(
                  'Priority:',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _priority,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onChanged: (String? newValue) {
                    setState(() {
                      _priority = newValue!;
                    });
                  },
                  items: _priorityOptions
                      .map<DropdownMenuItem<String>>((String value) {
                    Color priorityColor;
                    if (value == 'High') {
                      priorityColor = Colors.red;
                    } else if (value == 'Medium') {
                      priorityColor = Colors.orange;
                    } else {
                      priorityColor = Colors.green;
                    }
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: priorityColor, size: 16),
                          const SizedBox(width: 8),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _dueDate == null
                      ? 'Select Due Date'
                      : 'Due Date: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  onPressed: () => _selectDueDate(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _dueTime == null
                      ? 'Select Time'
                      : 'Time: ${_dueTime!.format(context)}',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.access_time, color: Colors.white),
                  onPressed: () => _selectDueTime(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Task'),
            ),
            const SizedBox(height: 24),
            // Task List
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(userId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white)));
                  }

                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  List<dynamic> tasks =
                      userData?['tasks'] as List<dynamic>? ?? [];

                  // Apply filter based on _taskFilter.
                  if (_taskFilter == 'Completed') {
                    tasks = tasks
                        .where((task) => task['isCompleted'] == true)
                        .toList();
                  } else if (_taskFilter == 'Pending') {
                    tasks = tasks
                        .where((task) => task['isCompleted'] == false)
                        .toList();
                  }

                  // Sort tasks by due date (ascending)
                  tasks.sort((a, b) {
                    final aDate = (a['dueDate'] as Timestamp).toDate();
                    final bDate = (b['dueDate'] as Timestamp).toDate();
                    return aDate.compareTo(bDate);
                  });

                  if (tasks.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tasks found',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskId = task['id'];
                      final title = task['title'];
                      final description = task['description'];
                      final dueDate = (task['dueDate'] as Timestamp).toDate();
                      final isCompleted = task['isCompleted'];
                      final priority = task['priority'] ?? 'Medium';

                      Color priorityColor;
                      if (priority == 'High') {
                        priorityColor = Colors.red;
                      } else if (priority == 'Medium') {
                        priorityColor = Colors.orange;
                      } else {
                        priorityColor = Colors.green;
                      }

                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Due: ${DateFormat('MMM dd, yyyy hh:mm a').format(dueDate)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Row(
                                children: [
                                  const Text(
                                    'Priority: ',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Icon(Icons.circle,
                                      color: priorityColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(priority,
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isCompleted ? Icons.undo : Icons.check,
                                  color: Colors.white,
                                ),
                                onPressed: () => _toggleTaskCompletion(
                                    userId!, taskId, isCompleted),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTask(userId!, taskId),
                              ),
                            ],
                          ),
                          onTap: () => _showEditTaskDialog(
                            context,
                            userId!,
                            taskId,
                            title,
                            description,
                            dueDate,
                            priority,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to edit an existing task.
  void _showEditTaskDialog(BuildContext context, String userId, String taskId,
      String title, String description, DateTime dueDate, String priority) {
    final editTitleController = TextEditingController(text: title);
    final editDescriptionController = TextEditingController(text: description);
    // Split the dueDate into date and time parts.
    DateTime? editDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    TimeOfDay editDueTime = TimeOfDay.fromDateTime(dueDate);
    String editPriority = priority;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Edit Task',
            style: TextStyle(color: Colors.white),
          ),
          content: StatefulBuilder(
            // Use StatefulBuilder to update dialog state
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editTitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: const TextStyle(color: Colors.white),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: editDescriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(color: Colors.white),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Priority dropdown in edit dialog
                  Row(
                    children: [
                      const Text(
                        'Priority:',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: editPriority,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.white),
                        onChanged: (String? newValue) {
                          setState(() {
                            editPriority = newValue!;
                          });
                        },
                        items: _priorityOptions
                            .map<DropdownMenuItem<String>>((String value) {
                          Color priorityColor;
                          if (value == 'High') {
                            priorityColor = Colors.red;
                          } else if (value == 'Medium') {
                            priorityColor = Colors.orange;
                          } else {
                            priorityColor = Colors.green;
                          }
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    color: priorityColor, size: 16),
                                const SizedBox(width: 8),
                                Text(value),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        editDueDate == null
                            ? 'Select Due Date'
                            : 'Due Date: ${DateFormat('MMM dd, yyyy').format(editDueDate!)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today,
                            color: Colors.white),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: editDueDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => editDueDate = pickedDate);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Time: ${editDueTime.format(context)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.access_time, color: Colors.white),
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: editDueTime,
                          );
                          if (pickedTime != null) {
                            setState(() {
                              editDueTime = pickedTime;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                if (editDueDate != null) {
                  // Combine the selected date and time.
                  final dueDateTime = DateTime(
                    editDueDate!.year,
                    editDueDate!.month,
                    editDueDate!.day,
                    editDueTime.hour,
                    editDueTime.minute,
                  );
                  _editTask(
                    userId,
                    taskId,
                    editTitleController.text.trim(),
                    editDescriptionController.text.trim(),
                    dueDateTime,
                    editPriority,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
