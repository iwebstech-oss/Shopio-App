import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecommerce/models/category_model.dart';
import 'package:ecommerce/services/category_service.dart';
import 'product_details_screen.dart';
import 'dart:ui';
import 'cart_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;

  const SearchResultsScreen({super.key, required this.searchQuery});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final CategoryService _categoryService = CategoryService();

  late TextEditingController _searchController;
  String _currentSearchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Category> _categories = [];
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isLoading = true;
  String _selectedCategoryId = 'All';
  String _selectedSortOption = 'Relevance';
  
  // Advanced Filter State
  double _minPrice = 0;
  double _maxPrice = 100000;
  double _currentMinPrice = 0;
  double _currentMaxPrice = 100000;
  List<String> _selectedBrands = [];
  Set<String> _allBrands = {};

  @override
  void initState() {
    super.initState();
    _currentSearchQuery = widget.searchQuery;
    _searchController = TextEditingController(text: widget.searchQuery);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadProducts(), _loadCategories()]);
    await _loadWishlist();
    _filterAndSortResults();
  }

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
        Map<String, dynamic> wishlist = {};

        if (value is Map) {
          wishlist = Map<String, dynamic>.from(value);
        } else if (value is List) {
          for (var item in value) {
            if (item is Map && item['id'] != null) {
              wishlist[item['id'].toString()] = item;
            }
          }
        }

        if (mounted) {
          setState(() {
            for (var product in _searchResults) {
              product['isWishlisted'] = wishlist.containsKey(product['id']);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> _toggleWishlist(String productId) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to wishlist')),
      );
      return;
    }

    final productIndex = _searchResults.indexWhere((p) => p['id'] == productId);
    if (productIndex == -1) return;

    final product = _searchResults[productIndex];
    final bool isCurrentlyWishlisted = product['isWishlisted'] ?? false;

    setState(() {
      _searchResults[productIndex]['isWishlisted'] = !isCurrentlyWishlisted;
      _filterAndSortResults();
    });

    try {
      final wishlistRef = _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .child(productId);

      if (isCurrentlyWishlisted) {
        await wishlistRef.remove();
      } else {
        await wishlistRef.set({
          'id': product['id'],
          'name': product['name'],
          'price': product['price'],
          'salePrice': product['salePrice'] ?? product['price'],
          'imageUrl': product['imageUrl'],
          'addedAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      setState(() {
        _searchResults[productIndex]['isWishlisted'] = isCurrentlyWishlisted;
        _filterAndSortResults();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update wishlist')),
      );
    }
  }

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
      final productId = product['id'];

      final event = await cartRef.child(productId).once();
      if (event.snapshot.value != null) {
        final currentData = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        await cartRef.child(productId).update({
          'quantity': (currentData['quantity'] ?? 0) + 1,
        });
      } else {
        await cartRef.child(productId).set({
          'id': productId,
          'name': product['name'],
          'price': product['price'],
          'salePrice': product['salePrice'] ?? product['price'],
          'imageUrl': product['imageUrl'],
          'quantity': 1,
          'addedAt': ServerValue.timestamp,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['name']} added to cart'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add to cart')),
      );
    }
  }

  Future<void> _loadProducts() async {
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

          final Iterable<dynamic> imagesIterable = imagesRaw is List
              ? imagesRaw
              : (imagesRaw is Map ? imagesRaw.values : const []);

          for (final img in imagesIterable) {
            if (img is Map) {
              final isMain = img['isMain'] == true;
              final url = (img['url'] ?? '').toString();
              if (url.isNotEmpty && isMain) {
                mainImageUrl = url;
                break;
              }
            }
          }

          if (mainImageUrl.isEmpty) {
            for (final img in imagesIterable) {
              if (img is Map) {
                final url = (img['url'] ?? '').toString();
                if (url.isNotEmpty) {
                  mainImageUrl = url;
                  break;
                }
              }
            }
          }

          product['id'] = key;
          product['name'] = title;
          product['imageUrl'] = mainImageUrl;
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
            _searchResults = allProducts;
            _allBrands = brands;
            if (maxDetectedPrice > 0) {
              _maxPrice = maxDetectedPrice;
              _currentMaxPrice = maxDetectedPrice;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _loadCategories() async {
    _categoryService.getParentCategories().listen((categories) {
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    });
  }

  void _filterAndSortResults() {
    List<Map<String, dynamic>> filtered = _searchResults.where((product) {
      final title = (product['name'] ?? product['title'] ?? '')
          .toString()
          .toLowerCase();
      final description = (product['description'] ?? '')
          .toString()
          .toLowerCase();
      final searchQuery = _currentSearchQuery.toLowerCase();
      final searchTerms = searchQuery.split(' ').where((t) => t.isNotEmpty).toList();

      if (searchTerms.isEmpty) return true;

      final tagsRaw = product['tags'];
      bool matchesTags = false;
      
      List<String> productTags = [];
      if (tagsRaw is List) {
        productTags = tagsRaw.map((e) => e.toString().toLowerCase()).toList();
      } else if (tagsRaw is Map) {
        // Handle both { "tag": true } and { "id": "tag" }
        productTags.addAll(tagsRaw.keys.map((k) => k.toString().toLowerCase()));
        productTags.addAll(
          tagsRaw.values
              .where((v) => v is String)
              .map((v) => v.toString().toLowerCase()),
        );
      } else if (tagsRaw is String) {
        productTags = tagsRaw.toLowerCase().split(',').map((s) => s.trim()).toList();
      }

      if (searchTerms.isNotEmpty) {
        bool matchesSearch = false;
        for (var term in searchTerms) {
          if (title.contains(term) || 
              description.contains(term) || 
              productTags.any((tag) => tag.contains(term))) {
            matchesSearch = true;
            break;
          }
        }
        if (!matchesSearch) return false;
      }

      // Category filter
      if (_selectedCategoryId != 'All' && product['categoryId'] != _selectedCategoryId) {
        return false;
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
          final priceA = double.tryParse((a['price'] ?? '0').toString()) ?? 0;
          final priceB = double.tryParse((b['price'] ?? '0').toString()) ?? 0;
          return priceA.compareTo(priceB);
        });
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) {
          final priceA = double.tryParse((a['price'] ?? '0').toString()) ?? 0;
          final priceB = double.tryParse((b['price'] ?? '0').toString()) ?? 0;
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
      case 'Relevance':
      default:
        // Keep original order or implement relevance scoring
        break;
    }

    if (mounted) {
      setState(() {
        _filteredResults = filtered;
        _isLoading = false;
      });
    }
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
                  ].map((option) {
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
                  }).toList().cast<Widget>(),
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
                          _filterAndSortResults();
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
    );
  }

  void _showSortBottomSheet() {
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
              'Sort by',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...[
              'Relevance',
              'Price: Low to High',
              'Price: High to Low',
              'Name: A to Z',
            ].map(
              (option) => RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: _selectedSortOption,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSortOption = value;
                    });
                    Navigator.pop(context);
                    _filterAndSortResults();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(left: 16, right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Icon(Icons.search, color: Color(0xFF5F6368), size: 22),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            setState(() {
                              _currentSearchQuery = value;
                              _isLoading = true;
                            });
                            _filterAndSortResults();
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Color(0xFF5F6368),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _showFilterDialog,
              icon: const Icon(
                Icons.tune,
                color: Color(0xFF5F6368),
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredResults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$_currentSearchQuery"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try different keywords or filters',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Results for section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Results for "$_currentSearchQuery"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${_filteredResults.length} found',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.grey),

                // Results grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _filteredResults.length,
                    itemBuilder: (context, index) {
                      final product = _filteredResults[index];
                      return _buildProductCard(product);
                    },
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = (product['name'] ?? product['title'] ?? 'Unknown').toString();
    final price = (product['price'] ?? '0').toString();
    final salePrice = (product['salePrice'] ?? price).toString();
    final imageUrl = (product['imageUrl'] ?? '').toString();
    final hasDiscount = product['salePrice'] != null && 
                       product['salePrice'] != product['price'];
    final isWishlisted = product['isWishlisted'] ?? false;
    
    final hasImageUrl = imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    final priceNum = double.tryParse(price);
    final salePriceNum = double.tryParse(salePrice);
    final discountPercent = (hasDiscount && priceNum != null && salePriceNum != null && priceNum > 0)
        ? (((priceNum - salePriceNum) / priceNum) * 100).round()
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        ).then((_) => _loadWishlist());
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
            // Product image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
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
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 46,
                                      color: Colors.grey,
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
                    if (discountPercent != null && discountPercent > 0)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-$discountPercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _toggleWishlist(product['id']),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              height: 34,
                              width: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              child: Icon(
                                isWishlisted ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: isWishlisted ? Colors.red : Colors.black,
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
  
            // Product info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount)
                            Text(
                              '₹$price',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '₹$salePrice',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _addToCart(product),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
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
                                  fontWeight: FontWeight.w700,
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
  }
}
