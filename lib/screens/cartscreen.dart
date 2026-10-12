// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:food/config/api_config.dart';
import 'package:food/screens/checkoutscreen.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

extension SafeJsonParsing on Map<String, dynamic> {
  T? getValue<T>(String key, {T? defaultValue}) {
    try {
      if (!containsKey(key)) return defaultValue;
      final value = this[key];
      if (value == null) return defaultValue;
      if (value is T) return value;
      
      if (T == int && value is double) return (value.toInt()) as T;
      if (T == double && value is int) return (value.toDouble()) as T;
      if (T == String && value is num) return (value.toString()) as T;
      if (T == bool && value is int) return (value == 1) as T;
      if (T == bool && value is String) {
        final lowerValue = value.toLowerCase();
        return (lowerValue == 'true' || lowerValue == '1') as T;
      }
      if (T == bool && value == null) return defaultValue;
      
      return defaultValue;
    } catch (e) {
      print('Error getting value for key $key: $e');
      return defaultValue;
    }
  }
  
  String getString(String key, {String defaultValue = ''}) {
    final value = getValue<String>(key);
    return value ?? defaultValue;
  }
  
  int getInt(String key, {int defaultValue = 0}) {
    final value = getValue<int>(key);
    return value ?? defaultValue;
  }
  
  double getDouble(String key, {double defaultValue = 0.0}) {
    final numValue = getValue<num>(key);
    return numValue?.toDouble() ?? defaultValue;
  }
  
  bool getBool(String key, {bool defaultValue = false}) {
    final value = getValue<bool>(key);
    return value ?? defaultValue;
  }
  
  List<T> getList<T>(String key, {required T Function(Map<String, dynamic>) fromJson}) {
    final list = getValue<List<dynamic>>(key);
    if (list == null) return [];
    return list
        .where((item) => item is Map<String, dynamic>)
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }
  
  Map<String, dynamic> getMap(String key, {Map<String, dynamic> defaultValue = const {}}) {
    final value = getValue<Map<String, dynamic>>(key);
    return value ?? defaultValue;
  }
}

// ==================== ADDON MODEL ====================
class CartAddon {
  final String id;
  final String name;
  final double price;
  final String? category;
  final int quantity;

  CartAddon({
    required this.id,
    required this.name,
    required this.price,
    this.category,
    this.quantity = 1,
  });

  factory CartAddon.fromJson(Map<String, dynamic> json) {
    String id = '';
    String name = '';
    double price = 0.0;
    String? category;
    int quantity = 1;
    
    final addonIdData = json['addon_id'];
    if (addonIdData is Map<String, dynamic>) {
      id = addonIdData.getString('_id');
      name = addonIdData.getString('name', defaultValue: 'Addon');
      price = addonIdData.getDouble('price', defaultValue: 0.0);
      category = addonIdData.getString('category', defaultValue: '');
    } else if (addonIdData is String) {
      id = addonIdData;
      name = json.getString('name', defaultValue: 'Addon');
      price = json.getDouble('price', defaultValue: 0.0);
    } else {
      id = json.getString('addon_id');
      name = json.getString('name', defaultValue: 'Addon');
      price = json.getDouble('price', defaultValue: 0.0);
    }
    
    quantity = json.getInt('quantity', defaultValue: 1);
    category = json.getString('category', defaultValue: '');
    
    return CartAddon(
      id: id,
      name: name,
      price: price,
      category: category,
      quantity: quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addon_id': id,
      'name': name,
      'price': price,
      'category': category,
      'quantity': quantity,
    };
  }
  
  CartAddon copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    int? quantity,
  }) {
    return CartAddon(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
    );
  }
}

