import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:food/custom/bottomnavbar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MyOrderScreen extends StatefulWidget {
  final int? initialTabIndex;
  
  const MyOrderScreen({super.key, this.initialTabIndex});

  @override
  State<MyOrderScreen> createState() => _MyOrderScreenState();
}

class _MyOrderScreenState extends State<MyOrderScreen> with TickerProviderStateMixin {
  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;
  String? _storeId;
  bool _isTiffinStore = false;
  String _selectedFilter = 'All';
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;
  bool _isSilentRefresh = false;

  // Design Tokens - Black & Grey with custom primary
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _black = Color(0xFF000000);
  static const Color _darkGrey = Color(0xFF1A1A1A);
  static const Color _grey700 = Color(0xFF4A4A4A);
  static const Color _grey600 = Color(0xFF6B6B6B);
  static const Color _grey500 = Color(0xFF8A8A8A);
  static const Color _grey400 = Color(0xFFB0B0B0);
  static const Color _grey300 = Color(0xFFD0D0D0);
  static const Color _grey200 = Color(0xFFE8E8E8);
  static const Color _grey100 = Color(0xFFF5F5F5);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF8F8F8);

  final List<String> _filterOptions = [
    'All', 'Pending', 'Confirmed', 'Preparing', 'Ready', 'Delivered', 'Completed', 'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _getUserIdAndFetchData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted && _userId != null) {
        await _fetchOrders(showLoading: false, silentRefresh: true);
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  List<dynamic> _getFilteredItems() {
    if (_selectedFilter == 'All') {
      return List.from(_allOrders);
    }
    return _allOrders.where((order) {
      final itemStatus = order['status']?.toString().toLowerCase();
      return itemStatus == _selectedFilter.toLowerCase();
    }).toList();
  }

  int _getFilterCount(String filter) {
    if (filter == 'All') {
      return _allOrders.length;
    }
    return _allOrders.where((order) {
      final itemStatus = order['status']?.toString().toLowerCase();
      return itemStatus == filter.toLowerCase();
    }).length;
  }

  Future<void> _getUserIdAndFetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      _storeId = prefs.getString('store_id');
      _isTiffinStore = prefs.getBool('isTiffinStore') ?? false;

      if (_userId != null && _userId!.isNotEmpty) {
        await _fetchOrders(showLoading: true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User ID not found. Please login again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading user data: $e';
      });
    }
  }

  Future<void> _fetchOrders({bool showLoading = true, bool silentRefresh = false}) async {
    if (_userId == null) return;
    try {
      if (showLoading && mounted) {
        setState(() { _isLoading = true; _errorMessage = null; });
      } else if (silentRefresh) {
        _isSilentRefresh = true;
      } else if (mounted) {
        setState(() { _isAutoRefreshing = true; });
      }

      final url = Uri.parse('http://142.54.168.26:5050/api/order/get-by-customer/$_userId');
      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _allOrders = data['data'] ?? [];
          _isLoading = false;
          _isAutoRefreshing = false;
          _errorMessage = null;
        });
      } else if (mounted && !silentRefresh) {
        setState(() {
          _isLoading = false;
          _isAutoRefreshing = false;
          _errorMessage = 'Failed to load orders (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted && !silentRefresh) setState(() {
        _isLoading = false;
        _isAutoRefreshing = false;
        _errorMessage = 'Network error: $e';
      });
    } finally {
      _isSilentRefresh = false;
    }
  }

  Future<void> _onRefresh() async {
    await _fetchOrders(showLoading: true, silentRefresh: false);
  }

  void _navigateToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  int _getCurrentNavIndex() {
    return _isTiffinStore ? 4 : 3;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _darkGrey,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filterOptions.map((filter) {
                  final count = _getFilterCount(filter);
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _primary : _grey100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? _primary : _grey300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            filter,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? _white : _grey700,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? _white.withOpacity(0.3) : _primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? _white : _primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  if (_isAutoRefreshing) _buildRefreshBannerSliver(),
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active Filter Display
                          if (_selectedFilter != 'All')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Filter: $_selectedFilter',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${_getFilterCount(_selectedFilter)})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFilter = 'All';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _grey100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: _grey600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: _grey600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          // Orders List
                          _isLoading
                              ? _buildShimmer()
                              : _errorMessage != null
                                  ? _buildErrorView(_errorMessage!, () => _getUserIdAndFetchData())
                                  : filteredItems.isEmpty
                                      ? _buildEmptyView(
                                          Icons.receipt_long_rounded,
                                          _selectedFilter == 'All'
                                              ? 'No orders yet'
                                              : 'No $_selectedFilter orders',
                                          'Place an order to get started',
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                          itemCount: filteredItems.length,
                                          itemBuilder: (context, i) {
                                            final order = filteredItems[i];
                                            return _ElegantOrderCard(order: order);
                                          },
                                        ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppBottomNavBar(currentIndex: 2, storeId: _storeId)
        ],
      ),
    );
  }

  Widget _buildRefreshBannerSliver() {
    return SliverToBoxAdapter(
      child: Container(
        color: _primary.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
            ),
            const SizedBox(width: 10),
            Text('Refreshing…', style: TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: _primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: _navigateToHome,
      ),
      title: const Text(
        'My Orders',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 24),
          onPressed: _showFilterDialog,
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _grey300),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorView(String msg, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, size: 48, color: _primary),
            ),
            const SizedBox(height: 20),
            Text(msg, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _grey600, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 52, color: _primary),
            ),
            const SizedBox(height: 18),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _darkGrey)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontSize: 13, color: _grey600)),
            const SizedBox(height: 8),
            Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: _grey500)),
          ],
        ),
      ),
    );
  }
}

