import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:ui';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  bool _isWishlisted = false;
  bool _isLoading = false;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _checkWishlistStatus();
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkWishlistStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final event = await _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .child(widget.product['id'])
          .once();

      if (mounted) {
        setState(() {
          _isWishlisted = event.snapshot.value != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking wishlist status: $e');
    }
  }

  Future<void> _toggleWishlist() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showLoginPrompt();
      return;
    }

    setState(() {
      _isWishlisted = !_isWishlisted;
    });

    _heartAnimationController.forward().then((_) {
      _heartAnimationController.reverse();
    });

    try {
      final wishlistRef = _database
          .child('users')
          .child(user.uid)
          .child('wishlist')
          .child(widget.product['id']);

      if (_isWishlisted) {
        await wishlistRef.set({
          'id': widget.product['id'],
          'name': widget.product['title'] ?? widget.product['name'],
          'price': widget.product['price'],
          'salePrice': widget.product['salePrice'] ?? widget.product['price'],
          'imageUrl': widget.product['imageUrl'],
          'addedAt': ServerValue.timestamp,
        });
      } else {
        await wishlistRef.remove();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.grey[800],
            content: Row(
              children: [
                Icon(
                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isWishlisted
                        ? 'Added to wishlist'
                        : 'Removed from wishlist',
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
      setState(() {
        _isWishlisted = !_isWishlisted;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update wishlist: ${e.toString()}')),
        );
      }
    }
  }

  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please login to add items to wishlist'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addToCart() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showLoginPrompt();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cartRef = _database.child('users').child(user.uid).child('cart');

      // Check if product already in cart
      final event = await cartRef.once();
      Map<dynamic, dynamic> cartItems = {};
      if (event.snapshot.value != null) {
        cartItems = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      }

      if (cartItems.containsKey(widget.product['id'])) {
        // Update quantity if already in cart
        await cartRef.child(widget.product['id']).update({
          'quantity': cartItems[widget.product['id']]['quantity'] + 1,
        });
      } else {
        // Add new item to cart
        await cartRef.child(widget.product['id']).set({
          'name': widget.product['title'] ?? widget.product['name'],
          'price': widget.product['price'],
          'salePrice': widget.product['salePrice'] ?? widget.product['price'],
          'imageUrl': widget.product['imageUrl'],
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
                    '${widget.product['title'] ?? widget.product['name']} added to cart',
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> _getProductImages() {
    final images = <String>[];

    // Add main image
    if (widget.product['imageUrl'] != null &&
        widget.product['imageUrl'].toString().isNotEmpty) {
      images.add(widget.product['imageUrl']);
    }

    // Add additional images if available
    if (widget.product['images'] != null) {
      final imagesData = widget.product['images'];
      if (imagesData is List) {
        for (final img in imagesData) {
          if (img is Map && img['url'] != null) {
            final url = img['url'].toString();
            if (url.isNotEmpty && !images.contains(url)) {
              images.add(url);
            }
          }
        }
      }
    }

    // Fallback placeholder if no images
    if (images.isEmpty) {
      images.add('https://via.placeholder.com/400x400?text=Product');
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    final productImages = _getProductImages();
    final productName =
        widget.product['title'] ?? widget.product['name'] ?? 'Product';
    final productPrice = widget.product['price']?.toString() ?? '0';
    final productSalePrice =
        widget.product['salePrice']?.toString() ?? productPrice;
    final productSku = widget.product['sku']?.toString() ?? 'N/A';
    final productStock = widget.product['stock']?.toString() ?? '0';
    final productCategory =
        widget.product['category']?.toString() ?? 'Uncategorized';
    final hasDiscount = productSalePrice != productPrice;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            slivers: [
              // App bar with transparent background
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                expandedHeight: MediaQuery.of(context).size.height * 0.5,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedBuilder(
                        animation: _heartAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _heartAnimation.value,
                            child: IconButton(
                              icon: Icon(
                                _isWishlisted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _isWishlisted
                                    ? Colors.red
                                    : Colors.black,
                                size: 20,
                              ),
                              onPressed: _toggleWishlist,
                              padding: EdgeInsets.zero,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Product image with light grey background
                      Container(
                        color: const Color(0xFFF5F5F5),
                        child: PageView.builder(
                          onPageChanged: (index) {
                            setState(() {
                              _selectedImageIndex = index;
                            });
                          },
                          itemCount: productImages.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              productImages[index],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFF5F5F5),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      // Image indicators
                      if (productImages.length > 1)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              productImages.length,
                              (index) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedImageIndex == index
                                      ? Colors.black
                                      : Colors.black.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Product details section
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            productCategory.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Product title
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Price section
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹$productSalePrice',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 12),
                                Text(
                                  '₹$productPrice',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Product description
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        widget.product['description'] ??
                                        'The Nintendo Switch gaming console is a compact device that can be taken everywhere. This portable super device is also equipped with 2 gamepads. ',
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {
                                        // Handle read more functionality
                                      },
                                      child: const Text(
                                        'Read more',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Product metadata
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'SKU',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    productSku,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Stock',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$productStock units',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 120,
                        ), // Extra padding to avoid content being hidden by fixed button
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black, // Black color
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _isLoading ? null : _addToCart,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      extendBodyBehindAppBar: true,
      extendBody: true,
    );
  }
}

class CustomBackArrow extends StatelessWidget {
  const CustomBackArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _BackArrowPainter()),
    );
  }
}

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;

    final path = Path();

    // Convert SVG path to Flutter path
    // SVG: M169.4 297.4C156.9 309.9 156.9 330.2 169.4 342.7L361.4 534.7C373.9 547.2 394.2 547.2 406.7 534.7C419.2 522.2 419.2 501.9 406.7 489.4L237.3 320L406.6 150.6C419.1 138.1 419.1 117.8 406.6 105.3C394.1 92.8 373.8 92.8 361.3 105.3L169.3 297.3z

    // Scale down to 24x24 size
    final scale = size.width / 640;
    final double shiftX = 50 * scale; // Shift icon more to the right

    path.moveTo(169.4 * scale + shiftX, 297.4 * scale);
    path.cubicTo(
      156.9 * scale + shiftX,
      309.9 * scale,
      156.9 * scale + shiftX,
      330.2 * scale,
      169.4 * scale + shiftX,
      342.7 * scale,
    );
    path.lineTo(361.4 * scale + shiftX, 534.7 * scale);
    path.cubicTo(
      373.9 * scale + shiftX,
      547.2 * scale,
      394.2 * scale + shiftX,
      547.2 * scale,
      406.7 * scale + shiftX,
      534.7 * scale,
    );
    path.cubicTo(
      419.2 * scale + shiftX,
      522.2 * scale,
      419.2 * scale + shiftX,
      501.9 * scale,
      406.7 * scale + shiftX,
      489.4 * scale,
    );
    path.lineTo(237.3 * scale + shiftX, 320 * scale);
    path.lineTo(406.6 * scale + shiftX, 150.6 * scale);
    path.cubicTo(
      419.1 * scale + shiftX,
      138.1 * scale,
      419.1 * scale + shiftX,
      117.8 * scale,
      406.6 * scale + shiftX,
      105.3 * scale,
    );
    path.cubicTo(
      394.1 * scale + shiftX,
      92.8 * scale,
      373.8 * scale + shiftX,
      92.8 * scale,
      361.3 * scale + shiftX,
      105.3 * scale,
    );
    path.lineTo(169.3 * scale + shiftX, 297.3 * scale);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
