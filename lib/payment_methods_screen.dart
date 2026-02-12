import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dashboard_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final Map<String, dynamic> selectedAddress;
  final List<Map<String, dynamic>> cartItems;
  final double totalPrice;

  const PaymentMethodsScreen({
    super.key,
    required this.selectedAddress,
    required this.cartItems,
    required this.totalPrice,
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedPaymentMethod = 'UPI';
  String _selectedCardType = 'Debit Card';
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  bool _isProcessing = false;

  // Text controllers for payment details
  final _upiIdController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final s = value.toString().trim();
    return double.tryParse(s) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Padding(
          padding: const EdgeInsets.only(left: 0, top: 20.0),
          child: const Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Select the payment method you want to use.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 30),

                    // UPI Option
                    _buildPaymentOption(
                      title: 'UPI',
                      subtitle: 'Pay using UPI apps',
                      icon: Icons.account_balance_wallet,
                      value: 'UPI',
                      groupValue: _selectedPaymentMethod,
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'UPI'),
                    ),

                    // UPI Input Form (show when UPI is selected)
                    if (_selectedPaymentMethod == 'UPI') ...[
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enter UPI ID',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _upiIdController,
                              decoration: const InputDecoration(
                                labelText: 'UPI ID',
                                hintText: 'example@upi',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Card Option
                    _buildPaymentOption(
                      title: 'Card',
                      subtitle: 'Debit/Credit Card',
                      icon: Icons.credit_card,
                      value: 'Card',
                      groupValue: _selectedPaymentMethod,
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'Card'),
                    ),

                    // Card Input Form (show when Card is selected)
                    if (_selectedPaymentMethod == 'Card') ...[
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enter Card Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Card Type Selection
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedCardType = 'Debit Card',
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedCardType == 'Debit Card'
                                            ? Colors.black
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              _selectedCardType == 'Debit Card'
                                              ? Colors.black
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        'Debit Card',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color:
                                              _selectedCardType == 'Debit Card'
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedCardType = 'Credit Card',
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _selectedCardType == 'Credit Card'
                                            ? Colors.black
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              _selectedCardType == 'Credit Card'
                                              ? Colors.black
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        'Credit Card',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color:
                                              _selectedCardType == 'Credit Card'
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Card Number
                            TextField(
                              controller: _cardNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Card Number',
                                hintText: '1234 5678 9012 3456',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 19,
                            ),
                            const SizedBox(height: 12),

                            // Cardholder Name
                            TextField(
                              controller: _cardNameController,
                              decoration: const InputDecoration(
                                labelText: 'Cardholder Name',
                                hintText: 'John Doe',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Expiry Date and CVV
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _expiryDateController,
                                    decoration: const InputDecoration(
                                      labelText: 'Expiry Date',
                                      hintText: 'MM/YY',
                                      border: OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    maxLength: 5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _cvvController,
                                    decoration: const InputDecoration(
                                      labelText: 'CVV',
                                      hintText: '123',
                                      border: OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType: TextInputType.number,
                                    maxLength: 3,
                                    obscureText: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Cash on Delivery Option
                    _buildPaymentOption(
                      title: 'Cash on Delivery',
                      subtitle: 'Pay when you receive',
                      icon: Icons.money,
                      value: 'Cash on Delivery',
                      groupValue: _selectedPaymentMethod,
                      onTap: () => setState(
                        () => _selectedPaymentMethod = 'Cash on Delivery',
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '₹${widget.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
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
            ),

            // Confirm Payment Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 24,
              color: isSelected ? Colors.black : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getPaymentDetails() {
    if (_selectedPaymentMethod == 'UPI') {
      return {'type': 'UPI', 'upiId': _upiIdController.text, 'isUpi': true};
    } else if (_selectedPaymentMethod == 'Card') {
      return {
        'type': 'Card',
        'cardType': _selectedCardType,
        'cardNumber':
            '****${_cardNumberController.text.length >= 4 ? _cardNumberController.text.substring(_cardNumberController.text.length - 4) : ''}',
        'cardholderName': _cardNameController.text,
        'expiryDate': _expiryDateController.text,
        'lastFourDigits': _cardNumberController.text.length >= 4
            ? _cardNumberController.text.substring(
                _cardNumberController.text.length - 4,
              )
            : '',
        'isCard': true,
      };
    } else if (_selectedPaymentMethod == 'Cash on Delivery') {
      return {'type': 'Cash on Delivery', 'isCashOnDelivery': true};
    }
    return {'type': 'Unknown', 'isUnknown': true};
  }

  Future<void> _confirmPayment() async {
    // Validate payment details before proceeding
    if (_selectedPaymentMethod == 'UPI' && _upiIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your UPI ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod == 'Card') {
      if (_cardNumberController.text.isEmpty ||
          _cardNameController.text.isEmpty ||
          _expiryDateController.text.isEmpty ||
          _cvvController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all card details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Show payment confirmation dialog
    String paymentDetails = '';
    if (_selectedPaymentMethod == 'UPI') {
      paymentDetails = 'UPI ID: ${_upiIdController.text}';
    } else if (_selectedPaymentMethod == 'Card') {
      paymentDetails =
          '$_selectedCardType ending with ****${_cardNumberController.text.length >= 4 ? _cardNumberController.text.substring(_cardNumberController.text.length - 4) : ''}';
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm $_selectedPaymentMethod Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Method: $_selectedPaymentMethod'),
              const SizedBox(height: 8),
              Text('Payment Details: $paymentDetails'),
              const SizedBox(height: 8),
              Text('Amount: ₹${widget.totalPrice.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              const Text('Do you want to proceed with the payment?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text(
                'Pay Now',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Generate unique order ID
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Prepare order data
      final orderData = {
        'orderId': orderId,
        'userId': user.uid,
        'items': widget.cartItems,
        'shippingAddress': widget.selectedAddress,
        'totalAmount': widget.totalPrice,
        'paymentMethod': _selectedPaymentMethod,
        'cardType': _selectedPaymentMethod == 'Card' ? _selectedCardType : null,
        'orderStatus': 'Confirmed',
        'orderDate': DateTime.now().toIso8601String(),
        'estimatedDelivery': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
        // Store payment details
        'paymentDetails': _getPaymentDetails(),
      };

      // Save to users/myorders
      await _database
          .child('users')
          .child(user.uid)
          .child('myorders')
          .child(orderId)
          .set(orderData);

      // Save to orders node
      await _database.child('orders').child(orderId).set(orderData);

      // Update product stock for each ordered item
      await _updateProductStock(widget.cartItems);

      // Clear cart after successful order
      await _database.child('users').child(user.uid).child('cart').remove();

      if (mounted) {
        // Navigate to order success screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(orderId: orderId),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _updateProductStock(List<Map<String, dynamic>> cartItems) async {
    for (var item in cartItems) {
      final productId = item['id'] as String?;
      final quantity = _toDouble(item['quantity'] ?? 1);

      if (productId != null && productId.isNotEmpty) {
        try {
          // Get current product data
          DatabaseEvent productEvent = await _database
              .child('products')
              .child(productId)
              .once();

          if (productEvent.snapshot.value != null) {
            final productData = Map<String, dynamic>.from(
              productEvent.snapshot.value as Map,
            );

            // Get current stock
            final currentStock = _toDouble(productData['stock'] ?? 0);

            // Update stock (subtract ordered quantity)
            final newStock = (currentStock - quantity).clamp(
              0,
              double.infinity,
            );

            // Update product in database
            await _database.child('products').child(productId).update({
              'stock': newStock,
              'lastUpdated': DateTime.now().toIso8601String(),
            });

            debugPrint(
              'Updated stock for product $productId: $currentStock -> $newStock',
            );
          }
        } catch (e) {
          debugPrint('Error updating stock for product $productId: $e');
          // Continue with other products even if one fails
        }
      }
    }
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Successful!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Order ID: $orderId',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your order has been confirmed and will be delivered soon.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Continue Shopping',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
