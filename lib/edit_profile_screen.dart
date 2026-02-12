import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'address_book_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const EditProfileScreen({super.key, this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  // State variables
  File? _profileImage;
  String? _profileImageUrl;
  bool _hasChanges = false;
  bool _isLoading = false;
  Map<String, dynamic>? selectedAddress;

  // Firebase
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();

  // ImgBB API
  static const String _imgBBApiKey = '66078ac1ded9c8184ec8c35bd8b9dc7a';
  static const String _imgBBUrl = 'https://api.imgbb.com/1/upload';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(
      text: widget.userData?['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userData?['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData?['phone'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.userData?['address'] ?? '',
    );
    _profileImageUrl = widget.userData?['profileImage'];
    _loadSelectedAddress();
  }

  Future<void> _loadSelectedAddress() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DatabaseEvent event = await _database
            .child('users')
            .child(user.uid)
            .child('selectedAddress')
            .once();

        if (event.snapshot.value != null) {
          // Load the selected address
          final selectedAddressId = event.snapshot.value as String?;
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
                _addressController.text =
                    '${address['houseBuilding'] ?? ''}, ${address['area'] ?? ''}, ${address['state'] ?? ''}, ${address['pinCode'] ?? ''}';
              });
              return;
            }
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
              _addressController.text =
                  '${address['houseBuilding'] ?? ''}, ${address['area'] ?? ''}, ${address['state'] ?? ''}, ${address['pinCode'] ?? ''}';
            });
          }
        }
      } catch (e) {
        print('Error loading address: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<String?> _uploadImageToImgBB(File image) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_imgBBUrl));
      request.fields['key'] = _imgBBApiKey;

      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.path.split('/').last,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        return jsonResponse['data']['url'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? uploadedImageUrl = _profileImageUrl;

      // Upload new image if selected
      if (_profileImage != null) {
        uploadedImageUrl = await _uploadImageToImgBB(_profileImage!);
      }

      // Save to Firebase
      User? user = _auth.currentUser;
      if (user != null) {
        await _database.child('users').child(user.uid).update({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'profileImage': uploadedImageUrl,
          'updatedAt': ServerValue.timestamp,
        });
      }

      if (mounted) {
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'profileImage': uploadedImageUrl,
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToAddressBook() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressBookScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        selectedAddress = result;
        _addressController.text =
            '${result['houseBuilding'] ?? ''}, ${result['area'] ?? ''}, ${result['state'] ?? ''}, ${result['pinCode'] ?? ''}';
        _hasChanges = true;
      });
    }
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  onChanged: _onFieldChanged,
                  child: Column(
                    children: [
                      // Profile Picture
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: _profileImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildDefaultAvatar(),
                                  ),
                                )
                              : _profileImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: Image.network(
                                    _profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildDefaultAvatar(),
                                  ),
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to change photo',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),

                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                        onChanged: (value) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        onChanged: (value) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 20),

                      // Phone Field
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length != 10) {
                            return 'Please enter a valid 10-digit phone number';
                          }
                          return null;
                        },
                        onChanged: (value) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 20),

                      // Address Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextFormField(
                              controller: _addressController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Current Address',
                                prefixIcon: Icon(
                                  Icons.location_on,
                                  color: Colors.grey[600],
                                ),
                                suffixIcon: TextButton(
                                  onPressed: _navigateToAddressBook,
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 20,
                                ),
                              ),
                              style: TextStyle(
                                color: _addressController.text.isEmpty
                                    ? Colors.grey[500]
                                    : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Save Button (always visible but disabled when no changes)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_hasChanges && !_isLoading)
                              ? _saveProfile
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasChanges
                                ? Colors.black
                                : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  'Save Changes',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return const Icon(Icons.person, size: 60, color: Colors.grey);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 20,
        ),
      ),
    );
  }
}
