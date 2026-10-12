// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food/config/api_config.dart';
import 'package:food/screens/cartscreen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

class LoyaltyAccount {
  final String userId;
  final int balancePoints;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final bool isRedeemEnabled;
  final bool isEarnEnabled;
  final int maxRedeemPercent;
  final int pointsIfOrderPlaced;
  final int maxRedeemablePoints;
  final double maxRedeemableDiscount;

  LoyaltyAccount({
    required this.userId,
    required this.balancePoints,
    required this.lifetimeEarned,
    required this.lifetimeRedeemed,
    required this.isRedeemEnabled,
    required this.isEarnEnabled,
    required this.maxRedeemPercent,
    required this.pointsIfOrderPlaced,
    required this.maxRedeemablePoints,
    required this.maxRedeemableDiscount,
  });

  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) {
    return LoyaltyAccount(
      userId: json['user_id']?.toString() ?? '',
      balancePoints: json['balance_points'] ?? 0,
      lifetimeEarned: json['lifetime_earned'] ?? 0,
      lifetimeRedeemed: json['lifetime_redeemed'] ?? 0,
      isRedeemEnabled: json['is_redeem_enabled'] ?? false,
      isEarnEnabled: json['is_earn_enabled'] ?? false,
      maxRedeemPercent: json['max_redeem_percent'] ?? 0,
      pointsIfOrderPlaced: json['points_if_order_placed'] ?? 0,
      maxRedeemablePoints: json['max_redeemable_points'] ?? 0,
      maxRedeemableDiscount: (json['max_redeemable_discount'] ?? 0).toDouble(),
    );
  }
}

// ==================== REDEEM PREVIEW MODEL ====================

class RedeemPreview {
  final bool success;
  final int pointsToRedeem;
  final double discountAmount;
  final double netAmount;
  final int remainingPoints;
  final String? message;

  RedeemPreview({
    required this.success,
    required this.pointsToRedeem,
    required this.discountAmount,
    required this.netAmount,
    required this.remainingPoints,
    this.message,
  });

  factory RedeemPreview.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return RedeemPreview(
      success: json['success'] == true || json['status'] == 'success',
      pointsToRedeem: data['points_to_redeem'] ?? data['points_redeemed'] ?? 0,
      discountAmount: (data['discount_amount'] ?? data['discount'] ?? 0).toDouble(),
      netAmount: (data['net_amount'] ?? data['final_amount'] ?? 0).toDouble(),
      remainingPoints: data['remaining_points'] ?? data['balance_after_redeem'] ?? 0,
      message: json['message'],
    );
  }
}

// ==================== APPLY REDEMPTION MODEL ====================

class ApplyRedemptionResponse {
  final bool success;
  final int pointsRedeemed;
  final double discountAmount;
  final double netAmount;
  final String? message;

  ApplyRedemptionResponse({
    required this.success,
    required this.pointsRedeemed,
    required this.discountAmount,
    required this.netAmount,
    this.message,
  });

  factory ApplyRedemptionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return ApplyRedemptionResponse(
      success: json['success'] == true || json['status'] == 'success',
      pointsRedeemed: data['points_redeemed'] ?? data['points_to_redeem'] ?? 0,
      discountAmount: (data['discount_amount'] ?? data['discount'] ?? 0).toDouble(),
      netAmount: (data['net_amount'] ?? data['final_amount'] ?? 0).toDouble(),
      message: json['message'],
    );
  }
}

// ==================== ORDER RESPONSE MODEL (for COD) ====================

class OrderRequest {
  final String cartId;
  final double subtotal;
  final String paymentMode;
  final double netAmount;
  final String remark;
  final int? loyaltyPointsRedeemed;
  final double? loyaltyDiscount;