// ==================== CART ITEM MODEL (FIXED) ====================
class CartItem {
  final String id;
  final String name;
  final double price; // Total per-unit price (base + addons)
  int quantity;
  final String imageUrl;
  final String restaurant;
  final String menuItemId;
  final String? comboId;
  final bool isCombo;
  final String? description;
  bool isUpdating;
  final List<CartAddon> addons;
  final double basePrice; // ✅ ADDED: Store the base price separately

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.restaurant,
    required this.menuItemId,
    this.comboId,
    this.isCombo = false,
    this.description,
    this.isUpdating = false,
    this.addons = const [],
    this.basePrice = 0.0, // ✅ ADDED
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    try {
      final comboData = json['combo_id'];
      final isCombo = comboData != null;
      
      String name = 'Unknown Item';
      double basePrice = 0.0; // ✅ Store base price
      String imageUrl = 'https://via.placeholder.com/100';
      String itemId = '';
      String description = '';
      List<CartAddon> addons = [];
      
      // Parse addons first
      if (json.containsKey('addons') && json['addons'] is List) {
        final addonsList = json['addons'] as List;
        for (var addon in addonsList) {
          if (addon is Map<String, dynamic>) {
            addons.add(CartAddon.fromJson(addon));
          }
        }
      }
      
      if (isCombo && comboData is Map<String, dynamic>) {
        name = comboData.getString('name', defaultValue: 'Unknown Combo');
        basePrice = comboData.getDouble('combo_price', defaultValue: 0.0); // ✅ Set base price
        imageUrl = comboData.getString('image_url', defaultValue: 'https://via.placeholder.com/100');
        itemId = comboData.getString('_id', defaultValue: '');
        description = comboData.getString('description', defaultValue: '');
      } else {
        final menuItemData = json['menu_item_id'];
        
        if (menuItemData is Map<String, dynamic>) {
          name = menuItemData.getString('name', defaultValue: 'Unknown Item');
          basePrice = menuItemData.getDouble('price', defaultValue: 0.0); // ✅ Set base price
          imageUrl = menuItemData.getString('image_url', defaultValue: 'https://via.placeholder.com/100');
          itemId = menuItemData.getString('_id', defaultValue: '');
          description = menuItemData.getString('description', defaultValue: '');
        } else if (menuItemData is String) {
          itemId = menuItemData;
        }
      }
      
      int quantity = json.getInt('quantity', defaultValue: 1);
      
      // Calculate total price from base price + addons
      double addonsTotalPerUnit = addons.fold(0.0, (sum, addon) => sum + (addon.price * addon.quantity));
      double totalPricePerUnit = basePrice + addonsTotalPerUnit;
      
      // If server provides price, use it, otherwise use calculated
      if (json.containsKey('price') && json['price'] is num) {
        totalPricePerUnit = (json['price'] as num).toDouble();
        print('✅ Using server price: $totalPricePerUnit for $name');
      } else {
        print('✅ Calculated price: $totalPricePerUnit for $name (base: $basePrice, addons: $addonsTotalPerUnit)');
      }
      
      String restaurantName = 'Paldi Store';
      final storeData = json['store_id'];
      if (storeData is Map<String, dynamic>) {
        restaurantName = storeData.getString('name', defaultValue: 'Restaurant');
      }
      
      print('📊 Cart Item: $name | Price: $totalPricePerUnit | Qty: $quantity | Addons: ${addons.length}');
      
      return CartItem(
        id: json.getString('_id'),
        name: name,
        price: totalPricePerUnit,
        quantity: quantity,
        imageUrl: imageUrl,
        restaurant: restaurantName,
        menuItemId: isCombo ? '' : itemId,
        comboId: isCombo ? itemId : null,
        isCombo: isCombo,
        description: description,
        isUpdating: false,
        addons: addons,
        basePrice: basePrice, // ✅ Store base price
      );
    } catch (e) {
      print('❌ Error parsing CartItem: $e');
      return CartItem(
        id: json.getString('_id'),
        name: 'Error Loading Item',
        price: 0.0,
        quantity: 1,
        imageUrl: 'https://via.placeholder.com/100',
        restaurant: 'Unknown',
        menuItemId: '',
        comboId: null,
        isCombo: false,
        isUpdating: false,
        addons: [],
        basePrice: 0.0,
      );
    }
  }
  
  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? restaurant,
    String? menuItemId,
    String? comboId,
    bool? isCombo,
    String? description,
    bool? isUpdating,
    List<CartAddon>? addons,
    double? basePrice,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      restaurant: restaurant ?? this.restaurant,
      menuItemId: menuItemId ?? this.menuItemId,
      comboId: comboId ?? this.comboId,
      isCombo: isCombo ?? this.isCombo,
      description: description ?? this.description,
      isUpdating: isUpdating ?? this.isUpdating,
      addons: addons ?? this.addons,
      basePrice: basePrice ?? this.basePrice,
    );
  }
  
  // ✅ Get base price (without addons)
  double getBasePrice() {
    return basePrice;
  }
  
  // ✅ Calculate total price per unit including addons
  double getTotalPricePerUnit() {
    double addonsTotal = addons.fold(0.0, (sum, addon) => sum + (addon.price * addon.quantity));
    return basePrice + addonsTotal;
  }
  
  double getTotalPrice() {
    double total = getTotalPricePerUnit() * quantity;
    print('💰 Item Total: $name | Price: ${getTotalPricePerUnit()} × Qty: $quantity = $total');
    return total;
  }
}

