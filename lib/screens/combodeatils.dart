import 'package:flutter/material.dart';
import 'package:food/screens/comboscreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ComboDetailsPage extends StatefulWidget {
  final Combo combo;
  final Color brandColor;

  const ComboDetailsPage({
    super.key,
    required this.combo,
    required this.brandColor,
  });

  @override
  State<ComboDetailsPage> createState() => _ComboDetailsPageState();
}

class _ComboDetailsPageState extends State<ComboDetailsPage> {
  int _quantity = 1;
  List<MenuItem> _menuItems = [];
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _menuItems = widget.combo.getParsedMenuItems();
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
        backgroundColor: isError ? Colors.redAccent : widget.brandColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _addToCartApi(Combo combo, int quantity) async {
    if (_isAddingToCart) return;
    
    setState(() {
      _isAddingToCart = true;
    });
    
    try {
      _showLoadingDialog();
      
      final prefs = await SharedPreferences.getInstance();
      final String? customerId = prefs.getString('userId');
      final String? token = prefs.getString('token');
      final String? storeId = prefs.getString('store_id');

      print('=== Add Combo to Cart API Call ===');
      print('Customer ID: $customerId');
      print('Store ID: $storeId');
      print('Combo ID: ${combo.id}');
      print('Quantity: $quantity');

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

      // Prepare request body with combo_id
      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'store_id': storeId,
        'combo_id': combo.id,
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

      Navigator.pop(context);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Error adding combo to cart: $e');
      _showToast('Could not connect to server', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar with Back Button - iOS Style
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: widget.brandColor,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(12), // Square with rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF007AFF), // iOS Blue color
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Main Image
                  if (widget.combo.imageUrl.isNotEmpty)
                    Image.network(
                      widget.combo.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: widget.brandColor.withOpacity(0.1),
                          child: Icon(
                            Icons.lunch_dining,
                            size: 80,
                            color: widget.brandColor.withOpacity(0.5),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: widget.brandColor.withOpacity(0.1),
                      child: Icon(
                        Icons.lunch_dining,
                        size: 80,
                        color: widget.brandColor.withOpacity(0.5),
                      ),
                    ),
                  
                  // Discount Badge
                  Positioned(
                    top: 60,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Featured Badge
                  if (widget.combo.isFeatured)
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
          ),
          
          // Combo Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Combo Name
                  Text(
                    widget.combo.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  if (widget.combo.description.isNotEmpty)
                    Text(
                      widget.combo.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Price Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.brandColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.brandColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${widget.combo.comboPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: widget.brandColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '\$${widget.combo.originalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You save \$${(widget.combo.originalPrice - widget.combo.comboPrice).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Quantity Selector
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: widget.brandColor.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_quantity > 1) {
                                    setState(() => _quantity--);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.brandColor.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                  child: Icon(Icons.remove, 
                                      color: widget.brandColor, size: 20),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _quantity++),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.brandColor.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Icon(Icons.add, 
                                      color: widget.brandColor, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Menu Items Section
                  const Text(
                    'What\'s in this Combo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_menuItems.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No items in this combo'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        return _MenuItemCard(
                          menuItem: _menuItems[index],
                          brandColor: widget.brandColor,
                        );
                      },
                    ),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isAddingToCart
                ? null
                : () {
                    _addToCartApi(widget.combo, _quantity);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.brandColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              disabledBackgroundColor: widget.brandColor.withOpacity(0.5),
            ),
            child: _isAddingToCart
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Add to Cart',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final Color brandColor;

  const _MenuItemCard({
    required this.menuItem,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Item Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
              child: menuItem.imageUrl.isNotEmpty
                  ? Image.network(
                      menuItem.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: brandColor.withOpacity(0.1),
                          child: Icon(Icons.fastfood,
                              size: 30, color: brandColor.withOpacity(0.5)),
                        );
                      },
                    )
                  : Container(
                      color: brandColor.withOpacity(0.1),
                      child: Icon(Icons.fastfood,
                          size: 30, color: brandColor.withOpacity(0.5)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        menuItem.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F1F1F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: brandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${menuItem.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: brandColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (menuItem.description.isNotEmpty)
                  Text(
                    menuItem.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  '\$${menuItem.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: brandColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}