// edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isRemovingImage = false;
  String _token = '';
  String _storeId = '';
  String _currentProfileImage = '';
  File? _selectedImage;
  
  static const _brand = Color(0xFF132C48);
  static const _bg = Color(0xFFF8F9FA);
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    
    nameController.text = prefs.getString('full_name') ?? '';
    emailController.text = prefs.getString('email') ?? '';
    phoneController.text = prefs.getString('phone') ?? '';
    _storeId = prefs.getString('store_id') ?? '';
    _currentProfileImage = prefs.getString('profile_image') ?? '';
    
    print('Token: $_token');
    print('Store ID: $_storeId');
    print('Current profile image: $_currentProfileImage');
    
    if (_token.isNotEmpty) {
      await _fetchUserProfile();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication token not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      print('Fetching user profile...');
      
      final response = await http.get(
        Uri.parse('http://142.54.168.26:5050/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> userData = responseData['user'];
        
        setState(() {
          nameController.text = userData['full_name']?.toString() ?? '';
          emailController.text = userData['email']?.toString() ?? '';
          phoneController.text = userData['phone']?.toString() ?? '';
          _storeId = userData['store_id']?['_id']?.toString() ?? _storeId;
          _currentProfileImage = userData['profile_image']?.toString() ?? '';
          _isLoading = false;
        });
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', nameController.text);
        await prefs.setString('email', emailController.text);
        await prefs.setString('phone', phoneController.text);
        await prefs.setString('store_id', _storeId);
        await prefs.setString('profile_image', _currentProfileImage);
        
        print('Profile fetched successfully');
        
      } else {
        setState(() {
          _isLoading = false;
        });
        
        String errorMessage = 'Failed to load user profile';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server error: ${response.statusCode}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedImage != null) {
        setState(() {
          _selectedImage = File(pickedImage.path);
          _isRemovingImage = false; // Reset remove flag when new image is selected
        });
        print('Image selected: ${_selectedImage!.path}');
        print('Image size: ${await _selectedImage!.length()} bytes');
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _isRemovingImage = true;
    });
    
    // Clear the selected image and mark for removal
    setState(() {
      _selectedImage = null;
    });
    
    print('User wants to remove profile image');
  }

  Future<void> _updateUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://142.54.168.26:5050/api/auth/profile'),
      );
      
      request.headers['Authorization'] = 'Bearer $_token';
      
      // Add text fields
      request.fields['full_name'] = nameController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['phone'] = phoneController.text.trim();
      
      if (_storeId.isNotEmpty) {
        request.fields['store_id'] = _storeId;
      }
      
      // Handle image based on user action
      if (_isRemovingImage) {
        // User wants to remove image - send empty string
        request.fields['profile_image'] = '';
        print('Removing profile image - sending empty string');
      } else if (_selectedImage != null) {
        // User selected a new image - send as binary
        List<int> imageBytes = await _selectedImage!.readAsBytes();
        
        var multipartFile = http.MultipartFile.fromBytes(
          'profile_image',
          imageBytes,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        
        request.files.add(multipartFile);
        print('Uploading new image as binary data. Size: ${imageBytes.length} bytes');
      } else {
        // No change to image - don't send anything
        print('Keeping existing profile image');
      }
      
      print('Sending update request...');
      print('Fields: ${request.fields}');
      print('Files count: ${request.files.length}');
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final userData = responseData['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', userData['full_name'] ?? nameController.text.trim());
        await prefs.setString('email', userData['email'] ?? emailController.text.trim());
        await prefs.setString('phone', userData['phone'] ?? phoneController.text.trim());
        
        // Update profile image based on response
        if (userData['profile_image'] != null && userData['profile_image'].toString().isNotEmpty) {
          String newImagePath = userData['profile_image'];
          await prefs.setString('profile_image', newImagePath);
          setState(() {
            _currentProfileImage = newImagePath;
            _selectedImage = null;
            _isRemovingImage = false;
          });
          print('Profile image updated: $newImagePath');
        } else if (_isRemovingImage) {
          // Image was removed successfully
          await prefs.setString('profile_image', '');
          setState(() {
            _currentProfileImage = '';
            _selectedImage = null;
            _isRemovingImage = false;
          });
          print('Profile image removed successfully');
        }
        
        if (userData['store_id'] != null) {
          String storeId = userData['store_id']['_id'] ?? userData['store_id'].toString();
          await prefs.setString('store_id', storeId);
        }
        
        setState(() {
          _isUpdating = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Profile updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              duration: Duration(seconds: 2),
            ),
          );
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      } else {
        setState(() {
          _isUpdating = false;
          _isRemovingImage = false;
        });
        
        String errorMessage = 'Failed to update profile';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server error: ${response.statusCode}';
        }
        
        print('Error: $errorMessage');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _isUpdating = false;
        _isRemovingImage = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFullImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    return 'http://142.54.168.26:5050/$imagePath';
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return '?';
    List<String> nameParts = fullName.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }
    return (nameParts[0][0] + nameParts[nameParts.length - 1][0]).toUpperCase();
  }

  Widget _buildProfileImage() {
    // If user wants to remove image or no image exists, show initials
    if (_isRemovingImage || (_currentProfileImage.isEmpty && _selectedImage == null)) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: _brand.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _getInitials(nameController.text),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: _brand,
            ),
          ),
        ),
      );
    }
    
    // Show selected image
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }
    
    // Show existing profile image
    if (_currentProfileImage.isNotEmpty && _currentProfileImage != 'null') {
      String imageUrl = _getFullImageUrl(_currentProfileImage);
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(nameController.text),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _brand,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    
    // Default - show initials
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: _brand.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(nameController.text),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: _brand,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: _brand,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_brand),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Header - Moved below AppBar
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _brand,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Update your personal details',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Profile Image Section - Now above Full Name
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                border: Border.all(
                                  color: _brand,
                                  width: 3,
                                ),
                              ),
                              child: _buildProfileImage(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: Icon(Icons.camera_alt, size: 18, color: _brand),
                                label: Text(
                                  'Change',
                                  style: TextStyle(color: _brand),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              if (_currentProfileImage.isNotEmpty || _selectedImage != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Container(
                                    width: 1,
                                    height: 20,
                                    color: Colors.grey[300],
                                  ),
                                ),
                              if (_currentProfileImage.isNotEmpty || _selectedImage != null)
                                TextButton.icon(
                                  onPressed: _removeImage,
                                  icon: Icon(Icons.delete_outline, size: 18),
                                  label: Text(
                                    'Remove',
                                    style: TextStyle(color: Colors.red[400]),
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to change profile picture',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brand.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Full Name Field
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(
                            color: _brand.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person_rounded, color: _brand),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _brand, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.length < 3) {
                            return 'Name must be at least 3 characters';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (_currentProfileImage.isEmpty && _selectedImage == null) {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    
                    // Email Field
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(
                            color: _brand.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'Enter your email address',
                          prefixIcon: Icon(Icons.email_rounded, color: _brand),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _brand, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Phone Field
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(
                            color: _brand.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'Enter your phone number',
                          prefixIcon: Icon(Icons.phone_rounded, color: _brand),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _brand, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : _updateUserProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          disabledBackgroundColor: _brand.withOpacity(0.6),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Update Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}