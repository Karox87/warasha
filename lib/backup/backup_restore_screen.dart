import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../database/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isProcessing = false;
  String? _lastBackupPath;
  DateTime? _lastBackupDate;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLastBackupInfo();
  }

  Future<void> _loadLastBackupInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (await backupDir.exists()) {
        final files = await backupDir.list().toList();
        if (files.isNotEmpty) {
          final lastFile = files.whereType<File>().toList()
            ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          
          if (lastFile.isNotEmpty) {
            setState(() {
              _lastBackupPath = lastFile.first.path;
              _lastBackupDate = lastFile.first.statSync().modified;
            });
          }
        }
      }
    } catch (e) {
      print('هەڵە لە بارکردنی زانیاری باکئەپ: $e');
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    try {
      // وەرگرتنی هەموو داتاکان
      setState(() => _progress = 0.2);
      final products = await _dbHelper.getProducts();
      setState(() => _progress = 0.4);
      final purchases = await _dbHelper.getPurchases();
      setState(() => _progress = 0.6);
      final sales = await _dbHelper.getSales();
      setState(() => _progress = 0.8);
      final debts = await _dbHelper.getDebts();

     // درووستکردنی ئۆبجێکتی باکئەپ
final backupData = {
  'backup_date': DateTime.now().toIso8601String(),
  'app_version': '1.0.0',
  'data_count': {
    'products': products.length,
    'purchases': purchases.length,
    'sales': sales.length,
    'debts': debts.length,
  },
  'products': products,
  'purchases': purchases,
  'sales': sales,
  'debts': debts,
};

      // گۆڕینی بۆ JSON
      final jsonString = jsonEncode(backupData);

      // دیاریکردنی ناوی فایل
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'store_backup_$timestamp.json';

      // بەکارهێنانی دایرێکتۆری ناوەخۆیی ئەپ (کە مۆڵەتی پێویستی نییە)
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonString);

      setState(() {
        _lastBackupPath = file.path;
        _lastBackupDate = DateTime.now();
        _progress = 1.0;
      });

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'باکئەپ بە سەرکەوتوویی دروست کرا!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${products.length} کاڵا, ${sales.length} فرۆشتن, ${debts.length} قەرز',
            style: const TextStyle(fontSize: 12),
          ),
          // 🆕 زیادکراوە
          const SizedBox(height: 4),
          Text(
            'خانەی جوملە: پارێزراو',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'هاوبەشکردن',
        textColor: Colors.white,
        onPressed: () => _shareBackupFile(file.path),
      ),
    ),
  );
}

      // دوای 1 چرکە بگەڕێتەوە بۆ سفر
      await Future.delayed(const Duration(milliseconds: 1000));
      setState(() => _progress = 0.0);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هەڵە لە دروستکردنی باکئەپ: ${e.toString()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareBackupFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'باکئەپی کۆگا - ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
        subject: 'باکئەپی کۆگا',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە لە هاوبەشکردنی فایل: $e'),
            backgroundColor: Colors.orange.shade600,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    // دڵنیابوونەوە لە بەکارهێنەر
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text(
              'ئاگاداری',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'گەڕاندنەوەی باکئەپ:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• هەموو داتا ئێستاکان دەسڕێتەوە'),
            Text('• داتا کۆنەکان لەدەست دەچن'),
            Text('• کارەکە ناگەڕێتەوە'),
            SizedBox(height: 12),
            Text(
              'دڵنیایت لە بەردەوامبوون؟',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('نەخێر', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('بەڵێ، دەمەوێت', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    try {
      // هەڵبژاردنی فایل
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

    // پشکنینی دروستی فایل
if (!backupData.containsKey('products') || !backupData.containsKey('sales')) {
  throw Exception('فایلی باکئەپ نادروستە یان کەمە');
}

// 🆕 پشکنینی خانەی wholesale_price
final firstProduct = backupData['products'].first;
if (!firstProduct.containsKey('wholesale_price')) {
  // ئەگەر باکئەپ کۆنە، خانەی wholesale_price زیاد بکە
  for (var product in backupData['products']) {
    product['wholesale_price'] = null;
  }
}

      setState(() => _progress = 0.2);

      // سڕینەوەی داتا کۆنەکان
      final db = await _dbHelper.database;
      await db.delete('products');
      setState(() => _progress = 0.4);
      await db.delete('purchases');
      setState(() => _progress = 0.5);
      await db.delete('sales');
      setState(() => _progress = 0.6);
      await db.delete('debts');
      setState(() => _progress = 0.7);
      await db.delete('debt_payments');
      setState(() => _progress = 0.8);

   // گەڕاندنەوەی کاڵاکان
final products = backupData['products'] as List;
for (var product in products) {
  await db.insert('products', {
    'name': product['name'],
    'barcode': product['barcode'],
    'buy_price': product['buy_price'],
    'sell_price': product['sell_price'],
    'wholesale_price': product['wholesale_price'], // 🆕 زیادکراوە
    'quantity': product['quantity'],
    'created_at': product['created_at'] ?? DateTime.now().toIso8601String(),
  });
}

      setState(() => _progress = 0.85);

      // گەڕاندنەوەی کڕینەکان
      final purchases = backupData['purchases'] as List;
      for (var purchase in purchases) {
        await db.insert('purchases', {
          'product_id': purchase['product_id'],
          'quantity': purchase['quantity'],
          'price': purchase['price'],
          'total': purchase['total'],
          'date': purchase['date'],
        });
      }

      setState(() => _progress = 0.9);

      // گەڕاندنەوەی فرۆشتنەکان
      final sales = backupData['sales'] as List;
      for (var sale in sales) {
        await db.insert('sales', {
          'product_id': sale['product_id'],
          'product_name': sale['product_name'],
          'buy_price': sale['buy_price'],
          'quantity': sale['quantity'],
          'price': sale['price'],
          'total': sale['total'],
          'date': sale['date'],
          'bulk_sale_id': sale['bulk_sale_id'],
        });
      }

      setState(() => _progress = 0.95);

      // گەڕاندنەوەی قەرزەکان
      final debts = backupData['debts'] as List;
      for (var debt in debts) {
        await db.insert('debts', {
          'customer_name': debt['customer_name'],
          'amount': debt['amount'],
          'paid': debt['paid'],
          'remaining': debt['remaining'],
          'description': debt['description'],
          'date': debt['date'],
        });
      }

      setState(() => _progress = 1.0);

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'باکئەپ بە سەرکەوتوویی گەڕایەوە!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${products.length} کاڵا, ${sales.length} فرۆشتن گەڕێنرانەوە',
                  style: const TextStyle(fontSize: 12),
                ),
                // 🆕 زیادکراوە
                const Text(
                  'خانەی جوملە: گەڕێنرایەوە',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      duration: const Duration(seconds: 4),
    ),
  );
}

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'هەڵە لە گەڕاندنەوە: ${e.toString()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
      });
    }
  }

  Future<void> _viewBackupInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (!await backupDir.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هیچ باکئەپێک بوونی نییە'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }

      final files = await backupDir.list().toList();
      final backupFiles = files.whereType<File>().toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (backupFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هیچ باکئەپێک بوونی نییە'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.folder_open, color: Colors.blue),
                SizedBox(width: 8),
                Text('فایلەکانی باکئەپ'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: backupFiles.length,
                itemBuilder: (context, index) {
                  final file = backupFiles[index];
                  final stat = file.statSync();
                  final size = (stat.size / 1024).toStringAsFixed(1);
                  
                  return ListTile(
                    leading: const Icon(Icons.backup, color: Colors.green),
                    title: Text(file.uri.pathSegments.last),
                    subtitle: Text(
                      'قەبارە: ${size}KB • '
                      'بەروار: ${DateFormat('yyyy/MM/dd HH:mm').format(stat.modified)}'
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBackupFile(file),
                    ),
                  );
                },
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە لە بینینی باکئەپ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBackupFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی باکئەپ'),
        content: const Text('دڵنیایت لە سڕینەوەی ئەم فایلە؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('نەخێر'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('بەڵێ، بسڕەوە'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فایل بە سەرکەوتوویی سڕدرایەوە'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // داخستنی دیالۆگ
          _loadLastBackupInfo(); // نوێکردنەوەی زانیاری
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('هەڵە لە سڕینەوەی فایل: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // فەنکشنی _buildFeatureItem دروست دەکەین
  Widget _buildFeatureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // فەنکشنی _buildInfoCard دروست دەکەین
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.purple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 28, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'پاراستنی داتا',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.purple),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatureItem('✅', 'پاراستنی هەموو داتاکان'),
              _buildFeatureItem('🔄', 'گەڕاندنەوە لە کاتی پێویست'),
              _buildFeatureItem('📤', 'هاوبەشکردن لەگەڵ ئەپەکانی تر'),
              _buildFeatureItem('🔒', 'پاراستن لە ناو ئەپەکەوە'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'باکئەپ و گەڕاندنەوە',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _viewBackupInfo,
            tooltip: 'بینینی باکئەپەکان',
          ),
        ],
      ),
      body: _isProcessing
          ? _buildProgressIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // کارتی زانیاری
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // دوگمەی دروستکردنی باکئەپ
                  _buildActionCard(
                    title: '💾 دروستکردنی باکئەپ',
                    description: 'هەموو داتاکان پاشەکەوت بکە لە ئەپەکەوە',
                    icon: Icons.backup,
                    color: Colors.green.shade600,
                    onPressed: _createBackup,
                  ),
                  const SizedBox(height: 16),

                  // دوگمەی گەڕاندنەوە
                  _buildActionCard(
                    title: '📥 گەڕاندنەوەی باکئەپ',
                    description: 'داتاکان لە فایلێک بگەڕێنەوە',
                    icon: Icons.restore,
                    color: Colors.orange.shade600,
                    onPressed: _restoreBackup,
                  ),
                  const SizedBox(height: 24),

                  // زانیاری کۆتا باکئەپ
                  if (_lastBackupDate != null) ...[
                    _buildLastBackupInfo(),
                    const SizedBox(height: 24),
                  ],

                  // ڕێنماییەکان
                  _buildTipsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _progress,
                strokeWidth: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _progress < 0.5 ? 'بارکردنی داتا...' : 'پاشەکەوتکردن...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _progress < 0.3 ? 'کاڵاکان' :
            _progress < 0.6 ? 'فرۆشتنەکان' :
            _progress < 0.8 ? 'قەرزەکان' : 'تەواوبوون',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastBackupInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'کۆتا باکئەپ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy/MM/dd - HH:mm').format(_lastBackupDate!),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (_lastBackupPath != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastBackupPath!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'ڕێنماییەکان',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.blue),
          _buildTipItem('1️⃣', 'هەفتانە باکئەپ دروست بکە'),
          _buildTipItem('2️⃣', 'فایلەکە لە شوێنی سەلامەت هەڵبگرە'),
          _buildTipItem('3️⃣', 'پێش گەڕاندنەوە باکئەپێکی نوێ دروست بکە'),
          _buildTipItem('4️⃣', 'فایلەکان بە ناوی ڕێک هەڵبگرە'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}