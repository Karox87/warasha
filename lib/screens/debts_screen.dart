import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  bool _showPaidDebts = false;
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allDebts = await _dbHelper.getDebts();
    
    _debts = allDebts.where((debt) {
      final remaining = debt['remaining'] as double;
      return _showPaidDebts ? remaining <= 0 : remaining > 0;
    }).toList();
    
    setState(() => _isLoading = false);
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

  // 🆕 گەڕاندنەوەی لیستی فرۆشتنەکان بۆ قەرزدار
  Future<List<Map<String, dynamic>>> _getDebtSales(int debtId) async {
    try {
      final db = await _dbHelper.database;
      
      final debtResult = await db.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      
      if (debtResult.isEmpty) return [];
      
      final debtDate = DateTime.parse(debtResult.first['date'] as String);
      final debtDesc = debtResult.first['description'] as String?;
      
      if (debtDesc != null && debtDesc.contains('BULK_')) {
        final bulkIdMatch = RegExp(r'BULK_\d+').firstMatch(debtDesc);
        if (bulkIdMatch != null) {
          final bulkSaleId = bulkIdMatch.group(0);
          
          final sales = await db.query(
            'sales',
            where: 'bulk_sale_id = ?',
            whereArgs: [bulkSaleId],
            orderBy: 'id ASC',
          );
          
          return sales.map((s) => Map<String, dynamic>.from(s)).toList();
        }
      }
      
      final dayStart = DateTime(debtDate.year, debtDate.month, debtDate.day);
      
      final sales = await db.rawQuery('''
        SELECT * FROM sales 
        WHERE date(date) = date(?)
        ORDER BY id ASC
      ''', [debtDate.toIso8601String()]);
      
      return sales.map((s) => Map<String, dynamic>.from(s)).toList();
    } catch (e) {
      print('❌ هەڵە لە وەرگرتنی فرۆشتنەکان: $e');
      return [];
    }
  }

  // 🆕 پیشاندانی وەسڵی قەرز
