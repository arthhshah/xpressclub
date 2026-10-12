import 'package:flutter/material.dart';
import 'package:food/screens/menuitemdetailspage.dart';
import 'package:food/screens/cartscreen.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:food/provider/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===================== Category Model =====================
class Category {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final int? displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'],
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// ===================== MenuItem Model =====================
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

// ===================== Main Screen =====================
class CategoriesScreen extends StatefulWidget {
  final String? storeId;

  const CategoriesScreen({super.key, this.storeId});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  List<Category> _categories = [];
  Map<String, List<MenuItem>> _categoryMenuItems = {};
  Map<String, bool> _loadingCategories = {};
  Map<String, String?> _errorCategories = {};
  bool _isLoadingCategories = true;
  String? _error;
  late TabController _tabController;
  final int _currentNavIndex = 2;
  bool _isTiffinStore = false;
  
  // User data
  String? _userId;
  String? _token;
  String? _storeId;

  static const Color _brand = Color(0xFF132C48);
  static const Color _orange = Color(0xFFFF6B00);
  static const Color _bg = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadStoreType();
    _loadUserData();
    _fetchCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      setState(() {
        _userId = prefs.getString('userId');
        _token = prefs.getString('token');
        _storeId = prefs.getString('store_id');
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      String apiUrl = 'http://142.54.168.26:5050/api/categories?limit=1000';
      if (widget.storeId != null && widget.storeId!.isNotEmpty) {
        apiUrl =
            'http://142.54.168.26:5050/api/categories/store/${widget.storeId}';
      }

      final response = await http.get(Uri.parse(apiUrl), headers: {
        'Content-Type': 'application/json',
        if (authProvider.token != null)
          'Authorization': 'Bearer ${authProvider.token}',
      });

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<Category> categoriesList = [];

        if (decoded is List) {
          categoriesList = decoded.map((e) => Category.fromJson(e)).toList();
        } else if (decoded is Map<String, dynamic> &&
            decoded['data'] is List) {
          categoriesList = (decoded['data'] as List)
              .map((e) => Category.fromJson(e))
              .toList();
        }

        categoriesList.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        setState(() {
          _categories = categoriesList;
          _isLoadingCategories = false;
          
          // Initialize tab controller
          _tabController = TabController(
            length: _categories.length,
            vsync: this,
          );
          
          // Initialize loading states for each category
          for (var category in _categories) {
            _loadingCategories[category.id] = true;
            _categoryMenuItems[category.id] = [];
          }
        });

        // Fetch menu items for each category
        for (var category in _categories) {
          await _fetchMenuItemsForCategory(category.id);
        }
      } else {
        setState(() {
          _error = 'Failed to load categories (${response.statusCode})';
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server.';
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchMenuItemsForCategory(String categoryId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String apiUrl =
          'http://142.54.168.26:5050/api/menu-items/category/$categoryId';

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
          _categoryMenuItems[categoryId] = menuItemsList;
          _loadingCategories[categoryId] = false;
          _errorCategories[categoryId] = null;
        });
      } else {
        setState(() {
          _loadingCategories[categoryId] = false;
          _errorCategories[categoryId] = 
              'Failed to load items (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _loadingCategories[categoryId] = false;
        _errorCategories[categoryId] = 'Could not connect to server.';
      });
    }
  }

  Future<void> _refreshCategory(String categoryId) async {
    setState(() {
      _loadingCategories[categoryId] = true;
      _errorCategories[categoryId] = null;
    });
    await _fetchMenuItemsForCategory(categoryId);
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
      _showLoadingDialog();
      
      final prefs = await SharedPreferences.getInstance();
      final String? customerId = prefs.getString('userId');
      final String? token = prefs.getString('token');
      final String? storeId = prefs.getString('store_id');

      if (customerId == null || customerId.isEmpty) {
        Navigator.pop(context);
        _showToast('Please login to add items to cart', isError: true);
        return;
      }

      if (storeId == null || storeId.isEmpty) {
        Navigator.pop(context);
        _showToast('Store information not found.', isError: true);
        return;
      }

      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'store_id': storeId,
        'menu_id': item.id,
        'quantity': quantity,
      };

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

      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showToast('$quantity × ${item.name} added to cart successfully!');
      } else {
        final decoded = jsonDecode(response.body);
        final message = decoded['message'] ?? decoded['error'] ?? 'Failed to add to cart';
        _showToast(message, isError: true);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showToast('Could not connect to server.', isError: true);
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
                CircularProgressIndicator(color: _orange),
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
        backgroundColor: isError ? Colors.redAccent : _orange,
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
                            color: _orange,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _orange.withOpacity(0.2)),
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
                                    color: _orange.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                  child: Icon(Icons.remove, 
                                      color: _orange, size: 20),
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
                                    color: _orange.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Icon(Icons.add, 
                                      color: _orange, size: 20),
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
                          Navigator.pop(context);
                          await _addToCartApi(item, qty);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white),
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
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: _brand,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: _isLoadingCategories
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                tabs: _categories.map((category) {
                  return Tab(text: category.name);
                }).toList(),
              ),
      ),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        storeId: widget.storeId,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingCategories) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _orange),
            SizedBox(height: 16),
            Text('Loading categories...'),
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
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchCategories,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text('No categories available'),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _categories.map((category) {
        return _CategoryTabContent(
          categoryId: category.id,
          categoryName: category.name,
          menuItems: _categoryMenuItems[category.id] ?? [],
          isLoading: _loadingCategories[category.id] ?? true,
          error: _errorCategories[category.id],
          brandColor: _brand,
          orangeColor: _orange,
          onRefresh: () => _refreshCategory(category.id),
          onItemTap: _navigateToDetails,
          onAddToCartTap: _showAddToCartDialog,
        );
      }).toList(),
    );
  }
}

