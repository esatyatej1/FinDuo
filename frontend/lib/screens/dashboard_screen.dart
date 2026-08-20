import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/finance_provider.dart';
import 'overview_screen.dart';
import 'transactions_screen.dart';
import 'analytics_screen.dart';
import 'admin_screen.dart';
import 'ai_chat_dialog.dart';
import 'settings_screen.dart';
import 'changelog_screen.dart';
import 'phonepe_import_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final finance = context.read<FinanceProvider>();
      finance.fetchData();
      finance.fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  void _openChangelog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangelogScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final finance = context.watch<FinanceProvider>();
    final userName = finance.userData['name'] ?? 'User';
    final firstName = userName.toString().split(' ').first;

    final isSatya = firstName.toLowerCase() == 'satya';
    final int maxIndex = isSatya ? 5 : 4;
    final safeIndex = _selectedIndex > maxIndex ? maxIndex : _selectedIndex;

    int getNavIndex(int pageIndex) {
      if (pageIndex <= 2) return pageIndex;
      if (pageIndex == 3) return 4;
      if (pageIndex == 4) return 5;
      if (pageIndex == 5) return 6;
      return 0;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final int navItemCount = isSatya ? 7 : 6;
    final double itemWidth = screenWidth / navItemCount;
    // AI Chat is at index 3
    final double aiChatCenterX = (itemWidth * 3) + (itemWidth / 2);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/Small.png',
                  height: 18,
                  width: 18,
                  fit: BoxFit.cover,
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FinDuo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                Text(
                  'Hi, $firstName 👋',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (finance.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: themeColor,
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: themeColor, size: 20),
            onPressed: () => finance.fetchData(),
            tooltip: 'Refresh data',
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: themeColor.withValues(alpha: 0.2),
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            onSelected: (val) {
              if (val == 'logout') _confirmLogout(context);
              if (val == 'changelog') _openChangelog();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'info',
                enabled: false,
                child: Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'changelog',
                child: Row(
                  children: [
                    Icon(Icons.new_releases_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('What\'s New'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          const OverviewScreen(),
          const TransactionsScreen(),
          const AnalyticsScreen(),
          const AdminScreen(),
          const SettingsScreen(),
          if (isSatya) const PhonePeImportScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 58 + MediaQuery.paddingOf(context).bottom,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: themeColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: getNavIndex(safeIndex),
          onTap: (i) {
            if (i == 3) {
              showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (context) => const AiChatDialog(),
              );
              return;
            }
            
            int targetPage = 0;
            if (i == 0) targetPage = 0;
            else if (i == 1) targetPage = 1;
            else if (i == 2) targetPage = 2;
            else if (i == 4) targetPage = 3;
            else if (i == 5) targetPage = 4;
            else if (i == 6) targetPage = 5;

            _pageController.animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconSize: 22,
          selectedItemColor: themeColor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Overview',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline_rounded),
              activeIcon: Icon(Icons.add_circle_rounded),
              label: 'Transactions',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                height: 24,
                child: Center(
                  // Empty space where the Stacked icon will visually appear
                ),
              ),
              label: 'AI',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
            if (isSatya)
              const BottomNavigationBarItem(
                icon: Icon(Icons.sync_outlined),
                activeIcon: Icon(Icons.sync_rounded),
                label: 'Sync',
              ),
          ],
        ),
      ),
        ),
        Positioned(
          left: aiChatCenterX - 30,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: SafeArea(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (context) => const AiChatDialog(),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds)
               .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