// ==================== ELEGANT ORDER CARD ====================
class _ElegantOrderCard extends StatelessWidget {
  final dynamic order;
  const _ElegantOrderCard({required this.order});

  // Black & Grey color scheme with primary
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _black = Color(0xFF000000);
  static const Color _darkGrey = Color(0xFF1A1A1A);
  static const Color _grey700 = Color(0xFF4A4A4A);
  static const Color _grey600 = Color(0xFF6B6B6B);
  static const Color _grey500 = Color(0xFF8A8A8A);
  static const Color _grey400 = Color(0xFFB0B0B0);
  static const Color _grey300 = Color(0xFFD0D0D0);
  static const Color _grey200 = Color(0xFFE8E8E8);
  static const Color _grey100 = Color(0xFFF5F5F5);
  static const Color _white = Color(0xFFFFFFFF);

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'preparing': return 'Preparing';
      case 'ready': return 'Ready';
      case 'delivered': return 'Delivered';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status ?? 'Order';
    }
  }

  List<dynamic> _getOrderItems() {
    try {
      dynamic items = order['items'] ?? [];
      if (items.isEmpty && order['cart_id']?['items'] != null) {
        items = order['cart_id']['items'];
      }
      return items is List ? items : [];
    } catch (e) {
      return [];
    }
  }

  String _getItemName(dynamic item) {
    try {
      if (item['menu_item_id'] is Map) {
        return item['menu_item_id']['name'] ?? 'Item';
      }
      if (item['combo_id'] is Map) {
        return item['combo_id']['name'] ?? 'Combo';
      }
      return item['name'] ?? item['productName'] ?? 'Item';
    } catch (e) {
      return 'Item';
    }
  }

  int _getItemQty(dynamic item) {
    try {
      return item['quantity'] ?? item['qty'] ?? 1;
    } catch (e) {
      return 1;
    }
  }

  double _getItemPrice(dynamic item) {
    try {
      return (item['total_price'] ?? ((item['price'] ?? 0) * _getItemQty(item))).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  String _getItemImage(dynamic item) {
    try {
      if (item['menu_item_id'] is Map) {
        return item['menu_item_id']['image_url'] ?? item['menu_item_id']['imageUrl'] ?? '';
      }
      if (item['combo_id'] is Map) {
        return item['combo_id']['image_url'] ?? item['combo_id']['imageUrl'] ?? '';
      }
      return item['image_url'] ?? item['imageUrl'] ?? '';
    } catch (e) {
      return '';
    }
  }

  double _getTotalAmount() {
    try {
      return (order['final_total'] ?? 
              order['grand_total'] ?? 
              order['cart_id']?['grand_total'] ?? 
              order['totalAmount'] ?? 
              order['amount'] ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  Widget _imgPlaceholder() {
    return Container(
      color: _grey100,
      child: Center(
        child: Icon(Icons.restaurant_rounded, size: 20, color: _grey400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderId = order['order_id'] ?? '';
    final totalAmount = _getTotalAmount();
    final status = order['status'] ?? 'Pending';
    final isCancelled = status.toLowerCase() == 'cancelled';
    final statusText = _getStatusText(status);
    final orderItems = _getOrderItems();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grey200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _grey200.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCancelled ? null : () {
            final itemsList = order['items'] ?? order['cart_id']?['items'] ?? [];
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => OrderDetailsPage(
                order: order,
                items: itemsList,
                orderId: order['_id'],
              ),
            ));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID and Status Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _grey100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${orderId.isNotEmpty ? orderId : (order['_id']?.toString().substring(0, 8) ?? '—')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCancelled ? _grey200 : _primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCancelled ? _grey600 : _white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: _grey200, height: 1),
                const SizedBox(height: 14),

                // Ordered Products List Preview
                ...orderItems.take(3).map((item) {
                  final name = _getItemName(item);
                  final qty = _getItemQty(item);
                  final price = _getItemPrice(item);
                  final imgUrl = _getItemImage(item);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: imgUrl.isNotEmpty
                                ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => _imgPlaceholder())
                                : _imgPlaceholder(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$qty x $name',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _darkGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _black,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                if (orderItems.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 10),
                    child: Text(
                      '+ ${orderItems.length - 3} more items...',
                      style: TextStyle(
                        fontSize: 12,
                        color: _grey500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 6),
                Divider(color: _grey200, height: 1),
                const SizedBox(height: 12),

                // Total and Details Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(fontSize: 12, color: _grey500, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _black,
                          ),
                        ),
                      ],
                    ),
                    if (!isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: _white,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== ORDER DETAILS PAGE ====================
class OrderDetailsPage extends StatefulWidget {
  final dynamic order;
  final dynamic items;
  final String? orderId;

  const OrderDetailsPage({super.key, required this.order, required this.items, this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late dynamic _order;
  late dynamic _items;

  // Black & Grey color scheme with primary
  static const Color _primary = Color(0xFF1E3A5F);
  static const Color _black = Color(0xFF000000);
  static const Color _darkGrey = Color(0xFF1A1A1A);
  static const Color _grey700 = Color(0xFF4A4A4A);
  static const Color _grey600 = Color(0xFF6B6B6B);
  static const Color _grey500 = Color(0xFF8A8A8A);
  static const Color _grey400 = Color(0xFFB0B0B0);
  static const Color _grey300 = Color(0xFFD0D0D0);
  static const Color _grey200 = Color(0xFFE8E8E8);
  static const Color _grey100 = Color(0xFFF5F5F5);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF8F8F8);

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _items = widget.items;
  }

  String _getItemName(dynamic item) {
    try {
      if (item == null) return 'Item';
      if (item['menu_item_id'] is Map) {
        return item['menu_item_id']['name'] ?? 'Item';
      }
      if (item['combo_id'] is Map) {
        return item['combo_id']['name'] ?? 'Combo';
      }
      return item['name'] ?? item['productName'] ?? 'Item';
    } catch (e) {
      return 'Item';
    }
  }

  String _getItemImage(dynamic item) {
    try {
      if (item == null) return '';
      if (item['menu_item_id'] is Map) {
        return item['menu_item_id']['image_url'] ?? item['menu_item_id']['imageUrl'] ?? '';
      }
      if (item['combo_id'] is Map) {
        return item['combo_id']['image_url'] ?? item['combo_id']['imageUrl'] ?? '';
      }
      return item['image_url'] ?? item['imageUrl'] ?? '';
    } catch (e) {
      return '';
    }
  }

  double _getItemPrice(dynamic item) {
    try { 
      if (item['price'] != null) return (item['price']).toDouble();
      if (item['total_price'] != null && item['quantity'] != null) {
        return (item['total_price'] / item['quantity']).toDouble();
      }
      return 0.0;
    } catch (e) { 
      return 0.0; 
    }
  }

  int _getItemQuantity(dynamic item) {
    try { return item['quantity'] ?? 1; } catch (e) { return 1; }
  }

  double _getTotalAmount() {
    try {
      return (widget.order['final_total'] ?? 
              widget.order['grand_total'] ?? 
              widget.order['cart_id']?['grand_total'] ?? 
              0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  String _formatDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      return DateFormat('d MMM yyyy, h:mm a').format(dt);
    } catch (_) {
      return d;
    }
  }

  List<dynamic> _getItemAddons(dynamic item) {
    try {
      if (item['menu_item_id'] is Map) {
        var addons = item['menu_item_id']['addons'];
        if (addons is List) {
          return addons;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _order['order_id'] ?? '';
    final orderDate = _order['createdAt'] ?? _order['orderDate'];
    final totalAmount = _getTotalAmount();
    final status = _order['status'] ?? 'Pending';
    final payMode = _order['payment_mode'] ?? 'N/A';
    final remark = _order['remark'] ?? 'No remarks';
    final subtotal = (_order['subtotal'] ?? 0).toDouble();
    final netAmount = (_order['net_amount'] ?? totalAmount).toDouble();

    dynamic customer = _order['customer_id'];
    String custName = customer is Map ? customer['full_name'] ?? 'N/A' : 'N/A';
    String custPhone = customer is Map ? customer['phone'] ?? 'N/A' : 'N/A';

    dynamic store = _order['store_id'];
    String sName = store is Map ? store['name'] ?? 'N/A' : 'N/A';
    String sAddr = store is Map ? store['address'] ?? 'N/A' : 'N/A';

    List<dynamic> itemsList = [];
    if (_items is List) {
      itemsList = _items;
    } else if (_items != null) {
      itemsList = [_items];
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: _white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        title: Text(
          orderId.isNotEmpty ? 'Order #$orderId' : 'Order Details',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Order Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _grey200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _white),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(orderDate),
                        style: TextStyle(fontSize: 11, color: _grey500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: TextStyle(fontSize: 13, color: _grey600)),
                      Text('\$${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _darkGrey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Order Items
            if (itemsList.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _grey200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Items',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkGrey)),
                      const SizedBox(height: 12),
                      ...itemsList.map((item) {
                        String name = _getItemName(item);
                        int qty = _getItemQuantity(item);
                        double price = _getItemPrice(item);
                        double itemTotal = price * qty;
                        
                        List<dynamic> addons = _getItemAddons(item);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 44, height: 44,
                                      child: _getItemImage(item).isNotEmpty
                                          ? Image.network(_getItemImage(item), fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: _grey100, child: Icon(Icons.restaurant_rounded, size: 20, color: _grey400)))
                                          : Container(color: _grey100, child: Icon(Icons.restaurant_rounded, size: 20, color: _grey400)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkGrey)),
                                        Text('Qty: $qty',
                                            style: TextStyle(fontSize: 12, color: _grey600)),
                                      ],
                                    ),
                                  ),
                                  Text('\$${itemTotal.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _black)),
                                ],
                              ),
                              // Show Addons
                              if (addons.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 46, top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Addons:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _grey600,
                                        ),
                                      ),
                                      ...addons.map((addon) {
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 8, top: 2),
                                          child: Text(
                                            '• ${addon['name'] ?? ''} (\$${(addon['price'] ?? 0).toStringAsFixed(2)})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _grey500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              if (item['special_instructions'] != null && item['special_instructions'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 46, top: 4),
                                  child: Text(
                                    'Note: ${item['special_instructions']}',
                                    style: TextStyle(fontSize: 10, color: _grey600, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(height: 20),
                      if (subtotal > 0 && subtotal != totalAmount) 
                        _priceRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
                      if (subtotal > 0 && subtotal != totalAmount) 
                        const SizedBox(height: 4),
                      _priceRow('Net Amount', '\$${netAmount.toStringAsFixed(2)}', bold: true),
                      const SizedBox(height: 4),
                      _priceRow('Payment', payMode),
                      if (_order['delivery_charge'] != null && _order['delivery_charge'] > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _priceRow('Delivery', '\$${(_order['delivery_charge'] ?? 0).toStringAsFixed(2)}'),
                        ),
                      if (_order['coupon_discount'] != null && _order['coupon_discount'] > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _priceRow('Coupon', '-\$${(_order['coupon_discount'] ?? 0).toStringAsFixed(2)}'),
                        ),
                      if (_order['loyalty_discount'] != null && _order['loyalty_discount'] > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _priceRow('Loyalty', '-\$${(_order['loyalty_discount'] ?? 0).toStringAsFixed(2)}'),
                        ),
                      if (_order['addons_total'] != null && _order['addons_total'] > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _priceRow('Add-ons', '\$${(_order['addons_total'] ?? 0).toStringAsFixed(2)}'),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Customer Info
            Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _grey200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkGrey)),
                    const SizedBox(height: 12),
                    _infoRow('Name', custName, Icons.person_rounded),
                    _infoRow('Phone', custPhone, Icons.phone_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Store Info
            Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _grey200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Store',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkGrey)),
                    const SizedBox(height: 12),
                    _infoRow('Name', sName, Icons.store_rounded),
                    _infoRow('Address', sAddr, Icons.location_on_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Additional Info
            if (remark != 'No remarks' && remark != null && remark.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _grey200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Additional',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkGrey)),
                      const SizedBox(height: 8),
                      _infoRow('Remarks', remark, Icons.notes_rounded),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: bold ? _darkGrey : _grey600,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? _darkGrey : _grey600)),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: _grey100, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 14, color: _primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(label, style: TextStyle(fontSize: 12, color: _grey600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _darkGrey)),
          ),
        ],
      ),
    );
  }
}