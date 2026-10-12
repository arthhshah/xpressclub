import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:food/provider/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food/screens/cartscreen.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:flutter/services.dart';

// ==================== ADDON MODEL ====================
class AddonItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool isRequired;
  final bool isActive;

  AddonItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isRequired,
    required this.isActive,
  });

  factory AddonItem.fromJson(Map<String, dynamic> json) {
    return AddonItem(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? 'general',
      isRequired: json['is_required'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }
}

class MenuItemDetail {
  final String id;
  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final int discountPercentage;
  final String? discountName;
  final String? imageUrl;
  final bool isAvailable;
  final bool isActive;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final String categoryId;
  final String categoryName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AddonItem> addons;

  MenuItemDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice = 0.0,
    this.discountPercentage = 0,
    this.discountName,
    this.imageUrl,
    required this.isAvailable,
    required this.isActive,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.categoryId,
    required this.categoryName,
    required this.createdAt,
    required this.updatedAt,
    this.addons = const [],
  });

  bool get hasOffer => discountPercentage > 0 || discountName != null || originalPrice > price;

  factory MenuItemDetail.fromJson(Map<String, dynamic> json) {
    // Parse addons
    List<AddonItem> addonsList = [];
    if (json['addons'] != null && json['addons'] is List) {
      addonsList = (json['addons'] as List)
          .map((addon) => AddonItem.fromJson(addon))
          .where((addon) => addon.isActive)
          .toList();
    }

    double price = 0.0;
    if (json['price'] != null) {
      if (json['price'] is int) {
        price = (json['price'] as int).toDouble();
      } else if (json['price'] is double) {
        price = json['price'];
      } else if (json['price'] is String) {
        price = double.tryParse(json['price']) ?? 0.0;
      } else if (json['price'] is num) {
        price = (json['price'] as num).toDouble();
      }
    }

    int discountPercentage = 0;
    String? discountName;

    if (json['discount_percentage'] != null) {
      discountPercentage = (json['discount_percentage'] as num).toInt();
    } else if (json['discount'] != null) {
      discountPercentage = (json['discount'] as num).toInt();
    }

    if (json['discount_id'] != null) {
      if (json['discount_id'] is Map) {
        final dMap = json['discount_id'];
        discountName = dMap['discount_name'] ?? dMap['name'];
        final amt = dMap['amount'] ?? dMap['discount_percentage'] ?? dMap['percentage'] ?? dMap['value'];
        if (amt is num && amt > 0) {
          discountPercentage = amt.toInt();
        }
      } else if (json['discount_id'] is String) {
        discountName = 'Special Offer';
      }
    }

    double originalPrice = 0.0;
    if (json['original_price'] != null) {
      if (json['original_price'] is int) {
        originalPrice = (json['original_price'] as int).toDouble();
      } else if (json['original_price'] is double) {
        originalPrice = json['original_price'];
      } else if (json['original_price'] is String) {
        originalPrice = double.tryParse(json['original_price']) ?? 0.0;
      } else if (json['original_price'] is num) {
        originalPrice = (json['original_price'] as num).toDouble();
      }
    } else if (discountPercentage > 0 && price > 0) {
      originalPrice = price / (1 - (discountPercentage / 100));
    }

    return MenuItemDetail(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: price,
      originalPrice: originalPrice,
      discountPercentage: discountPercentage,
      discountName: discountName,
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
      isActive: json['is_active'] ?? true,
      storeId: json['store']?['_id'] ?? json['store'] ?? '',
      storeName: json['store']?['name'] ?? 'Unknown Store',
      storeAddress: json['store']?['address'] ?? '',
      categoryId: json['category']?['_id'] ?? json['category'] ?? '',
      categoryName: json['category']?['name'] ?? 'Unknown Category',
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updatedAt'] ?? DateTime.now().toIso8601String()),
      addons: addonsList,
    );
  }
}

class MenuItemDetailsScreen extends StatefulWidget {
  final String menuItemId;

  const MenuItemDetailsScreen({
    super.key,
    required this.menuItemId,
  });

  @override
  State<MenuItemDetailsScreen> createState() => _MenuItemDetailsScreenState();
}