  OrderRequest({
    required this.cartId,
    required this.subtotal,
    required this.paymentMode,
    required this.netAmount,
    required this.remark,
    this.loyaltyPointsRedeemed,
    this.loyaltyDiscount,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'subtotal': subtotal,
      'payment_mode': paymentMode,
      'net_amount': netAmount,
      'remark': remark,
      if (loyaltyPointsRedeemed != null && loyaltyPointsRedeemed! > 0)
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
      if (loyaltyDiscount != null && loyaltyDiscount! > 0)
        'loyalty_discount': loyaltyDiscount,
    };
  }
}

class OrderResponse {
  final bool success;
  final String? orderId;
  final String? message;
  final Map<String, dynamic>? data;

  OrderResponse({
    required this.success,
    this.orderId,
    this.message,
    this.data,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    String? orderId;
    if (data is Map<String, dynamic>) {
      orderId = data['order_id']?.toString();
    }
    return OrderResponse(
      success: json['success'] == true || json['status'] == 'success',
      orderId: orderId ?? json['order_id']?.toString() ?? json['orderId']?.toString(),
      message: json['message'],
      data: json,
    );
  }
}

// ==================== ONLINE ORDER MODELS ====================

class OnlineOrderRequest {
  final String cartId;
  final double subtotal;
  final double netAmount;
  final String remark;
  final int loyaltyPointsRedeemed;
  final double loyaltyDiscount;
  final double deliveryCharge;
  final double taxAmount;
  final String couponCode;
  final double couponDiscount;
  final bool saveCard;

  OnlineOrderRequest({
    required this.cartId,
    required this.subtotal,
    required this.netAmount,
    required this.remark,
    this.loyaltyPointsRedeemed = 0,
    this.loyaltyDiscount = 0,
    this.deliveryCharge = 0,
    this.taxAmount = 0,
    this.couponCode = '',
    this.couponDiscount = 0,
    this.saveCard = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'subtotal': subtotal,
      'net_amount': netAmount,
      'remark': remark,
      'loyalty_points_redeemed': loyaltyPointsRedeemed,
      'loyalty_discount': loyaltyDiscount,
      'delivery_charge': deliveryCharge,
      'tax_amount': taxAmount,
      'coupon_code': couponCode,
      'coupon_discount': couponDiscount,
      'save_card': saveCard,
    };
  }
}

class OnlineOrderResponse {
  final bool success;
  final String? message;
  final String? orderId;
  final double? amount;
  final String? orderStatus;
  final PaymentData? paymentData;

  OnlineOrderResponse({
    required this.success,
    this.message,
    this.orderId,
    this.amount,
    this.orderStatus,
    this.paymentData,
  });

  factory OnlineOrderResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final order = data['order'] ?? {};
    final payment = data['payment'] ?? {};

    return OnlineOrderResponse(
      success: json['success'] == true,
      message: json['message'],
      orderId: order['order_id'],
      amount: (order['amount'] ?? 0).toDouble(),
      orderStatus: order['status'],
      paymentData: PaymentData.fromJson(payment),
    );
  }
}

class PaymentData {
  final String clientSecret;
  final String paymentIntentId;
  final String publishableKey;
  final String transactionId;

  PaymentData({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.publishableKey,
    required this.transactionId,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      clientSecret: json['clientSecret'] ?? '',
      paymentIntentId: json['paymentIntentId'] ?? '',
      publishableKey: json['publishableKey'] ?? '',
      transactionId: json['transactionId'] ?? '',
    );
  }
}

// ==================== CONFIRM PAYMENT MODELS ====================

class ConfirmPaymentRequest {
  final String paymentIntentId;
  final String transactionId;

  ConfirmPaymentRequest({
    required this.paymentIntentId,
    required this.transactionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'payment_intent_id': paymentIntentId,
      'transaction_id': transactionId,
    };
  }
}

class ConfirmPaymentResponse {
  final bool success;
  final String? message;
  final String? status;
  final TransactionData? transaction;

  ConfirmPaymentResponse({
    required this.success,
    this.message,
    this.status,
    this.transaction,
  });

