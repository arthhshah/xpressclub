import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:food/screens/cartscreen.dart';
import 'package:food/screens/loyaltypointsdetails.dart';
import 'package:food/screens/menuitemdetailspage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:food/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== MODEL CLASSES ====================

class Addon {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool isRequired;
  final bool isActive;

  Addon({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isRequired,
    required this.isActive,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
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
    return Addon(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      price: price,
      category: json['category'] ?? 'topping',
      isRequired: json['is_required'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final int discountPercentage;
  final String? discountName;
  final String imageUrl;
  final bool isAvailable;
  final String storeId;
  final String categoryId;
  final String categoryName;
  final List<Addon> addons;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice = 0.0,
    this.discountPercentage = 0,
    this.discountName,
    required this.imageUrl,
    required this.isAvailable,
    required this.storeId,
    required this.categoryId,
    required this.categoryName,
    this.addons = const [],
  });

  bool get hasOffer => discountPercentage > 0 || discountName != null || originalPrice > price;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    String storeId = '';
    if (json['store'] != null) {
      if (json['store'] is Map) {
        storeId = json['store']['_id'] ?? '';
      } else if (json['store'] is String) {
        storeId = json['store'];
      }
    }
    if (storeId.isEmpty) {
      storeId = json['storeId'] ?? json['store_id'] ?? '';
    }

    String categoryId = '';
    String categoryName = 'Uncategorized';
    if (json['category'] != null) {
      if (json['category'] is Map) {
        categoryId = json['category']['_id'] ?? '';
        categoryName = json['category']['name'] ?? 'Uncategorized';
      } else if (json['category'] is String) {
        categoryId = json['category'];
        categoryName = json['category_name'] ?? 'Uncategorized';
      }
    }
    if (categoryId.isEmpty) {
      categoryId = json['categoryId'] ?? json['category_id'] ?? '';
    }
    if (categoryName == 'Uncategorized') {
      categoryName = json['category_name'] ?? json['categoryName'] ?? 'Uncategorized';
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

    List<Addon> addons = [];
    if (json['addons'] != null && json['addons'] is List) {
      addons = (json['addons'] as List)
          .map((e) => Addon.fromJson(e))
          .where((a) => a.isActive)
          .toList();
    }
    if (json['data'] != null && json['data'] is Map) {
      final data = json['data'];
      if (data['addons'] != null && data['addons'] is List) {
        addons = (data['addons'] as List)
            .map((e) => Addon.fromJson(e))
            .where((a) => a.isActive)
            .toList();
      }
    }

    return MenuItem(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: price,
      originalPrice: originalPrice,
      discountPercentage: discountPercentage,
      discountName: discountName,
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      isAvailable: json['is_available'] ?? json['isAvailable'] ?? true,
      storeId: storeId,
      categoryId: categoryId,
      categoryName: categoryName,
      addons: addons,
    );
  }
}

class Combo {
  final String id;
  final String storeId;
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

  Combo({
    required this.id,
    required this.storeId,
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
  });

  factory Combo.fromJson(Map<String, dynamic> json) {
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
    }

    double comboPrice = 0.0;
    if (json['combo_price'] != null) {
      if (json['combo_price'] is int) {
        comboPrice = (json['combo_price'] as int).toDouble();
      } else if (json['combo_price'] is double) {
        comboPrice = json['combo_price'];
      } else if (json['combo_price'] is String) {
        comboPrice = double.tryParse(json['combo_price']) ?? 0.0;
      } else if (json['combo_price'] is num) {
        comboPrice = (json['combo_price'] as num).toDouble();
      }
    }

    return Combo(
      id: json['_id'] ?? '',
      storeId: json['store'] ?? '',
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
    );
  }
}

class Store {
  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String openingTime;
  final String closingTime;
  final bool isActive;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.openingTime,
    required this.closingTime,
    required this.isActive,
    this.distanceKm,
    this.latitude,
    this.longitude,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      openingTime: json['opening_time'] ?? '',
      closingTime: json['closing_time'] ?? '',
      isActive: json['is_active'] ?? true,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }
}

// Kept in case other files import it. Not used on the home screen anymore.
class TrendingItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final int orderCount;
  final String productType;
  final int totalQuantity;

  TrendingItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.orderCount,
    required this.productType,
    required this.totalQuantity,
  });

  factory TrendingItem.fromJson(Map<String, dynamic> json) {
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

    return TrendingItem(
      id: json['product_id'] ?? '',
      name: json['product_name'] ?? '',
      description: json['product_description'] ?? '',
      price: price,
      imageUrl: json['image'] ?? '',
      orderCount: json['total_orders'] ?? 0,
      productType: json['product_type'] ?? 'menu',
      totalQuantity: json['total_quantity'] ?? 0,
    );
  }
}

