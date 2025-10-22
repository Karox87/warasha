import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Map<String, double> _financialReport = {};
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _topSellingProducts = [];
  
  // ئامارەکانی ئەمڕۆ و ئەم مانگە
  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  double _monthSales = 0.0;
  double _monthProfit = 0.0;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // وەرگرتنی هەموو داتاکان
      _financialReport = await _dbHelper.getFinancialReport();
      _products = await _dbHelper.getProducts();
      
      // حیساب کردنی ئامارەکانی ئەمڕۆ و ئەم مانگە
      await _calculateDailyAndMonthlyStats();
      
      // دۆزینەوەی بەرزترین کاڵا فرۆشراوەکان
      await _calculateTopSellingProducts();
      
    } catch (e) {
      print('هەڵە لە بارکردنی داتا: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateDailyAndMonthlyStats() async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final monthStart = DateTime(now.year, now.month, 1);
      final monthStartStr = DateFormat('yyyy-MM-dd').format(monthStart);

      // ئامارەکانی ئەمڕۆ
      final todaySalesResult = await db.rawQuery('''
        SELECT 
          SUM(s.total) as total_sales,
          SUM((s.price - p.buy_price) * s.quantity) as total_profit
        FROM sales s
        LEFT JOIN products p ON s.product_id = p.id
        WHERE date(s.date) = ?
      ''', [today]);

      if (todaySalesResult.isNotEmpty && todaySalesResult.first['total_sales'] != null) {
        _todaySales = (todaySalesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;
        _todayProfit = (todaySalesResult.first['total_profit'] as num?)?.toDouble() ?? 0.0;
      }

      // ئامارەکانی ئەم مانگە
      final monthSalesResult = await db.rawQuery('''
        SELECT 
          SUM(s.total) as total_sales,
          SUM((s.price - p.buy_price) * s.quantity) as total_profit
        FROM sales s
        LEFT JOIN products p ON s.product_id = p.id
        WHERE date(s.date) >= ?
      ''', [monthStartStr]);

      if (monthSalesResult.isNotEmpty && monthSalesResult.first['total_sales'] != null) {
        _monthSales = (monthSalesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;
        _monthProfit = (monthSalesResult.first['total_profit'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('هەڵە لە حیسابکردنی ئامار: $e');
    }
  }

  Future<void> _calculateTopSellingProducts() async {
    try {
      final db = await _dbHelper.database;
      
      final result = await db.rawQuery('''
        SELECT 
          p.id,
          p.name,
          p.sell_price,
          p.buy_price,
          SUM(s.quantity) as total_sold,
          SUM(s.total) as total_revenue,
          SUM((s.price - p.buy_price) * s.quantity) as total_profit
        FROM sales s
        LEFT JOIN products p ON s.product_id = p.id
        WHERE p.id IS NOT NULL
        GROUP BY p.id
        ORDER BY total_sold DESC
        LIMIT 5
      ''');

      _topSellingProducts = result.map((row) {
        return {
          'name': row['name'] ?? 'نەناسراو',
          'total_sold': (row['total_sold'] as num?)?.toInt() ?? 0,
          'total_revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
          'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0.0,
          'sell_price': (row['sell_price'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      print('هەڵە لە حیسابکردنی بەرزترین کاڵا: $e');
    }
  }

  String _formatNumber(double number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final totalPurchases = _financialReport['totalPurchases'] ?? 0.0;
    final totalSales = _financialReport['totalSales'] ?? 0.0;
    final totalDebts = _financialReport['totalDebts'] ?? 0.0;
    final profit = _financialReport['profit'] ?? 0.0;
    
    double inventoryValue = 0;
    for (var product in _products) {
      inventoryValue += (product['buy_price'] as double) * (product['quantity'] as int);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرت گشتی'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'نوێکردنەوە',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // کارتەکانی ئەمڕۆ و ئەم مانگە
                    _buildTimeBasedStats(),
                    const SizedBox(height: 16),
                    
                    // کارتی قازانج گشتی
                    _buildMainProfitCard(profit),
                    const SizedBox(height: 16),
                    
                    // ئاماری گشتی
                    _buildSectionTitle('ئاماری گشتی'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'کۆی کڕین',
                            totalPurchases,
                            Icons.shopping_cart,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'کۆی فرۆشتن',
                            totalSales,
                            Icons.sell,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'کۆی قەرز',
                            totalDebts,
                            Icons.account_balance_wallet,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'نرخی کۆگا',
                            inventoryValue,
                            Icons.inventory,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // بەرزترین کاڵا فرۆشراوەکان
                    _buildSectionTitle('بەرزترین کاڵا فرۆشراوەکان'),
                    _buildTopSellingProducts(),
                    const SizedBox(height: 24),
                    
                    // ئاماری کاڵاکان
                    _buildSectionTitle('ئاماری کاڵاکان'),
                    _buildProductsStats(),
                    const SizedBox(height: 24),
                    
                    // کاڵای کەم لە کۆگا
                    _buildSectionTitle('کاڵای کەم لە کۆگا'),
                    _buildLowStockProducts(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimeBasedStats() {
    return Column(
      children: [
        // ئامارەکانی ئەمڕۆ
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.today, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'فرۆشتنی ئەمڕۆ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white30, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildMiniStatCard(
                      'فرۆشتن',
                      _todaySales,
                      Icons.sell,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard(
                      'قازانج',
                      _todayProfit,
                      Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // ئامارەکانی ئەم مانگە
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade400, Colors.purple.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.shade200,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'فرۆشتنی ${DateFormat('MMMM').format(DateTime.now())}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white30, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildMiniStatCard(
                      'فرۆشتن',
                      _monthSales,
                      Icons.sell,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatCard(
                      'قازانج',
                      _monthProfit,
                      Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, double value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatNumber(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'IQD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingProducts() {
    if (_topSellingProducts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'هیچ فرۆشتنێک نییە',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topSellingProducts.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = _topSellingProducts[index];
          final rank = index + 1;
          Color rankColor;
          
          switch (rank) {
            case 1:
              rankColor = Colors.amber.shade700;
              break;
            case 2:
              rankColor = Colors.grey.shade600;
              break;
            case 3:
              rankColor = Colors.brown.shade400;
              break;
            default:
              rankColor = Colors.blue.shade400;
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: rankColor.withOpacity(0.2),
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              product['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'فرۆشراو: ${product['total_sold']} دانە',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'قازانج: ${_formatNumber(product['total_profit'])} IQD',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatNumber(product['total_revenue']),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainProfitCard(double profit) {
    final isProfit = profit >= 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isProfit ? Colors.green.shade200 : Colors.red.shade200,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isProfit ? Icons.trending_up : Icons.trending_down,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            isProfit ? 'قازانج گشتی' : 'زەرەر',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatNumber(profit.abs())} IQD',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _formatNumber(value),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'IQD',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductsStats() {
    if (_products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'هیچ کاڵایەک نییە',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('ژمارەی کاڵاکان', '${_products.length} جۆر'),
            const Divider(),
            _buildInfoRow(
              'کۆی بڕ',
              '${_products.fold(0, (sum, p) => sum + (p['quantity'] as int))} دانە',
            ),
            const Divider(),
            _buildInfoRow(
              'کاڵای کەم (< 10)',
              '${_products.where((p) => p['quantity'] < 10).length} جۆر',
              color: Colors.red,
            ),
            const Divider(),
            _buildInfoRow(
              'کاڵای بەتاڵ',
              '${_products.where((p) => p['quantity'] == 0).length} جۆر',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockProducts() {
    final lowStockProducts = _products.where((p) => p['quantity'] < 10).toList();

    if (lowStockProducts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade400),
              const SizedBox(width: 12),
              Text(
                'هەموو کاڵاکان بڕی باشیان هەیە',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lowStockProducts.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = lowStockProducts[index];
          final quantity = product['quantity'] as int;
          final isCritical = quantity == 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isCritical 
                  ? Colors.red.shade100 
                  : Colors.orange.shade100,
              child: Icon(
                isCritical ? Icons.warning : Icons.info,
                color: isCritical ? Colors.red : Colors.orange,
                size: 20,
              ),
            ),
            title: Text(product['name']),
            subtitle: Text(
              isCritical ? 'بەتاڵە!' : 'بڕی کەم',
              style: TextStyle(
                color: isCritical ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCritical 
                    ? Colors.red.shade100 
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$quantity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCritical ? Colors.red.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}