  factory ConfirmPaymentResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final transaction = data['transaction'] ?? {};

    return ConfirmPaymentResponse(
      success: json['success'] == true,
      message: json['message'],
      status: data['status'],
      transaction: TransactionData.fromJson(transaction),
    );
  }
}

class TransactionData {
  final String? id;
  final String? paymentIntentId;
  final double? amount;
  final String? status;
  final String? paidAt;

  TransactionData({
    this.id,
    this.paymentIntentId,
    this.amount,
    this.status,
    this.paidAt,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      id: json['_id'],
      paymentIntentId: json['payment_intent_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'],
      paidAt: json['paid_at'],
    );
  }
}

// ==================== API SERVICE ====================

class LoyaltyApiService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<LoyaltyAccount?> getLoyaltyAccount(String userId) async {
    final url = '$baseUrl/api/loyalty/account/$userId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final accountData = jsonResponse['data'] ?? jsonResponse;
        return LoyaltyAccount.fromJson(accountData);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching loyalty account: $e');
      return null;
    }
  }

  static Future<RedeemPreview?> getRedeemPreview({
    required String customerId,
    required String storeId,
    required int pointsToRedeem,
  }) async {
    final url = '$baseUrl/api/cart/redeem-preview';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customer_id': customerId,
          'store_id': storeId,
          'points_to_redeem': pointsToRedeem,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return RedeemPreview.fromJson(jsonResponse);
      } else {
        print('Redeem preview error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching redeem preview: $e');
      return null;
    }
  }

  static Future<ApplyRedemptionResponse?> applyRedemption({
    required String customerId,
    required String storeId,
    required int pointsToRedeem,
  }) async {
    final url = '$baseUrl/api/cart/apply-redemption';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customer_id': customerId,
          'store_id': storeId,
          'points_to_redeem': pointsToRedeem,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApplyRedemptionResponse.fromJson(jsonResponse);
      } else {
        print('Apply redemption error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error applying redemption: $e');
      return null;
    }
  }
}

class CheckoutApiService {
  static const String baseUrl = ApiConfig.baseUrl;