// ===================== Category Tab Content =====================
class _CategoryTabContent extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  final List<MenuItem> menuItems;
  final bool isLoading;
  final String? error;
  final Color brandColor;
  final Color orangeColor;
  final Future<void> Function() onRefresh;
  final Function(MenuItem) onItemTap;
  final Function(MenuItem) onAddToCartTap;

  const _CategoryTabContent({
    required this.categoryId,
    required this.categoryName,
    required this.menuItems,
    required this.isLoading,
    required this.error,
    required this.brandColor,
    required this.orangeColor,
    required this.onRefresh,
    required this.onItemTap,
    required this.onAddToCartTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading menu items...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: orangeColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No menu items available in $categoryName',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: orangeColor,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuItems.length,
        itemBuilder: (context, index) => _MenuItemCard(
          menuItem: menuItems[index],
          brandColor: brandColor,
          orangeColor: orangeColor,
          onTap: () => onItemTap(menuItems[index]),
          onAddToCartTap: () => onAddToCartTap(menuItems[index]),
        ),
      ),
    );
  }
}

// ===================== Menu Item Card =====================
class _MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final Color brandColor;
  final Color orangeColor;
  final VoidCallback onTap;
  final VoidCallback onAddToCartTap;

  const _MenuItemCard({
    required this.menuItem,
    required this.brandColor,
    required this.orangeColor,
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge with Orange Color
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: orangeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      menuItem.categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: orangeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  if (menuItem.description.isNotEmpty)
                    Text(
                      menuItem.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price with Orange Color
                      Text(
                        '\$${menuItem.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: orangeColor,
                        ),
                      ),
                      // Add to Cart Button - ORANGE
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onAddToCartTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: orangeColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: orangeColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_rounded,
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

// ===================== Search Delegate =====================
class MenuItemSearchDelegate extends SearchDelegate<String> {
  final List<MenuItem> menuItems;
  final Color brandColor;
  final Color orangeColor;
  final Function(MenuItem) onItemTap;
  final Function(MenuItem) onAddToCartTap;

  MenuItemSearchDelegate(
      this.menuItems, 
      this.brandColor,
      this.orangeColor,
      this.onItemTap, 
      this.onAddToCartTap);

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
          orangeColor: orangeColor,
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
          orangeColor: orangeColor,
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