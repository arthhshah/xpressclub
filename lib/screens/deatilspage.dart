import 'package:flutter/material.dart';
import 'package:food/screens/homescreen.dart';

class MenuDetailsScreen extends StatefulWidget {
  final MenuItem menuItem;
  final int initialQuantity;
  final Function(MenuItem) onAddToCart;
  final Function(String) onRemoveFromCart;

  const MenuDetailsScreen({
    super.key,
    required this.menuItem,
    this.initialQuantity = 0,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  State<MenuDetailsScreen> createState() => _MenuDetailsScreenState();
}

class _MenuDetailsScreenState extends State<MenuDetailsScreen> {
  late int _quantity;
  bool _isLoading = false;
  String? _selectedOption;
  String? _selectedSize;
  
  static const Color _brand = Color(0xFF132C48);
  
  // Price conversion
  double get priceInUSD => widget.menuItem.price / 84;
  double get totalInUSD => (widget.menuItem.price * _quantity) / 84;
  double get totalInRupees => widget.menuItem.price * _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  void _updateQuantity(int delta) {
    setState(() {
      _quantity += delta;
      if (_quantity < 0) _quantity = 0;
    });
  }

  void _handleAddToCart() {
    if (_quantity > 0) {
      for (int i = 0; i < _quantity; i++) {
        widget.onAddToCart(widget.menuItem);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_quantity} × ${widget.menuItem.name} added to cart',
                ),
              ),
            ],
          ),
          backgroundColor: _brand,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: CustomScrollView(
      slivers: [
        // Custom App Bar with Image
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          floating: false,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _brand),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                widget.menuItem.imageUrl.isNotEmpty
                    ? Image.network(
                        widget.menuItem.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                // Availability Badge
                if (!widget.menuItem.isAvailable)
                  Positioned(
                    top: 80,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Sold Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Content Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.menuItem.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F1F1F),
                          height: 1.2,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${priceInUSD.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _brand,
                          ),
                        ),
                        Text(
                          '₹${widget.menuItem.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Rating and Info Row
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.star_rounded,
                      label: '4.5',
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: Icons.timer_rounded,
                      label: '20-30 min',
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${(widget.menuItem.price * 0.3).toInt()} cal',
                      color: Colors.orange.shade600,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Description Section
                if (widget.menuItem.description.trim().isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.menuItem.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Customization Section (Optional)
                const Text(
                  'Customize',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Size Selection
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Size',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSizeOption('Small', '+0'),
                          const SizedBox(width: 12),
                          _buildSizeOption('Medium', '+2'),
                          const SizedBox(width: 12),
                          _buildSizeOption('Large', '+4'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Add-ons Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add-ons',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAddonOption('Extra Cheese', '+\$0.99'),
                      const SizedBox(height: 8),
                      _buildAddonOption('Extra Sauce', '+\$0.50'),
                      const SizedBox(height: 8),
                      _buildAddonOption('Double Meat', '+\$2.99'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    ),
    
    // Bottom Bar
    bottomNavigationBar: _buildBottomBar(),
  );
}

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brand.withOpacity(0.2), _brand.withOpacity(0.05)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: 80,
          color: _brand.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeOption(String size, String price) {
    final isSelected = _selectedSize == size;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSize = size;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _brand.withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _brand : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                size,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _brand : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? _brand : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddonOption(String name, String price) {
    final isSelected = _selectedOption == name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = name;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _brand.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _brand : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: isSelected ? _brand : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? _brand : const Color(0xFF1F1F1F),
                ),
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? _brand : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Quantity Selector
            Container(
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _updateQuantity(-1),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _quantity > 0 ? _brand : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 20,
                        color: _quantity > 0 ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.menuItem.isAvailable ? () => _updateQuantity(1) : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.menuItem.isAvailable ? _brand : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: widget.menuItem.isAvailable ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Add to Cart Button
            Expanded(
              child: ElevatedButton(
                onPressed: _quantity > 0 && widget.menuItem.isAvailable
                    ? _handleAddToCart
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add to Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (_quantity > 0)
                          Text(
                            '\$${totalInUSD.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}