  // COD Order
  static Future<OrderResponse> createOrder(OrderRequest orderRequest) async {
    final url = '$baseUrl/api/order/create-order';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderRequest.toJson()),
      ).timeout(const Duration(seconds: 30));

      print('📤 Order Request: ${orderRequest.toJson()}');
      print('📥 Order Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        return OrderResponse.fromJson(jsonResponse);
      } else {
        return OrderResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Order Error: $e');
      return OrderResponse(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // Online Order with Stripe
  static Future<OnlineOrderResponse> createOnlineOrder(OnlineOrderRequest orderRequest) async {
    final url = '$baseUrl/api/order/create-online-order';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderRequest.toJson()),
      ).timeout(const Duration(seconds: 30));

      print('📤 Online Order Request: ${orderRequest.toJson()}');
      print('📥 Online Order Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        return OnlineOrderResponse.fromJson(jsonResponse);
      } else {
        return OnlineOrderResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Online Order Error: $e');
      return OnlineOrderResponse(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // Confirm Payment
  static Future<ConfirmPaymentResponse> confirmPayment({
    required String paymentIntentId,
    required String transactionId,
  }) async {
    final url = '$baseUrl/api/order/confirm-payment';

    try {
      final request = ConfirmPaymentRequest(
        paymentIntentId: paymentIntentId,
        transactionId: transactionId,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      print('📤 Confirm Payment Request: ${request.toJson()}');
      print('📥 Confirm Payment Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        return ConfirmPaymentResponse.fromJson(jsonResponse);
      } else {
        return ConfirmPaymentResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Confirm Payment Error: $e');
      return ConfirmPaymentResponse(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // Get Payment Status
  static Future<Map<String, dynamic>> getPaymentStatus(String paymentIntentId) async {
    final url = '$baseUrl/api/transactions/payment-status/$paymentIntentId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': 'Failed to get payment status'};
      }
    } catch (e) {
      print('❌ Get Payment Status Error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Reset Cart (for failed payments)
  static Future<Map<String, dynamic>> resetCart(String cartId) async {
    final url = '$baseUrl/api/order/reset-cart';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'cart_id': cartId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': 'Failed to reset cart'};
      }
    } catch (e) {
      print('❌ Reset Cart Error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Get Store Stripe Config
  static Future<Map<String, dynamic>> getStoreStripeConfig(String storeId) async {
    final url = '$baseUrl/api/store-stripe/store/$storeId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': 'Failed to get store config'};
      }
    } catch (e) {
      print('❌ Get Store Stripe Config Error: $e');
      return {'success': false, 'message': 'Connection error'};
    }
  }
}

// ==================== ORDER SUCCESS SCREEN ====================

class OrderSuccessScreen extends StatefulWidget {
  final String? orderId;
  final double amount;
  final int? pointsEarned;
  final int? pointsRedeemed;
  final String? paymentStatus;

  const OrderSuccessScreen({
    super.key,
    this.orderId,
    required this.amount,
    this.pointsEarned,
    this.pointsRedeemed,
    this.paymentStatus,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = widget.paymentStatus == 'succeeded' || 
                           widget.paymentStatus == 'completed' ||
                           widget.paymentStatus == null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: (isSuccess ? Colors.green : Colors.orange).withOpacity(0.05 * _fadeAnimation.value),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: (isSuccess ? Colors.green : Colors.orange).withOpacity(0.03 * _fadeAnimation.value),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSuccess ? Colors.green : Colors.orange).withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isSuccess 
                                        ? [Colors.green, Colors.green.shade700]
                                        : [Colors.orange, Colors.orange.shade700],
                                  ),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Icon(
                                  isSuccess ? Icons.check : Icons.warning_rounded,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              children: [
                                Text(
                                  isSuccess ? 'ORDER PLACED!' : 'ORDER PENDING',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF132C48),
                                    letterSpacing: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isSuccess 
                                      ? 'Your order has been placed successfully'
                                      : 'Your order is pending payment confirmation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Total Amount: \$${widget.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF132C48),
                                  ),
                                ),
                                if (widget.orderId != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Order ID: ${widget.orderId}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                                if (widget.paymentStatus != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSuccess ? Colors.green[50] : Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSuccess ? Colors.green[200]! : Colors.orange[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      'Payment Status: ${widget.paymentStatus!.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSuccess ? Colors.green[700] : Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                                if (widget.pointsEarned != null || widget.pointsRedeemed != null) ...[
                                  const SizedBox(height: 16),
                                  if (widget.pointsEarned != null && widget.pointsEarned! > 0)
                                    Text(
                                      '✨ You earned ${widget.pointsEarned} points!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.amber[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (widget.pointsRedeemed != null && widget.pointsRedeemed! > 0)
                                    Text(
                                      '🔄 ${widget.pointsRedeemed} points redeemed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF132C48),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'Continue Shopping',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CHECKOUT SCREEN ====================

class CheckoutScreen extends StatefulWidget {
  final String cartId;
  final double grandTotal;
  final List<CartItem> cartItems;
  final String userId;
  final String? storeId;

  const CheckoutScreen({
    super.key,
    required this.cartId,
    required this.grandTotal,
    required this.cartItems,
    required this.userId,
    this.storeId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _remarkController = TextEditingController();
  String _paymentMode = 'COD'; // COD | Online
  bool _isProcessing = false;
  bool _agreeToTerms = false;

  // Loyalty related states
  LoyaltyAccount? _loyaltyAccount;
  bool _isLoadingLoyalty = true;
  bool _applyLoyaltyPoints = false;
  bool _isLoadingRedeemPreview = false;
  String? _redeemPreviewError;
  int _pointsToRedeem = 0;
  double _discountAmount = 0.0;
  double _finalTotal = 0.0;
  int _selectedPointsToRedeem = 50;

  // Payment related states
  bool _saveCard = false;

  static const Color brandColor = Color(0xFF132C48);
  static const Color appBarColor = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    _finalTotal = widget.grandTotal;
    _fetchLoyaltyAccount();
    _initializeStripe();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _initializeStripe() async {
    try {
      // Get store's Stripe configuration
      final prefs = await SharedPreferences.getInstance();
      final storeId = widget.storeId ?? prefs.getString('store_id');
      
      if (storeId != null && storeId.isNotEmpty) {
        final config = await CheckoutApiService.getStoreStripeConfig(storeId);
        if (config['success'] == true && config['data'] != null) {
          final publishableKey = config['data']['publishableKey'];
          if (publishableKey != null && publishableKey.isNotEmpty) {
            Stripe.publishableKey = publishableKey;
            print('✅ Stripe initialized with store key');
          }
        }
      }
    } catch (e) {
      print('⚠️ Stripe initialization warning: $e');
    }
  }

  Future<void> _fetchLoyaltyAccount() async {
    setState(() {
      _isLoadingLoyalty = true;
    });

    final account = await LoyaltyApiService.getLoyaltyAccount(widget.userId);

    if (mounted) {
      setState(() {
        _loyaltyAccount = account;
        _isLoadingLoyalty = false;
        if (account != null && account.balancePoints > 0) {
          _selectedPointsToRedeem = account.balancePoints >= 50 ? 50 : account.balancePoints;
        }
      });
    }
  }

  Future<void> _fetchRedeemPreview() async {
    if (_loyaltyAccount == null || _loyaltyAccount!.balancePoints <= 0) {
      return;
    }

    if (_selectedPointsToRedeem <= 0) {
      setState(() {
        _redeemPreviewError = 'Please select at least 1 point to redeem';
        _applyLoyaltyPoints = false;
      });
      return;
    }

    if (_selectedPointsToRedeem > _loyaltyAccount!.balancePoints) {
      setState(() {
        _redeemPreviewError = 'Not enough points. Available: ${_loyaltyAccount!.balancePoints}';
        _applyLoyaltyPoints = false;
      });
      return;
    }

    setState(() {
      _isLoadingRedeemPreview = true;
      _redeemPreviewError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId') ?? widget.userId;
      final storeId = prefs.getString('store_id') ?? widget.storeId;

      if (storeId == null || storeId.isEmpty) {
        setState(() {
          _isLoadingRedeemPreview = false;
          _redeemPreviewError = 'Store not selected';
          _applyLoyaltyPoints = false;
        });
        return;
      }

      final preview = await LoyaltyApiService.getRedeemPreview(
        customerId: customerId,
        storeId: storeId,
        pointsToRedeem: _selectedPointsToRedeem,
      );

      if (!mounted) return;

      if (preview != null && preview.success) {
        setState(() {
          _pointsToRedeem = preview.pointsToRedeem;
          _discountAmount = preview.discountAmount;
          _finalTotal = preview.netAmount > 0
              ? preview.netAmount
              : (widget.grandTotal - preview.discountAmount).clamp(0, widget.grandTotal);
          _isLoadingRedeemPreview = false;
        });
      } else {
        setState(() {
          _isLoadingRedeemPreview = false;
          _redeemPreviewError = preview?.message ?? 'Could not preview discount';
          _applyLoyaltyPoints = false;
          _pointsToRedeem = 0;
          _discountAmount = 0.0;
          _finalTotal = widget.grandTotal;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRedeemPreview = false;
        _redeemPreviewError = 'Failed to load preview';
        _applyLoyaltyPoints = false;
        _pointsToRedeem = 0;
        _discountAmount = 0.0;
        _finalTotal = widget.grandTotal;
      });
    }
  }

  void _onToggleApplyLoyaltyPoints(bool value) {
    setState(() {
      _applyLoyaltyPoints = value;
    });

    if (value) {
      _fetchRedeemPreview();
    } else {
      setState(() {
        _pointsToRedeem = 0;
        _discountAmount = 0.0;
        _finalTotal = widget.grandTotal;
        _redeemPreviewError = null;
      });
    }
  }

  void _updatePointsToRedeem(int newValue) {
    setState(() {
      _selectedPointsToRedeem = newValue;
    });
    if (_applyLoyaltyPoints) {
      _fetchRedeemPreview();
    }
  }

  // Handle Stripe payment with proper flow
  Future<void> _handleStripePayment() async {
    if (!_agreeToTerms) {
      _showSnackBar('Please agree to the terms and conditions', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Apply loyalty points if enabled
      int loyaltyPointsRedeemed = 0;
      double loyaltyDiscount = 0.0;

      if (_applyLoyaltyPoints && _pointsToRedeem > 0) {
        final prefs = await SharedPreferences.getInstance();
        final customerId = prefs.getString('userId') ?? widget.userId;
        final storeId = prefs.getString('store_id') ?? widget.storeId;

        if (storeId != null && storeId.isNotEmpty) {
          final applyResult = await LoyaltyApiService.applyRedemption(
            customerId: customerId,
            storeId: storeId,
            pointsToRedeem: _pointsToRedeem,
          );

          if (applyResult != null && applyResult.success) {
            loyaltyPointsRedeemed = applyResult.pointsRedeemed;
            loyaltyDiscount = applyResult.discountAmount;
            _discountAmount = applyResult.discountAmount;
            _finalTotal = applyResult.netAmount > 0
                ? applyResult.netAmount
                : _finalTotal;
          }
        }
      }

      // Step 1: Create online order
      final onlineOrderRequest = OnlineOrderRequest(
        cartId: widget.cartId,
        subtotal: widget.grandTotal,
        netAmount: _finalTotal,
        remark: _remarkController.text.trim().isEmpty
            ? 'No remarks'
            : _remarkController.text.trim(),
        loyaltyPointsRedeemed: loyaltyPointsRedeemed,
        loyaltyDiscount: loyaltyDiscount,
        deliveryCharge: 0,
        taxAmount: 0,
        couponCode: '',
        couponDiscount: 0,
        saveCard: _saveCard,
      );

      final response = await CheckoutApiService.createOnlineOrder(onlineOrderRequest);

      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      if (!response.success || response.paymentData == null) {
        setState(() => _isProcessing = false);
        _showSnackBar(
          response.message ?? 'Failed to create order. Please try again.',
          isError: true,
        );
        return;
      }

      final paymentData = response.paymentData!;

      // Set publishable key from server response (per-store Stripe account)
      if (paymentData.publishableKey.isNotEmpty) {
        Stripe.publishableKey = paymentData.publishableKey;
      }
      await Stripe.instance.applySettings();

      // Initialize and present Stripe Payment Sheet
      try {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentData.clientSecret,
            merchantDisplayName: 'HappyXpress',
            style: ThemeMode.light,
          ),
        );

        // Step 3: Present Payment Sheet
        await Stripe.instance.presentPaymentSheet();

        // Step 4: Confirm payment with backend
        final confirmResponse = await CheckoutApiService.confirmPayment(
          paymentIntentId: paymentData.paymentIntentId,
          transactionId: paymentData.transactionId,
        );

        if (mounted) {
          setState(() => _isProcessing = false);

          if (confirmResponse.success && confirmResponse.status == 'succeeded') {
            // Payment successful
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrderSuccessScreen(
                  orderId: response.orderId,
                  amount: response.amount ?? _finalTotal,
                  pointsEarned: _loyaltyAccount?.pointsIfOrderPlaced,
                  pointsRedeemed: loyaltyPointsRedeemed > 0 ? loyaltyPointsRedeemed : null,
                  paymentStatus: 'succeeded',
                ),
              ),
            );
          } else {
            // Payment failed or requires action
            _showSnackBar(
              confirmResponse.message ?? 'Payment verification failed. Please check your order status.',
              isError: true,
            );
          }
        }
      } on StripeException catch (e) {
        print('❌ Stripe Exception: $e');
        if (mounted) {
          setState(() => _isProcessing = false);

          if (e.error.code.toString().toLowerCase().contains('cancel')) {
            _showSnackBar(
              'Payment cancelled. Tap "Pay Online" again to retry.',
              isError: true,
            );
          } else {
            _showSnackBar(
              'Payment error: ${e.error.localizedMessage ?? 'Please try again'}',
              isError: true,
            );
          }
        }
      }
    } on PlatformException catch (e) {
      print('❌ Stripe Platform Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar(
          e.message ?? 'Stripe payment failed. Please restart the app and try again.',
          isError: true,
        );
      }
    } catch (e) {
      print('❌ Payment Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar(
          'Payment error: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _placeOrder() async {
    if (_paymentMode == 'Online') {
      await _handleStripePayment();
      return;
    }

    // Handle COD payment
    if (!_agreeToTerms) {
      _showSnackBar('Please agree to the terms and conditions', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    int loyaltyPointsRedeemed = 0;
    double loyaltyDiscount = 0.0;

    if (_applyLoyaltyPoints && _pointsToRedeem > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final customerId = prefs.getString('userId') ?? widget.userId;
        final storeId = prefs.getString('store_id') ?? widget.storeId;

        if (storeId != null && storeId.isNotEmpty) {
          final applyResult = await LoyaltyApiService.applyRedemption(
            customerId: customerId,
            storeId: storeId,
            pointsToRedeem: _pointsToRedeem,
          );

          if (applyResult == null || !applyResult.success) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
              _showSnackBar(
                applyResult?.message ?? 'Could not apply loyalty points. Please try again.',
                isError: true,
              );
            }
            return;
          }

          loyaltyPointsRedeemed = applyResult.pointsRedeemed;
          loyaltyDiscount = applyResult.discountAmount;
          _discountAmount = applyResult.discountAmount;
          _finalTotal = applyResult.netAmount > 0
              ? applyResult.netAmount
              : _finalTotal;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          _showSnackBar('Could not apply loyalty points. Please try again.', isError: true);
        }
        return;
      }
    }

    final orderRequest = OrderRequest(
      cartId: widget.cartId,
      subtotal: widget.grandTotal,
      paymentMode: _paymentMode,
      netAmount: _finalTotal,
      remark: _remarkController.text.trim().isEmpty
          ? 'No remarks'
          : _remarkController.text.trim(),
      loyaltyPointsRedeemed: loyaltyPointsRedeemed > 0 ? loyaltyPointsRedeemed : null,
      loyaltyDiscount: loyaltyDiscount > 0 ? loyaltyDiscount : null,
    );

    final response = await CheckoutApiService.createOrder(orderRequest);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (response.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderId: response.orderId,
              amount: _finalTotal,
              pointsEarned: _loyaltyAccount?.pointsIfOrderPlaced,
              pointsRedeemed: loyaltyPointsRedeemed > 0 ? loyaltyPointsRedeemed : null,
              paymentStatus: 'completed',
            ),
          ),
        );
      } else {
        _showSnackBar(
          response.message ?? 'Failed to place order. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.cartItems.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(itemCount),
                _buildPaymentMethod(),
                _buildLoyaltySection(),
                _buildRemarksSection(),
                _buildTermsAndConditions(),
                const SizedBox(height: 24),
                _buildPayButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing your order...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF132C48),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildOrderSummary(int itemCount) {
    return _sectionCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Order Summary'),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cartItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = widget.cartItems[index];
              return Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.fastfood_outlined,
                                size: 18,
                                color: brandColor,
                              ),
                            )
                          : Icon(
                              Icons.fastfood_outlined,
                              size: 18,
                              color: brandColor,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty ${item.quantity}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal ($itemCount items)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                '\$${widget.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (_applyLoyaltyPoints && _discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Loyalty discount',
                  style: TextStyle(fontSize: 14, color: Colors.green[700]),
                ),
                Text(
                  '-\$${_discountAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '\$${_finalTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: brandColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Payment Method'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: brandColor.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(12),
              color: brandColor.withOpacity(0.04),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  RadioListTile<String>(
                  value: 'COD',
                  groupValue: _paymentMode,
                  onChanged: (value) {
                    setState(() {
                      _paymentMode = value!;
                    });
                  },
                  title: const Text(
                    'Cash on Delivery (COD)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Pay when you receive your order',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeColor: brandColor,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'Online',
                  groupValue: _paymentMode,
                  onChanged: (value) {
                    setState(() {
                      _paymentMode = value!;
                    });
                  },
                  title: const Text(
                    'Pay Online',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Credit/Debit Card via Stripe',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeColor: brandColor,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                ],
              ),
            ),
          ),
          if (_paymentMode == 'Online') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _saveCard,
                    onChanged: (value) {
                      setState(() {
                        _saveCard = value ?? false;
                      });
                    },
                    activeColor: brandColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Save card for future payments',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoyaltySection() {
    if (_isLoadingLoyalty) {
      return _sectionCard(
        child: Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading loyalty points...',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_loyaltyAccount == null) {
      return _sectionCard(
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.orange[400], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Loyalty points unavailable right now',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _fetchLoyaltyAccount,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    final bool hasPoints = _loyaltyAccount!.balancePoints > 0;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.star_rounded, color: Colors.amber[700], size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_loyaltyAccount!.balancePoints} points available',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (!hasPoints)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Earn points on this order',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                  ],
                ),
              ),
              if (_isLoadingRedeemPreview)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Checkbox(
                  value: _applyLoyaltyPoints && hasPoints,
                  onChanged: hasPoints
                      ? (value) => _onToggleApplyLoyaltyPoints(value ?? false)
                      : null,
                  activeColor: brandColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          if (_applyLoyaltyPoints && hasPoints && !_isLoadingRedeemPreview) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Points to redeem',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_selectedPointsToRedeem pts',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF132C48),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _selectedPointsToRedeem.toDouble(),
                    min: 50.0,
                    max: _loyaltyAccount!.balancePoints.toDouble(),
                    divisions: 10,
                    label: '$_selectedPointsToRedeem points',
                    onChanged: (value) {
                      _updatePointsToRedeem(value.round());
                    },
                    activeColor: brandColor,
                    inactiveColor: Colors.grey[300],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Min: 50 pts',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      Text(
                        'Max: ${_loyaltyAccount!.balancePoints} pts',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_redeemPreviewError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.red[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _redeemPreviewError!,
                        style: TextStyle(fontSize: 12.5, color: Colors.red[600]),
                      ),
                    ),
                  ],
                ),
              )
            else if (_discountAmount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You save',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '-\$${_discountAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemarksSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Additional Remarks'),
          const SizedBox(height: 10),
          TextField(
            controller: _remarkController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'E.g., extra ketchup, no onions...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: brandColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Checkbox(
            value: _agreeToTerms,
            onChanged: (value) {
              setState(() {
                _agreeToTerms = value ?? false;
              });
            },
            activeColor: brandColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'I agree to the terms and conditions',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    final bool isOnlinePayment = _paymentMode == 'Online';
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOnlinePayment ? const Color(0xFF635BFF) : brandColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                isOnlinePayment
                    ? 'Pay Online  •  \$${_finalTotal.toStringAsFixed(2)}'
                    : (_applyLoyaltyPoints && _discountAmount > 0
                        ? 'Place Order (COD)  •  Save \$${_discountAmount.toStringAsFixed(2)}'
                        : 'Place Order (COD)'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}