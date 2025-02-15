import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mainproj/theme_notifier.dart';
import 'package:provider/provider.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeProvider>(context);
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: themeNotifier.backgroundColor,
        body: Center(
          child: Text(
            'User not found',
            style: TextStyle(color: themeNotifier.textColor),
          ),
        ),
      );
    }

    // Listen to the habits subcollection.
    return Scaffold(
      backgroundColor: themeNotifier.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Statistics Page',
          style: TextStyle(color: themeNotifier.textColor),
        ),
        backgroundColor: themeNotifier.backgroundColor,
        iconTheme: IconThemeData(color: themeNotifier.textColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(userId)
            .collection('habits')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: themeNotifier.textColor),
            );
          }
          final habitDocs = snapshot.data!.docs;
          List<Map<String, dynamic>> habitsList = habitDocs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          // Compute statistics.
          Map<String, dynamic> stats = {
            'totalHabits': habitsList.length,
            'completedToday': 0,
            'streaks': {},
            'weeklyProgress': List<int>.filled(7, 0),
            'monthlyProgress': List<int>.filled(30, 0),
            'categoryDistribution': {},
            'longestStreak': 0,
            'averageCompletionRate': 0.0,
          };

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          int totalCompletions = 0;

          for (var habit in habitsList) {
            final completions = (habit['completions'] as List?) ?? [];
            final rawCategory = (habit['category'] as String?)?.trim() ?? '';
            final category = rawCategory.isEmpty ||
                    rawCategory.toLowerCase() == 'uncategorized'
                ? 'Other'
                : rawCategory;

            int currentStreak = 0;
            DateTime? lastCompletionDate;
            // Loop over completions (assuming they are sorted in chronological order)
            for (var completion in completions) {
              final completionDate = (completion as Timestamp).toDate();
              if (lastCompletionDate == null) {
                currentStreak = 1;
              } else {
                final diff =
                    lastCompletionDate.difference(completionDate).inDays;
                if (diff == 1) {
                  currentStreak++;
                } else {
                  break;
                }
              }
              lastCompletionDate = completionDate;
            }
            // Group streaks by category.
            if (stats['streaks'][category] == null ||
                currentStreak > stats['streaks'][category]) {
              stats['streaks'][category] = currentStreak;
            }
            if (currentStreak > stats['longestStreak']) {
              stats['longestStreak'] = currentStreak;
            }

            // Check if the habit was completed today.
            if (completions.isNotEmpty) {
              final lastCompletion = (completions.last as Timestamp).toDate();
              if (lastCompletion.isAfter(today)) {
                stats['completedToday'] = (stats['completedToday'] ?? 0) + 1;
              }
            }

            // Update category distribution.
            stats['categoryDistribution'][category] =
                (stats['categoryDistribution'][category] ?? 0) + 1;

            // Calculate weekly progress.
            final weeklyCompletions = completions.where((completion) {
              final date = (completion as Timestamp).toDate();
              return date.isAfter(now.subtract(const Duration(days: 7)));
            }).toList();
            for (var completion in weeklyCompletions) {
              final date = (completion as Timestamp).toDate();
              final dayIndex = date.weekday - 1;
              stats['weeklyProgress'][dayIndex] =
                  (stats['weeklyProgress'][dayIndex] ?? 0) + 1;
            }

            // Calculate monthly progress.
            final monthlyCompletions = completions.where((completion) {
              final date = (completion as Timestamp).toDate();
              return date.isAfter(now.subtract(const Duration(days: 30)));
            }).toList();
            for (var completion in monthlyCompletions) {
              final date = (completion as Timestamp).toDate();
              final dayIndex = now.difference(date).inDays;
              if (dayIndex < 30) {
                stats['monthlyProgress'][29 - dayIndex] =
                    (stats['monthlyProgress'][29 - dayIndex] ?? 0) + 1;
              }
            }

            totalCompletions += completions.length;
          }

          if (habitsList.isNotEmpty) {
            stats['averageCompletionRate'] =
                totalCompletions / habitsList.length;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCards(themeNotifier, stats),
                const SizedBox(height: 24),
                _buildWeeklyProgressChart(themeNotifier, stats),
                const SizedBox(height: 24),
                _buildMonthlyProgressChart(themeNotifier, stats),
                const SizedBox(height: 24),
                _buildCategoryDistributionChart(themeNotifier, stats),
                const SizedBox(height: 24),
                _buildStreaksList(themeNotifier, stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCards(
      ThemeProvider themeNotifier, Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Habits', stats['totalHabits'].toString(),
            Icons.list_alt, Colors.blue, themeNotifier),
        _buildStatCard('Completed Today', stats['completedToday'].toString(),
            Icons.check_circle, Colors.green, themeNotifier),
        _buildStatCard('Longest Streak', stats['longestStreak'].toString(),
            Icons.local_fire_department, Colors.orange, themeNotifier),
        _buildStatCard(
            'Avg Completion',
            stats['averageCompletionRate'].toStringAsFixed(1),
            Icons.trending_up,
            Colors.purple,
            themeNotifier),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color iconColor, ThemeProvider themeNotifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeNotifier.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeNotifier.textColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(color: themeNotifier.textColor, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: themeNotifier.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressChart(
      ThemeProvider themeNotifier, Map<String, dynamic> stats) {
    final List weeklyProgress = stats['weeklyProgress'] as List;
    final double maxY = weeklyProgress.isNotEmpty
        ? weeklyProgress
                .map((e) => e as int)
                .reduce((a, b) => a > b ? a : b)
                .toDouble() +
            1
        : 1.0;
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeNotifier.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeNotifier.textColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Progress',
              style: TextStyle(
                  color: themeNotifier.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Text(days[value.toInt()],
                            style: TextStyle(
                                color:
                                    themeNotifier.textColor.withOpacity(0.7)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(),
                            style: TextStyle(
                                color:
                                    themeNotifier.textColor.withOpacity(0.7)));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (weeklyProgress[index] as int).toDouble(),
                        color: Colors.purple,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyProgressChart(
      ThemeProvider themeNotifier, Map<String, dynamic> stats) {
    final List monthlyProgress = stats['monthlyProgress'] as List;
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeNotifier.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeNotifier.textColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Progress',
              style: TextStyle(
                  color: themeNotifier.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('Day ${value.toInt() + 1}',
                            style: TextStyle(
                                color:
                                    themeNotifier.textColor.withOpacity(0.7)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(),
                            style: TextStyle(
                                color:
                                    themeNotifier.textColor.withOpacity(0.7)));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(30, (index) {
                      return FlSpot(index.toDouble(),
                          (monthlyProgress[index] as int).toDouble());
                    }),
                    isCurved: true,
                    color: Colors.blue,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionChart(
      ThemeProvider themeNotifier, Map<String, dynamic> stats) {
    final Map<String, int> categoryMap =
        (stats['categoryDistribution'] as Map<dynamic, dynamic>?)
                ?.map((key, value) => MapEntry(key.toString(), value as int)) ??
            {};
    if (categoryMap.isEmpty) return const SizedBox.shrink();

    final total = categoryMap.values.reduce((a, b) => a + b);
    final pieData = categoryMap.entries.map((entry) {
      return PieChartSectionData(
        color: Colors.primaries[categoryMap.keys.toList().indexOf(entry.key) %
            Colors.primaries.length],
        value: entry.value.toDouble(),
        title: '${(entry.value / total * 100).toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: TextStyle(
            color: themeNotifier.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold),
      );
    }).toList();

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeNotifier.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeNotifier.textColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category Distribution',
              style: TextStyle(
                  color: themeNotifier.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: pieData,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: categoryMap.keys.map((category) {
              final index = categoryMap.keys.toList().indexOf(category) %
                  Colors.primaries.length;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: Colors.primaries[index],
                          shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(category,
                      style: TextStyle(
                          color: themeNotifier.textColor.withOpacity(0.7))),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStreaksList(
      ThemeProvider themeNotifier, Map<String, dynamic> stats) {
    final Map<String, int> streaks =
        (stats['streaks'] as Map<dynamic, dynamic>?)
                ?.map((key, value) => MapEntry(key.toString(), value as int)) ??
            {};
    if (streaks.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeNotifier.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeNotifier.textColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Streaks by Category',
              style: TextStyle(
                  color: themeNotifier.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...streaks.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key,
                        style: TextStyle(
                            color: themeNotifier.textColor.withOpacity(0.7))),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 4),
                        Text('${entry.value} days',
                            style: TextStyle(
                                color: themeNotifier.textColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