// 🆕 پیشاندانی وەسڵی قەرز
Future<void> _showDebtReceipt(Map<String, dynamic> debt) async {
  final sales = await _getDebtSales(debt['id']);
  
  if (!mounted) return;
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'وەسڵی قەرز',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // 🆕 زیادکردنی پۆپ ئەپ مێنیو بۆ وەسڵکردن
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.white),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'payment',
                            child: Row(
                              children: [
                                Icon(Icons.payment, size: 18, color: Colors.green),
                                SizedBox(width: 8),
                                Text('وەسڵکردن'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('هاوبەشکردن'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'payment') {
                            Navigator.pop(context); // داخستنی دیالۆگی وەسڵ
                            _showPaymentDialog(debt); // کردنەوەی دیالۆگی وەسڵکردن
                          } else if (value == 'share') {
                            _shareReceipt(debt, sales);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: _buildReceiptContent(debt, sales),
                  ),
                ),
              ),
            ),
            
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
                      onPressed: () => _shareReceipt(debt, sales),
                      icon: const Icon(Icons.share),
                      label: const Text('هاوبەشکردن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  // 🆕 زیادکردنی دوگمەی وەسڵکردن لە خوارەوە
                  if (debt['remaining'] > 0) ...[
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // داخستنی دیالۆگی وەسڵ
                          _showPaymentDialog(debt); // کردنەوەی دیالۆگی وەسڵکردن
                        },
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: const Text('وەسڵکردن', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildReceiptContent(Map<String, dynamic> debt, List<Map<String, dynamic>> sales) {
    final date = DateTime.parse(debt['date']);
    final formattedDate = DateFormat('yyyy-MM-dd | hh:mm a').format(date);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store,
                    size: 48,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'سیستەمی بەڕێوەبردنی فرۆشگا',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'وەسڵی قەرز',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 32, thickness: 2),
          
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
                    Icon(Icons.person, size: 20, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'زانیاری کڕیار',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _buildInfoRow('ناو:', debt['customer_name']),
                _buildInfoRow('بەروار:', formattedDate),
                if (debt['description'] != null && debt['description'].isNotEmpty && !debt['description'].contains('BULK_'))
                  _buildInfoRow('تێبینی:', debt['description']),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
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
                  'کۆدی قەرز: #${debt['id']}',
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
          
          if (sales.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.shopping_cart, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'وردەکاری کاڵاکان',
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
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.red.shade100],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Column(
              children: [
                _buildTotalRow('کۆی قەرز:', debt['amount'], isBold: true),
                const Divider(height: 16),
                _buildTotalRow('پارەی دراو:', debt['paid'], color: Colors.green.shade700),
                const Divider(height: 16),
                _buildTotalRow(
                  'ماوە:',
                  debt['remaining'],
                  color: Colors.red.shade700,
                  isBold: true,
                  isLarge: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    ' تکایە پارەکە لە کاتی خۆیدا بدەرەوە',
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
          
          // پێی وەسڵ - زانیاری گەشەپێدەر
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
                            'گەشەپێدەر: کارۆخ غەفور',
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
                        'بۆ دروستکردنی سیستەمی موبایل',
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, dynamic value, {Color? color, bool isBold = false, bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Row(
          children: [
            Text(
              _formatNumber(value),
              style: TextStyle(
                fontSize: isLarge ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'IQD',
              style: TextStyle(
                fontSize: isLarge ? 14 : 12,
                color: color ?? Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _shareReceipt(Map<String, dynamic> debt, List<Map<String, dynamic>> sales) async {
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

      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        throw Exception('هەڵە لە دروستکردنی وێنە');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/debt_receipt_${debt['id']}_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: 'وەسڵی قەرز - ${debt['customer_name']}\nماوە: ${_formatNumber(debt['remaining'])} IQD',
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

  void _showAddDebtDialog() {
    final customerNameController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('زیادکردنی قەرزی نوێ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customerNameController,
                decoration: const InputDecoration(
                  labelText: 'ناوی کڕیار',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'بەی قەرز',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                  suffixText: 'IQD',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'تێبینی (ئارەزوومەندانە)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (customerNameController.text.isEmpty ||
                  amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە ناو و بەی قەرز بنووسە')),
                );
                return;
              }

              final amount = double.parse(amountController.text);
              final debt = {
                'customer_name': customerNameController.text,
                'amount': amount,
                'paid': 0.0,
                'remaining': amount,
                'description': descriptionController.text.isEmpty 
                    ? null 
                    : descriptionController.text,
                'date': DateTime.now().toIso8601String(),
              };

              await _dbHelper.insertDebt(debt);
              Navigator.pop(context);
              _loadData();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('قەرزەکە بە سەرکەوتوویی زیادکرا'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('زیادکردن'),
          ),
        ],
      ),
    );
  }

  // 🆕 دەستکاری قەرز
  void _showEditDebtDialog(Map<String, dynamic> debt) {
    final customerNameController = TextEditingController(text: debt['customer_name']);
    final amountController = TextEditingController(text: _formatNumber(debt['amount']));
    final descriptionController = TextEditingController(text: debt['description'] ?? '');
    final paidController = TextEditingController(text: _formatNumber(debt['paid']));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دەستکاری قەرز'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customerNameController,
                decoration: const InputDecoration(
                  labelText: 'ناوی کڕیار',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'کۆی قەرز',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                  suffixText: 'IQD',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: paidController,
                decoration: const InputDecoration(
                  labelText: 'پارەی دراو',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                  suffixText: 'IQD',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'تێبینی',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (customerNameController.text.isEmpty ||
                  amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە هەموو خانەکان پڕبکەرەوە')),
                );
                return;
              }

              final amount = double.parse(amountController.text.replaceAll(',', ''));
              final paid = double.parse(paidController.text.replaceAll(',', ''));
              final remaining = amount - paid;

              final updatedDebt = {
                'id': debt['id'],
                'customer_name': customerNameController.text,
                'amount': amount,
                'paid': paid,
                'remaining': remaining,
                'description': descriptionController.text.isEmpty 
                    ? null 
                    : descriptionController.text,
                'date': debt['date'],
              };

              await _dbHelper.updateDebt(debt['id'], updatedDebt);
              Navigator.pop(context);
              _loadData();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('قەرزەکە بە سەرکەوتوویی نوێکرایەوە'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('نوێکردنەوە'),
          ),
        ],
      ),
    );
  }

  // 🆕 سڕینەوەی قەرز
  void _showDeleteDebtDialog(Map<String, dynamic> debt) {
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
              'دڵنیایت لە سڕینەوەی ئەم قەرزە؟',
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
                      const Icon(Icons.person, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          debt['customer_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('کۆی قەرز:', style: TextStyle(fontSize: 14)),
                      Text(
                        '${_formatNumber(debt['amount'])} IQD',
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
                      const Text('ماوە:', style: TextStyle(fontSize: 14)),
                      Text(
                        '${_formatNumber(debt['remaining'])} IQD',
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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مێژووی وەسڵەکانیش دەسڕێتەوە!',
                      style: TextStyle(fontSize: 13),
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
            child: const Text('نەخێر'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final db = await _dbHelper.database;
                
                await db.delete('debt_payments', where: 'debt_id = ?', whereArgs: [debt['id']]);
                await db.delete('debts', where: 'id = ?', whereArgs: [debt['id']]);
                
                Navigator.pop(context);
                _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('قەرزەکە بە سەرکەوتوویی سڕایەوە'),
                      backgroundColor: Colors.red,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('بەڵێ، بیسڕەوە'),
          ),
        ],
      ),
    );
  }

  // 🆕 وەسڵکردنی پارە
// 🆕 وەسڵکردنی پارە
void _showPaymentDialog(Map<String, dynamic> debt) {
  final amountController = TextEditingController();
  final remaining = debt['remaining'] as double;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('وەسڵی قەرز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ك:'),
                      Text(
                        debt['customer_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('کۆی قەرز:'),
                      Text(
                        '${_formatNumber(debt['amount'])} IQD',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('پارەی دراو:'),
                      Text(
                        '${_formatNumber(debt['paid'])} IQD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ماوە:'),
                      Text(
                        '${_formatNumber(remaining)} IQD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'بەی پارەی وەرگیراو',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments),
                suffixText: 'IQD',
                helperText: 'زۆرترین بە: ${_formatNumber(remaining)} IQD',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setStateDialog(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // 🆕 نیوەی ماوە
                      amountController.text = (remaining / 2).toStringAsFixed(0);
                      setStateDialog(() {});
                    },
                    child: const Text('نیوە'),
                  ),
                ),
                const SizedBox(width: 8),
               Expanded(
  child: OutlinedButton(
    onPressed: () {
      // 🆕 تەواوی ماوە - هەموو پارەکە
      amountController.text = remaining.toStringAsFixed(0);
      setStateDialog(() {});
    },
    child: const Text('تەواو'),
  ),
),
              ],
            ),
            if (amountController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ماوە دوای وەسڵ:'),
                      Text(
                        '${_formatNumber(remaining - (double.tryParse(amountController.text) ?? 0))} IQD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
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
              if (amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە بەیەکە بنووسە')),
                );
                return;
              }

              final payment = double.parse(amountController.text);

              if (payment <= 0 || payment > remaining) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('بەیەکە نادروستە'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final debtPayment = {
                'debt_id': debt['id'],
                'amount': payment,
                'date': DateTime.now().toIso8601String(),
              };
              await _dbHelper.insertDebtPayment(debtPayment);

              final newPaid = (debt['paid'] as double) + payment;
              final newRemaining = (debt['amount'] as double) - newPaid;
              
              await _dbHelper.updateDebt(debt['id'], {
                ...debt,
                'paid': newPaid,
                'remaining': newRemaining,
              });

              Navigator.pop(context);
              await _loadData();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newRemaining <= 0 
                          ? '✅ قەرزەکە بە تەواوی دراوەتەوە!' 
                          : '✅ وەسڵەکە تۆمارکرا - ماوە: ${_formatNumber(newRemaining)} IQD',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('تۆمارکردن'),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    double totalDebts = 0;
    double totalPaid = 0;
    double totalRemaining = 0;

    for (var debt in _debts) {
      totalDebts += debt['amount'] as double;
      totalPaid += debt['paid'] as double;
      totalRemaining += debt['remaining'] as double;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('قەرزەکان'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(_showPaidDebts ? Icons.pending : Icons.check_circle),
            tooltip: _showPaidDebts ? 'پیشاندانی قەرزە مانەکان' : 'پیشاندانی قەرزە دراوەکان',
            onPressed: () {
              setState(() {
                _showPaidDebts = !_showPaidDebts;
              });
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'نوێکردنەوە',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('کۆی قەرز', totalDebts),
                    _buildSummaryItem('دراوە', totalPaid),
                    _buildSummaryItem('ماوە', totalRemaining),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _debts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showPaidDebts 
                                  ? Icons.check_circle_outline 
                                  : Icons.account_balance_wallet_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showPaidDebts
                                  ? 'هیچ قەرزێکی دراوە نییە'
                                  : 'هیچ قەرزێک تۆمار نەکراوە',
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
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _debts.length,
                          itemBuilder: (context, index) {
                            final debt = _debts[index];
                            final remaining = debt['remaining'] as double;
                            final percentage = (debt['paid'] as double) / (debt['amount'] as double);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 2,
                              child: ListTile(
                                onTap: () => _showDebtReceipt(debt),
                                leading: CircleAvatar(
                                  backgroundColor: remaining <= 0 
                                      ? Colors.green.shade100 
                                      : Colors.red.shade100,
                                  child: Icon(
                                    remaining <= 0 ? Icons.check : Icons.money_off,
                                    color: remaining <= 0 
                                        ? Colors.green.shade700 
                                        : Colors.red.shade700,
                                  ),
                                ),
                                title: Text(
                                  debt['customer_name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('کۆ: ${_formatNumber(debt['amount'])} IQD | ماوە: ${_formatNumber(remaining)} IQD'),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        remaining <= 0 ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (remaining > 0)
                                      IconButton(
                                        icon: const Icon(Icons.payment, size: 20),
                                        color: Colors.green,
                                        onPressed: () => _showPaymentDialog(debt),
                                        tooltip: 'وەسڵ',
                                      ),
                           PopupMenuButton<String>(
  icon: const Icon(Icons.more_vert, size: 20),
  itemBuilder: (context) => [
    const PopupMenuItem(
      value: 'receipt',
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 18, color: Colors.blue),
          SizedBox(width: 8),
          Text('وەسڵی قەرز'),
        ],
      ),
    ),
    // 🆕 زیادکردنی دوگمەی وەسڵکردن
    if (debt['remaining'] > 0)
      const PopupMenuItem(
        value: 'payment',
        child: Row(
          children: [
            Icon(Icons.payment, size: 18, color: Colors.green),
            SizedBox(width: 8),
            Text('وەسڵکردن'),
          ],
        ),
      ),
    const PopupMenuItem(
      value: 'edit',
      child: Row(
        children: [
          Icon(Icons.edit, size: 18, color: Colors.orange),
          SizedBox(width: 8),
          Text('دەستکاری'),
        ],
      ),
    ),
    const PopupMenuItem(
      value: 'delete',
      child: Row(
        children: [
          Icon(Icons.delete, size: 18, color: Colors.red),
          SizedBox(width: 8),
          Text('سڕینەوە'),
        ],
      ),
    ),
  ],
  onSelected: (value) {
    if (value == 'receipt') {
      _showDebtReceipt(debt);
    } else if (value == 'payment') {
      _showPaymentDialog(debt); // 🆕 فەنکشنی وەسڵکردن
    } else if (value == 'edit') {
      _showEditDebtDialog(debt);
    } else if (value == 'delete') {
      _showDeleteDebtDialog(debt);
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDebtDialog,
        icon: const Icon(Icons.add),
        label: const Text('قەرزی نوێ'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value) {
    return Column(
      children: [
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
    );
  }
}