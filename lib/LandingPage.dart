import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black, // Black background
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Navigation (Logo)
                  const Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Momentum',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // White text
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Left Section (Main Content)
                  const Text(
                    'Build Better Habits, One Day at a Time',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // White text
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Transform your life with Momentum, the habit tracking app that helps you build lasting routines and achieve your goals.',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white70, // Light gray text
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Features Section
                  const Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      FeatureItem(
                        icon: Icons.check_circle,
                        text: 'Track daily habits with ease',
                      ),
                      FeatureItem(
                        icon: Icons.check_circle,
                        text: 'Build lasting routines',
                      ),
                      FeatureItem(
                        icon: Icons.check_circle,
                        text: 'Visualize your progress',
                      ),
                      FeatureItem(
                        icon: Icons.check_circle,
                        text: 'Stay motivated with streaks',
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  // Call-to-Action Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                    child: Container(
                      width: 200,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white, // White button
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26, // Subtle shadow
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black, // Black text
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.black, // Black icon
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // App Preview Section (Visible Content without Blur)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(30), // Increased padding
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white
                            .withOpacity(0.1), // Semi-transparent white
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min, // Adjust to fit content
                        children: [
                          Text(
                            '📱',
                            style: TextStyle(
                              fontSize: 40, // Reduced size for better fit
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Your personalized habit tracking experience awaits!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white, // White text
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  // Footer
                  const Text(
                    '© 2025 Momentum Inc. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70, // Light gray text
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Feature Item Widget
class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white, // White icon
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white, // White text
          ),
        ),
      ],
    );
  }
}
