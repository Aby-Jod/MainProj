import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mainproj/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'theme_notifier.dart';

// Import your login and categories pages (update paths as needed)
import 'login.dart';
import 'categories.dart';

/// A reusable widget that applies a slight scale animation when tapped.
class TapAnimatedWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const TapAnimatedWidget({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  _TapAnimatedWidgetState createState() => _TapAnimatedWidgetState();
}

class _TapAnimatedWidgetState extends State<TapAnimatedWidget> {
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
        child: widget.child,
      ),
    );
  }
}

/// ------------------------- SettingsPage -------------------------
class SettingsPage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const SettingsPage({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  // Initialize with widget values so we have defaults.
  late String userName;
  late String userEmail;
  bool isLoadingUserData = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Set initial values from the widget (passed from login or elsewhere)
    userName = widget.userName;
    userEmail = widget.userEmail;
    _loadUserData();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
  }

  /// Loads user details from SharedPreferences, or fall back to FirebaseAuth.
  Future<void> _loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        userName = prefs.getString('userName') ?? widget.userName;
        userEmail = prefs.getString('userEmail') ?? widget.userEmail;
      });
      // If no data is stored or if they are empty, fall back to FirebaseAuth.
      if (userName.isEmpty || userEmail.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          setState(() {
            // Use currentUser.displayName if available,
            // otherwise derive a name from the email address.
            userName = (currentUser.displayName != null &&
                    currentUser.displayName!.isNotEmpty)
                ? currentUser.displayName!
                : (currentUser.email?.split('@')[0] ?? 'User');
            userEmail = currentUser.email ?? widget.userEmail;
          });
        }
      }
      setState(() {
        isLoadingUserData = false;
      });
    } catch (e) {
      setState(() {
        isLoadingUserData = false;
      });
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  /// Launches an email client for "Contact Us" (with admin email).
  Future<void> _launchContactEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'aeropc321@gmail.com',
      query: _encodeQueryParameters({'subject': 'App Support'}),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch the email app.")),
      );
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _openCustomizationDialog() {
    final themeNotifier = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeNotifier.backgroundColor,
          title: Text(
            "Customize Settings",
            style: TextStyle(color: themeNotifier.textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // Text Color Options
                Text(
                  "Text Color",
                  style: TextStyle(color: themeNotifier.textColor),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildColorOption(Colors.white, isTextColor: true),
                    _buildColorOption(Colors.red, isTextColor: true),
                    _buildColorOption(Colors.green, isTextColor: true),
                    _buildColorOption(Colors.blue, isTextColor: true),
                    _buildColorOption(Colors.yellow, isTextColor: true),
                  ],
                ),
                const SizedBox(height: 20),
                // Background Color Options
                Text(
                  "Background Color",
                  style: TextStyle(color: themeNotifier.textColor),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildColorOption(Colors.black, isTextColor: false),
                    _buildColorOption(Colors.grey[900]!, isTextColor: false),
                    _buildColorOption(Colors.deepPurple, isTextColor: false),
                    _buildColorOption(Colors.teal, isTextColor: false),
                    _buildColorOption(Colors.brown, isTextColor: false),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close",
                  style: TextStyle(color: themeNotifier.textColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorOption(Color color, {required bool isTextColor}) {
    return Consumer<ThemeProvider>(
      builder: (context, themeNotifier, child) {
        return GestureDetector(
          onTap: () {
            if (isTextColor) {
              themeNotifier.setTextColor(color);
            } else {
              themeNotifier.setBackgroundColor(color);
            }
            Navigator.pop(context);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: themeNotifier.textColor, width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final themeNotifier = Provider.of<ThemeProvider>(context);
    return TapAnimatedWidget(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: themeNotifier.textColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: themeNotifier.textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeNotifier.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeNotifier.backgroundColor,
        elevation: 0,
        title: Text(
          "Settings",
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: themeNotifier.textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeNotifier.textColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: themeNotifier.textColor),
            onPressed: _logout,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Profile Section
                isLoadingUserData
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[800],
                            child: Text(
                              userName.isNotEmpty
                                  ? userName.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                  fontSize: 24, color: themeNotifier.textColor),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName.isNotEmpty
                                    ? userName
                                    : 'No username provided',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeNotifier.textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userEmail.isNotEmpty
                                    ? userEmail
                                    : 'No email provided',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: themeNotifier.textColor
                                        .withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                const SizedBox(height: 20),
                // Settings List
                Expanded(
                  child: ListView(
                    children: [
                      _buildSettingsItem(
                        title: "Categories",
                        icon: Icons.category,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => CategoriesPage()),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        title: "Backups",
                        icon: Icons.backup,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BackupPage(
                                userName: userName,
                                userEmail: userEmail,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        title: "Customize",
                        icon: Icons.brush,
                        onTap: _openCustomizationDialog,
                      ),
                      _buildSettingsItem(
                        title: "Contact Us",
                        icon: Icons.contact_support,
                        onTap: _launchContactEmail,
                      ),
                      _buildSettingsItem(
                        title: "Premium",
                        icon: Icons.star,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PremiumLandingPage()),
                          );
                        },
                      ),
                    ],
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

/// ------------------------- BackupPage -------------------------
class BackupPage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const BackupPage({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool isBackingUp = false;
  String backupMessage = '';

  /// Simulate backup data.
  String _generateBackupData() {
    return 'Full Name: ${widget.userName}\n'
        'Email: ${widget.userEmail}\n'
        'Backup Time: ${DateTime.now()}\n';
  }

  /// Backup to phone storage by writing a file to the documents directory.
  Future<void> _backupToStorage() async {
    setState(() {
      isBackingUp = true;
      backupMessage = '';
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupData = _generateBackupData();
      final file = File(
          '${directory.path}/backup_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(backupData);

      setState(() {
        backupMessage = 'Backup saved to ${file.path}';
      });
    } catch (e) {
      setState(() {
        backupMessage = 'Backup failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        isBackingUp = false;
      });
    }
  }

  /// Backup via Gmail.
  Future<void> _backupViaGmail() async {
    if (!widget.userEmail.toLowerCase().endsWith('@gmail.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Backup via Gmail is only available for Gmail accounts.")),
      );
      return;
    }

    final backupData = _generateBackupData();
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: widget.userEmail,
      query: _encodeQueryParameters({
        'subject': 'Backup Data',
        'body': backupData,
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch the email app.")),
      );
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeNotifier.backgroundColor,
      appBar: AppBar(
        title:
            Text("Backups", style: TextStyle(color: themeNotifier.textColor)),
        backgroundColor: themeNotifier.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isBackingUp
            ? Center(
                child:
                    CircularProgressIndicator(color: themeNotifier.textColor),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _backupToStorage,
                    icon: const Icon(Icons.save),
                    label: const Text("Backup to Phone Storage"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: themeNotifier.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _backupViaGmail,
                    icon: const Icon(Icons.email),
                    label: const Text("Backup via Gmail"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: themeNotifier.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (backupMessage.isNotEmpty)
                    Text(
                      backupMessage,
                      style: TextStyle(color: themeNotifier.textColor),
                    ),
                ],
              ),
      ),
    );
  }
}

/// ------------------------- PremiumLandingPage -------------------------
class PremiumLandingPage extends StatelessWidget {
  const PremiumLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Premium Features",
            style: TextStyle(color: themeNotifier.textColor)),
        backgroundColor: themeNotifier.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeNotifier.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: themeNotifier.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Upgrade to Premium",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeNotifier.textColor),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading:
                        Icon(Icons.bar_chart, color: themeNotifier.textColor),
                    title: Text("Advanced Analytics",
                        style: TextStyle(color: themeNotifier.textColor)),
                    subtitle: Text(
                        "Get detailed progress reports and habit insights.",
                        style: TextStyle(
                            color: themeNotifier.textColor.withOpacity(0.7))),
                  ),
                  ListTile(
                    leading:
                        Icon(Icons.palette, color: themeNotifier.textColor),
                    title: Text("Enhanced Customization",
                        style: TextStyle(color: themeNotifier.textColor)),
                    subtitle: Text(
                        "Access exclusive themes and a personalized interface.",
                        style: TextStyle(
                            color: themeNotifier.textColor.withOpacity(0.7))),
                  ),
                  ListTile(
                    leading: Icon(Icons.group, color: themeNotifier.textColor),
                    title: Text("Community Challenges",
                        style: TextStyle(color: themeNotifier.textColor)),
                    subtitle: Text(
                        "Participate in members-only challenges and leaderboards.",
                        style: TextStyle(
                            color: themeNotifier.textColor.withOpacity(0.7))),
                  ),
                  ListTile(
                    leading: Icon(Icons.chat, color: themeNotifier.textColor),
                    title: Text("Personalized Coaching & AI Assistance",
                        style: TextStyle(color: themeNotifier.textColor)),
                    subtitle: Text(
                        "Receive tailored advice and automated coaching.",
                        style: TextStyle(
                            color: themeNotifier.textColor.withOpacity(0.7))),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Subscription feature is not available.")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Subscribe for Rs. 399",
                  style:
                      TextStyle(fontSize: 18, color: themeNotifier.textColor),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
