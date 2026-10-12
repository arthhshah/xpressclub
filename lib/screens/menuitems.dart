import 'package:flutter/material.dart';
import 'package:food/screens/menuitemdetailspage.dart';
import 'package:food/screens/cartscreen.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:food/provider/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final bool isActive;
  final String storeId;
  final String categoryId;
  final String storeName;
  final String categoryName;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.isActive,
    required this.storeId,
    required this.categoryId,
    required this.storeName,
    required this.categoryName,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
      isActive: json['is_active'] ?? true,
      storeId: json['store']?['_id'] ?? json['store'] ?? '',
      categoryId: json['category']?['_id'] ?? json['category'] ?? '',
      storeName: json['store']?['name'] ?? 'Store',
      categoryName: json['category']?['name'] ?? 'Category',
    );
  }
}

class MenuItemsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const MenuItemsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<MenuItemsScreen> createState() => _MenuItemsScreenState();
}

class _MenuItemsScreenState extends State<MenuItemsScreen> {
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;
  int _currentNavIndex = 2; // Categories is index 2
  bool _isTiffinStore = false;
  
  // User data from SharedPreferences
  String? _userId;
  String? _token;
  String? _storeId;

  static const Color _brand = Color(0xFF132C48);

  @override
  void initState() {
    super.initState();
    _loadStoreType();
    _loadUserData();
    _fetchMenuItems();
  }

  Future<void> _loadStoreType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTiffinStore = prefs.getBool('is_tiffin_store') ?? false;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('Loading user data from SharedPreferences...');
      
      setState(() {
        _userId = prefs.getString('userId');
        _token = prefs.getString('token');
        _storeId = prefs.getString('store_id');
      });
      
      print('User ID: $_userId');
      print('Store ID: $_storeId');
      print('Token exists: ${_token != null}');
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchMenuItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String apiUrl =
          'http://142.54.168.26:5050/api/menu-items/category/${widget.categoryId}';

