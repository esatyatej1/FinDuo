import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  List<Map<String, dynamic>> _dynamicLogs = [];

  // Hardcoded changelog entries based on development history
  final List<Map<String, dynamic>> _hardcodedLogs = [
    {
      'version': 'v2.0.0',
      'date': 'June 6, 2026',
      'features': [
        'PhonePe Statement Import functionality',
        'Enhanced UI Micro-animations',
      ],
      'fixes': ['Performance optimizations for Analytics'],
    },
    {
      'version': 'v1.3.0',
      'date': 'June 5, 2026',
      'features': [
        'AI Chat integration with Cerebras & Gemini',
        'Interactive Chat UI for financial insights',
      ],
      'fixes': [],
    },
    {
      'version': 'v1.2.0',
      'date': 'June 5, 2026',
      'features': [
        'Google SSO Authentication integration',
        '\'Remember Me\' secure credential saving',
      ],
      'fixes': ['Resolved Google Sign-In SDK conflicts'],
    },
    {
      'version': 'v1.1.0',
      'date': 'June 4, 2026',
      'features': [
        'Dark/Light Theme Support',
        'Dynamic Accent Colors & Fonts',
        'Settings Management',
      ],
      'fixes': [],
    },
    {
      'version': 'v1.0.0',
      'date': 'Initial Release',
      'features': [
        'Dashboard & Overview',
        'Analytics Module',
        'Admin Panel',
        'Spends Tracking',
      ],
      'fixes': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDynamicLogs();
  }

  Future<void> _loadDynamicLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStr = prefs.getString('saved_changelogs');
    if (savedStr != null) {
      try {
        final List<dynamic> decoded = json.decode(savedStr);
        setState(() {
          _dynamicLogs = decoded
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } catch (e) {
        debugPrint('Error loading dynamic logs: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final isDark =
        context.watch<SettingsProvider>().themeMode == ThemeMode.dark;

    final allLogs = [..._dynamicLogs, ..._hardcodedLogs];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'What\'s New',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allLogs.length,
        itemBuilder: (context, index) {
          final log = allLogs[index];
          return _ChangelogCard(
                log: log,
                themeColor: themeColor,
                isDark: isDark,
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: (index * 100).ms)
              .slideY(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Color themeColor;
  final bool isDark;

  const _ChangelogCard({
    required this.log,
    required this.themeColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  log['version'],
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                log['date'],
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if ((log['features'] as List).isNotEmpty) ...[
            Text(
              '✨ New Features',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...((log['features'] as List).map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Icon(Icons.circle, size: 6, color: themeColor),
                    ),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
          ],
          if ((log['fixes'] as List).isNotEmpty) ...[
            Text(
              '🔧 Fixes & Improvements',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...((log['fixes'] as List).map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Icon(Icons.circle, size: 6, color: Colors.grey),
                    ),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}
