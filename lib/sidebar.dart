import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting the current date
import 'package:mainproj/community_page.dart';
import 'package:mainproj/quizpage.dart';
import 'package:mainproj/statistics.dart';
import 'package:mainproj/settings.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import for FirebaseAuth

/// A custom widget that animates a drawer item when tapped.
class AnimatedDrawerItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const AnimatedDrawerItem({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AnimatedDrawerItemState createState() => _AnimatedDrawerItemState();
}

class _AnimatedDrawerItemState extends State<AnimatedDrawerItem> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.95; // Shrink slightly when pressed.
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: ListTile(
          leading: Icon(widget.icon, color: Colors.white),
          title: Text(
            widget.text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The Sidebar widget with animated drawer items and a motivational quote at the bottom.
class Sidebar extends StatefulWidget {
  final String userName;
  final String userEmail;

  const Sidebar({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  // A larger list of motivational quotes.
  static const List<String> motivationalQuotes = [
    "The only way to do great work is to love what you do. – Steve Jobs",
    "Success is not final, failure is not fatal: It is the courage to continue that counts. – Winston Churchill",
    "Believe you can and you're halfway there. – Theodore Roosevelt",
    "I can't change the direction of the wind, but I can adjust my sails to always reach my destination. – Jimmy Dean",
    "You are never too old to set another goal or to dream a new dream. – C.S. Lewis",
    "The best time to plant a tree was 20 years ago. The second best time is now. – Chinese Proverb",
    "Hardships often prepare ordinary people for an extraordinary destiny. – C.S. Lewis",
    "Don't watch the clock; do what it does. Keep going. – Sam Levenson",
    "Everything you’ve ever wanted is on the other side of fear. – George Addair",
    "Dream big and dare to fail. – Norman Vaughan",
    "Success usually comes to those who are too busy to be looking for it. – Henry David Thoreau",
    "Keep your face always toward the sunshine—and shadows will fall behind you. – Walt Whitman",
    "The future belongs to those who believe in the beauty of their dreams. – Eleanor Roosevelt",
  ];

  late final String randomQuote;
  // Local variables to hold user data.
  String localUserName = "";
  String localUserEmail = "";

  @override
  void initState() {
    super.initState();
    // Compute the random quote once when the Sidebar is created.
    randomQuote =
        motivationalQuotes[Random().nextInt(motivationalQuotes.length)];
    // Initialize with widget values.
    localUserName = widget.userName;
    localUserEmail = widget.userEmail;
    _loadUserData();
  }

  /// Loads user details from FirebaseAuth if the provided values are empty.
  Future<void> _loadUserData() async {
    if (localUserName.isEmpty || localUserEmail.isEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          // Use currentUser.displayName if available; otherwise, derive a name from the email.
          localUserName = (currentUser.displayName != null &&
                  currentUser.displayName!.isNotEmpty)
              ? currentUser.displayName!
              : (currentUser.email?.split('@')[0] ?? "User");
          localUserEmail = currentUser.email ?? "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        // Keeping a dark theme with a solid black background.
        color: Colors.black,
        child: Column(
          children: [
            // Modified DrawerHeader to remove default padding and align content to the margin.
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: Container(
                width: double.infinity,
                // Custom padding for a tight layout.
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome, $localUserName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${DateFormat('dd MMM, yyyy').format(DateTime.now())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The expandable list of drawer items.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  AnimatedDrawerItem(
                    icon: Icons.home,
                    text: 'Home',
                    onTap: () {
                      // Simply close the drawer.
                      Navigator.pop(context);
                    },
                  ),
                  AnimatedDrawerItem(
                    icon: Icons.bar_chart,
                    text: 'Statistics',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsPage(),
                        ),
                      );
                    },
                  ),
                  AnimatedDrawerItem(
                    icon: Icons.group,
                    text: 'Community',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CommunityPage(),
                        ),
                      );
                    },
                  ),
                  AnimatedDrawerItem(
                    icon: Icons.quiz,
                    text: 'Quiz',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuizPage(),
                        ),
                      );
                    },
                  ),
                  AnimatedDrawerItem(
                    icon: Icons.settings,
                    text: 'Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(
                            userName: localUserName,
                            userEmail: localUserEmail,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(
              color: Colors.white54,
            ),
            // The motivational quote at the bottom.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                randomQuote,
                style: const TextStyle(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