      print('Fetching menu items from: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (authProvider.token != null)
            'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);

        List<MenuItem> menuItemsList = [];

        if (decoded['data'] != null && decoded['data'] is List) {
          menuItemsList = (decoded['data'] as List)
              .map((e) => MenuItem.fromJson(e))
              .where((item) => item.isActive && item.isAvailable)
              .toList();
        } else if (decoded is List) {
          menuItemsList = (decoded as List)
              .map((e) => MenuItem.fromJson(e))
              .where((item) => item.isActive && item.isAvailable)
              .toList();
        }

        setState(() {
          _menuItems = menuItemsList;
          _isLoading = false;
        });
        
        print('Loaded ${menuItemsList.length} menu items');
      } else {
        setState(() {
          _error = 'Failed to load menu items (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching menu items: $e');
      setState(() {
        _error = 'Could not connect to server. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  void _navigateToDetails(MenuItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuItemDetailsScreen(menuItemId: item.id),
      ),
    );
  }

  Future<void> _addToCartApi(MenuItem item, int quantity) async {
    try {
      // Show loading indicator
      _showLoadingDialog();
      
      // Reload user data to ensure we have latest values
      final prefs = await SharedPreferences.getInstance();
      final String? customerId = prefs.getString('userId');
      final String? token = prefs.getString('token');
      final String? storeId = prefs.getString('store_id');

      print('=== Add to Cart API Call ===');
      print('Customer ID: $customerId');
      print('Store ID: $storeId');
      print('Menu ID: ${item.id}');
      print('Quantity: $quantity');
      print('Token exists: ${token != null}');

      // Validate required fields
      if (customerId == null || customerId.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        _showToast('Please login to add items to cart', isError: true);
        return;
      }

      if (storeId == null || storeId.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        _showToast('Store information not found. Please try again.', isError: true);
        return;
      }

      if (item.id == null || item.id.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        _showToast('Invalid menu item', isError: true);
        return;
      }

      // Prepare request body for the API
      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'store_id': storeId,
        'menu_id': item.id,
        'quantity': quantity,
      };

      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('http://142.54.168.26:5050/api/cart/manage'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      // Close loading dialog
      Navigator.pop(context);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showToast('$quantity × ${item.name} added to cart successfully!');
        
        // Optional: Refresh cart count if you have a cart provider
        // You can add a callback to update cart badge here
      } else {
        final message = decoded['message'] ?? decoded['error'] ?? 'Failed to add to cart';
        _showToast(message, isError: true);
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print('Error adding to cart: $e');
      _showToast('Could not connect to server. Please check your connection.', isError: true);
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Adding to cart...'),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToast(String message, {bool isError = false}) {
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
        backgroundColor: isError ? Colors.redAccent : _brand,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showAddToCartDialog(MenuItem item) {
    int tempQuantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            item.imageUrl!,
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  color: _brand.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.fastfood,
                                    size: 60, color: _brand.withOpacity(0.5)),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600], height: 1.4),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _brand,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _brand.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (tempQuantity > 1) {
                                    setStateModal(() => tempQuantity--);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _brand.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(Icons.remove, 
                                      color: _brand, size: 20),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Text(
                                  '$tempQuantity',
                                  style: const TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setStateModal(() => tempQuantity++),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _brand.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(Icons.add, 
                                      color: _brand, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final qty = tempQuantity;
                          Navigator.pop(context); // Close bottom sheet
                          await _addToCartApi(item, qty);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _brand,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        storeId: _menuItems.isNotEmpty ? _menuItems[0].storeId : null,
      ),
    );
  }

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: MenuItemSearchDelegate(
          _menuItems, _brand, _navigateToDetails, _showAddToCartDialog),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _brand),
            SizedBox(height: 16),
            Text('Loading menu items...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchMenuItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No menu items available in ${widget.categoryName}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _brand,
      onRefresh: _fetchMenuItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) => _MenuItemCard(
          menuItem: _menuItems[index],
          brandColor: _brand,
          onTap: () => _navigateToDetails(_menuItems[index]),
          onAddToCartTap: () => _showAddToCartDialog(_menuItems[index]),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final Color brandColor;
  final VoidCallback onTap;
  final VoidCallback onAddToCartTap;

  const _MenuItemCard({
    required this.menuItem,
    required this.brandColor,
    required this.onTap,
    required this.onAddToCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (removed 0% OFF badge)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: menuItem.imageUrl != null && menuItem.imageUrl!.isNotEmpty
                    ? Image.network(
                        menuItem.imageUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 180,
                            color: brandColor.withOpacity(0.1),
                            child: Icon(Icons.fastfood,
                                size: 60, color: brandColor.withOpacity(0.5)),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 180,
                        color: brandColor.withOpacity(0.1),
                        child: Icon(Icons.fastfood,
                            size: 60, color: brandColor.withOpacity(0.5)),
                      ),
              ),
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Combo badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Combo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: brandColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    menuItem.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1F1F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Description
                  if (menuItem.description.isNotEmpty)
                    Text(
                      menuItem.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  // Price and items info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${menuItem.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: brandColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '3 items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Add to Cart Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onAddToCartTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: brandColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_shopping_cart,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Add to Cart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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

class MenuItemSearchDelegate extends SearchDelegate<String> {
  final List<MenuItem> menuItems;
  final Color brandColor;
  final Function(MenuItem) onItemTap;
  final Function(MenuItem) onAddToCartTap;

  MenuItemSearchDelegate(
      this.menuItems, this.brandColor, this.onItemTap, this.onAddToCartTap);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = menuItems
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _MenuItemCard(
          menuItem: results[index],
          brandColor: brandColor,
          onTap: () {
            close(context, '');
            onItemTap(results[index]);
          },
          onAddToCartTap: () {
            close(context, '');
            onAddToCartTap(results[index]);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = menuItems
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return _MenuItemCard(
          menuItem: suggestions[index],
          brandColor: brandColor,
          onTap: () {
            close(context, '');
            onItemTap(suggestions[index]);
          },
          onAddToCartTap: () {
            close(context, '');
            onAddToCartTap(suggestions[index]);
          },
        );
      },
    );
  }
}