import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _searchTerm = '';

  void _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchMessages();
  }

  Future<void> _fetchUsers() async {
    try {
      QuerySnapshot userSnapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> users = userSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
          // Optionally, mark active status here.
          'isActive': _auth.currentUser?.uid == doc.id,
        };
      }).toList();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching users: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMessages() async {
    try {
      QuerySnapshot messageSnapshot =
          await _firestore.collection('community_chat').get();
      List<Map<String, dynamic>> messages = messageSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      setState(() {
        _messages = messages;
      });
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }
  }

  Future<void> _removeUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      setState(() {
        _users.removeWhere((user) => user['id'] == userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove user: $e')),
      );
    }
  }

  Future<void> _blockUser(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'blocked': true});
      setState(() {
        final userIndex = _users.indexWhere((user) => user['id'] == userId);
        if (userIndex != -1) {
          _users[userIndex]['blocked'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to block user: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers => _users.where((user) {
        final name = (user['fullName'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final searchLower = _searchTerm.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final totalChats = _messages.length;
    final blockedUsers = _users.where((user) => user['blocked'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Cards
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 600 ? 3 : 1,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _StatCard(
                            icon: Icons.people,
                            iconColor: Colors.blue,
                            title: 'Total Users',
                            value: _users.length.toString(),
                          ),
                          _StatCard(
                            icon: Icons.chat_bubble,
                            iconColor: Colors.green,
                            title: 'Total Chats',
                            value: totalChats.toString(),
                          ),
                          _StatCard(
                            icon: Icons.block,
                            iconColor: Colors.red,
                            title: 'Blocked Users',
                            value: blockedUsers.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Search Bar
                      TextField(
                        onChanged: (value) =>
                            setState(() => _searchTerm = value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // User Table
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              MaterialStateProperty.all(Colors.grey[900]),
                          columns: const [
                            DataColumn(
                                label: Text('Name',
                                    style: TextStyle(color: Colors.white))),
                            DataColumn(
                                label: Text('Email',
                                    style: TextStyle(color: Colors.white))),
                            DataColumn(
                                label: Text('Status',
                                    style: TextStyle(color: Colors.white))),
                            DataColumn(
                                label: Text('Actions',
                                    style: TextStyle(color: Colors.white))),
                          ],
                          rows: _filteredUsers.map((user) {
                            return DataRow(cells: [
                              DataCell(Text(user['fullName'] ?? 'N/A',
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(user['email'] ?? 'N/A',
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(
                                user['blocked'] == true
                                    ? 'Blocked'
                                    : (user['isActive']
                                        ? 'Active'
                                        : 'Inactive'),
                                style: TextStyle(
                                  color: user['blocked'] == true
                                      ? Colors.red
                                      : (user['isActive']
                                          ? Colors.green
                                          : Colors.grey),
                                ),
                              )),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.block,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _blockUser(user['id'] ?? ''),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.grey),
                                    onPressed: () =>
                                        _removeUser(user['id'] ?? ''),
                                  ),
                                ],
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Recent Chats Table
                      const Text(
                        'Recent Chats',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              MaterialStateProperty.all(Colors.grey[900]),
                          columns: const [
                            DataColumn(
                                label: Text('User',
                                    style: TextStyle(color: Colors.white))),
                            DataColumn(
                                label: Text('Message',
                                    style: TextStyle(color: Colors.white))),
                            DataColumn(
                                label: Text('Timestamp',
                                    style: TextStyle(color: Colors.white))),
                          ],
                          rows: _messages.map((message) {
                            return DataRow(cells: [
                              DataCell(Text(
                                message['userName'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white),
                              )),
                              DataCell(Text(
                                message['message'] ?? '',
                                style: const TextStyle(color: Colors.white70),
                              )),
                              DataCell(Text(
                                message['timestamp']?.toDate().toString() ?? '',
                                style: const TextStyle(color: Colors.white60),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    // ignore: unused_element
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w400,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              )),
        ],
      ),
    );
  }
}
