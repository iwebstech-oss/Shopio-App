import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:ecommerce/models/category_model.dart';
import 'package:ecommerce/services/category_service.dart';
import 'widgets/dashboard_search_bar.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';
import 'address_book_screen.dart';
import 'search_home_screen.dart';
import 'product_details_screen.dart';
import 'dart:ui';

// Search delegate for product search
class ProductSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> _allProducts;

  ProductSearchDelegate({required List<Map<String, dynamic>> allProducts})
    : _allProducts = allProducts;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _allProducts.where((product) {
      final title = (product['name'] ?? product['title'] ?? '')
          .toString()
          .toLowerCase();
      final description = (product['description'] ?? '')
          .toString()
          .toLowerCase();
      final searchQuery = query.toLowerCase();
      final searchTerms = searchQuery.split(' ').where((t) => t.isNotEmpty).toList();

      if (searchTerms.isEmpty) return true;

      final tagsRaw = product['tags'];
      List<String> productTags = [];
      if (tagsRaw is List) {
        productTags = tagsRaw.map((e) => e.toString().toLowerCase()).toList();
      } else if (tagsRaw is Map) {
        productTags.addAll(tagsRaw.keys.map((k) => k.toString().toLowerCase()));
        productTags.addAll(
          tagsRaw.values
              .where((v) => v is String)
              .map((v) => v.toString().toLowerCase()),
        );
      } else if (tagsRaw is String) {
        productTags = tagsRaw.toLowerCase().split(',').map((s) => s.trim()).toList();
      }

      for (var term in searchTerms) {
        if (title.contains(term) || 
            description.contains(term) || 
            productTags.any((tag) => tag.contains(term))) {
          return true;
        }
      }
      return false;
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final product = results[index];
        final title = (product['name'] ?? product['title'] ?? '').toString();
        final price = (product['price'] ?? '').toString();

        return ListTile(
          title: Text(title),
          subtitle: Text('Price: $price'),
          onTap: () {
            // Handle product selection
            close(context, title);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _allProducts.where((product) {
      final title = (product['name'] ?? product['title'] ?? '')
          .toString()
          .toLowerCase();
      final searchQuery = query.toLowerCase();
      final searchTerms = searchQuery.split(' ').where((t) => t.isNotEmpty).toList();

      if (searchTerms.isEmpty) return true;

      final tagsRaw = product['tags'];
      List<String> productTags = [];
      if (tagsRaw is List) {
        productTags = tagsRaw.map((e) => e.toString().toLowerCase()).toList();
      } else if (tagsRaw is Map) {
        productTags.addAll(tagsRaw.keys.map((k) => k.toString().toLowerCase()));
        productTags.addAll(
          tagsRaw.values
              .where((v) => v is String)
              .map((v) => v.toString().toLowerCase()),
        );
      } else if (tagsRaw is String) {
        productTags = tagsRaw.toLowerCase().split(',').map((s) => s.trim()).toList();
      }

      for (var term in searchTerms) {
        if (title.contains(term) || productTags.any((tag) => tag.contains(term))) {
          return true;
        }
      }
      return false;
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final product = suggestions[index];
        final title = (product['name'] ?? product['title'] ?? '').toString();

        return ListTile(
          title: Text(title),
          onTap: () {
            query = title;
            showResults(context);
          },
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final int initialIndex;

  const DashboardScreen({super.key, this.initialIndex = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Featured products from database
  List<Map<String, dynamic>> _featuredProducts = [];
  bool _isLoadingProducts = true;

  String _selectedSortOption = 'Relevance';
  
  // Advanced Filter State
  double _minPrice = 0;
  double _maxPrice = 100000;
  double _currentMinPrice = 0;
  double _currentMaxPrice = 100000;
  List<String> _selectedBrands = [];
  Set<String> _allBrands = {};

  // Delivery address
  Map<String, dynamic>? selectedAddress;

  // Load all products from database
  Future<void> _loadAllProducts() async {
    try {
      final productsRef = _database.child('products');
      final event = await productsRef.once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> productsData = Map<dynamic, dynamic>.from(
          event.snapshot.value as Map,
        );
        List<Map<String, dynamic>> allProducts = [];

        productsData.forEach((key, value) {
          Map<String, dynamic> product = Map<String, dynamic>.from(value);
          final title = (product['title'] ?? '').toString();
          final imagesRaw = product['images'];
          String mainImageUrl = '';

          debugPrint('Processing product: $key');
          debugPrint('Images raw data: $imagesRaw');
          debugPrint('Images type: ${imagesRaw.runtimeType}');

          final Iterable<dynamic> imagesIterable = imagesRaw is List
              ? imagesRaw
              : (imagesRaw is Map ? imagesRaw.values : const []);

          debugPrint('Images iterable length: ${imagesIterable.length}');

          for (final img in imagesIterable) {
            if (img is Map) {
              final isMain = img['isMain'] == true;
              final url = (img['url'] ?? '').toString();
              debugPrint('Found image: isMain=$isMain, url=$url');
              if (url.isNotEmpty && isMain) {
                mainImageUrl = url;
                debugPrint('Set main image URL: $mainImageUrl');
                break;
              }
            }
          }

          if (mainImageUrl.isEmpty) {
            debugPrint('No main image found, trying any image');
            for (final img in imagesIterable) {
              if (img is Map) {
                final url = (img['url'] ?? '').toString();
                debugPrint('Fallback image URL: $url');
                if (url.isNotEmpty) {
                  mainImageUrl = url;
                  debugPrint('Set fallback image URL: $mainImageUrl');
                  break;
                }
              }
            }
          }

          product['id'] = key;
          product['name'] = title;
          product['imageUrl'] = mainImageUrl;
          debugPrint(
            'Product: id=$key title=$title price=${product['price']} salePrice=${product['salePrice']} imageUrl=$mainImageUrl category=${product['category']} categoryId=${product['categoryId']}',
          );
          allProducts.add(product);
        });

        if (mounted) {
          // Extract all unique brands
          final brands = allProducts
              .map((p) => p['brand']?.toString() ?? '')
              .where((b) => b.isNotEmpty)
              .toSet();
          
          // Find max price for range slider
          double maxDetectedPrice = 0;
          for (var p in allProducts) {
             final pPrice = double.tryParse((p['salePrice'] ?? p['price'] ?? '0').toString()) ?? 0;
             if (pPrice > maxDetectedPrice) maxDetectedPrice = pPrice;
          }

          setState(() {
            _featuredProducts = allProducts;
            _isLoadingProducts = false;
            _allBrands = brands;
            if (maxDetectedPrice > 0) {
              _maxPrice = maxDetectedPrice;
              _currentMaxPrice = maxDetectedPrice;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingProducts = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: ${e.toString()}')),
        );
      }
    }
  }

  // Load user's wishlist
  Future<void> _loadWishlist() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final event = await _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .once();

      if (event.snapshot.value != null) {
        final value = event.snapshot.value;
        debugPrint('Raw wishlist data type: ${value.runtimeType}');
        debugPrint('Raw wishlist data: $value');
        Map<String, dynamic> wishlist = {};

        // Handle both Map and List data structures
        if (value is Map) {
          wishlist = Map<String, dynamic>.from(value);
          debugPrint('Wishlist as Map: $wishlist');
        } else if (value is List) {
          debugPrint('Wishlist as List with ${value.length} items');
          // Convert list to map using product IDs as keys
          for (var item in value) {
            if (item is Map && item['id'] != null) {
              wishlist[item['id'].toString()] = item;
              debugPrint('Added to wishlist map: ${item['id']} -> $item');
            }
          }
          debugPrint('Final wishlist map: $wishlist');
        }

        if (mounted) {
          debugPrint(
            '=== Checking wishlist status for ${_featuredProducts.length} products ===',
          );
          setState(() {
            for (var product in _featuredProducts) {
              final isInWishlist = wishlist.containsKey(product['id']);
              debugPrint(
                'Product: ${product['name']} (ID: ${product['id']}) - In wishlist: $isInWishlist',
              );
              product['isWishlisted'] = isInWishlist;
            }
            debugPrint('=== Wishlist status check complete ===');
          });
        }
      } else {
        // Initialize all products as not wishlisted if wishlist is empty
        if (mounted) {
          setState(() {
            for (var product in _featuredProducts) {
              product['isWishlisted'] = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
      // Initialize all products as not wishlisted on error to prevent null issues
      if (mounted) {
        setState(() {
          for (var product in _featuredProducts) {
            product['isWishlisted'] = false;
          }
        });
      }
      // Only show error message for critical errors, not for permission or empty wishlist issues
      if (e.toString().contains('permission-denied') == false &&
          e.toString().contains('Index') == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.grey[800],
              content: Text(
                'Wishlist error: ${e.toString()}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
  }

  // Load selected delivery address
  Future<void> _loadSelectedAddress() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Load selected address ID first
        DatabaseEvent selectedEvent = await _database
            .child('users')
            .child(user.uid)
            .child('selectedAddress')
            .once();

        String? selectedAddressId;
        if (selectedEvent.snapshot.value != null) {
          selectedAddressId = selectedEvent.snapshot.value as String?;
        }

        // Load the selected address
        if (selectedAddressId != null) {
          DatabaseEvent addressEvent = await _database
              .child('users')
              .child(user.uid)
              .child('Address Book')
              .child(selectedAddressId)
              .once();

          if (addressEvent.snapshot.value != null) {
            final address = Map<String, dynamic>.from(
              addressEvent.snapshot.value as Map,
            );

            setState(() {
              selectedAddress = address;
            });
            return;
          }
        }

        // Fallback: Load first address if no selected address
        DatabaseEvent allAddressesEvent = await _database
            .child('users')
            .child(user.uid)
            .child('Address Book')
            .once();

        if (allAddressesEvent.snapshot.value != null) {
          Map<dynamic, dynamic> addressData =
              allAddressesEvent.snapshot.value as Map;

          if (addressData.isNotEmpty) {
            final firstAddressKey = addressData.keys.first;
            final address = Map<String, dynamic>.from(
              addressData[firstAddressKey],
            );

            setState(() {
              selectedAddress = address;
            });
          }
        }
      } catch (e) {
        print('Error loading address: $e');
      }
    }
  }

  // Navigate to address book
  Future<void> _navigateToAddressBook() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressBookScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        selectedAddress = result;
      });
    }
  }

  // Filter products based on search query and selected category
  List<Map<String, dynamic>> get _filteredProducts {
    List<Map<String, dynamic>> filtered = _featuredProducts.where((product) {
      final productName = (product['name'] ?? product['title'] ?? '')
          .toString()
          .toLowerCase();
      final description = (product['description'] ?? '')
          .toString()
          .toLowerCase();
      final searchQuery = _searchQuery.toLowerCase();
      final searchTerms = searchQuery.split(' ').where((t) => t.isNotEmpty).toList();

      if (searchTerms.isNotEmpty) {
        bool matchesSearch = false;
        final tagsRaw = product['tags'];
        List<String> productTags = [];
        if (tagsRaw is List) {
          productTags = tagsRaw.map((e) => e.toString().toLowerCase()).toList();
        } else if (tagsRaw is Map) {
          productTags.addAll(tagsRaw.keys.map((k) => k.toString().toLowerCase()));
          productTags.addAll(
            tagsRaw.values
                .where((v) => v is String)
                .map((v) => v.toString().toLowerCase()),
          );
        } else if (tagsRaw is String) {
          productTags = tagsRaw.toLowerCase().split(',').map((s) => s.trim()).toList();
        }

        for (var term in searchTerms) {
          if (productName.contains(term) || 
              description.contains(term) ||
              productTags.any((tag) => tag.contains(term))) {
            matchesSearch = true;
            break;
          }
        }
        if (!matchesSearch) return false;
      }

      // Category filter
      if (_selectedCategoryId != 'All') {
        final productCategoryId = (product['categoryId'] ?? '').toString();
        final productCategoryName = (product['category'] ?? '').toString().toLowerCase();
        final selectedCategoryName = _categories
            .where((c) => c.id == _selectedCategoryId)
            .map((c) => c.name.toLowerCase())
            .firstOrNull;

        if (productCategoryId != _selectedCategoryId && productCategoryName != selectedCategoryName) {
          return false;
        }
      }

      // Price filter
      final productPrice = double.tryParse((product['salePrice'] ?? product['price'] ?? '0').toString()) ?? 0;
      if (productPrice < _currentMinPrice || productPrice > _currentMaxPrice) {
        return false;
      }

      // Brand filter
      if (_selectedBrands.isNotEmpty) {
        final productBrand = product['brand']?.toString() ?? '';
        if (!_selectedBrands.contains(productBrand)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort results
    switch (_selectedSortOption) {
      case 'Price: Low to High':
        filtered.sort((a, b) {
          final priceA = double.tryParse((a['salePrice'] ?? a['price'] ?? '0').toString()) ?? 0;
          final priceB = double.tryParse((b['salePrice'] ?? b['price'] ?? '0').toString()) ?? 0;
          return priceA.compareTo(priceB);
        });
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) {
          final priceA = double.tryParse((a['salePrice'] ?? a['price'] ?? '0').toString()) ?? 0;
          final priceB = double.tryParse((b['salePrice'] ?? b['price'] ?? '0').toString()) ?? 0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'Name: A to Z':
        filtered.sort((a, b) {
          final nameA = (a['name'] ?? a['title'] ?? '').toString();
          final nameB = (b['name'] ?? b['title'] ?? '').toString();
          return nameA.compareTo(nameB);
        });
        break;
    }
    
    return filtered;
  }

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _loadUserData().then((_) {
      _loadSelectedAddress();
      _loadAllProducts().then((_) => _loadWishlist());
    });
    _loadCategories();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _featuredProducts.isNotEmpty) {
      // Refresh wishlist when app resumes (user returns from another screen)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _featuredProducts.isNotEmpty) {
          _loadWishlist();
        }
      });
    }
  }

  // Call this method when returning from other screens
  void refreshWishlist() {
    if (_featuredProducts.isNotEmpty) {
      _loadWishlist();
    }
  }

  void _loadCategories() {
    _categoryService.getParentCategories().listen((categories) {
      if (mounted) {
        debugPrint('=== Categories fetched ===');
        for (var category in categories) {
          debugPrint('Category: ${category.name} (ID: ${category.id})');
        }

        // Sort categories by their numeric ID field
        List<Category> sortedCategories = List.from(categories);
        sortedCategories.sort((a, b) {
          try {
            int aId = int.parse(a.id);
            int bId = int.parse(b.id);
            return aId.compareTo(bId);
          } catch (e) {
            debugPrint('Failed to parse category IDs: ${a.id} vs ${b.id}');
            return a.id.compareTo(b.id);
          }
        });

        debugPrint('=== Categories after sorting ===');
        for (var category in sortedCategories) {
          debugPrint('Category: ${category.name} (ID: ${category.id})');
        }

        setState(() {
          _categories = sortedCategories;
        });
      }
    });
  }

  // Toggle wishlist status for a product
  Future<void> _toggleWishlist(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint('Toggling wishlist for product ID: $productId');

    setState(() {
      final productIndex = _featuredProducts.indexWhere(
        (p) => p['id'] == productId,
      );
      if (productIndex != -1) {
        final currentValue =
            _featuredProducts[productIndex]['isWishlisted'] as bool?;
        _featuredProducts[productIndex]['isWishlisted'] = currentValue ?? false;
        _featuredProducts[productIndex]['isWishlisted'] =
            !_featuredProducts[productIndex]['isWishlisted'];
        debugPrint(
          'Updated product ${_featuredProducts[productIndex]['name']} isWishlisted to: ${_featuredProducts[productIndex]['isWishlisted']}',
        );
      }
    });

    try {
      final wishlistRef = _database
          .child('users')
          .child(user.uid)
          .child('wishlist');

      // Get current wishlist
      final event = await wishlistRef.once();
      Map<dynamic, dynamic> wishlist = {};
      if (event.snapshot.value != null) {
        final value = event.snapshot.value;
        // Handle both Map and List data structures
        if (value is Map) {
          wishlist = Map<dynamic, dynamic>.from(value);
        } else if (value is List) {
          // Convert list to map using product IDs as keys
          for (var item in value) {
            if (item is Map && item['id'] != null) {
              wishlist[item['id'].toString()] = item;
            }
          }
        }
      }

      // Toggle product in wishlist
      if (wishlist.containsKey(productId)) {
        await wishlistRef.child(productId).remove();
        debugPrint('Removed $productId from wishlist');
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
      } else {
        final product = _featuredProducts.firstWhere(
          (p) => p['id'] == productId,
        );
        await wishlistRef.child(productId).set({
          'name': product['name'],
          'price': product['price'],
          'salePrice': product['salePrice'] ?? product['price'],
          'imageUrl': product['imageUrl'] ?? product['image'],
          'addedAt': ServerValue.timestamp,
        });
        debugPrint('Added $productId to wishlist');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.grey[700],
              content: const Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Added to wishlist',
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
      }

      // Refresh wishlist status after successful operation
      if (mounted) {
        await _loadWishlist();
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        final productIndex = _featuredProducts.indexWhere(
          (p) => p['id'] == productId,
        );
        if (productIndex != -1) {
          final currentValue =
              _featuredProducts[productIndex]['isWishlisted'] as bool?;
          _featuredProducts[productIndex]['isWishlisted'] =
              currentValue ?? false;
          _featuredProducts[productIndex]['isWishlisted'] =
              !_featuredProducts[productIndex]['isWishlisted'];
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wishlist')),
        );
      }
    }
  }

  // Add product to cart
  Future<void> _addToCart(Map<String, dynamic> product) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to cart')),
      );
      return;
    }

    try {
      final cartRef = _database.child('users').child(user.uid).child('cart');

      // Check if product already in cart
      final event = await cartRef.once();
      Map<dynamic, dynamic> cartItems = {};
      if (event.snapshot.value != null) {
        cartItems = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      }

      if (cartItems.containsKey(product['id'])) {
        // Update quantity if already in cart
        await cartRef.child(product['id']).update({
          'quantity': cartItems[product['id']]['quantity'] + 1,
        });
      } else {
        // Add new item to cart
        await cartRef.child(product['id']).set({
          'name': (product['title'] ?? product['name'] ?? '').toString(),
          'price': product['price'],
          'salePrice': product['salePrice'] ?? product['price'],
          'imageUrl': (product['imageUrl'] ?? '').toString(),
          'quantity': 1,
          'addedAt': ServerValue.timestamp,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.grey[700],
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${(product['title'] ?? product['name'] ?? '').toString()} added to cart',
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to cart: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DatabaseEvent event = await _database
            .child('users')
            .child(user.uid)
            .once();
        if (event.snapshot.value != null && mounted) {
          setState(() {
            userData = Map<String, dynamic>.from(event.snapshot.value as Map);
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading user data: ${e.toString()}')),
          );
        }
      }
    }
  }

  // Handle cart button press in app bar
  void _onCartPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
    ).then((_) {
      // Refresh wishlist when returning from cart
      refreshWishlist();
    });
  }

  final CategoryService _categoryService = CategoryService();
  List<Category> _categories = [];
  String _selectedCategoryId = 'All';

  // Show search screen
  void _showSearchScreen() {
    debugPrint('Search bar tapped! Opening search home screen...');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchHomeScreen()),
    );
  }

  // Show all categories in a dialog
  void _showAllCategories() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // All categories option
                _buildCategoryChip(
                  'All',
                  isSelected: _selectedCategoryId == 'All',
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = 'All';
                    });
                    Navigator.pop(context);
                  },
                ),
                // Dynamic parent categories
                ..._categories.map((category) {
                  return _buildCategoryChip(
                    category.name,
                    isSelected: _selectedCategoryId == category.id,
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Price Range
                  const Text(
                    'Price Range',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: RangeValues(_currentMinPrice, _currentMaxPrice),
                    min: _minPrice,
                    max: _maxPrice <= _minPrice ? _minPrice + 1 : _maxPrice,
                    divisions: 50,
                    activeColor: Colors.black,
                    inactiveColor: Colors.grey[200],
                    labels: RangeLabels(
                      '₹${_currentMinPrice.round()}',
                      '₹${_currentMaxPrice.round()}',
                    ),
                    onChanged: (RangeValues values) {
                      setDialogState(() {
                        _currentMinPrice = values.start;
                        _currentMaxPrice = values.end;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${_currentMinPrice.round()}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      Text('₹${_currentMaxPrice.round()}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // Category
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: _selectedCategoryId == 'All',
                            onSelected: (selected) {
                              setDialogState(() {
                                _selectedCategoryId = 'All';
                              });
                            },
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.black,
                            labelStyle: TextStyle(
                              color: _selectedCategoryId == 'All' ? Colors.white : Colors.black,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                        ..._categories.map<Widget>((category) {
                          final isSelected = _selectedCategoryId == category.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  _selectedCategoryId = selected ? category.id : 'All';
                                });
                              },
                              backgroundColor: Colors.grey[100],
                              selectedColor: Colors.black,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Brands
                  if (_allBrands.isNotEmpty) ...[
                    const Text(
                      'Brands',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _allBrands.map<Widget>((brand) {
                          final isSelected = _selectedBrands.contains(brand);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(brand),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedBrands.add(brand);
                                  } else {
                                    _selectedBrands.remove(brand);
                                  }
                                });
                              },
                              backgroundColor: Colors.grey[100],
                              selectedColor: Colors.black,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sort By
                  const Text(
                    'Sort By',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Relevance',
                      'Price: Low to High',
                      'Price: High to Low',
                      'Name: A to Z',
                    ].map<Widget>((option) {
                      final isSelected = _selectedSortOption == option;
                      return ChoiceChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              _selectedSortOption = option;
                            });
                          }
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setDialogState(() {
                              _selectedCategoryId = 'All';
                              _selectedBrands = [];
                              _currentMinPrice = _minPrice;
                              _currentMaxPrice = _maxPrice;
                              _selectedSortOption = 'Relevance';
                            });
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Actual results re-calculation
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery address',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                GestureDetector(
                  onTap: _navigateToAddressBook,
                  child: Row(
                    children: [
                      Text(
                        selectedAddress?['tag'] ?? 'Select Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.black,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
            onPressed: _onCartPressed,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar with Filter
                  DashboardSearchBar(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onFilterPressed: _showFilterDialog,
                    onTap: _showSearchScreen,
                  ),
                  const SizedBox(height: 24),

                  // Category Options
                  SizedBox(
                    height: 40,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // "All" option
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = 'All';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedCategoryId == 'All'
                                      ? Colors.black
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  'All',
                                  style: TextStyle(
                                    color: _selectedCategoryId == 'All'
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Display up to 4 categories
                          ..._categories.take(4).map((category) {
                            final isSelected =
                                _selectedCategoryId == category.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    category.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

                          // "See All" button if there are more than 4 categories
                          if (_categories.length > 4)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: GestureDetector(
                                onTap: _showAllCategories,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Text(
                                    'See All',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // User Info Section
                  // Products Grid
                  const Text(
                    'Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isLoadingProducts || _featuredProducts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.72,
                              ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final imageUrl =
                                (product['imageUrl'] ?? product['image'] ?? '')
                                    .toString();
                            final hasImageUrl =
                                imageUrl.isNotEmpty &&
                                (imageUrl.startsWith('http://') ||
                                    imageUrl.startsWith('https://'));
                            final title =
                                (product['name'] ?? product['title'] ?? '')
                                    .toString();

                            debugPrint('Displaying product: $title');
                            debugPrint('Image URL: "$imageUrl"');
                            debugPrint('Has valid URL: $hasImageUrl');
                            final price = (product['price'] ?? '').toString();
                            final salePrice =
                                (product['salePrice'] ?? product['price'] ?? '')
                                    .toString();
                            final hasDiscount =
                                product['salePrice'] != null &&
                                product['salePrice'] != product['price'];
                            final priceNum = double.tryParse(
                              (product['price'] ?? '').toString(),
                            );
                            final salePriceNum = double.tryParse(
                              (product['salePrice'] ?? product['price'] ?? '')
                                  .toString(),
                            );
                            final discountPercent =
                                (hasDiscount &&
                                    priceNum != null &&
                                    salePriceNum != null &&
                                    priceNum > 0)
                                ? (((priceNum - salePriceNum) / priceNum) * 100)
                                      .round()
                                : null;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProductDetailsScreen(product: product),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(18),
                                            ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Container(
                                                color: Colors.grey[50],
                                                child: hasImageUrl
                                                    ? Image.network(
                                                        imageUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) {
                                                              return const Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  size: 46,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              );
                                                            },
                                                      )
                                                    : const Center(
                                                        child: Icon(
                                                          Icons.image,
                                                          size: 46,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            if (discountPercent != null &&
                                                discountPercent > 0)
                                              Positioned(
                                                top: 10,
                                                left: 10,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '-$discountPercent%',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: GestureDetector(
                                                onTap: () => _toggleWishlist(
                                                  product['id'],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(
                                                      sigmaX: 10,
                                                      sigmaY: 10,
                                                    ),
                                                    child: Container(
                                                      height: 34,
                                                      width: 34,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.7),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withOpacity(0.8),
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        product['isWishlisted'] ==
                                                                true
                                                            ? Icons.favorite
                                                            : Icons
                                                                  .favorite_border,
                                                        size: 18,
                                                        color:
                                                            product['isWishlisted'] ==
                                                                true
                                                            ? Colors.red
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 34, // Fixed height for 2 lines of text
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black,
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (hasDiscount)
                                                    Text(
                                                      '₹$price',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                      ),
                                                    ),
                                                  Text(
                                                    '₹$salePrice',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: () =>
                                                    _addToCart(product),
                                                child: Container(
                                                  height: 34,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.add,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Add',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(
                    height: 120,
                  ), // Extra space for floating bottom nav
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WishlistScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }
}
