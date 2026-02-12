import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'cart_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'widgets/custom_bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // List of screens for navigation
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        key: ValueKey('dashboard_${DateTime.now().millisecondsSinceEpoch}'),
      ),
      const CartScreen(),
      const WishlistScreen(),
      const ProfileScreen(),
    ];
  }

  // Handle navigation tap
  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Refresh dashboard wishlist when returning to dashboard (index 0)
    if (index == 0) {
      // Recreate dashboard screen to refresh wishlist
      setState(() {
        _screens[0] = DashboardScreen(
          key: ValueKey('dashboard_${DateTime.now().millisecondsSinceEpoch}'),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
