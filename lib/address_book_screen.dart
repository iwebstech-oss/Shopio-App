import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> addresses = [];
  bool _isLoading = true;
  int _currentIndex = 3; // Profile is the 4th tab (0-indexed as 3)
  int? _selectedAddressIndex;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
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

        // Load all addresses
        DatabaseEvent event = await _database
            .child('users')
            .child(user.uid)
            .child('Address Book')
            .once();

        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> addressData = event.snapshot.value as Map;
          List<Map<String, dynamic>> loadedAddresses = [];
          int? selectedIndex = 0;

          addressData.forEach((key, value) {
            final address = {'id': key, ...Map<String, dynamic>.from(value)};
            loadedAddresses.add(address);

            // Find the selected address index
            if (key == selectedAddressId) {
              selectedIndex = loadedAddresses.length - 1;
            }
          });

          setState(() {
            addresses = loadedAddresses;
            _selectedAddressIndex = selectedIndex;
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
            SnackBar(content: Text('Error loading addresses: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _addAddress(Map<String, String> addressData) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DatabaseReference addressRef = _database
            .child('users')
            .child(user.uid)
            .child('Address Book')
            .push();

        await addressRef.set(addressData);

        setState(() {
          addresses.add({'id': addressRef.key, ...addressData});
          _selectedAddressIndex = 0; // Select first address if none selected
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address added successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding address: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) {
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(initialIndex: index),
        ),
        (route) => false,
      );
    }
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
          padding: const EdgeInsets.only(top: 20.0),
          child: const Text(
            'Address Book',
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
            // Add Address Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddAddressScreen(),
                    ),
                  );

                  if (result != null) {
                    await _addAddress(result);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.black54, size: 22),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Add Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Addresses List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : addresses.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No addresses yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first address to get started',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        final address = addresses[index];
                        final isSelected = index == _selectedAddressIndex;
                        return GestureDetector(
                          onTap: () async {
                            setState(() {
                              _selectedAddressIndex = index;
                            });

                            // Save selected address ID to Firebase
                            User? user = _auth.currentUser;
                            if (user != null) {
                              await _database
                                  .child('users')
                                  .child(user.uid)
                                  .child('selectedAddress')
                                  .set(address['id']);
                            }

                            // Return selected address to previous screen
                            Navigator.pop(context, address);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            address['tag'] ?? 'Other',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Selected',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${address['houseBuilding'] ?? ''}, ${address['area'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (address['landmark'] != null &&
                                          address['landmark']!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          address['landmark'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        '${address['state'] ?? ''}, ${address['pinCode'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey[400],
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

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _houseBuildingController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _countryController = TextEditingController();

  String _selectedTag = 'Home';
  bool _isOtherTag = false;
  final _otherTagController = TextEditingController();

  final List<String> _tags = ['Home', 'Work', 'Other'];

  @override
  void dispose() {
    _houseBuildingController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    _countryController.dispose();
    _otherTagController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      final tag = _selectedTag == 'Other'
          ? _otherTagController.text.trim()
          : _selectedTag;

      if (_selectedTag == 'Other' && _otherTagController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a tag name')),
        );
        return;
      }

      final addressData = {
        'tag': tag,
        'houseBuilding': _houseBuildingController.text.trim(),
        'area': _areaController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'state': _stateController.text.trim(),
        'pinCode': _pinCodeController.text.trim(),
        'country': _countryController.text.trim(),
      };

      Navigator.pop(context, addressData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add Address',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag Selection
                const Text(
                  'Address Tag',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _tags.map((tag) {
                    final isSelected = _selectedTag == tag;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTag = tag;
                            _isOtherTag = tag == 'Other';
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            tag,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_isOtherTag) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otherTagController,
                    decoration: const InputDecoration(
                      labelText: 'Enter tag name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a tag name';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // House/Building No.
                TextFormField(
                  controller: _houseBuildingController,
                  decoration: const InputDecoration(
                    labelText: 'House / Building No.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter house/building number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Area
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter area';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Landmark
                TextFormField(
                  controller: _landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'Landmark (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // State
                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter state';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Pin Code
                TextFormField(
                  controller: _pinCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Pin Code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter pin code';
                    }
                    if (value.length != 6) {
                      return 'Pin code must be 6 digits';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Country
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter country';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
