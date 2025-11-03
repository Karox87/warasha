import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:flutter/services.dart'; // 🆕 ئەمە زیاد بکە
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  List<Map<String, dynamic>> _products = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _groupBulkSales = true;
  final bool _showOnlyBulkSales = false; // 🆕 پیشاندانی تەنها فرۆشتنی جوملە
  final GlobalKey _receiptKey = GlobalKey();

  String _selectedFilter = 'هەموو';
  final List<String> _filterOptions = [
    'هەموو',
    'ئەمڕۆ',
    'ئەم حەفتەیە',
    'ئەم مانگە',
    'مانگی پێشوو',
    'دەستی',
  ];

  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _products = await _dbHelper.getProducts();
      final salesFromDb = await _dbHelper.getSales();

      _allSales = salesFromDb.map((sale) {
        final saleCopy = Map<String, dynamic>.from(sale);
        
        final productExists = _products.any((p) => p['id'] == saleCopy['product_id']);
        
        if (!productExists) {
          saleCopy['product_name'] = saleCopy['product_name'] ?? 'کاڵای سڕاوە';
          saleCopy['buy_price'] = saleCopy['buy_price'] ?? 0;
        } else {
          final product = _products.firstWhere((p) => p['id'] == saleCopy['product_id']);
          saleCopy['product_name'] = product['name'];
          saleCopy['buy_price'] = product['buy_price'];
        }
        
        return saleCopy;
      }).toList();

      _allSales.sort((a, b) => 
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']))
      );

      _applyFilters();
    } catch (e) {
      print('هەڵە لە بارکردنی داتا: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> filtered = List.from(_allSales);

    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'ئەمڕۆ':
        filtered = filtered.where((sale) {
          final saleDate = DateTime.parse(sale['date']);
          return saleDate.year == now.year &&
              saleDate.month == now.month &&
              saleDate.day == now.day;
        }).toList();
        break;
      case 'ئەم حەفتەیە':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered.where((sale) {
          final saleDate = DateTime.parse(sale['date']);
          return saleDate.isAfter(startOfWeek.subtract(const Duration(days: 1)));
        }).toList();
        break;
      case 'ئەم مانگە':
        filtered = filtered.where((sale) {
          final saleDate = DateTime.parse(sale['date']);
          return saleDate.year == now.year && saleDate.month == now.month;
        }).toList();
        break;
      case 'مانگی پێشوو':
        final lastMonth = DateTime(now.year, now.month - 1);
        filtered = filtered.where((sale) {
          final saleDate = DateTime.parse(sale['date']);
          return saleDate.year == lastMonth.year && 
                 saleDate.month == lastMonth.month;
        }).toList();
        break;
      case 'دەستی':
        if (_customDateRange != null) {
          filtered = filtered.where((sale) {
            final saleDate = DateTime.parse(sale['date']);
            return saleDate.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) &&
                   saleDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }
        break;
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((sale) {
        final productName = sale['product_name'].toString().toLowerCase();
        return productName.contains(query);
      }).toList();
    }

    setState(() => _filteredSales = filtered);
  }

  String _formatNumber(dynamic number) {
    final formatter = NumberFormat('#,###');
    if (number is int) {
      return formatter.format(number);
    } else if (number is double) {
      return formatter.format(number.toInt());
    }
    return number.toString();
  }

  double _getTotalSales() {
    return _filteredSales.fold(0.0, (sum, sale) => 
      sum + (sale['total'] as num).toDouble()
    );
  }

  double _getTotalProfit() {
    return _filteredSales.fold(0.0, (sum, sale) {
      final sellPrice = (sale['price'] as num).toDouble();
      final buyPrice = (sale['buy_price'] as num?)?.toDouble() ?? 0;
      final quantity = (sale['quantity'] as num).toInt();
      return sum + ((sellPrice - buyPrice) * quantity);
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupSalesByBulkId() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var sale in _filteredSales) {
      final bulkId = sale['bulk_sale_id'] as String?;
      if (bulkId != null && bulkId.isNotEmpty) {
        grouped.putIfAbsent(bulkId, () => []);
        grouped[bulkId]!.add(sale);
      } else {
        // 🆕 ئەگەر تەنها جوملە بوو، فرۆشتنی تاک مەخەرەوە
        if (!_showOnlyBulkSales) {
          final uniqueKey = 'SINGLE_${sale['id']}';
          grouped[uniqueKey] = [sale];
        }
      }
    }
    
    return grouped;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 'دەستی';
      });
      _applyFilters();
    }
  }

  Widget _buildReceiptContent(Map<String, dynamic> sale) {
  final date = DateTime.parse(sale['date']);
  final formattedDate = DateFormat('yyyy-MM-dd | hh:mm a').format(date);
  final profit = ((sale['price'] as num).toDouble() - 
                ((sale['buy_price'] as num?)?.toDouble() ?? 0)) * 
                (sale['quantity'] as num).toInt();
  
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سەرپەڕە
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.store,
                  size: 48,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'وەرشەی وەستا پشتیوان',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'وەسڵی فرۆشتن',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        const Divider(height: 32, thickness: 2),
        
        // زانیاری فرۆشتن
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'زانیاری وەسڵ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildInfoRow('بەروار:', formattedDate),
              _buildInfoRow('کۆدی وەسڵ:', '#${sale['id']}'),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // وردەکاری کاڵا
        Row(
          children: [
            Icon(Icons.shopping_bag, size: 20, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text(
              'وردەکاری کاڵا',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale['product_name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('بڕ:', style: TextStyle(fontSize: 14)),
                  Text(
                    '${sale['quantity']} دانە',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('نرخی یەک دانە:', style: TextStyle(fontSize: 14)),
                  Text(
                    '${_formatNumber(sale['price'])} IQD',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // کۆی گشتی
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.orange.shade100],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'کۆی گشتی:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_formatNumber(sale['total'])} IQD',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // تێبینی
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سوپاس بۆ کڕینەکەت! هیوادارین دووبارە بگەڕێیتەوە',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // پێی وەسڵ
        const Divider(thickness: 1),
        Center(
          child: Column(
            children: [
              const Text(
                'سوپاس بۆ باوەڕت بە ئێمە',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'گەشەپێدەر: کاروخ غەففور',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '0750 232 16 37',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بۆ دروستکردنی سیستەمی مۆبایل',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'چاپکراوە: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSingleSaleReceiptContent(Map<String, dynamic> sale) {
  final date = DateTime.parse(sale['date']);
  final formattedDate = DateFormat('yyyy-MM-dd | hh:mm a').format(date);
  
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سەرپەڕە
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.store,
                  size: 48,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'وەرشەی وەستا پشتیوان',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'وەسڵی فرۆشتن',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        const Divider(height: 32, thickness: 2),
        
        // زانیاری وەسڵ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'زانیاری وەسڵ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildInfoRow('بەروار:', formattedDate),
              _buildInfoRow('کۆدی وەسڵ:', '#${sale['id']}'),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // وردەکاری کاڵا
        Row(
          children: [
            Icon(Icons.shopping_bag, size: 20, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text(
              'وردەکاری کاڵا',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale['product_name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('بڕ:', style: TextStyle(fontSize: 14)),
                  Text(
                    '${sale['quantity']} دانە',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('نرخی یەک دانە:', style: TextStyle(fontSize: 14)),
                  Text(
                    '${_formatNumber(sale['price'])} IQD',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // کۆی گشتی (بێ قازانج)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.orange.shade100],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'کۆی گشتی:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_formatNumber(sale['total'])} IQD',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // تێبینی
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سوپاس بۆ کڕینەکەت! هیوادارین دووبارە بگەڕێیتەوە',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // پێی وەسڵ
        const Divider(thickness: 1),
        Center(
          child: Column(
            children: [
              const Text(
                'سوپاس بۆ باوەڕت بە ئێمە',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'گەشەپێدەر: کاروخ غەففور',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '0750 232 16 37',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بۆ دروستکردنی سیستەمی مۆبایل',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'چاپکراوە: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


Widget _buildBulkSaleReceiptContent(String bulkSaleId, List<Map<String, dynamic>> sales) {
  final totalAmount = sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
  final totalProfit = sales.fold(0.0, (sum, sale) {
    final sellPrice = (sale['price'] as num).toDouble();
    final buyPrice = (sale['buy_price'] as num?)?.toDouble() ?? 0;
    final quantity = (sale['quantity'] as num).toInt();
    return sum + ((sellPrice - buyPrice) * quantity);
  });
  final date = DateTime.parse(sales[0]['date']);
  final formattedDate = DateFormat('yyyy-MM-dd | hh:mm a').format(date);
  
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سەرپەڕە
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory,
                  size: 48,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'وەرشەی وەستا پشتیوان',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'وەسڵی فرۆشتنی جوملە',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        const Divider(height: 32, thickness: 2),
        
        // زانیاری وەسڵ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'زانیاری وەسڵ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildInfoRow('بەروار:', formattedDate),
              _buildInfoRow('ژمارەی کاڵا:', '${sales.length} جۆر'),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // کۆدی فرۆشتنی جوملە
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'کۆدی جوملە: ${bulkSaleId.split('_').last.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // کۆی گشتی فرۆشتنەکان
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کۆی گشتی فرۆشتنەکان',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Text(
                    '${sales.length} جۆر کاڵا',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(totalAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Text(
                    'IQD',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // لیستی کاڵاکان
        Row(
          children: [
            Icon(Icons.shopping_cart, size: 20, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text(
              'هەموو کاڵاکان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // سەرپەڕە
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ناوی کاڵا',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'بڕ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'نرخ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'کۆ',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // کاڵاکان
              ...sales.asMap().entries.map((entry) {
                final index = entry.key;
                final sale = entry.value;
                final isLast = index == sales.length - 1;
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey.shade50,
                    border: !isLast ? Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ) : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          sale['product_name'] ?? 'کاڵا',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${sale['quantity']}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatNumber(sale['price']),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatNumber(sale['total']),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // کۆی گشتی
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300, width: 2),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'کۆی گشتی:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_formatNumber(totalAmount)} IQD',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              
             
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // تێبینی
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سوپاس بۆ کڕینی جوملە! هەموو کاڵاکان لەم وەسڵەدا پیشاندراون',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // پێی وەسڵ
        const Divider(thickness: 1),
        Center(
          child: Column(
            children: [
              const Text(
                'سوپاس بۆ باوەڕت بە ئێمە',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'گەشەپێدەر: کاروخ غەففور',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '0750 232 16 37',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بۆ دروستکردنی سیستەمی مۆبایل',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'چاپکراوە: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  void _showBulkSaleDetails(String bulkSaleId, List<Map<String, dynamic>> sales) {
    final totalAmount = sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
    final totalProfit = sales.fold(0.0, (sum, sale) {
      final sellPrice = (sale['price'] as num).toDouble();
      final buyPrice = (sale['buy_price'] as num?)?.toDouble() ?? 0;
      final quantity = (sale['quantity'] as num).toInt();
      return sum + ((sellPrice - buyPrice) * quantity);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'وردەکاری فرۆشتنی جوملە',
                style: TextStyle(fontSize: 18),
              ),
            ),
            // 🆕 دوگمەی مۆر
            
            
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
              itemBuilder: (context) => [
                PopupMenuItem(
  value: 'receipt',
  child: Row(
    children: [
      Icon(Icons.receipt_long, size: 18, color: Colors.blue),
      SizedBox(width: 6),
      Text('وەسڵی جوملە'),
    ],
  ),
),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('سڕینەوەی هەموویان'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  Navigator.pop(context);
                  _showDeleteBulkSaleDialog(bulkSaleId, sales);
                }
                if (value == 'receipt') {
  Navigator.pop(context);
  _showBulkSaleReceipt(bulkSaleId, sales);
}
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('کۆدی فرۆشتن:'),
                        Text(
                          bulkSaleId.split('_').last.substring(0, 8),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ژمارەی کاڵا:'),
                        Text(
                          '${sales.length} جۆر',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('کۆی گشتی:'),
                        Text(
                          '${_formatNumber(totalAmount)} IQD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('قازانج:'),
                        Text(
                          '${_formatNumber(totalProfit)} IQD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'کاڵاکان:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final profit = ((sale['price'] as num).toDouble() - 
                                  ((sale['buy_price'] as num?)?.toDouble() ?? 0)) * 
                                  (sale['quantity'] as num).toInt();
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          radius: 18,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          sale['product_name'],
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'بڕ: ${sale['quantity']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'قازانج: ${_formatNumber(profit)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatNumber(sale['total']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const Text(
                                  'IQD',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            // 🆕 دوگمەی دەستکاری بۆ هەر کاڵایەک
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('دەستکاری', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('سڕینەوە', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                Navigator.pop(context);
                                if (value == 'edit') {
                                  _showEditSaleDialog(sale);
                                } else if (value == 'delete') {
                                  _showDeleteSaleDialog(sale);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  // 🆕 سڕینەوەی هەموو فرۆشتنی جوملە
  void _showDeleteBulkSaleDialog(String bulkSaleId, List<Map<String, dynamic>> sales) {
    final totalAmount = sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
    final totalQuantity = sales.fold(0, (sum, sale) => sum + (sale['quantity'] as int));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'سڕینەوەی فرۆشتنی جوملە',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'دڵنیایت لە سڕینەوەی هەموو ئەم فرۆشتنە جوملەیە؟',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'زانیاری گشتی:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildInfoRow('ژمارەی کاڵا:', '${sales.length} جۆر'),
                  const SizedBox(height: 6),
                  _buildInfoRow('کۆی بڕ:', '$totalQuantity دانە'),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    'کۆی گشتی:',
                    '${_formatNumber(totalAmount)} IQD',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'هەموو کاڵاکان دەگەڕێنەوە بۆ کۆگا',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ئەم کردارە ناگەڕێتەوە!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر، پاشگەزبوونەوە'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final db = await _dbHelper.database;
                
                // گەڕاندنەوەی کاڵاکان بۆ کۆگا
                for (var sale in sales) {
                  final product = _products.firstWhere(
                    (p) => p['id'] == sale['product_id'],
                    orElse: () => <String, dynamic>{},
                  );

                  if (product.isNotEmpty) {
                    final newQuantity = product['quantity'] + sale['quantity'];
                    await _dbHelper.updateProduct(
                      sale['product_id'],
                      {...product, 'quantity': newQuantity},
                    );
                  }

                  // سڕینەوەی فرۆشتنەکە
                  await db.delete('sales', where: 'id = ?', whereArgs: [sale['id']]);
                }

                if (mounted) {
                  setState(() {
                    for (var sale in sales) {
                      _filteredSales.removeWhere((s) => s['id'] == sale['id']);
                      _allSales.removeWhere((s) => s['id'] == sale['id']);
                    }
                  });
                }

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'فرۆشتنی جوملە سڕایەوە - ${sales.length} جۆری کاڵا گەڕایەوە بۆ کۆگا',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('هەڵە: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('بەڵێ، هەموویان بسڕەوە'),
          ),
        ],
      ),
    );
  }

  // هێلپەر بۆ پیشاندانی زانیاری
 Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 13,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.orange.shade700 : Colors.black87,
          ),
        ),
      ],
    ),
  );
}
Future<void> _showSaleReceipt(Map<String, dynamic> sale) async {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // سەرپەڕە
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'وەسڵی فرۆشتن',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 16, color: Colors.blue),
                                SizedBox(width: 6),
                                Text('هاوبەشکردن'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'share') {
                            _shareReceipt(sale);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // ناوەڕۆک
            Flexible(
              child: RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: _buildReceiptContent(sale),
                  ),
                ),
              ),
            ),
            
            // خوارەوە
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareReceipt(sale),
                      icon: const Icon(Icons.share, color: Colors.white, size: 18),
                      label: const Text('هاوبەشکردن', style: TextStyle(color: Colors.white, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareReceipt(Map<String, dynamic> sale) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('ئامادەکردنی وەسڵ...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    final GlobalKey captureKey = GlobalKey();
    
    final captureWidget = RepaintBoundary(
      key: captureKey,
      child: Material(
        color: Colors.white,
        child: Container(
          width: 400,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: _buildReceiptContent(sale),
        ),
      ),
    );

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: 0,
        child: captureWidget,
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 800));

    final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      overlay.remove();
      Navigator.pop(context);
      throw Exception('هەڵە لە دروستکردنی وێنە');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    overlay.remove();

    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/sale_receipt_${sale['id']}_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(pngBytes);

    Navigator.pop(context);

    await Share.shareXFiles(
      [XFile(imagePath)],
      text: 'وەسڵی فرۆشتن - ${sale['product_name']}\nکۆ: ${_formatNumber(sale['total'])} IQD',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('وەسڵەکە بە سەرکەوتوویی هاوبەش کرا'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هەڵە: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


// 🔧 فەنکشنی دەستکاری فرۆشتن لە مێژوو
// لە sales_history_screen.dart بدۆزەرەوە و بیگۆڕە:

void _showEditSaleDialog(Map<String, dynamic> sale) {
  // 🆕 فۆرماتکردنی ژمارە بۆ پیشاندان (بێ .0 و بە فاریزە)
  String formatForDisplay(dynamic value) {
    if (value == null) return '';
    
    double numValue;
    if (value is int) {
      numValue = value.toDouble();
    } else if (value is double) {
      numValue = value;
    } else {
      numValue = double.tryParse(value.toString()) ?? 0.0;
    }
    
    // گۆڕینی بۆ int ئەگەر تەواوە
    if (numValue == numValue.truncateToDouble()) {
      return NumberFormat('#,###').format(numValue.toInt());
    }
    
    return numValue.toStringAsFixed(0);
  }
  
  final quantityController = TextEditingController(
    text: sale['quantity'].toString()
  );
  final priceController = TextEditingController(
    text: formatForDisplay(sale['price'])
  );

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('دەستکاری فرۆشتن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'بڕ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) => setStateDialog(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'نرخی یەک دانە',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'IQD',
                hintText: 'بۆ نموونە: 15,000',
              ),
              keyboardType: TextInputType.number,
              // 🆕 زیادکردنی فۆرماتکەر
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  
                  final number = int.tryParse(newValue.text.replaceAll(',', ''));
                  if (number == null) return oldValue;
                  
                  final formatted = NumberFormat('#,###').format(number);
                  
                  return TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
              onChanged: (value) => setStateDialog(() {}),
            ),
            const SizedBox(height: 16),
            if (quantityController.text.isNotEmpty && priceController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی گشتی:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${_formatNumber((int.tryParse(quantityController.text) ?? 0) * (int.tryParse(priceController.text.replaceAll(',', '')) ?? 0))} IQD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (quantityController.text.isEmpty || priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە هەموو خانەکان پڕبکەوە')),
                );
                return;
              }

              final newQuantity = int.parse(quantityController.text);
              // 🆕 لابردنی فاریزە پێش پاشەکەوت
              final cleanPrice = priceController.text.replaceAll(',', '');
              final newPrice = double.parse(cleanPrice);
              final oldQuantity = sale['quantity'];

              final product = _products.firstWhere((p) => p['id'] == sale['product_id']);
              final quantityDiff = oldQuantity - newQuantity;
              final updatedProductQuantity = product['quantity'] + quantityDiff;

              await _dbHelper.updateProduct(
                sale['product_id'],
                {...product, 'quantity': updatedProductQuantity},
              );

              final db = await _dbHelper.database;
              await db.update(
                'sales',
                {
                  'quantity': newQuantity,
                  'price': newPrice,
                  'total': newQuantity * newPrice,
                },
                where: 'id = ?',
                whereArgs: [sale['id']],
              );

              Navigator.pop(context);

              setState(() {
                final index = _filteredSales.indexWhere((s) => s['id'] == sale['id']);
                if (index != -1) {
                  _filteredSales[index] = {
                    ..._filteredSales[index],
                    'quantity': newQuantity,
                    'price': newPrice,
                    'total': newQuantity * newPrice,
                  };
                }
                
                final allIndex = _allSales.indexWhere((s) => s['id'] == sale['id']);
                if (allIndex != -1) {
                  _allSales[allIndex] = {
                    ..._allSales[allIndex],
                    'quantity': newQuantity,
                    'price': newPrice,
                    'total': newQuantity * newPrice,
                  };
                }
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('فرۆشتنەکە بە سەرکەوتوویی نوێکرایەوە'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('نوێکردنەوە'),
          ),
        ],
      ),
    ),
  );
}

  void _showDeleteSaleDialog(Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('سڕینەوە'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'دڵنیایت لە سڕینەوەی ئەم فرۆشتنە؟',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sale['product_name'] ?? 'کاڵای سڕاوە',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('بڕ:', style: TextStyle(fontSize: 14)),
                      Text(
                        '${sale['quantity']} دانە',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نرخ:', style: TextStyle(fontSize: 14)),
                      Text(
                        '${_formatNumber(sale['price'])} IQD',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('کۆ:', style: TextStyle(fontSize: 14)),
                      Text(
                        '${_formatNumber(sale['total'])} IQD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'کاڵاکە دەگەڕێتەوە بۆ کۆگا',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('نەخێر، پاشگەزبوونەوە'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final product = _products.firstWhere(
                  (p) => p['id'] == sale['product_id'],
                  orElse: () => <String, dynamic>{},
                );

                if (product.isNotEmpty) {
                  final newQuantity = product['quantity'] + sale['quantity'];
                  await _dbHelper.updateProduct(
                    sale['product_id'],
                    {...product, 'quantity': newQuantity},
                  );
                }

                final db = await _dbHelper.database;
                await db.delete('sales', where: 'id = ?', whereArgs: [sale['id']]);

                if (mounted) {
                  setState(() {
                    _filteredSales.removeWhere((s) => s['id'] == sale['id']);
                    _allSales.removeWhere((s) => s['id'] == sale['id']);
                  });
                }

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'فرۆشتنەکە سڕایەوە و ${sale['quantity']} دانە گەڕایەوە بۆ کۆگا',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('هەڵە: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('بەڵێ، بیسڕەوە'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSingleSaleReceipt(Map<String, dynamic> sale) async {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // سەرپەڕە
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'وەسڵی فرۆشتن',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 16, color: Colors.blue),
                                SizedBox(width: 6),
                                Text('هاوبەشکردن'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'share') {
                            _shareSingleReceipt(sale);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // ناوەڕۆک
            Flexible(
              child: RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: _buildSingleSaleReceiptContent(sale),
                  ),
                ),
              ),
            ),
            
            // خوارەوە
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareSingleReceipt(sale),
                      icon: const Icon(Icons.share, color: Colors.white, size: 18),
                      label: const Text('هاوبەشکردن', style: TextStyle(color: Colors.white, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareSingleReceipt(Map<String, dynamic> sale) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('ئامادەکردنی وەسڵ...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    final GlobalKey captureKey = GlobalKey();
    
    final captureWidget = RepaintBoundary(
      key: captureKey,
      child: Material(
        color: Colors.white,
        child: Container(
          width: 400,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: _buildSingleSaleReceiptContent(sale),
        ),
      ),
    );

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: 0,
        child: captureWidget,
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 800));

    final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      overlay.remove();
      Navigator.pop(context);
      throw Exception('هەڵە لە دروستکردنی وێنە');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    overlay.remove();

    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/sale_receipt_${sale['id']}_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(pngBytes);

    Navigator.pop(context);

    await Share.shareXFiles(
      [XFile(imagePath)],
      text: 'وەسڵی فرۆشتن - ${sale['product_name']}\nکۆ: ${_formatNumber(sale['total'])} IQD',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('وەسڵەکە بە سەرکەوتوویی هاوبەش کرا'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هەڵە: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


Future<void> _showBulkSaleReceipt(String bulkSaleId, List<Map<String, dynamic>> sales) async {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // سەرپەڕە
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'وەسڵی فرۆشتنی جوملە',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 16, color: Colors.blue),
                                SizedBox(width: 6),
                                Text('هاوبەشکردن'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'share') {
                            _shareBulkReceipt(bulkSaleId, sales);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // ناوەڕۆک
            Flexible(
              child: RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: _buildBulkSaleReceiptContent(bulkSaleId, sales),
                  ),
                ),
              ),
            ),
            
            // خوارەوە
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareBulkReceipt(bulkSaleId, sales),
                      icon: const Icon(Icons.share, color: Colors.white, size: 18),
                      label: const Text('هاوبەشکردن', style: TextStyle(color: Colors.white, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareBulkReceipt(String bulkSaleId, List<Map<String, dynamic>> sales) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('ئامادەکردنی وەسڵی جوملە...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    final GlobalKey captureKey = GlobalKey();
    
    final captureWidget = RepaintBoundary(
      key: captureKey,
      child: Material(
        color: Colors.white,
        child: Container(
          width: 400,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: _buildBulkSaleReceiptContent(bulkSaleId, sales),
        ),
      ),
    );

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: 0,
        child: captureWidget,
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 800));

    final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      overlay.remove();
      Navigator.pop(context);
      throw Exception('هەڵە لە دروستکردنی وێنە');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    overlay.remove();

    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/bulk_receipt_${bulkSaleId.split('_').last}_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(pngBytes);

    Navigator.pop(context);

    final totalAmount = sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
    await Share.shareXFiles(
      [XFile(imagePath)],
      text: 'وەسڵی فرۆشتنی جوملە\nژمارەی کاڵا: ${sales.length} جۆر\nکۆی گشتی: ${_formatNumber(totalAmount)} IQD',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('وەسڵی جوملە بە سەرکەوتوویی هاوبەش کرا'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هەڵە: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final groupedSales = _groupBulkSales ? _groupSalesByBulkId() : {};
    final displayList = _groupBulkSales 
        ? groupedSales.entries.toList()
        : _filteredSales.map((sale) => MapEntry('SINGLE_${sale['id']}', [sale])).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مێژووی فرۆشتن',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.orange,
        actions: [
          // 🆕 چێک بۆکس لە AppBar
       /*   PopupMenuButton<String>(
            icon: Icon(
              _showOnlyBulkSales ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showOnlyBulkSales ? Colors.blue.shade100 : Colors.white,
            ),
            tooltip: 'فلتەر',
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'فلتەری جۆری فرۆشتن',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                enabled: false,
                child: Divider(height: 8),
              ),
              PopupMenuItem<String>(
                value: 'bulk_only',
                child: StatefulBuilder(
                  builder: (context, setStateMenu) => CheckboxListTile(
                    value: _showOnlyBulkSales,
                    onChanged: (value) {
                      setState(() => _showOnlyBulkSales = value ?? false);
                      setStateMenu(() {});
                    },
                    title: const Row(
                      children: [
                        Icon(Icons.inventory, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'تەنها جوملە',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ), */
          IconButton(
            icon: Icon(_groupBulkSales ? Icons.view_list : Icons.view_module,color: Colors.white,),
            onPressed: () {
              setState(() => _groupBulkSales = !_groupBulkSales);
            },
            tooltip: _groupBulkSales ? 'بینینی وردەکاری' : 'گروپکردن',
          ),
          IconButton(
            icon: const Icon(Icons.refresh,color: Colors.white,),
            onPressed: _loadData,
            tooltip: 'نوێکردنەوە',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'ژمارەی فرۆشتن',
                        _groupBulkSales 
                            ? '${displayList.length}'
                            : '${_filteredSales.length}',
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'کۆی گشتی',
                        '${_formatNumber(_getTotalSales())} IQD',
                        Icons.attach_money,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  'قازانجی گشتی',
                  '${_formatNumber(_getTotalProfit())} IQD',
                  Icons.trending_up,
                  Colors.green,
                  fullWidth: true,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'گەڕان بەپێی ناوی کاڵا...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._filterOptions.map((filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: _selectedFilter == filter,
                              onSelected: (selected) {
                                if (filter == 'دەستی') {
                                  _selectDateRange();
                                } else {
                                  setState(() => _selectedFilter = filter);
                                  _applyFilters();
                                }
                              },
                              selectedColor: Colors.orange,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: _selectedFilter == filter
                                    ? Colors.white
                                    : const Color.fromARGB(221, 0, 0, 0),
                                fontWeight: _selectedFilter == filter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          )),
                      if (_selectedFilter == 'دەستی' && _customDateRange != null)
                        Chip(
                          label: Text(
                            '${DateFormat('yyyy-MM-dd').format(_customDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_customDateRange!.end)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _customDateRange = null;
                              _selectedFilter = 'هەموو';
                            });
                            _applyFilters();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'هیچ فرۆشتنێک نەدۆزرایەوە',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: Colors.orange,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final entry = displayList[index];
                            final bulkSaleId = entry.key;
                            final sales = entry.value;
                            final isBulk = sales.length > 1;
                            
                            if (isBulk) {
                              return _buildBulkSaleCard(bulkSaleId, sales, index);
                            } else {
                              return _buildSingleSaleCard(sales[0], index);
                            }
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkSaleCard(String bulkSaleId, List<Map<String, dynamic>> sales, int index) {
    final totalAmount = sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
    final totalProfit = sales.fold(0.0, (sum, sale) {
      final sellPrice = (sale['price'] as num).toDouble();
      final buyPrice = (sale['buy_price'] as num?)?.toDouble() ?? 0;
      final quantity = (sale['quantity'] as num).toInt();
      return sum + ((sellPrice - buyPrice) * quantity);
    });
    final date = DateTime.parse(sales[0]['date']);
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 2),
      ),
      child: InkWell(
        onTap: () => _showBulkSaleDetails(bulkSaleId, sales),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade100, Colors.blue.shade200],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory, color: Colors.blue.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '📦 فرۆشتنی جوملە',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${sales.length} جۆر',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatNumber(totalAmount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const Text(
                        'IQD',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'قازانج: ${_formatNumber(totalProfit)} IQD',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'دەستلێدان بۆ وردەکاری',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: sales.take(3).map((sale) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '${sale['product_name']} (${sale['quantity']})',
                    style: const TextStyle(fontSize: 10),
                  ),
                )).toList()
                  ..addAll(sales.length > 3 ? [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${sales.length - 3} زیاتر',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] : []),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildSingleSaleCard(Map<String, dynamic> sale, int index) {
  final date = DateTime.parse(sale['date']);
  final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);
  final productName = sale['product_name'] ?? 'کاڵای سڕاوە';
  final profit = ((sale['price'] as num).toDouble() - 
                ((sale['buy_price'] as num?)?.toDouble() ?? 0)) * 
                (sale['quantity'] as num).toInt();

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 2,
    child: IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              radius: 20,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'بڕ: ${sale['quantity']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'نرخ: ${_formatNumber(sale['price'])}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.trending_up, 
                        size: 11, 
                        color: Colors.green.shade600
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'قازانج: ${_formatNumber(profit)} IQD',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatNumber(sale['total']),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const Text(
                      'IQD',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(  // ✅ زیادکراوە <String>
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, 
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  // ✅ ئەمە بەشی نوێیە
                  onSelected: (value) {
                    if (value == 'receipt') {
                      _showSingleSaleReceipt(sale);
                    }
                  },
                  // ✅ کۆتایی بەشی نوێ
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('دەستکاری'),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => _showEditSaleDialog(sale),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'receipt',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('وەسڵی فرۆشتن'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('سڕینەوە'),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => _showDeleteSaleDialog(sale),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: fullWidth ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
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