class CartItem {
  final String id;
  final String? menuItemId;
  final String? comboId;
  final MenuItem menuItem;
  int quantity;
  Map<String, int> selectedAddons;
  double addonsPrice;
  double totalPrice;

  CartItem({
    required this.id,
    this.menuItemId,
    this.comboId,
    required this.menuItem,
    this.quantity = 1,
    this.selectedAddons = const {},
    this.addonsPrice = 0.0,
    this.totalPrice = 0.0,
  });

  CartItem copyWith({
    String? id,
    String? menuItemId,
    String? comboId,
    MenuItem? menuItem,
    int? quantity,
    Map<String, int>? selectedAddons,
    double? addonsPrice,
    double? totalPrice,
  }) {
    return CartItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      comboId: comboId ?? this.comboId,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      addonsPrice: addonsPrice ?? this.addonsPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final String storeId;
  final String? description;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.storeId,
    this.description,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? json['image'] ?? json['category_image'] ?? '',
      storeId: json['store'] is Map
          ? json['store']['_id'] ?? ''
          : json['store'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }
}

// ==================== CUSTOM STATUS BAR ====================
class CustomStatusBar extends StatelessWidget {
  final Widget child;
  final Color statusBarColor;
  final Brightness statusBarIconBrightness;

  const CustomStatusBar({
    super.key,
    required this.child,
    this.statusBarColor = const Color(0xFF1A1A1A),
    this.statusBarIconBrightness = Brightness.light,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarIconBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: child,
    );
  }
}

// ==================== EMPTY STATE ====================
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionText;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.onAction,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== SEARCH BAR ====================
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
            ),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: Color(0xFF1A1A1A),
                    selectionColor: Color(0xFFE0E0E0),
                    selectionHandleColor: Color(0xFF1A1A1A),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  readOnly: readOnly,
                  cursorColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Search dishes, combos...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.close, color: Colors.grey[400], size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== MENU ITEM CARD ====================
