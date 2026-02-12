import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'widgets/custom_bottom_nav_bar.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoading = true;

  StreamSubscription<DatabaseEvent>? _wishlistSub;

  @override
  void initState() {
    super.initState();
    _loadWishlistItems();
  }

  @override
  void dispose() {
    _wishlistSub?.cancel();
    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final s = value.toString().trim();
    return double.tryParse(s) ?? 0.0;
  }

  Future<void> _loadWishlistItems() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      _wishlistSub?.cancel();
      _wishlistSub = _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .onValue
          .listen(
            (event) {
              try {
                final value = event.snapshot.value;
                final List<Map<String, dynamic>> nextItems = [];

                if (value != null && value is Map) {
                  final wishlistData = Map<dynamic, dynamic>.from(value);
                  for (final entry in wishlistData.entries) {
                    final id = entry.key.toString();
                    final raw = entry.value;
                    if (raw is Map) {
                      nextItems.add({
                        'id': id,
                        ...Map<String, dynamic>.from(raw),
                      });
                    }
                  }
                }

                if (!mounted) return;
                setState(() {
                  _wishlistItems = nextItems;
                  _isLoading = false;
                });
              } catch (e) {
                debugPrint('Error processing wishlist data: $e');
                if (!mounted) return;
                setState(() {
                  _wishlistItems = [];
                  _isLoading = false;
                });
              }
            },
            onError: (error) {
              debugPrint('Wishlist stream error: $error');
              _loadWishlistItemsOnce(); // Fallback to one-time fetch
            },
          );
    } catch (e) {
      debugPrint('Error setting up wishlist stream: $e');
      _loadWishlistItemsOnce(); // Fallback to one-time fetch
    }
  }

  Future<void> _loadWishlistItemsOnce() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .once();

      final value = snapshot.snapshot.value;
      final List<Map<String, dynamic>> nextItems = [];

      if (value != null && value is Map) {
        final wishlistData = Map<dynamic, dynamic>.from(value);
        for (final entry in wishlistData.entries) {
          final id = entry.key.toString();
          final raw = entry.value;
          if (raw is Map) {
            nextItems.add({'id': id, ...Map<String, dynamic>.from(raw)});
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _wishlistItems = nextItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error in one-time wishlist fetch: $e');
      if (!mounted) return;
      setState(() {
        _wishlistItems = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.black,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load wishlist: ${e.toString()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _removeFromWishlist(dynamic productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .child(productId)
          .remove();

      setState(() {
        _wishlistItems.removeWhere((item) => item['id'] == productId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.grey[700],
            content: const Row(
              children: [
                Icon(Icons.favorite_border, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Removed from wishlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove from wishlist')),
        );
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if item already exists in cart
      final cartSnapshot = await _database
          .child('users')
          .child(user.uid)
          .child('cart')
          .child(product['id'])
          .get();

      if (cartSnapshot.exists) {
        // Update quantity if already exists
        final currentData = Map<String, dynamic>.from(
          cartSnapshot.value as Map,
        );
        final currentQuantity = currentData['quantity'] as int? ?? 1;
        await _database
            .child('users')
            .child(user.uid)
            .child('cart')
            .child(product['id'])
            .update({'quantity': currentQuantity + 1});
      } else {
        // Add new item to cart
        await _database
            .child('users')
            .child(user.uid)
            .child('cart')
            .child(product['id'])
            .set({
              'name': product['name'],
              'price': product['price'],
              'salePrice': product['salePrice'] ?? product['price'],
              'imageUrl': product['imageUrl'] ?? '',
              'quantity': 1,
              'addedAt': ServerValue.timestamp,
            });
      }

      // Remove from wishlist after adding to cart
      await _removeFromWishlist(product['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.grey[700],
            content: const Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Added to cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add to cart')));
      }
    }
  }

  // Navigation bar state
  int _currentIndex = 2; // Set to 2 to highlight wishlist tab

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

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CartScreen()),
      );
    } else if (index == 2) {
      // Already on wishlist screen
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      setState(() => _currentIndex = index);
    }
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
                      'My Wishlist',
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
            // Cart content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _wishlistItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite_border_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your wishlist is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Continue Shopping'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _wishlistItems.length,
                      itemBuilder: (context, index) {
                        final item = _wishlistItems[index];
                        final imageUrl = (item['imageUrl'] ?? '').toString();
                        final hasImageUrl =
                            imageUrl.isNotEmpty &&
                            (imageUrl.startsWith('http://') ||
                                imageUrl.startsWith('https://'));
                        final unit = item['salePrice'] ?? item['price'];
                        final unitPrice = _toDouble(unit);

                        return Dismissible(
                          key: Key(item['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) =>
                              _removeFromWishlist(item['id']),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Product Image
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: hasImageUrl
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.image_not_supported,
                                                      size: 40,
                                                      color: Colors.grey,
                                                    ),
                                          )
                                        : const Icon(
                                            Icons.image,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                  ),
                                ),
                                // Product Details
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (item['name'] ?? '').toString(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '₹${unitPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            // Action Buttons
                                            Row(
                                              children: [
                                                // Add to Cart Button
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons
                                                        .shopping_cart_outlined,
                                                    size: 20,
                                                    color: Colors.black,
                                                  ),
                                                  onPressed: () =>
                                                      _addToCart(item),
                                                ),
                                                // Remove from Wishlist Button
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.favorite,
                                                    size: 20,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _removeFromWishlist(
                                                        item['id'],
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