class _MenuItemDetailsScreenState extends State<MenuItemDetailsScreen>
    with SingleTickerProviderStateMixin {
  MenuItemDetail? _menuItem;
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;
  bool _isAddingToCart = false;
  String? _userId;
  String? _token;
  String? _storeId;

  // Addons State - using quantity map instead of boolean
  final Map<String, int> _selectedAddons = {};
  static const int _defaultMaxAddonQty = 5;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Colors
  static const Color appBarColor = Color(0xFF1E3A5F);
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color textBlack = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF8A8A8A);
  static const Color bgColor = Color(0xFFF8F9FC);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _initializeData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _fetchMenuItemDetails();
    await _fetchCartCount();
  }

  int _cartItemCount = 0;

  Future<void> _fetchCartCount() async {
    await CartManager.updateCartCount();
    if (mounted) {
      setState(() {
        _cartItemCount = CartManager.cartCount.value;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _token = prefs.getString('token');
        _userId = prefs.getString('userId');
        _storeId = prefs.getString('store_id');
      });

      print('=== User Data Loaded ===');
      print('User ID: $_userId');
      print('Store ID: $_storeId');
      print('Token: ${_token != null ? "Exists (${_token!.length} chars)" : "Not found"}');
      print('========================');
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchMenuItemDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String apiUrl =
          'http://142.54.168.26:5050/api/menu-items/viewmenuitem/${widget.menuItemId}';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (authProvider.token != null)
            'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['data'] != null) {
          setState(() {
            _menuItem = MenuItemDetail.fromJson(decoded['data']);
            _isLoading = false;
          });
          _animController.forward();
        } else {
          setState(() {
            _error = 'Invalid response format';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load menu item details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  // ==================== ADDONS HELPERS ====================
  void _incrementAddon(String addonId) {
    setState(() {
      final int current = _selectedAddons[addonId] ?? 0;
      if (current < _defaultMaxAddonQty) {
        _selectedAddons[addonId] = current + 1;
      } else {
        _showToastMessage('Maximum $_defaultMaxAddonQty addons allowed', isError: true);
      }
    });
  }

  void _decrementAddon(String addonId) {
    setState(() {
      final int current = _selectedAddons[addonId] ?? 0;
      if (current > 0) {
        if (current - 1 == 0) {
          _selectedAddons.remove(addonId);
        } else {
          _selectedAddons[addonId] = current - 1;
        }
      }
    });
  }

  double get _addonsUnitTotal {
    if (_menuItem == null) return 0;
    double total = 0;
    for (final addon in _menuItem!.addons) {
      final qty = _selectedAddons[addon.id] ?? 0;
      total += addon.price * qty;
    }
    return total;
  }

  double get _unitPrice => (_menuItem?.price ?? 0) + _addonsUnitTotal;

  double get _totalPrice => _unitPrice * _quantity;

  double get _originalUnitPrice => ((_menuItem?.originalPrice ?? 0) > (_menuItem?.price ?? 0) ? _menuItem!.originalPrice : _menuItem!.price) + _addonsUnitTotal;

  double get _originalTotalPrice => _originalUnitPrice * _quantity;

  // ==================== ADD TO CART METHOD ====================
  Future<void> _addToCart() async {
    if (_menuItem == null) return;

    final int addedQty = _quantity;
    setState(() => _isAddingToCart = true);

    // Show background loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accentOrange),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Adding to cart...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textBlack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? customerId = prefs.getString('userId');
      final String? token = prefs.getString('token');
      final String? storeId = prefs.getString('store_id');

      // Prepare addons payload
      final List<Map<String, dynamic>> addonsPayload = [];
      for (final addon in _menuItem!.addons) {
        final int qty = _selectedAddons[addon.id] ?? 0;
        if (qty > 0) {
          addonsPayload.add({
            'addon_id': addon.id,
            'name': addon.name,
            'price': addon.price,
            'quantity': qty,
          });
        }
      }

      if (customerId == null || customerId.isEmpty) {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
        _showToastMessage('Please login to add items to cart', isError: true);
        _showLoginDialog();
        return;
      }

      if (storeId == null || storeId.isEmpty) {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
        _showToastMessage('Store information not available.', isError: true);
        return;
      }

      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'menu_id': _menuItem!.id,
        'quantity': addedQty,
        'store_id': storeId,
        'addons': addonsPayload,
        'unit_price': _unitPrice,
        'total_price': _totalPrice,
      };

      final response = await http.post(
        Uri.parse('http://142.54.168.26:5050/api/cart/manage'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String message = responseData['message'] ??
            '${addedQty == 1 ? '' : '$addedQty × '}${_menuItem!.name} added to cart';

        _showToastMessage(message);

        // Instantly update global cart count badge
        CartManager.cartCount.value += addedQty;

        setState(() {
          _quantity = 1;
          _selectedAddons.clear();
        });

        // Sync with server in background
        CartManager.updateCartCount();
      } else {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          responseData = {};
        }

        String errorMessage = responseData['message'] ??
            responseData['error'] ??
            'Failed to add to cart';

        if (errorMessage.contains('duplicate key error') ||
            errorMessage.contains('E11000')) {
          _showCartConflictDialog();
        } else if (errorMessage.contains('customer_id') ||
            errorMessage.contains('token')) {
          _showLoginDialog();
        } else if (response.statusCode == 401) {
          _showLoginDialog();
        }

        _showToastMessage(errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog on error
      _showToastMessage(
        'Could not connect to server. Please check your connection.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  void _showCartConflictDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Item Already in Cart',
              style: TextStyle(color: textBlack)),
          content: const Text(
            'This item is already in your cart. Would you like to view your cart or continue shopping?',
            style: TextStyle(color: textGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Shopping',
                  style: TextStyle(color: textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openCart();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
              ),
              child: const Text('View Cart'),
            ),
          ],
        );
      },
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required',
              style: TextStyle(color: textBlack)),
          content: const Text(
            'Please login to add items to your cart.',
            style: TextStyle(color: textGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
              ),
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  void _showToastMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A1A1A),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
    _fetchCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: appBarColor,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: CartManager.cartCount,
            builder: (context, count, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, size: 24),
                        onPressed: _openCart,
                      ),
                      if (count > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        title: Text(
          _menuItem?.name ?? 'Item Details',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          // Main Content
          if (_error != null)
            _buildError()
          else if (_isLoading)
            const SizedBox.shrink()
          else if (_menuItem == null)
            _buildNotFound()
          else
            _buildContent(),

          // Loader Overlay
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 44,
                      width: 44,
                      child: CircularProgressIndicator(
                        color: accentOrange,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 48, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _initializeData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return const Center(
      child: Text(
        'Menu item not found',
        style: TextStyle(color: textBlack),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Image Section
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _menuItem!.imageUrl != null &&
                              _menuItem!.imageUrl!.isNotEmpty
                          ? Image.network(
                              _menuItem!.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                  ),
                  if (_menuItem!.hasOffer)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          _menuItem!.discountPercentage > 0
                              ? '${_menuItem!.discountPercentage}% OFF'
                              : (_menuItem!.discountName ?? 'OFFER'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Menu Name
              Text(
                _menuItem!.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: textBlack,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // Description Section
              if (_menuItem!.description.trim().isNotEmpty) ...[
                _sectionLabel('Description'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _menuItem!.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Addons Section with Counters
              if (_menuItem!.addons.isNotEmpty) ...[
                _sectionLabel('Add-ons'),
                const SizedBox(height: 8),
                _buildAddonsCard(),
                const SizedBox(height: 20),
              ],

              // Quantity and Total Price (only total price shown)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if ((_menuItem?.originalPrice ?? 0) > (_menuItem?.price ?? 0)) ...[
                              Text(
                                '\$${_originalTotalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '\$${_totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: textBlack,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _stepperButton(
                          icon: Icons.remove_rounded,
                          onTap: _decrementQuantity,
                          isActive: _quantity > 1,
                        ),
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textBlack,
                              ),
                            ),
                          ),
                        ),
                        _stepperButton(
                          icon: Icons.add_rounded,
                          onTap: _incrementQuantity,
                          isActive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Add to Cart Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isAddingToCart || !_menuItem!.isAvailable
                      ? null
                      : _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accentOrange.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: accentOrange.withOpacity(0.4),
                  ),
                  child: _isAddingToCart
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              !_menuItem!.isAvailable
                                  ? Icons.remove_shopping_cart_outlined
                                  : Icons.shopping_bag_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              !_menuItem!.isAvailable
                                  ? 'Unavailable'
                                  : 'Add to Cart',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ADDONS CARD WITH COUNTERS ====================
  Widget _buildAddonsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _menuItem!.addons.map((addon) {
          final int qty = _selectedAddons[addon.id] ?? 0;
          final bool isLast = addon == _menuItem!.addons.last;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 4),
            child: Row(
              children: [
                // Addon Name and Price on Left
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addon.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textBlack,
                        ),
                      ),
                      if (addon.price > 0)
                        Text(
                          '+\$${addon.price.toStringAsFixed(2)} each',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                // Counter on Right
                Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniStepperButton(
                        icon: Icons.remove_rounded,
                        onTap: () => _decrementAddon(addon.id),
                        isActive: qty > 0,
                      ),
                      SizedBox(
                        width: 28,
                        child: Center(
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textBlack,
                            ),
                          ),
                        ),
                      ),
                      _miniStepperButton(
                        icon: Icons.add_rounded,
                        onTap: () => _incrementAddon(addon.id),
                        isActive: qty < _defaultMaxAddonQty,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _miniStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isActive ? accentOrange : Colors.grey[200],
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 15,
          color: isActive ? Colors.white : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textBlack,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? accentOrange : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: Center(
        child: Icon(Icons.fastfood_rounded, size: 72, color: Colors.grey[400]),
      ),
    );
  }

  void _incrementQuantity() => setState(() => _quantity++);

  void _decrementQuantity() {
    if (_quantity > 1) setState(() => _quantity--);
  }
}