import 'package:flutter/material.dart';
import 'package:food/screens/combodeatils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:food/provider/auth_provider.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Combo {
  final String id;
  final dynamic store;
  final dynamic category;
  final String name;
  final String description;
  final String imageUrl;
  final List<dynamic> menuItems;
  final double originalPrice;
  final double comboPrice;
  final int discountPercentage;
  final bool isFeatured;
  final bool isAvailable;
  final int totalItems;

  Combo({
    required this.id,
    required this.store,
    required this.category,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.menuItems,
    required this.originalPrice,
    required this.comboPrice,
    required this.discountPercentage,
    required this.isFeatured,
    required this.isAvailable,
    required this.totalItems,
  });

  factory Combo.fromJson(Map<String, dynamic> json) {
    double originalPrice = (json['original_price'] ?? 0).toDouble();
    double comboPrice = (json['combo_price'] ?? 0).toDouble();
    
    return Combo(
      id: json['_id'] ?? '',
      store: json['store'] ?? '',
      category: json['category'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      menuItems: json['menuItems'] ?? [],
      originalPrice: originalPrice,
      comboPrice: comboPrice,
      discountPercentage: (json['discount_percentage'] ?? 0).toInt(),
      isFeatured: json['is_featured'] ?? false,
      isAvailable: json['is_available'] ?? true,
      totalItems: (json['total_items'] ?? 0).toInt(),
    );
  }

  List<MenuItem> getParsedMenuItems() {
    List<MenuItem> items = [];
    for (var item in menuItems) {
      int quantity = 1;
      Map<String, dynamic> itemMap = {};
      
      if (item is Map) {
        itemMap = Map<String, dynamic>.from(item);
        
        if (itemMap['quantity'] is int) {
          quantity = itemMap['quantity'];
        } else if (itemMap['quantity'] is double) {
          quantity = (itemMap['quantity'] as double).toInt();
        } else if (itemMap['quantity'] is num) {
          quantity = (itemMap['quantity'] as num).toInt();
        } else if (itemMap['quantity'] is String) {
          quantity = int.tryParse(itemMap['quantity'] as String) ?? 1;
        }
        
        if (itemMap.containsKey('menuItem') && itemMap['menuItem'] is Map) {
          final nestedItem = Map<String, dynamic>.from(itemMap['menuItem']);
          items.add(MenuItem(
            id: nestedItem['_id']?.toString() ?? '',
            name: nestedItem['name']?.toString() ?? '',
            description: nestedItem['description']?.toString() ?? '',
            price: (nestedItem['price'] ?? 0).toDouble(),
            imageUrl: nestedItem['image_url']?.toString() ?? '',
            quantity: quantity,
          ));
        } else {
          items.add(MenuItem(
            id: itemMap['_id']?.toString() ?? '',
            name: itemMap['name']?.toString() ?? '',
            description: itemMap['description']?.toString() ?? '',
            price: (itemMap['price'] ?? 0).toDouble(),
            imageUrl: itemMap['image_url']?.toString() ?? '',
            quantity: quantity,
          ));
        }
      }
    }
    return items;
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final int quantity;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.quantity,
  });
}

class ComboScreen extends StatefulWidget {
  final String storeId;
  
  const ComboScreen({
    super.key,
    required this.storeId,
  });

  @override
  State<ComboScreen> createState() => _ComboScreenState();
}

class _ComboScreenState extends State<ComboScreen> {
  List<Combo> _combos = [];
  bool _isLoading = true;
  String? _error;
  int _currentNavIndex = 1;
  bool _isTiffinStore = false;

