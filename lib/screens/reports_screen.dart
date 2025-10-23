import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:koga/backup/backup_restore_screen.dart';

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
      _showErrorSnackbar('هەڵە لە بارکردنی داتا: $e');
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
      _showErrorSnackbar('هەڵە لە حیسابکردنی ئامار: $e');
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
      _showErrorSnackbar('هەڵە لە حیسابکردنی بەرزترین کاڵا: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
        title: const Text(
          'ڕاپۆرت گشتی',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        actions: [
          // دوگمەی نوێکردنەوە
          IconButton(
            icon: const Icon(Icons.refresh, size: 24),
            onPressed: _loadData,
            tooltip: 'نوێکردنەوەی داتا',
          ),
          // دوگمەی باکئەپ
          IconButton(
            icon: const Icon(Icons.backup, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackupRestoreScreen(),
                ),
              );
            },
            tooltip: 'باکئەپ و گەڕاندنەوە',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // کارتەکانی ئەمڕۆ و ئەم مانگە
                    _buildTimeBasedStats(),
                    const SizedBox(height: 20),
                    
                    // کارتی قازانج گشتی
                    _buildMainProfitCard(profit),
                    const SizedBox(height: 20),
                    
                    // ئاماری گشتی
                    _buildSectionTitle('ئاماری گشتی'),
                    const SizedBox(height: 12),
                    _buildGeneralStats(totalPurchases, totalSales, totalDebts, inventoryValue),
                    const SizedBox(height: 24),
                    
                    // بەرزترین کاڵا فرۆشراوەکان
                    _buildSectionTitle('بەرزترین کاڵا فرۆشراوەکان'),
                    const SizedBox(height: 12),
                    _buildTopSellingProducts(),
                    const SizedBox(height: 24),
                    
                    // ئاماری کاڵاکان
                    _buildSectionTitle('ئاماری کاڵاکان'),
                    const SizedBox(height: 12),
                    _buildProductsStats(),
                    const SizedBox(height: 24),
                    
                    // کاڵای کەم لە کۆگا
                    _buildSectionTitle('کاڵای کەم لە کۆگا'),
                    const SizedBox(height: 12),
                    _buildLowStockProducts(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
          ),
          const SizedBox(height: 16),
          const Text(
            'بارکردنی داتا...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBasedStats() {
    return Column(
      children: [
        // ئامارەکانی ئەمڕۆ
        _buildTimeCard(
          title: 'فرۆشتنی ئەمڕۆ',
          icon: Icons.today,
          sales: _todaySales,
          profit: _todayProfit,
          gradientColors: [Colors.blue.shade500, Colors.blue.shade700],
          shadowColor: Colors.blue.shade200,
        ),
        const SizedBox(height: 12),
        
        // ئامارەکانی ئەم مانگە
        _buildTimeCard(
          title: 'فرۆشتنی ${DateFormat('MMMM').format(DateTime.now())}',
          icon: Icons.calendar_month,
          sales: _monthSales,
          profit: _monthProfit,
          gradientColors: [Colors.purple.shade500, Colors.purple.shade700],
          shadowColor: Colors.purple.shade200,
        ),
      ],
    );
  }

  Widget _buildTimeCard({
    required String title,
    required IconData icon,
    required double sales,
    required double profit,
    required List<Color> gradientColors,
    required Color shadowColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white30, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  'فرۆشتن',
                  sales,
                  Icons.sell,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStatCard(
                  'قازانج',
                  profit,
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, double value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatNumber(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'IQD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainProfitCard(double profit) {
    final isProfit = profit >= 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [Colors.green.shade500, Colors.green.shade700]
              : [Colors.red.shade500, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isProfit ? Colors.green.shade300 : Colors.red.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isProfit ? Icons.trending_up : Icons.trending_down,
            size: 52,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            isProfit ? 'قازانج گشتی' : 'زەرەر',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatNumber(profit.abs())} IQD',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('yyyy-MM-dd • HH:mm').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralStats(double purchases, double sales, double debts, double inventory) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'کۆی کڕین',
                purchases,
                Icons.shopping_cart,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'کۆی فرۆشتن',
                sales,
                Icons.sell,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'کۆی قەرز',
                debts,
                Icons.account_balance_wallet,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'نرخی کۆگا',
                inventory,
                Icons.inventory_2,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, double value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _formatNumber(value),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'IQD',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTopSellingProducts() {
    if (_topSellingProducts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.analytics_outlined,
        message: 'هیچ فرۆشتنێک نییە',
        description: 'فرۆشتنەکان لێرە دەردەکەون',
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topSellingProducts.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final product = _topSellingProducts[index];
          final rank = index + 1;
          Color rankColor;
          String rankText;
          
          switch (rank) {
            case 1:
              rankColor = Colors.amber.shade700;
              rankText = '١ەم';
              break;
            case 2:
              rankColor = Colors.grey.shade600;
              rankText = '٢ەم';
              break;
            case 3:
              rankColor = Colors.brown.shade500;
              rankText = '٣ەم';
              break;
            default:
              rankColor = Colors.blue.shade500;
              rankText = '#$rank';
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  rankText,
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            title: Text(
              product['name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  'فرۆشراو: ${product['total_sold']} دانە',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'قازانج: ${_formatNumber(product['total_profit'])} IQD',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatNumber(product['total_revenue']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'IQD',
                    style: TextStyle(
                      color: Colors.orange.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsStats() {
    if (_products.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        message: 'هیچ کاڵایەک نییە',
        description: 'کاڵاکان لێرە دەردەکەون',
      );
    }

    final totalQuantity = _products.fold(0, (sum, p) => sum + (p['quantity'] as int));
    final lowStockCount = _products.where((p) => p['quantity'] < 10).length;
    final outOfStockCount = _products.where((p) => p['quantity'] == 0).length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(
              'ژمارەی کاڵاکان',
              '${_products.length} جۆر',
              icon: Icons.category,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'کۆی بڕی کۆگا',
              '$totalQuantity دانە',
              icon: Icons.storage,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'کاڵای کەم (< 10)',
              '$lowStockCount جۆر',
              icon: Icons.warning_amber,
              color: Colors.orange,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'کاڵای بەتاڵ',
              '$outOfStockCount جۆر',
              icon: Icons.error_outline,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue.shade700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockProducts() {
    final lowStockProducts = _products.where((p) => p['quantity'] < 10).toList();

    if (lowStockProducts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        message: 'هەموو کاڵاکان بڕی باشیان هەیە',
        description: 'کاڵای کەم لە کۆگا نییە',
        color: Colors.green,
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lowStockProducts.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final product = lowStockProducts[index];
          final quantity = product['quantity'] as int;
          final isCritical = quantity == 0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCritical ? Colors.red.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCritical ? Colors.red.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Icon(
                isCritical ? Icons.warning : Icons.info,
                color: isCritical ? Colors.red : Colors.orange,
                size: 24,
              ),
            ),
            title: Text(
              product['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              isCritical ? 'کاڵا بەتاڵە!' : 'بڕی کەم لە کۆگا',
              style: TextStyle(
                color: isCritical ? Colors.red : Colors.orange,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCritical ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCritical ? Colors.red.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Text(
                '$quantity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCritical ? Colors.red.shade700 : Colors.orange.shade700,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String description,
    Color color = Colors.grey,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 64, color: color.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}