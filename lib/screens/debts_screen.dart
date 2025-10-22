import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

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
      return _showPaidDebts ? remaining == 0 : remaining > 0;
    }).toList();
    
    setState(() => _isLoading = false);
  }

  // 🆕 فەنکشنی فاریزکردنی ژمارە
  String _formatNumber(dynamic number) {
    final formatter = NumberFormat('#,###');
    if (number is int) {
      return formatter.format(number);
    } else if (number is double) {
      return formatter.format(number.toInt());
    }
    return number.toString();
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
                  labelText: 'ناوی کەیار',
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

  // فەنکشنی نوێ بۆ دەستکاری قەرز
  void _showEditDebtDialog(Map<String, dynamic> debt) {
    final customerNameController = TextEditingController(text: debt['customer_name']);
    final amountController = TextEditingController(text: debt['amount'].toString());
    final descriptionController = TextEditingController(text: debt['description'] ?? '');
    final paidController = TextEditingController(text: debt['paid'].toString());

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
                  labelText: 'ناوی کەیار',
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

              final amount = double.parse(amountController.text);
              final paid = double.parse(paidController.text);
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

  // فەنکشنی نوێ بۆ سڕینەوەی قەرز
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
                        '${_formatNumber(debt['amount'])} IQD', // 🆕 فاریز کراوە
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
                        '${_formatNumber(debt['remaining'])} IQD', // 🆕 فاریز کراوە
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
                
                // سڕینەوەی وەسڵەکان
                await db.delete('debt_payments', where: 'debt_id = ?', whereArgs: [debt['id']]);
                
                // سڕینەوەی قەرزەکە
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
                        const Text('کەیار:'),
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
                          '${_formatNumber(debt['amount'])} IQD', // 🆕 فاریز کراوە
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('پارەی دراو:'),
                        Text(
                          '${_formatNumber(debt['paid'])} IQD', // 🆕 فاریز کراوە
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
                          '${_formatNumber(remaining)} IQD', // 🆕 فاریز کراوە
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
                  helperText: 'زۆرترین بە: ${_formatNumber(remaining)} IQD', // 🆕 فاریز کراوە
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
                          '${_formatNumber(remaining - (double.tryParse(amountController.text) ?? 0))} IQD', // 🆕 فاریز کراوە
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
                _loadData();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newRemaining == 0 
                          ? 'قەرزەکە بە تەواوی دراوەتەوە!' 
                          : 'وەسڵەکە تۆمارکرا',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
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

  void _showDebtDetails(Map<String, dynamic> debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                debt['customer_name'],
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.blue),
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
                Navigator.pop(context);
                if (value == 'edit') {
                  _showEditDebtDialog(debt);
                } else if (value == 'delete') {
                  _showDeleteDebtDialog(debt);
                }
              },
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('کۆی قەرز:', '${_formatNumber(debt['amount'])} IQD'), // 🆕 فاریز کراوە
            _buildDetailRow('پارەی دراو:', '${_formatNumber(debt['paid'])} IQD', Colors.green), // 🆕 فاریز کراوە
            _buildDetailRow('ماوە:', '${_formatNumber(debt['remaining'])} IQD', Colors.red), // 🆕 فاریز کراوە
            const Divider(),
            _buildDetailRow(
              'بەرواری زیادکردن:',
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(debt['date'])),
            ),
            if (debt['description'] != null && debt['description'].isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'تێبینی:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(debt['description']),
            ],
          ],
        ),
        actions: [
          if (debt['remaining'] > 0)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showPaymentDialog(debt);
              },
              icon: const Icon(Icons.payment, color: Colors.white,),
              label: const Text('واسڵکردن', style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
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
                                onTap: () => _showDebtDetails(debt),
                                leading: CircleAvatar(
                                  backgroundColor: remaining == 0 
                                      ? Colors.green.shade100 
                                      : Colors.red.shade100,
                                  child: Icon(
                                    remaining == 0 ? Icons.check : Icons.money_off,
                                    color: remaining == 0 
                                        ? Colors.green.shade700 
                                        : Colors.red.shade700,
                                  ),
                                ),
                                title: Text(
                                  debt['customer_name'], // 🆕 ناوی کەیار دەردەکەوێت
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('کۆ: ${_formatNumber(debt['amount'])} IQD | ماوە: ${_formatNumber(remaining)} IQD'), // 🆕 فاریز کراوە
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        remaining == 0 ? Colors.green : Colors.orange,
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
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 18, color: Colors.blue),
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
                                        if (value == 'edit') {
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
          _formatNumber(value), // 🆕 فاریز کراوە
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