  static const Color _brand = Color(0xFF132C48);
  static const Color _orange = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _loadStoreType();
    _fetchCombos();
  }

  Future<void> _loadStoreType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTiffinStore = prefs.getBool('is_tiffin_store') ?? false;
    });
  }

  Future<void> _fetchCombos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = Uri.parse('http://142.54.168.26:5050/api/combo/getcombobystore/${widget.storeId}');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (authProvider.token != null)
          'Authorization': 'Bearer ${authProvider.token}',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        List combosJson = [];
        
        if (decoded is List) {
          combosJson = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] != null && decoded['data'] is List) {
            combosJson = decoded['data'];
          }
        }
        
        final allCombos = combosJson.map((e) => Combo.fromJson(e)).toList();
        final availableCombos = allCombos.where((combo) => combo.isAvailable).toList();

        setState(() {
          _combos = availableCombos;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load combos';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server';
        _isLoading = false;
      });
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

  Future<void> _addToCartApi(Combo combo, int quantity) async {
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
        _showToast('Store information not found', isError: true);
        return;
      }

      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'store_id': storeId,
        'combo_id': combo.id,
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

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showToast('$quantity × ${combo.name} added to cart successfully!');
      } else {
        final message = decoded['message'] ?? decoded['error'] ?? 'Failed to add to cart';
        _showToast(message, isError: true);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showToast('Could not connect to server', isError: true);
    }
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

  void _navigateToComboDetails(Combo combo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComboDetailsPage(
          combo: combo,
          brandColor: _orange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Express Combos',
          style: TextStyle(
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
            onPressed: () => _showSearchDialog(),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        storeId: widget.storeId,
      ),
    );
  }

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: ComboSearchDelegate(
        _combos, 
        _brand,
        _orange,
        _navigateToComboDetails, 
        _addToCartApi,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _orange),
            SizedBox(height: 16),
            Text('Loading delicious combos...'),
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
              onPressed: _fetchCombos,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_combos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No combos available',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _orange,
      onRefresh: _fetchCombos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _combos.length,
        itemBuilder: (context, index) => _ComboCard(
          combo: _combos[index],
          brandColor: _brand,
          orangeColor: _orange,
          onAddToCart: _addToCartApi,
          onTap: () => _navigateToComboDetails(_combos[index]),
        ),
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  final Combo combo;
  final Color brandColor;
  final Color orangeColor;
  final Function(Combo, int) onAddToCart;
  final VoidCallback? onTap;

  const _ComboCard({
    required this.combo,
    required this.brandColor,
    required this.orangeColor,
    required this.onAddToCart,
    this.onTap,
  });

  String _getCategoryName() {
    if (combo.category is Map) {
      return (combo.category as Map)['name'] ?? 'Combo';
    }
    return 'Combo';
  }

  void _showAddToCartDialog(BuildContext context) {
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
            return Container(
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
                  if (combo.imageUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          combo.imageUrl,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                color: brandColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.lunch_dining,
                                  size: 60, color: brandColor.withOpacity(0.5)),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    combo.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (combo.description.isNotEmpty)
                    Text(
                      combo.description,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[600], height: 1.4),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${combo.comboPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: orangeColor,
                            ),
                          ),
                          Text(
                            '${combo.totalItems} items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: orangeColor.withOpacity(0.2)),
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
                                  color: orangeColor.withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(Icons.remove, 
                                    color: orangeColor, size: 20),
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
                                  color: orangeColor.withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(Icons.add, 
                                    color: orangeColor, size: 20),
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
                        await onAddToCart(combo, qty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orangeColor,
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
            );
          },
        );
      },
    );
  }

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
            // Image Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: combo.imageUrl.isNotEmpty
                        ? Image.network(
                            combo.imageUrl,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 180,
                                color: brandColor.withOpacity(0.1),
                                child: Icon(Icons.lunch_dining,
                                    size: 60, color: brandColor.withOpacity(0.5)),
                              );
                            },
                          )
                        : Container(
                            width: double.infinity,
                            height: 180,
                            color: brandColor.withOpacity(0.1),
                            child: Icon(Icons.lunch_dining,
                                size: 60, color: brandColor.withOpacity(0.5)),
                          ),
                  ),
                ),
                // Discount Badge
                if (combo.discountPercentage > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF8F00)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${combo.discountPercentage}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Featured Badge
                if (combo.isFeatured)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Featured',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Content Section
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Combo Name and Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Combo Info
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              combo.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F1F1F),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (combo.description.isNotEmpty)
                              Text(
                                combo.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.restaurant_menu, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  '${combo.totalItems} items',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _getCategoryName(),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Right side - Price
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${combo.comboPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: orangeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${combo.originalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Add to Cart Button - Orange
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showAddToCartDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orangeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class ComboSearchDelegate extends SearchDelegate<String> {
  final List<Combo> combos;
  final Color brandColor;
  final Color orangeColor;
  final Function(Combo) onComboTap;
  final Function(Combo, int) onAddToCart;

  ComboSearchDelegate(
    this.combos, 
    this.brandColor,
    this.orangeColor,
    this.onComboTap,
    this.onAddToCart,
  );

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
    final results = combos
        .where((combo) => combo.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _ComboCard(
          combo: results[index],
          brandColor: brandColor,
          orangeColor: orangeColor,
          onAddToCart: onAddToCart,
          onTap: () {
            close(context, '');
            onComboTap(results[index]);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = combos
        .where((combo) => combo.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return _ComboCard(
          combo: suggestions[index],
          brandColor: brandColor,
          orangeColor: orangeColor,
          onAddToCart: onAddToCart,
          onTap: () {
            close(context, '');
            onComboTap(suggestions[index]);
          },
        );
      },
    );
  }
}