class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool isCompact;

  const MenuItemCard({
    super.key,
    required this.menuItem,
    required this.quantity,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
    this.isCompact = false,
  });

  static const Color _accent = Color(0xFFFF6B00);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _detailGrey = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 390.0).clamp(0.9, 1.25);
    final double imageHeight = (isCompact ? 175 : 190) * scale;
    const double radius = 20;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: _ink.withOpacity(0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    topRight: Radius.circular(radius),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: imageHeight,
                    child: menuItem.imageUrl.isNotEmpty
                        ? Image.network(
                      menuItem.imageUrl,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFF6F6F6),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                            ),
                          ),
                        );
                      },
                    )
                        : _imagePlaceholder(),
                  ),
                ),
                if (!menuItem.isAvailable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(radius),
                          topRight: Radius.circular(radius),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Currently Unavailable',
                            style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Orange Discount Badge
                if (menuItem.hasOffer)
                  Positioned(
                    top: 12,
                    right: 12,
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
                        menuItem.discountPercentage > 0
                            ? '${menuItem.discountPercentage}% OFF'
                            : (menuItem.discountName ?? 'OFFER'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    menuItem.name,
                    style: TextStyle(
                      fontSize: isCompact ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (menuItem.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      menuItem.description,
                      style: TextStyle(
                          fontSize: 13,
                          color: _detailGrey,
                          height: 1.35
                      ),
                      maxLines: isCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  if (menuItem.isAvailable)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        quantity > 0 ? _buildStepper() : _buildAddButton(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (menuItem.originalPrice > menuItem.price) ...[
                              Text(
                                '\$${menuItem.originalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: isCompact ? 12 : 13,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              '\$${menuItem.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isCompact ? 15 : 17,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ],
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

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF6F6F6),
      child: Center(
        child: Icon(Icons.restaurant_menu_rounded, size: 40, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildAddButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: _accent.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4)
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 20
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: _accent.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperBtn(Icons.remove_rounded, onRemove),
          Container(
            constraints: const BoxConstraints(minWidth: 26),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white
              ),
            ),
          ),
          _stepperBtn(Icons.add_rounded, onAdd),
        ],
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 30,
          height: 34,
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// ==================== ADDON SELECTION MODAL ====================
class AddonSelectionModal extends StatefulWidget {
  final MenuItem menuItem;
  final Function(Map<String, int>, double) onConfirm;

  const AddonSelectionModal({
    super.key,
    required this.menuItem,
    required this.onConfirm,
  });

  @override
  State<AddonSelectionModal> createState() => _AddonSelectionModalState();
}

class _AddonSelectionModalState extends State<AddonSelectionModal> {
  Map<String, int> selectedAddons = {};
  double totalAddonsPrice = 0.0;

  @override
  Widget build(BuildContext context) {
    Map<String, List<Addon>> groupedAddons = {};
    for (var addon in widget.menuItem.addons) {
      if (!groupedAddons.containsKey(addon.category)) {
        groupedAddons[addon.category] = [];
      }
      groupedAddons[addon.category]!.add(addon);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.menuItem.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                '\$${widget.menuItem.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          if (widget.menuItem.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.menuItem.description,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groupedAddons.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      ...entry.value.map((addon) {
                        final isSelected = selectedAddons.containsKey(addon.id);
                        final quantity = selectedAddons[addon.id] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[100]!,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      addon.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    if (addon.price > 0)
                                      Text(
                                        '\$${addon.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B00),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildSmallQtyBtn(Icons.remove, () {
                                          setState(() {
                                            if (selectedAddons[addon.id]! > 1) {
                                              selectedAddons[addon.id] =
                                                  selectedAddons[addon.id]! - 1;
                                            } else {
                                              selectedAddons.remove(addon.id);
                                            }
                                            totalAddonsPrice -= addon.price;
                                          });
                                        }),
                                        Container(
                                          width: 24,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$quantity',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        _buildSmallQtyBtn(Icons.add, () {
                                          setState(() {
                                            selectedAddons[addon.id] =
                                                (selectedAddons[addon.id] ?? 0) + 1;
                                            totalAddonsPrice += addon.price;
                                          });
                                        }),
                                      ],
                                    )
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedAddons[addon.id] = 1;
                                      totalAddonsPrice += addon.price;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B00),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Add',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '\$${(widget.menuItem.price + totalAddonsPrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(selectedAddons, totalAddonsPrice);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallQtyBtn(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

// ==================== HOME SCREEN ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<MenuItem> _allMenuItems = [];
  List<Combo> _combos = [];
  List<Category> _categories = [];
  Store? _selectedStore;
  bool _isLoadingCombos = false;
  bool _isLoadingCategories = false;
  bool _isLoadingMenuItems = false;
  bool _isLoadingAllMenu = false;
  bool _isRefreshing = false;
  final Map<String, CartItem> _cart = {};
  int _currentNavIndex = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _userPoints = 0;
  bool _isPointsInitialized = false;
  bool _isLoadingStore = true;
  bool _noNearbyStore = false;

  List<Store> _allStores = [];
  bool _isLoadingStoresList = false;

  String? _selectedCategoryId;
  Category? _selectedCategory;
  List<MenuItem> _categoryMenuItems = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _userName = '';

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 
                  prefs.getString('full_name') ?? 
                  prefs.getString('name') ?? 
                  'User';
    });
  }

  String? _cartId;

  static const Color _brand = Color(0xFF1A1A1A);
  static const Color _accent = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _loadUserName();
    _checkForStoredStoreId();
    _fetchLoyaltyPointsSilently();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoyaltyPointsSilently() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _isPointsInitialized = true;
            _userPoints = 0;
          });
        }
        return;
      }
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = 'http://142.54.168.26:5050/api/loyalty/account/$userId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (authProvider.token != null) 'Authorization': 'Bearer ${authProvider.token}',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'];
          int points = 0;
          if (data['balance_points'] != null) {
            points = (data['balance_points'] as num).toInt();
          } else if (data['points'] != null) {
            points = (data['points'] as num).toInt();
          }
          if (mounted) {
            setState(() {
              _userPoints = points;
              _isPointsInitialized = true;
            });
          }
        } else {
          if (mounted) setState(() => _isPointsInitialized = true);
        }
      } else {
        if (mounted) setState(() => _isPointsInitialized = true);
      }
    } catch (e) {
      if (mounted) setState(() => _isPointsInitialized = true);
    }
  }

  Future<void> _refreshLoyaltyPoints() async => await _fetchLoyaltyPointsSilently();

  void _openLoyaltyPointsDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoyaltyPointsDetailPage()),
    ).then((_) => _refreshLoyaltyPoints());
  }

  Future<void> _checkForStoredStoreId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedStoreId = prefs.getString('store_id');
      final storedStoreName = prefs.getString('store_name');
      if (storedStoreId != null && storedStoreId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedStore = Store(
              id: storedStoreId,
              name: storedStoreName ?? 'Your Store',
              address: '', city: '', phone: '', email: '',
              openingTime: '', closingTime: '', isActive: true,
            );
            _isLoadingStore = false;
            _noNearbyStore = false;
          });
        }
        await _fetchAllData();
      } else {
        if (mounted) {
          setState(() {
            _isLoadingStore = false;
            _noNearbyStore = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStore = false;
          _noNearbyStore = true;
        });
      }
    }
  }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchCombos(),
      _fetchAllMenuItems(),
      _fetchCart(),
      _refreshLoyaltyPoints(),
      _fetchCategories(),
    ]);
  }

  Future<void> _saveStoreId(String storeId, String storeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store_id', storeId);
      await prefs.setString('store_name', storeName);
    } catch (e) {}
  }

  Future<void> _fetchCategories() async {
    if (mounted) setState(() => _isLoadingCategories = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = Uri.parse('http://142.54.168.26:5050/api/categories?limit=1000');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (authProvider.token != null) 'Authorization': 'Bearer ${authProvider.token}',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List categoriesJson = [];
        if (decoded is List) {
          categoriesJson = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            categoriesJson = decoded['data'];
          } else if (decoded['categories'] is List) {
            categoriesJson = decoded['categories'];
          }
        }

        final categoriesList = categoriesJson.map((e) => Category.fromJson(e)).toList();
        categoriesList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (mounted) setState(() { _categories = categoriesList; _isLoadingCategories = false; });
      } else {
        if (mounted) setState(() { _categories = []; _isLoadingCategories = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _categories = []; _isLoadingCategories = false; });
    }
  }

  Future<void> _fetchMenuItemsByCategory(String categoryId) async {
    if (categoryId.isEmpty) return;
    if (mounted) setState(() { _isLoadingMenuItems = true; _categoryMenuItems = []; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = Uri.parse('http://142.54.168.26:5050/api/menu-items/category/$categoryId');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (authProvider.token != null) 'Authorization': 'Bearer ${authProvider.token}',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List itemsJson = [];
        if (decoded is List) itemsJson = decoded;
        else if (decoded is Map && decoded['data'] is List) itemsJson = decoded['data'];

        List<MenuItem> items = [];
        for (var itemJson in itemsJson) {
          MenuItem item = MenuItem.fromJson(itemJson);
          items.add(item);
        }

        final availableItems = items.where((item) => item.isAvailable).toList();
        if (mounted) setState(() { _categoryMenuItems = availableItems; _isLoadingMenuItems = false; });
      } else {
        if (mounted) setState(() { _categoryMenuItems = []; _isLoadingMenuItems = false; });
      }
    } catch (e) {
      print('Error fetching menu items: $e');
      if (mounted) setState(() { _categoryMenuItems = []; _isLoadingMenuItems = false; });
    }
  }

  Future<void> _fetchCart() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('userId');
    final storeId = prefs.getString('store_id');
    if (customerId == null || customerId.isEmpty || storeId == null || storeId.isEmpty) {
      if (mounted) setState(() { _cart.clear(); _cartId = null; });
      return;
    }
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = 'http://142.54.168.26:5050/api/cart/$customerId/$storeId';
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authProvider.token}',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final cartData = data['data'];
          String cartId = '';
          List itemsList = [];

          if (cartData is List && cartData.isNotEmpty) {
            final firstCart = cartData[0];
            cartId = firstCart['_id'] ?? '';
            itemsList = firstCart['items'] ?? [];
          } else if (cartData is Map) {
            cartId = cartData['_id'] ?? '';
            itemsList = cartData['items'] ?? [];
          }

          final Map<String, CartItem> cartItemsMap = {};
          for (var item in itemsList) {
            try {
              int quantity = 0;
              if (item['quantity'] is int) quantity = item['quantity'];
              else if (item['quantity'] is String) quantity = int.tryParse(item['quantity']) ?? 0;

              String itemId = item['_id'] ?? '';
              Map<String, int> selectedAddons = {};
              double addonsPrice = 0.0;

              if (item['addons'] != null && item['addons'] is List) {
                for (var addon in item['addons']) {
                  String addonId = addon['_id'] ?? addon['id'] ?? '';
                  int addonQuantity = addon['quantity'] ?? 1;
                  if (addonId.isNotEmpty) {
                    selectedAddons[addonId] = addonQuantity;
                  }
                  double addonPrice = 0.0;
                  if (addon['price'] != null) {
                    if (addon['price'] is num) addonPrice = (addon['price'] as num).toDouble();
                    else if (addon['price'] is String) addonPrice = double.tryParse(addon['price']) ?? 0.0;
                  }
                  addonsPrice += addonPrice * addonQuantity;
                }
              }

              if (item['combo_id'] != null && item['combo_id'] is Map) {
                final comboMap = item['combo_id'];
                final comboId = comboMap['_id'] ?? '';
                if (comboId.isNotEmpty) {
                  final comboMenuItem = MenuItem(
                    id: comboId,
                    name: comboMap['name'] ?? 'Combo',
                    description: comboMap['description'] ?? '',
                    price: (comboMap['combo_price'] as num?)?.toDouble() ?? 0.0,
                    imageUrl: comboMap['image_url'] ?? '',
                    isAvailable: true, storeId: storeId, categoryId: '', categoryName: 'Combo',
                  );
                  final double totalPrice = item['total_price'] != null
                      ? (item['total_price'] as num).toDouble()
                      : comboMenuItem.price * quantity + addonsPrice;
                  cartItemsMap[comboId] = CartItem(
                    id: itemId,
                    comboId: comboId,
                    menuItem: comboMenuItem,
                    quantity: quantity,
                    selectedAddons: selectedAddons,
                    addonsPrice: addonsPrice,
                    totalPrice: totalPrice,
                  );
                }
              } else if (item['menu_item_id'] != null && item['menu_item_id'] is Map) {
                final menuItemMap = item['menu_item_id'];
                final menuItemId = menuItemMap['_id'] ?? '';
                if (menuItemId.isNotEmpty) {
                  MenuItem? menuItem = _findMenuItemById(menuItemId);
                  if (menuItem == null) {
                    menuItem = MenuItem(
                      id: menuItemId,
                      name: menuItemMap['name'] ?? 'Product',
                      description: menuItemMap['description'] ?? '',
                      price: (menuItemMap['price'] as num?)?.toDouble() ?? 0.0,
                      imageUrl: menuItemMap['image_url'] ?? '',
                      isAvailable: true, storeId: storeId,
                      categoryId: menuItemMap['category'] is Map ? (menuItemMap['category']['_id'] ?? '') : '',
                      categoryName: menuItemMap['category'] is Map ? (menuItemMap['category']['name'] ?? 'Uncategorized') : 'Uncategorized',
                    );
                  }
                  final double totalPrice = item['total_price'] != null
                      ? (item['total_price'] as num).toDouble()
                      : menuItem.price * quantity + addonsPrice;
                  cartItemsMap[menuItem.id] = CartItem(
                    id: itemId,
                    menuItemId: menuItemId,
                    menuItem: menuItem,
                    quantity: quantity,
                    selectedAddons: selectedAddons,
                    addonsPrice: addonsPrice,
                    totalPrice: totalPrice,
                  );
                }
              }
            } catch (e) {
              print('Error parsing cart item: $e');
            }
          }

          if (mounted) {
            setState(() {
              _cart.clear();
              _cart.addAll(cartItemsMap);
              _cartId = cartId;
            });
          }
        } else {
          if (mounted) setState(() { _cart.clear(); _cartId = null; });
        }
      } else {
        if (mounted) setState(() { _cart.clear(); _cartId = null; });
      }
    } catch (e) {
      print('Error fetching cart: $e');
      if (mounted) setState(() { _cart.clear(); _cartId = null; });
    }
  }

  Future<void> _fetchAllMenuItems() async {
    if (_selectedStore == null) return;
    if (mounted) setState(() => _isLoadingAllMenu = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = Uri.parse('http://142.54.168.26:5050/api/menu-items/getallmenuitem?storeId=${_selectedStore!.id}&limit=10000&page=1');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (authProvider.token != null) 'Authorization': 'Bearer ${authProvider.token}',
      });
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List itemsJson = _extractItems(decoded);
        final allItems = itemsJson.map((e) => MenuItem.fromJson(e)).toList();
        _allMenuItems = allItems.where((item) => item.storeId == _selectedStore!.id).toList();
        _allMenuItems.shuffle();
      }
    } catch (e) {
      print('Error fetching all menu items: $e');
    }
    if (mounted) setState(() => _isLoadingAllMenu = false);
  }

  List<dynamic> _extractItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (decoded['data'] is List) return decoded['data'];
      if (decoded['menu_items'] is List) return decoded['menu_items'];
      if (decoded['items'] is List) return decoded['items'];
      if (decoded['data'] is Map && decoded['data']['items'] is List) return decoded['data']['items'];
    }
    return [];
  }

  Future<void> _fetchCombos() async {
    if (_selectedStore == null) return;
    if (mounted) setState(() => _isLoadingCombos = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = Uri.parse('http://142.54.168.26:5050/api/combo/getcombobystore/${_selectedStore!.id}?limit=1000');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (authProvider.token != null) 'Authorization': 'Bearer ${authProvider.token}',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List combosJson = [];
        if (decoded is List) combosJson = decoded;
        else if (decoded is Map && decoded['data'] is List) combosJson = decoded['data'];
        final allCombos = combosJson.map((e) => Combo.fromJson(e)).toList();
        final availableCombos = allCombos.where((combo) => combo.isAvailable).toList();
        if (mounted) setState(() { _combos = availableCombos; _isLoadingCombos = false; });
      } else {
        if (mounted) setState(() { _combos = []; _isLoadingCombos = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _combos = []; _isLoadingCombos = false; });
    }
  }

  // ==================== CORE CART FUNCTIONS ====================

  Future<void> _addToCart(MenuItem item, int quantity) async {
    if (!item.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is currently unavailable'), backgroundColor: Colors.red),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('userId');
    final storeId = prefs.getString('store_id');

    if (customerId == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to cart'), backgroundColor: Colors.red),
      );
      return;
    }
    if (storeId == null || storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a store'), backgroundColor: Colors.red),
      );
      return;
    }

    if (item.addons.isNotEmpty) {
      await _showAddonsModal(item);
    } else {
      await _addItemToCart(
        customerId: customerId,
        storeId: storeId,
        menuId: item.id,
        quantity: quantity,
        addons: {},
      );
    }
  }

  Future<void> _addItemToCart({
    required String customerId,
    required String storeId,
    required String menuId,
    required int quantity,
    Map<String, int> addons = const {},
    String? comboId,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'store_id': storeId,
        'quantity': quantity,
      };

      if (comboId != null && comboId.isNotEmpty) {
        requestBody['combo_id'] = comboId;
      } else {
        requestBody['menu_id'] = menuId;
      }

      if (addons.isNotEmpty) {
        List<Map<String, dynamic>> addonList = addons.entries.map((entry) => {
          'addon_id': entry.key,
          'quantity': entry.value,
        }).toList();
        requestBody['addons'] = addonList;
      }

      final response = await http.post(
        Uri.parse('http://142.54.168.26:5050/api/cart/manage'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _fetchCart();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item added to cart!'),
                backgroundColor: Color(0xFFFF6B00),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to add item to cart');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to cart: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  Future<void> _removeFromCart(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('userId');
    final storeId = prefs.getString('store_id');

    if (customerId == null || storeId == null) {
      return;
    }

    final cartItem = _cart[itemId];
    if (cartItem == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      int newQuantity = cartItem.quantity - 1;

      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'store_id': storeId,
        'quantity': newQuantity >= 1 ? newQuantity : 0,
      };

      if (cartItem.comboId != null) {
        requestBody['combo_id'] = cartItem.comboId;
      } else {
        requestBody['menu_id'] = cartItem.menuItemId ?? cartItem.menuItem.id;
      }

      if (cartItem.selectedAddons.isNotEmpty) {
        List<Map<String, dynamic>> addonList = cartItem.selectedAddons.entries.map((entry) => {
          'addon_id': entry.key,
          'quantity': entry.value,
        }).toList();
        requestBody['addons'] = addonList;
      }

      final response = await http.post(
        Uri.parse('http://142.54.168.26:5050/api/cart/manage'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _fetchCart();
        } else {
          throw Exception(data['message'] ?? 'Failed to update cart');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error removing from cart: $e');
      if (mounted) {
        await _fetchCart();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cart: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddonsModal(MenuItem item) async {
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: AddonSelectionModal(
            menuItem: item,
            onConfirm: (selectedAddons, addonsPrice) {
              Navigator.pop(context, {
                'selectedAddons': selectedAddons,
                'addonsPrice': addonsPrice,
              });
            },
          ),
        );
      },
    );

    if (result != null && mounted) {
      final selectedAddons = result['selectedAddons'] as Map<String, int>;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
        ),
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        final customerId = prefs.getString('userId');
        final storeId = prefs.getString('store_id');

        if (customerId != null && storeId != null) {
          await _addItemToCart(
            customerId: customerId,
            storeId: storeId,
            menuId: item.id,
            quantity: 1,
            addons: selectedAddons,
          );
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _addComboToCart(Combo combo, int quantity) async {
    if (!combo.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This combo is currently unavailable'), backgroundColor: Colors.red),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('userId');
    final storeId = prefs.getString('store_id');

    if (customerId == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to cart'), backgroundColor: Colors.red),
      );
      return;
    }
    if (storeId == null || storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a store'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
        ),
      );

      await _addItemToCart(
        customerId: customerId,
        storeId: storeId,
        menuId: '',
        quantity: quantity,
        comboId: combo.id,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _removeComboFromCart(String comboId) async {
    await _removeFromCart(comboId);
  }

  MenuItem? _findMenuItemById(String id) {
    for (var item in _allMenuItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _navigateToDetails(MenuItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MenuItemDetailsScreen(menuItemId: item.id)),
    );
  }

  Future<List<Store>> _fetchAllStores() async {
    try {
      if (mounted) setState(() => _isLoadingStoresList = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('http://142.54.168.26:5050/api/stores/getlist'),
        headers: {
          'Content-Type': 'application/json',
          if (authProvider.token != null) 'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List storesData = decoded['data'] ?? [];
        final List<Store> stores = storesData.map((storeJson) => Store.fromJson(storeJson)).toList();
        if (mounted) setState(() { _allStores = stores; _isLoadingStoresList = false; });
        return stores;
      } else {
        if (mounted) setState(() => _isLoadingStoresList = false);
        return [];
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStoresList = false);
      return [];
    }
  }

  Future<void> _showStoreSelectionModal() async {
    await _fetchAllStores();
    if (_allStores.isEmpty) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 32, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Store', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _allStores.length,
                    itemBuilder: (context, index) {
                      final store = _allStores[index];
                      final isSelected = _selectedStore?.id == store.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.store, color: isSelected ? _accent : Colors.grey[600]),
                        title: Text(store.name, style: TextStyle(color: const Color(0xFF1A1A1A), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                        subtitle: Text(store.address, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: _accent)
                            : null,
                        onTap: () => _changeStore(store, context),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeStore(Store newStore, BuildContext modalContext) async {
    Navigator.pop(modalContext);
    await _saveStoreId(newStore.id, newStore.name);
    if (mounted) {
      setState(() {
        _selectedStore = newStore;
        _isLoadingStore = false;
        _noNearbyStore = false;
        _combos.clear();
        _allMenuItems = [];
        _cart.clear();
        _cartId = null;
        _categories.clear();
        _categoryMenuItems.clear();
        _selectedCategoryId = null;
        _selectedCategory = null;
      });
    }
    await _fetchAllData();
  }

  void _selectCategory(Category category) {
    setState(() {
      _selectedCategoryId = category.id;
      _selectedCategory = category;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchMenuItemsByCategory(category.id);
  }

  void _selectAllCategory() {
    setState(() {
      _selectedCategoryId = null;
      _selectedCategory = null;
      _searchQuery = '';
      _searchController.clear();
      _categoryMenuItems = [];
      _isLoadingMenuItems = false;
    });
  }

  void _selectOffersCategory() {
    setState(() {
      _selectedCategoryId = 'offers';
      _selectedCategory = null;
      _searchQuery = '';
      _searchController.clear();
      _categoryMenuItems = [];
      _isLoadingMenuItems = false;
    });
  }

  List<MenuItem> _getFilteredItems() {
    // "All" shows the full menu; "Offers" shows discounted items; a selected category shows only its items.
    final List<MenuItem> source = _selectedCategoryId == null
        ? _allMenuItems.where((item) => item.isAvailable).toList()
        : _selectedCategoryId == 'offers'
        ? _allMenuItems.where((item) => item.isAvailable && item.hasOffer).toList()
        : List<MenuItem>.from(_categoryMenuItems);

    if (_searchQuery.isEmpty) return source;

    final q = _searchQuery.toLowerCase();
    return source.where((item) =>
    item.name.toLowerCase().contains(q) ||
        item.description.toLowerCase().contains(q)
    ).toList();
  }

  Widget _buildCategoryChip({
    required Category category,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAllCategory = false,
    bool isOffersCategory = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isAllCategory || isOffersCategory ? null : Border.all(
                  color: isSelected ? _accent : Colors.grey[200]!,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected && !isAllCategory && !isOffersCategory
                    ? [
                  BoxShadow(
                    color: _accent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
                    : null,
              ),
              child: ClipOval(
                child: isAllCategory
                    ? Container(
                  color: Colors.grey[50],
                  child: Center(
                    child: Icon(
                      Icons.apps_rounded,
                      size: 30,
                      color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey[500],
                    ),
                  ),
                )
                    : isOffersCategory
                    ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF8F00)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_offer_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                )
                    : category.imageUrl != null && category.imageUrl!.isNotEmpty
                    ? Image.network(
                  category.imageUrl!,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[50],
                      child: Center(
                        child: Icon(
                          Icons.category_outlined,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[50],
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: _accent,
                          ),
                        ),
                      ),
                    );
                  },
                )
                    : Container(
                  color: Colors.grey[50],
                  child: Center(
                    child: Icon(
                      Icons.category_outlined,
                      size: 30,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 75,
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey[700],
                  height: 1.1,
                ),
                maxLines: 3,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    if (_selectedStore != null) {
      await Future.wait([
        _fetchCombos(), _fetchAllMenuItems(),
        _fetchCart(), _refreshLoyaltyPoints(), _fetchCategories(),
      ]);
      if (_selectedCategoryId != null) {
        await _fetchMenuItemsByCategory(_selectedCategoryId!);
      }
    } else {
      await _showStoreSelectionModal();
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return CustomStatusBar(
      statusBarColor: _brand,
      statusBarIconBrightness: Brightness.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: 0,
          storeId: _selectedStore?.id,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: _accent,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 90,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  backgroundColor: const Color(0xFF1E3A5F),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: const Color(0xFF1E3A5F),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: _showStoreSelectionModal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on_outlined, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _noNearbyStore ? 'Select Store' : (_selectedStore?.name ?? 'Loading...'),
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _openLoyaltyPointsDetail,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.wallet_outlined, color: Colors.white, size: 20),
                                      if (_isPointsInitialized && _userPoints > 0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_userPoints}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(0),
                    child: Container(
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Hi, ${_userName.isNotEmpty ? _userName : 'User'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SearchBarWidget(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                if (_categories.isNotEmpty && !_isLoadingStore && !_noNearbyStore)
                  SliverToBoxAdapter(
                    child: Container(
                      color: const Color(0xFFF5F5F5),
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Text(
                              'Categories',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                            ),
                          ),
                          SizedBox(
                            height: 140,
                            child: _isLoadingCategories
                                ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                              ),
                            )
                                : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              itemCount: _categories.length + 2,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildCategoryChip(
                                    category: Category(
                                      id: 'all',
                                      name: 'All',
                                      imageUrl: null,
                                      storeId: _selectedStore?.id ?? '',
                                    ),
                                    isSelected: _selectedCategoryId == null,
                                    onTap: _selectAllCategory,
                                    isAllCategory: true,
                                  );
                                }
                                if (index == 1) {
                                  return _buildCategoryChip(
                                    category: Category(
                                      id: 'offers',
                                      name: 'Offers',
                                      imageUrl: null,
                                      storeId: _selectedStore?.id ?? '',
                                    ),
                                    isSelected: _selectedCategoryId == 'offers',
                                    onTap: _selectOffersCategory,
                                    isOffersCategory: true,
                                  );
                                }
                                final category = _categories[index - 2];
                                return _buildCategoryChip(
                                  category: category,
                                  isSelected: _selectedCategoryId == category.id,
                                  onTap: () => _selectCategory(category),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SliverPadding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
                  sliver: SliverToBoxAdapter(child: _buildBodyContent()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoadingStore) {
      return SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: _accent)));
    }
    if (_noNearbyStore) {
      return SizedBox(
        height: 400,
        child: EmptyState(
          title: 'No Store Selected',
          message: 'Select a store to start ordering.',
          icon: Icons.store_outlined,
          onAction: _showStoreSelectionModal,
          actionText: 'Choose Store',
        ),
      );
    }
    if (_isLoadingMenuItems && _selectedCategoryId != null) {
      return SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: _accent)));
    }
    if (_isLoadingAllMenu && _selectedCategoryId == null && _allMenuItems.isEmpty) {
      return SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: _accent)));
    }

    final filteredItems = _getFilteredItems();

    if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
      return SizedBox(
        height: 300,
        child: EmptyState(
          title: 'No Results',
          message: 'No items match "$_searchQuery"',
          icon: Icons.search_off,
          onAction: () { setState(() { _searchQuery = ''; _searchController.clear(); }); },
          actionText: 'Clear Search',
        ),
      );
    }

    final bool isAllView = _selectedCategoryId == null;
    final bool showCombos = isAllView && _searchQuery.isEmpty && _combos.isNotEmpty;
    final double _screenWidth = MediaQuery.of(context).size.width;
    final double _hCardWidth = (_screenWidth * 0.6).clamp(215.0, 280.0);
    final double _hListHeight = 340 * (_screenWidth / 390.0).clamp(0.9, 1.25);

    String listTitle;
    if (_searchQuery.isNotEmpty) {
      listTitle = 'Search Results';
    } else if (isAllView) {
      listTitle = 'Menu';
    } else {
      listTitle = _selectedCategory?.name ?? 'Menu';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCombos) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Special Combos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
            ),
          ),
          SizedBox(
            height: _hListHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _combos.length > 4 ? 4 : _combos.length,
              itemBuilder: (context, index) {
                final combo = _combos[index];
                final qty = _cart[combo.id]?.quantity ?? 0;
                return SizedBox(
                  width: _hCardWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: MenuItemCard(
                      isCompact: true,
                      menuItem: MenuItem(
                        id: combo.id, name: combo.name, description: combo.description,
                        price: combo.comboPrice, imageUrl: combo.imageUrl, isAvailable: true,
                        storeId: _selectedStore?.id ?? '', categoryId: '', categoryName: 'Combo',
                        addons: [],
                      ),
                      quantity: qty,
                      onTap: () {},
                      onAdd: () => _addComboToCart(combo, 1),
                      onRemove: () => _removeComboFromCart(combo.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        if (filteredItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              listTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final qty = _cart[item.id]?.quantity ?? 0;
                return MenuItemCard(
                  menuItem: item,
                  quantity: qty,
                  onTap: () => _navigateToDetails(item),
                  onAdd: () => _addToCart(item, 1),
                  onRemove: () => _removeFromCart(item.id),
                );
              },
            ),
          ),
        ],

        if (filteredItems.isEmpty && !_isLoadingMenuItems && !_isLoadingAllMenu && !showCombos)
          SizedBox(
            height: 200,
            child: Center(
              child: Text(
                isAllView ? 'No items available' : 'No items in this category',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }
}