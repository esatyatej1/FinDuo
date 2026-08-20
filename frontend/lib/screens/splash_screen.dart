import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../main.dart'; // To get AuthenticationWrapper
import '../providers/settings_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Wait for the animation to complete and give a premium feel
    await Future.delayed(const Duration(milliseconds: 2800));
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthenticationWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Container with glow effect around the logo
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: settings.themeColor.withOpacity(0.25),
                    blurRadius: 60,
                    spreadRadius: 25,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/Large.png',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            )
            .animate()
            .fade(duration: 800.ms, curve: Curves.easeOut)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 1000.ms, curve: Curves.easeOutBack)
            .shimmer(delay: 1000.ms, duration: 1500.ms, color: settings.themeColor.withOpacity(0.3)),
            
            const SizedBox(height: 40),
            
            Text(
              'FinDuo',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: 1.2,
              ),
            )
            .animate()
            .fade(delay: 400.ms, duration: 800.ms)
            .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 800.ms, curve: Curves.easeOut),
            
            const SizedBox(height: 12),
            
            Text(
              'Intelligent Finance, Together.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 0.5,
              ),
            )
            .animate()
            .fade(delay: 800.ms, duration: 800.ms),
            
            const SizedBox(height: 60),
            
            // Subtle loading indicator
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(settings.themeColor),
              ),
            )
            .animate()
            .fade(delay: 1400.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