// ==================== CART RESPONSE ====================
class CartResponse {
  final bool success;
  final CartData? data;
  final String? message;
  final Map<String, dynamic>? loyalty;
  final Map<String, dynamic>? redemption;

  CartResponse({
    required this.success,
    this.data,
    this.message,
    this.loyalty,
    this.redemption,
  });

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    try {
      bool success = false;
      final successValue = json['success'];
      if (successValue is bool) {
        success = successValue;
      } else if (successValue is int) {
        success = successValue == 1;
      } else if (successValue is String) {
        success = successValue.toLowerCase() == 'true';
      }
      
      CartData? data;
      
      if (json.containsKey('data') && json['data'] is List) {
        final List<dynamic> dataList = json['data'] as List;
        if (dataList.isNotEmpty && dataList[0] is Map<String, dynamic>) {
          data = CartData.fromJson(dataList[0] as Map<String, dynamic>);
        }
      } else if (json.containsKey('data') && json['data'] != null && json['data'] is Map<String, dynamic>) {
        data = CartData.fromJson(json['data'] as Map<String, dynamic>);
      } else if (json.containsKey('_id') && json.containsKey('items')) {
        data = CartData.fromJson(json);
        success = true;
      } else if (json.containsKey('cart') && json['cart'] is Map<String, dynamic>) {
        data = CartData.fromJson(json['cart'] as Map<String, dynamic>);
        success = true;
      } else if (json.containsKey('cart_id')) {
        data = CartData.fromJson(json);
        success = true;
      }
      
      String? message;
      if (json.containsKey('message') && json['message'] != null) {
        message = json['message'].toString();
      } else if (!success && data == null) {
        message = 'No cart data found';
      }
      
      Map<String, dynamic>? loyalty;
      if (json.containsKey('loyalty') && json['loyalty'] is Map<String, dynamic>) {
        loyalty = json['loyalty'] as Map<String, dynamic>;
      }
      
      Map<String, dynamic>? redemption;
      if (json.containsKey('redemption') && json['redemption'] != null) {
        redemption = json['redemption'] as Map<String, dynamic>;
      }
      
      print('✅ Cart response parsed: success=$success, items=${data?.items.length ?? 0}');
      
      return CartResponse(
        success: success,
        data: data,
        message: message,
        loyalty: loyalty,
        redemption: redemption,
      );
    } catch (e) {
      print('❌ Error parsing CartResponse: $e');
      return CartResponse(success: false, message: 'Failed to parse response: $e');
    }
  }
}

// ==================== CART DATA ====================
class CartData {
  final String id;
  final List<CartItem> items;
  final double grandTotal;
  final int totalItems;
  final double subtotal;
  final double discountAmount;
  final double deliveryCharge;
  final double taxAmount;
  final double finalTotal;

  CartData({
    required this.id,
    required this.items,
    required this.grandTotal,
    this.totalItems = 0,
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    this.deliveryCharge = 0.0,
    this.taxAmount = 0.0,
    this.finalTotal = 0.0,
  });

