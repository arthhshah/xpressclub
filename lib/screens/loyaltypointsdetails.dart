import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:food/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoyaltyPointsDetailPage extends StatefulWidget {
  const LoyaltyPointsDetailPage({super.key});

  @override
  State<LoyaltyPointsDetailPage> createState() => _LoyaltyPointsDetailPageState();
}

class _LoyaltyPointsDetailPageState extends State<LoyaltyPointsDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _loyaltyData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLoyaltyDetails();
  }

  Future<void> _fetchLoyaltyDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Please login to view loyalty points';
        });
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final url = 'http://142.54.168.26:5050/api/loyalty/account/$userId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (authProvider.token != null)
            'Authorization': 'Bearer ${authProvider.token}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          setState(() {
            _loyaltyData = decoded['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load loyalty data';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load loyalty data';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not connect to server';
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchLoyaltyDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Loyalty Points',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLoyaltyDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color(0xFF1E3A5F),
                  backgroundColor: Colors.white,
                  strokeWidth: 3,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balance Card
                        _buildBalanceCard(),
                        const SizedBox(height: 20),
                        // Quick Stats Grid
                        _buildStatsGrid(),
                        const SizedBox(height: 24),
                        // Timeline Section
                        _buildTimelineSection(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBalanceCard() {
    final data = _loyaltyData!;
    final balancePoints = data['balance_points'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Points Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$balancePoints',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Active Points: ${_loyaltyData?['expiry_summary']?['active'] ?? 0}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final data = _loyaltyData!;
    final lifetimeEarned = data['lifetime_earned'] ?? 0;
    final lifetimeRedeemed = data['lifetime_redeemed'] ?? 0;
    final lifetimeExpired = data['lifetime_expired'] ?? 0;
    final expirySummary = data['expiry_summary'] ?? {};

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Lifetime Earned',
            '$lifetimeEarned',
            Icons.trending_up,
            Colors.green,
            'Total points earned',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Lifetime Redeemed',
            '$lifetimeRedeemed',
            Icons.swap_horiz,
            Colors.orange,
            'Total points used',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final data = _loyaltyData!;
    final transactions = data['transactions'] ?? {};
    final earnedList = transactions['earned'] as List? ?? [];
    final redeemedList = transactions['redeemed'] as List? ?? [];

    // Combine all transactions
    List<Map<String, dynamic>> allTransactions = [];

    // Add earned transactions
    for (var item in earnedList) {
      allTransactions.add({
        ...item,
        'type': 'earned',
        'points': item['points'] ?? 0,
        'date': item['created_at'] ?? '',
        'orderId': item['order']?['order_id'] ?? '',
        'orderDate': item['order']?['created_at'] ?? '',
      });
    }

    // Add redeemed transactions
    for (var item in redeemedList) {
      allTransactions.add({
        ...item,
        'type': 'redeemed',
        'points': item['points'] ?? 0,
        'date': item['created_at'] ?? '',
        'orderId': item['order']?['order_id'] ?? '',
        'orderDate': item['order']?['created_at'] ?? '',
      });
    }

    // Sort by date (newest first)
    allTransactions.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    if (allTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allTransactions.length > 20 ? 20 : allTransactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = allTransactions[index];
              final isEarned = item['type'] == 'earned';
              final points = item['points'] ?? 0;
              final orderId = item['orderId'] ?? '';
              final date = item['date'] ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Icon with circle background
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isEarned ? Colors.green.shade50 : Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isEarned ? Icons.add_circle : Icons.remove_circle,
                        color: isEarned ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${isEarned ? '+' : '-'}$points points',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isEarned ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (orderId.isNotEmpty)
                            Text(
                              'Order #$orderId',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (allTransactions.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Showing last 20 of ${allTransactions.length} transactions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}