import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'dashboard_screen.dart';
import 'wishlist_screen.dart';
import 'edit_profile_screen.dart';
import 'address_book_screen.dart';
import 'my_orders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  int _currentIndex = 3; // Profile is the 4th tab (0-indexed as 3)

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DatabaseEvent event = await _database
            .child('users')
            .child(user.uid)
            .once();
        if (event.snapshot.value != null) {
          setState(() {
            userData = Map<String, dynamic>.from(event.snapshot.value as Map);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading profile: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildPillMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isLogout ? Colors.red.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
          border: isLogout
              ? Border.all(color: Colors.red.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isLogout ? Colors.red : Colors.black54, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isLogout ? Colors.red : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isLogout ? Colors.red : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

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

  void _onItemTapped(int index) {
    if (index == _currentIndex) {
      // Already on this tab
      return;
    }

    if (index == 3) {
      // Already on profile screen
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => DashboardScreen(initialIndex: index),
      ),
      (route) => false,
    );
  }

  Widget _buildNavItem(int index, {bool isSelected = false}) {
    final icon = _getNavIcon(index, isSelected: isSelected);
    final label = ['Home', 'Cart', 'Wishlist', 'Profile'][index];

    return GestureDetector(
      onTap: () => _onItemTapped(index),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Profile content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Profile header
                          Container(
                            padding: const EdgeInsets.all(20),
                            color: Colors.white,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage:
                                      userData?['profileImage'] != null
                                      ? NetworkImage(userData!['profileImage'])
                                      : null,
                                  child: userData?['profileImage'] == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  userData?['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  userData?['email'] ?? 'user@example.com',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Menu items as pills
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _buildPillMenuItem(
                                  icon: Icons.person_outline,
                                  title: 'Edit Profile',
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                          userData: userData,
                                        ),
                                      ),
                                    );

                                    // Update userData if profile was updated
                                    if (result != null && mounted) {
                                      setState(() {
                                        userData = {...?userData, ...result};
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildPillMenuItem(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'My Orders',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MyOrdersScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildPillMenuItem(
                                  icon: Icons.favorite_border,
                                  title: 'Wishlist',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const WishlistScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildPillMenuItem(
                                  icon: Icons.location_on_outlined,
                                  title: 'Shipping Address',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddressBookScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildPillMenuItem(
                                  icon: Icons.credit_card_outlined,
                                  title: 'Payment Methods',
                                  onTap: () {
                                    // Handle payment methods
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildPillMenuItem(
                                  icon: Icons.settings_outlined,
                                  title: 'Settings',
                                  onTap: () {
                                    // Handle settings
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildPillMenuItem(
                                  icon: Icons.logout,
                                  title: 'Logout',
                                  onTap: _signOut,
                                  isLogout: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 120,
                          ), // Extra space for floating bottom nav
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