  factory CartData.fromJson(Map<String, dynamic> json) {
    try {
      String id = '';
      
      if (json.containsKey('_id')) {
        id = json.getString('_id');
      } else if (json.containsKey('cart_id')) {
        id = json.getString('cart_id');
      } else if (json.containsKey('id')) {
        id = json.getString('id');
      }
      
      List<CartItem> items = [];
      
      List<dynamic> itemsList = [];
      if (json.containsKey('items') && json['items'] is List) {
        itemsList = json['items'] as List;
      } else if (json.containsKey('menu_items') && json['menu_items'] is List) {
        itemsList = json['menu_items'] as List;
      }
      
      print('📦 Parsing ${itemsList.length} items from server');
      
      for (var item in itemsList) {
        if (item is Map<String, dynamic>) {
          items.add(CartItem.fromJson(item));
        }
      }
      
      // Calculate grand total from items
      double grandTotal = 0.0;
      for (var item in items) {
        grandTotal += item.getTotalPrice();
      }
      
      // Use server grand_total if available
      if (json.containsKey('grand_total') && json['grand_total'] is num) {
        grandTotal = (json['grand_total'] as num).toDouble();
        print('✅ Using server grand_total: $grandTotal');
      } else {
        print('✅ Calculated grand_total: $grandTotal');
      }
      
      int totalItems = items.fold(0, (sum, item) => sum + item.quantity);
      
      double subtotal = json.getDouble('subtotal', defaultValue: grandTotal);
      double discountAmount = json.getDouble('discount_amount', defaultValue: 0.0);
      double deliveryCharge = json.getDouble('delivery_charge', defaultValue: 0.0);
      double taxAmount = json.getDouble('tax_amount', defaultValue: 0.0);
      double finalTotal = json.getDouble('final_total', defaultValue: grandTotal);
      
      print('💰 Grand Total: $grandTotal | Items: $totalItems');
      
      return CartData(
        id: id,
        items: items,
        grandTotal: grandTotal,
        totalItems: totalItems,
        subtotal: subtotal,
        discountAmount: discountAmount,
        deliveryCharge: deliveryCharge,
        taxAmount: taxAmount,
        finalTotal: finalTotal,
      );
    } catch (e) {
      print('❌ Error parsing CartData: $e');
      return CartData(id: '', items: [], grandTotal: 0.0);
    }
  }
}

// ==================== API SERVICE ====================

class CartApiService {
  static const String baseUrl = ApiConfig.baseUrl;
  
