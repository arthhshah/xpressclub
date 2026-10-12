import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food/screens/cartscreen.dart';
import 'package:food/screens/myorders.dart';
import 'package:food/screens/settingsscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartManager {
  static final ValueNotifier<int> cartCount = ValueNotifier<int>(0);

  static Future<void> updateCartCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId');
      final storeId = prefs.getString('store_id');

      if (customerId != null && storeId != null && customerId.isNotEmpty && storeId.isNotEmpty) {
        final response = await CartApiService.fetchCart(customerId, storeId);
        if (response.success && response.data != null) {
          final newCount = response.data!.totalItems > 0
              ? response.data!.totalItems
              : response.data!.items.length;
          if (cartCount.value != newCount) {
            cartCount.value = newCount;
          }
        }
      }
    } catch (e) {
      // Ignore silently
    }
  }
}

class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final String? storeId;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.storeId,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> with WidgetsBindingObserver {
  Timer? _bgRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CartManager.updateCartCount();

    // Background refresh timer every 4 seconds to keep cart badge in sync automatically via API call
    _bgRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      CartManager.updateCartCount();
    });
  }

  @override
  void dispose() {
    _bgRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CartManager.updateCartCount();
    }
  }

  @override
  void didUpdateWidget(AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    CartManager.updateCartCount();
  }

  void _navigateToScreen(BuildContext context, int index) async {
    // Already on this tab → do nothing
    if (index == widget.currentIndex) return;

    switch (index) {
      case 0: // Home
        Navigator.popUntil(context, (route) => route.isFirst);
        break;

      case 1: // Cart
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
        CartManager.updateCartCount();
        break;

      case 2: // Orders
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyOrderScreen()),
        );
        break;

      case 3: // Settings
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E293B).withOpacity(0.95),
                const Color(0xFF0F172A).withOpacity(0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 35,
                spreadRadius: 5,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.06),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E293B).withOpacity(0.92),
                      const Color(0xFF0F172A).withOpacity(0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(context, 0, Icons.home_rounded, 'Home'),
                      _buildNavItem(context, 1, Icons.shopping_cart_rounded, 'Cart'),
                      _buildNavItem(context, 2, Icons.shopping_bag_rounded, 'Orders'),
                      _buildNavItem(context, 3, Icons.settings_rounded, 'Settings'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final bool isSelected = widget.currentIndex == index;

    return Expanded(
      flex: isSelected ? 2 : 1,
      child: index == 1
          ? ValueListenableBuilder<int>(
              valueListenable: CartManager.cartCount,
              builder: (context, count, child) {
                return _NavItem(
                  icon: icon,
                  label: label,
                  isSelected: isSelected,
                  badgeCount: count,
                  onTap: () => _navigateToScreen(context, index),
                );
              },
            )
          : _NavItem(
              icon: icon,
              label: label,
              isSelected: isSelected,
              badgeCount: 0,
              onTap: () => _navigateToScreen(context, index),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  static const Color _orange = Color(0xFFFF6B35);
  static const Color _white = Colors.white;
  static const Color _unselectedTextAndIcon = Color(0xB3FFFFFF);

  // Highlighter size — tweak these to resize
  // Bigger inset = smaller pill, smaller inset = bigger pill
  static const double _highlightInset = 22;
  static const double _highlightHeight = 48;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSelected)
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              height: _highlightHeight,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: _highlightInset),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        icon,
                        color: isSelected ? _orange : _unselectedTextAndIcon,
                        size: isSelected ? 26 : 24,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -6,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
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
                const SizedBox(height: 3),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  opacity: isSelected ? 1.0 : 0.7,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    style: TextStyle(
                      fontSize: isSelected ? 11 : 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? _white : _unselectedTextAndIcon,
                      letterSpacing: isSelected ? 0.5 : 0,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
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
