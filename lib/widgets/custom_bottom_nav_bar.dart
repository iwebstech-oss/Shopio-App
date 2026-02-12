import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard_screen.dart';
import '../cart_screen.dart';
import '../wishlist_screen.dart';
import '../profile_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Function()? onReturnToDashboard;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onReturnToDashboard,
  });

  // Get icon for navigation items
  IconData _getNavIcon(int index, {bool isSelected = false}) {
    switch (index) {
      case 0:
        return isSelected ? Icons.home : Icons.home_outlined;
      case 1:
        return isSelected ? Icons.shopping_cart : Icons.shopping_cart_outlined;
      case 2:
        return isSelected ? Icons.favorite : Icons.favorite_border_outlined;
      case 3:
        return isSelected ? Icons.person : Icons.person_outline;
      default:
        return Icons.home_outlined;
    }
  }

  Widget _buildNavItem(int index, {bool isSelected = false}) {
    final icon = _getNavIcon(index, isSelected: isSelected);
    final label = ['Home', 'Cart', 'Wishlist', 'Profile'][index];

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 68,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 15),
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          return _buildNavItem(index, isSelected: currentIndex == index);
        }),
      ),
    );
  }
}

// Navigation handler class to manage navigation logic
class NavigationHandler {
  static void handleNavigation(
    BuildContext context,
    int index,
    Function()? onReturnToDashboard,
  ) {
    switch (index) {
      case 0:
        // Home - already on dashboard
        break;
      case 1:
        // Cart
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        ).then((_) {
          onReturnToDashboard?.call();
        });
        break;
      case 2:
        // Wishlist
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WishlistScreen()),
        ).then((_) {
          onReturnToDashboard?.call();
        });
        break;
      case 3:
        // Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        ).then((_) {
          onReturnToDashboard?.call();
        });
        break;
    }
  }
}