  static Future<CartResponse> fetchCart(String customerId, String storeId) async {
    final url = '$baseUrl/api/cart/getcart/$customerId/$storeId';
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return CartResponse.fromJson(jsonResponse as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return CartResponse(success: false, message: 'Cart not found');
      } else {
        return CartResponse(success: false, message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching cart: $e');
      return CartResponse(success: false, message: 'Connection error: $e');
    }
  }
  
  static Future<bool> clearCart(String customerId) async {
    final url = '$baseUrl/api/cart/customer/$customerId';
    
    try {
      final response = await http.delete(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error clearing cart: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>> updateCartItemWithAddons({
    required String cartId,
    required String itemId,
    required int quantity,
    required List<Map<String, dynamic>> addons,
  }) async {
    final url = '$baseUrl/api/cart/update/$cartId';
    
    try {
      final Map<String, dynamic> requestBody = {
        'item_id': itemId,
        'quantity': quantity,
        'addons': addons,
      };
      
      print('📤 Updating cart with addons: ${json.encode(requestBody)}');
      
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': 'Cart updated successfully',
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Error updating cart with addons: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
        'data': null,
      };
    }
  }
}

// ==================== CART SCREEN ====================

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _cartItems = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;
  double _grandTotal = 0.0;
  String? _customerId;
  String? _storeId;
  String? _cartId;

  static const Color brandColor = Color(0xFF132C48);
  static const Color appBarColor = Color(0xFF1E3A5F);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    await _getUserData();
    if (_customerId != null && _customerId!.isNotEmpty && _storeId != null && _storeId!.isNotEmpty) {
      await _fetchCart();
    } else {
      setState(() {
        if (_customerId == null || _customerId!.isEmpty) {
          _errorMessage = "Please login to view cart";
        } else if (_storeId == null || _storeId!.isEmpty) {
          _errorMessage = "Please select a store";
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customerId = prefs.getString('customer_id') ?? 
                    prefs.getString('userId') ??
                    prefs.getString('user_id');
      
      _storeId = prefs.getString('store_id') ??
                 prefs.getString('storeId') ??
                 prefs.getString('storeid');
    });
  }

  Future<void> _fetchCart() async {
    if (_customerId == null || _customerId!.isEmpty || _storeId == null || _storeId!.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final currentStoreName = prefs.getString('store_name') ?? prefs.getString('storeName');

    final response = await CartApiService.fetchCart(_customerId!, _storeId!);
    
    if (mounted) {
      if (response.success && response.data != null) {
        if (response.data!.items.isNotEmpty) {
          List<CartItem> items = response.data!.items;
          if (currentStoreName != null && currentStoreName.isNotEmpty) {
            items = items.map((item) => item.copyWith(
              restaurant: (item.restaurant == 'Paldi Store' || item.restaurant == 'Restaurant' || item.restaurant.isEmpty)
                  ? currentStoreName
                  : item.restaurant,
            )).toList();
          }
          setState(() {
            _cartItems = items;
            _grandTotal = response.data!.grandTotal;
            _cartId = response.data!.id;
            _errorMessage = null;
            print('🔄 Cart refreshed: ${_cartItems.length} items, Total: $_grandTotal, Store: $currentStoreName');
          });
        } else {
          setState(() {
            _cartItems = [];
            _grandTotal = 0.0;
            _cartId = response.data!.id;
            _errorMessage = null;
          });
        }
      } else {
        setState(() {
          _cartItems = [];
          _grandTotal = 0.0;
          _cartId = null;
          _errorMessage = null;
        });
      }
      
      setState(() => _isLoading = false);
      CartManager.updateCartCount();
    }
  }

  Future<void> _clearCart() async {
    if (_customerId == null || _customerId!.isEmpty) {
      _showSnackBar('Customer ID not found. Please login again.', isError: true);
      return;
    }
    
    setState(() => _isUpdating = true);
    
    final success = await CartApiService.clearCart(_customerId!);
    
    if (mounted) {
      setState(() => _isUpdating = false);
      
      if (success) {
        setState(() {
          _cartItems.clear();
          _grandTotal = 0.0;
          _cartId = null;
        });
        _showSnackBar('Cart cleared successfully', isError: false);
      } else {
        _showSnackBar('Failed to clear cart', isError: true);
      }
    }
  }

  Future<void> _updateQuantity(CartItem item, int newQuantity) async {
    if (_cartId == null || _cartId!.isEmpty) {
      _showSnackBar('Cart ID not found. Please refresh the cart.', isError: true);
      return;
    }
    
    final String itemId = item.id;
    
    final index = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
    if (index == -1) return;
    
    final originalItem = _cartItems[index];
    
    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(isUpdating: true);
    });
    
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
      }
      _recalculateTotal();
    });
    
    try {
      final addonsList = item.addons.map((addon) => {
        'addon_id': addon.id,
        'quantity': addon.quantity,
      }).toList();
      
      final result = await CartApiService.updateCartItemWithAddons(
        cartId: _cartId!,
        itemId: itemId,
        quantity: newQuantity,
        addons: addonsList,
      );
      
      if (mounted) {
        final currentIndex = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
        
        if (!result['success']) {
          setState(() {
            if (newQuantity <= 0) {
              if (currentIndex == -1) {
                _cartItems.insert(index, originalItem);
              }
            } else {
              if (currentIndex != -1) {
                _cartItems[currentIndex] = _cartItems[currentIndex].copyWith(
                  quantity: originalItem.quantity,
                  isUpdating: false,
                );
              }
            }
            _recalculateTotal();
          });
          _showSnackBar(result['message'] ?? 'Failed to update cart', isError: true);
        } else {
          // ✅ Refresh cart to get updated prices
          await _fetchCart();
          
          if (newQuantity <= 0) {
            _showSnackBar(
              '${item.isCombo ? "Combo" : "Item"} removed',
              isError: false,
              duration: const Duration(seconds: 1),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error in updateQuantity: $e');
      if (mounted) {
        setState(() {
          final currentIndex = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
          if (newQuantity <= 0) {
            if (currentIndex == -1) {
              _cartItems.insert(index, originalItem);
            }
          } else {
            if (currentIndex != -1) {
              _cartItems[currentIndex] = _cartItems[currentIndex].copyWith(
                quantity: originalItem.quantity,
                isUpdating: false,
              );
            }
          }
          _recalculateTotal();
        });
        _showSnackBar('Error updating cart', isError: true);
      }
    }
  }

  // ✅ FIXED: Update addon quantity with proper price recalculation
  Future<void> _updateAddonQuantity(CartItem item, CartAddon addon, int newQuantity) async {
    if (_cartId == null || _cartId!.isEmpty) {
      _showSnackBar('Cart ID not found. Please refresh the cart.', isError: true);
      return;
    }
    
    final index = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
    if (index == -1) return;
    
    // ✅ Update local addon quantity
    final updatedAddons = item.addons.map((a) {
      if (a.id == addon.id) {
        return a.copyWith(quantity: newQuantity);
      }
      return a;
    }).where((a) => a.quantity > 0).toList();
    
    // ✅ Calculate new price from base price + updated addons
    double newAddonsTotal = updatedAddons.fold(0.0, (sum, a) => sum + (a.price * a.quantity));
    double newPrice = item.basePrice + newAddonsTotal; // ✅ Use base price for calculation
    
    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(
        addons: updatedAddons,
        price: newPrice, // ✅ Update price immediately
        isUpdating: true,
      );
      _recalculateTotal(); // ✅ Recalculate grand total
    });
    
    try {
      final addonsList = updatedAddons.map((a) => {
        'addon_id': a.id,
        'quantity': a.quantity,
      }).toList();
      
      final result = await CartApiService.updateCartItemWithAddons(
        cartId: _cartId!,
        itemId: item.id,
        quantity: item.quantity,
        addons: addonsList,
      );
      
      if (mounted) {
        if (!result['success']) {
          // Revert on failure
          final currentIndex = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
          if (currentIndex != -1) {
            setState(() {
              _cartItems[currentIndex] = item.copyWith(
                addons: item.addons,
                price: item.price, // ✅ Revert to original price
                isUpdating: false,
              );
              _recalculateTotal();
            });
          }
          _showSnackBar(result['message'] ?? 'Failed to update addons', isError: true);
        } else {
          // ✅ Success - keep local price and just update the flag
          final currentIndex = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
          if (currentIndex != -1) {
            setState(() {
              _cartItems[currentIndex] = _cartItems[currentIndex].copyWith(
                isUpdating: false,
              );
            });
          }
          _showSnackBar('Addon updated successfully', isError: false, duration: const Duration(seconds: 1));
        }
      }
    } catch (e) {
      print('❌ Error in updateAddonQuantity: $e');
      if (mounted) {
        final currentIndex = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
        if (currentIndex != -1) {
          setState(() {
            _cartItems[currentIndex] = item.copyWith(
              addons: item.addons,
              price: item.price, // ✅ Revert to original price
              isUpdating: false,
            );
            _recalculateTotal();
          });
        }
        _showSnackBar('Error updating addon', isError: true);
      }
    }
  }

  void _recalculateTotal() {
    double total = 0.0;
    for (var item in _cartItems) {
      total += item.getTotalPrice();
    }
    _grandTotal = total;
    print('🔄 Recalculated total: $_grandTotal');
  }

  void _proceedToCheckout() {
    if (_cartId == null || _cartId!.isEmpty) {
      _showSnackBar('Cart ID not found. Please refresh the cart.', isError: true);
      return;
    }
    
    if (_customerId == null || _customerId!.isEmpty) {
      _showSnackBar('Please login to proceed to checkout.', isError: true);
      return;
    }
    
    if (_cartItems.isEmpty) {
      _showSnackBar('Your cart is empty', isError: true);
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartId: _cartId!,
          grandTotal: _grandTotal,
          cartItems: _cartItems,
          userId: _customerId!,
          storeId: _storeId,
        ),
      ),
    ).then((_) {
      _fetchCart();
    });
  }

  void _showSnackBar(String message, {required bool isError, Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCart();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_cartItems.isNotEmpty && !_isUpdating)
            TextButton.icon(
              onPressed: _showClearCartDialog,
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
              label: const Text('Clear Cart', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchCart,
            color: brandColor,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchCart,
              style: ElevatedButton.styleFrom(backgroundColor: brandColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return _buildEmptyCart();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return _CartItemCard(
                key: ValueKey(item.id),
                item: item,
                onQuantityChanged: (newQuantity) => _updateQuantity(item, newQuantity),
                onAddonQuantityChanged: (addon, newQuantity) => _updateAddonQuantity(item, addon, newQuantity),
                brandColor: brandColor,
              );
            },
          ),
        ),
        _buildTotalSection(),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Your Cart is empty!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            "Looks like you haven't added any items yet",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    final itemCount = _cartItems.fold(0, (sum, item) => sum + item.quantity);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$itemCount item${itemCount != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              Text(
                '\$${_grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: brandColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _proceedToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: const Text(
                'Proceed to Checkout',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CART ITEM CARD ====================

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final Function(int) onQuantityChanged;
  final Function(CartAddon, int) onAddonQuantityChanged;
  final Color brandColor;

  const _CartItemCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onAddonQuantityChanged,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    double basePrice = item.getBasePrice();
    double addonsTotal = item.addons.fold(0.0, (sum, addon) => sum + (addon.price * addon.quantity));
    double itemTotal = item.getTotalPrice();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Image + Product Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                  image: item.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(item.imageUrl),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) => null,
                        )
                      : null,
                ),
                child: item.imageUrl.isEmpty
                    ? Icon(
                        item.isCombo ? Icons.lunch_dining : Icons.fastfood_rounded,
                        size: 30,
                        color: Colors.grey[400],
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Product Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isCombo) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'COMBO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1F1F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.store, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.restaurant,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2: Price + Quantity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Base Price
              Text(
                '\$${basePrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: brandColor,
                ),
              ),
              
              // Quantity buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quantityButton(
                      Icons.remove,
                      () => onQuantityChanged(item.quantity - 1),
                      brandColor,
                      isLoading: item.isUpdating,
                    ),
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: item.isUpdating
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF132C48)),
                              ),
                            )
                          : Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    _quantityButton(
                      Icons.add,
                      () => onQuantityChanged(item.quantity + 1),
                      brandColor,
                      isAdd: true,
                      isLoading: item.isUpdating,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Item Total
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Item Total: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '\$${itemTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: brandColor,
                ),
              ),
            ],
          ),
          
          // Addons Section
          if (item.addons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Addons',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '\$${addonsTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...item.addons.map((addon) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${addon.name}${addon.category != null && addon.category!.isNotEmpty ? ' (${addon.category})' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Addon quantity controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Minus button
                            GestureDetector(
                              onTap: item.isUpdating ? null : () {
                                if (addon.quantity > 1) {
                                  onAddonQuantityChanged(addon, addon.quantity - 1);
                                }
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: addon.quantity > 1 
                                      ? Colors.grey.shade200 
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: addon.quantity > 1 
                                      ? Colors.grey[800] 
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Quantity text
                            Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Text(
                                '${addon.quantity}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F1F1F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Plus button
                            GestureDetector(
                              onTap: item.isUpdating ? null : () {
                                onAddonQuantityChanged(addon, addon.quantity + 1);
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: brandColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 18,
                                  color: brandColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Price
                            Container(
                              width: 60,
                              alignment: Alignment.centerRight,
                              child: addon.price > 0
                                  ? Text(
                                      '\$${(addon.price * addon.quantity).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quantityButton(
    IconData icon,
    VoidCallback onTap,
    Color color, {
    bool isAdd = false,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          gradient: isAdd 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.8)],
                )
              : null,
          color: isAdd ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                icon,
                size: 20,
                color: isAdd ? Colors.white : color,
              ),
      ),
    );
  }
}