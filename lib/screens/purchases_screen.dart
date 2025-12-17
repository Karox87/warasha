import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:flutter/services.dart';
import 'barcode_scanner_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
 final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  final ScreenshotController _screenshotController = ScreenshotController();

  // ✅ زیاد کردنی متغیرەکانی پاجنەیشن
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  List<Map<String, dynamic>> _paginatedProducts = [];
  int get _totalPages => (_filteredProducts.length / _itemsPerPage).ceil();


  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  void _updatePagination() {
  final startIndex = _currentPage * _itemsPerPage;
  final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredProducts.length);
  
  _paginatedProducts = _filteredProducts.sublist(
    startIndex,
    endIndex,
  ).map((p) => Map<String, dynamic>.from(p)).toList();
}

void _goToPage(int page) {
  if (page >= 0 && page < _totalPages) {
    setState(() {
      _currentPage = page;
      _updatePagination();
    });
  }
}

  

  void _filterProducts() {
  final query = _searchController.text.toLowerCase();
  if (mounted) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products.map((p) => Map<String, dynamic>.from(p)).toList();
      } else {
        _filteredProducts = _products.where((product) {
          final name = product['name'].toString().toLowerCase();
          final barcode = product['barcode']?.toString().toLowerCase() ?? '';
          return name.contains(query) || barcode.contains(query);
        }).map((p) => Map<String, dynamic>.from(p)).toList();
      }
      _currentPage = 0; // ✅ گەڕانەوە بۆ پەیجی یەکەم
      _updatePagination();
    });
  }
}

  String _calculateEAN13Checksum(String barcode) {
  if (barcode.length != 12 && barcode.length != 13) {
    return barcode;
  }
  
  // ئەگەر 13 ژمارە بێت، یەکەمین 12 وەربگرە
  String first12 = barcode.length == 13 ? barcode.substring(0, 12) : barcode;
  
  int sum = 0;
  for (int i = 0; i < 12; i++) {
    int digit = int.parse(first12[i]);
    // ژمارەکانی تاق (پۆزیشنی 1,3,5...) × 1
    // ژمارەکانی جووت (پۆزیشنی 0,2,4...) × 3
    sum += (i % 2 == 0) ? digit : digit * 3;
  }
  
  int checksum = (10 - (sum % 10)) % 10;
  return first12 + checksum.toString();
}

Map<String, dynamic> _prepareBarcodeData(String? barcode) {
  // ئەگەر باڕکۆد بەتاڵ بێت
  if (barcode == null || barcode.isEmpty) {
    return {
      'data': 'NO-BARCODE',
      'type': Barcode.code128(),
      'isValid': false,
      'displayText': 'باڕکۆد نییە',
    };
  }
  
  // پاککردنەوەی تەنها بۆشایی
  String cleaned = barcode.trim();
  
  if (cleaned.isEmpty) {
    return {
      'data': 'NO-BARCODE',
      'type': Barcode.code128(),
      'isValid': false,
      'displayText': 'باڕکۆد نادروستە',
    };
  }
  
  // ✅ بەکارهێنانی Code128 بۆ هەموو جۆرێک
  // Code128 هەموو کاراکتێرێک قبووڵ دەکات (ژمارە، پیت، هێما)
  try {
    return {
      'data': cleaned,  // ✅ وەک خۆی بەکاری دەهێنین
      'type': Barcode.code128(),
      'isValid': true,
      'displayText': cleaned,
    };
  } catch (e) {
    // ئەگەر Code128 کار نەکرد، QR Code بەکاربهێنە
    return {
      'data': cleaned,
      'type': Barcode.qrCode(),
      'isValid': true,
      'displayText': cleaned,
    };
  }
}

  Barcode _getBarcodeType(String barcode) {
  final length = barcode.length;
  
  if (length == 13) {
    return Barcode.ean13();
  } else if (length == 8) {
    return Barcode.ean8();
  } else if (length == 12) {
    return Barcode.upcA();
  } else {
    return Barcode.code128(); // بۆ هەموو درێژییەکی تر
  }
}


  String _prepareBarcode(String? barcode) {
  if (barcode == null || barcode.isEmpty) {
    return '0000000000000'; // باڕکۆدی default
  }
  
  // لابردنی هەموو کاراکتەرێک جگە لە ژمارە
  String cleaned = barcode.replaceAll(RegExp(r'[^0-9]'), '');
  
  if (cleaned.isEmpty) {
    return '0000000000000';
  }
  
  // ئەگەر کەمتر لە 13 ژمارە بێت، سفر زیاد بکە
  if (cleaned.length < 13) {
    cleaned = cleaned.padLeft(13, '0');
  }
  
  // ئەگەر زیاتر لە 13 بێت، بیبڕەوە
  if (cleaned.length > 13) {
    cleaned = cleaned.substring(0, 13);
  }
  
  return cleaned;
}

  String _generateUniqueBarcode() {
    final random = Random();
    String barcode;
    
    do {
      // دروستکردنی باڕکۆدی 13 ژمارەیی (2 بەش: 3 ژمارە + 10 ژمارە)
      final part1 = '200';
      final part2 = random.nextInt(1000000000).toString().padLeft(9, '0');
      final checkDigit = random.nextInt(10).toString();
      barcode = part1 + part2 + checkDigit;
    } while (_products.any((p) => p['barcode']?.toString() == barcode));
    
    return barcode;
  }

  void _searchByBarcode(String barcode) {
    try {
      final product = _products.firstWhere(
        (p) => p['barcode']?.toString() == barcode,
      );
      _showProductDetails(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کاڵایەک بەم باڕکۆدە نەدۆزرایەوە'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }


    



Future<void> _printBarcode(
  Map<String, dynamic> product, {
  bool showName = true,
  bool showPrice = true,
  String? customName,
}) async {
  try {
    final barcodeInfo = _prepareBarcodeData(product['barcode']?.toString());
    
    // دروستکردنی وێنەی باڕکۆد
    final Uint8List image = await _screenshotController.captureFromWidget(
      Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ناوی کاڵا
            if (showName)
              Text(
                customName ?? product['name'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            if (showName) const SizedBox(height: 20),
            
            // باڕکۆد
            if (barcodeInfo['isValid'])
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: BarcodeWidget(
                  barcode: barcodeInfo['type'],
                  data: barcodeInfo['data'],
                  width: 320,
                  height: 110,
                  drawText: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  errorBuilder: (context, error) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'هەڵە لە باڕکۆد',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2_outlined, size: 70, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'باڕکۆد نییە',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // نرخی فرۆشتن
            if (showPrice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Text(
                  'نرخ: ${_formatNumber(product['sell_price'])} IQD',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
      delay: const Duration(milliseconds: 200),
    );

    if (image == null) {
      throw Exception('نەتوانرا وێنە دروست بکرێت');
    }

    // پاشەکەوتکردنی وێنە
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imagePath = '${directory.path}/barcode_${product['id']}_$timestamp.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(image);

    // هاوبەشکردنی وێنە (بۆ پرێنت)
    await Share.shareXFiles(
      [XFile(imagePath)],
      text: 'باڕکۆدی ${product['name']}',
      subject: 'باڕکۆد',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'وێنەی باڕکۆد ئامادەیە بۆ پرێنت',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    print('هەڵە لە پرێنتی باڕکۆد: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('هەڵە: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

void _showBarcodePrintDialog(Map<String, dynamic> product) {
  final TextEditingController nameController = TextEditingController(
    text: product['name'],
  );
  bool showPrice = true;
  bool showProductName = true;
  
  final barcodeInfo = _prepareBarcodeData(product['barcode']?.toString());

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.print, color: Colors.blue.shade700, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'پرێنتی باڕکۆد',
                style: TextStyle(fontSize: 22),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // پێشبینینی باڕکۆد
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (showProductName)
                      Text(
                        nameController.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (showProductName) const SizedBox(height: 16),
                    
                    if (barcodeInfo['isValid'])
                      BarcodeWidget(
                        barcode: barcodeInfo['type'],
                        data: barcodeInfo['data'],
                        width: 240,
                        height: 100,
                        drawText: true,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        errorBuilder: (context, error) => Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, size: 50, color: Colors.red.shade300),
                              const SizedBox(height: 8),
                              Text(
                                'هەڵە',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.qr_code_2_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'باڕکۆد نییە',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    
                    if (showPrice) const SizedBox(height: 16),
                    if (showPrice)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200, width: 2),
                        ),
                        child: Text(
                          '${_formatNumber(product['sell_price'])} IQD',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // کەستەمایزکردن
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Colors.blue.shade700, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'کەستەمایزکردن',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // ناوی کاڵا
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: CheckboxListTile(
                  title: const Text('پیشاندانی ناوی کاڵا'),
                  value: showProductName,
                  onChanged: (value) {
                    setState(() => showProductName = value ?? true);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // نرخ
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: CheckboxListTile(
                  title: const Text('پیشاندانی نرخ'),
                  value: showPrice,
                  onChanged: (value) {
                    setState(() => showPrice = value ?? true);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // دەستکاریی ناو
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'دەستکاریی ناوی کاڵا',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.edit),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => setState(() {}),
              ),
              
              const SizedBox(height: 16),
              
              // زانیاری باڕکۆد
              if (product['barcode'] != null && barcodeInfo['isValid'])
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'باڕکۆد: ${barcodeInfo['data']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            Text(
                              'جۆر: ${barcodeInfo['type'].name}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _printBarcode(
                product,
                showName: showProductName,
                showPrice: showPrice,
                customName: nameController.text,
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('پرێنت', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    ),
  );
}


  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ناو: ${product['name']}'),
            if (product['barcode'] != null) 
              Text('باڕکۆد: ${product['barcode']}'),
            Text('نرخی کڕین: ${_formatNumber(product['buy_price'])} IQD'),
            Text('نرخی فرۆشتن: ${_formatNumber(product['sell_price'])} IQD'),
            Text('بڕ: ${_formatNumber(product['quantity'])} دانە'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditProductDialog(product);
            },
            child: const Text('دەستکاری'),
          ),
        ],
      ),
    );
  }


 void _showGeneratedBarcodeDialog(String barcode, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code_2, color: Colors.green.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'باڕکۆدی نوێ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_scanner, size: 80, color: Colors.green.shade600),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SelectableText(
                      barcode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ئەم باڕکۆدە تایبەتە بە ئەم کاڵایە',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: barcode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('باڕکۆد کۆپی کرا: $barcode'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('کۆپیکردن'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              controller.text = barcode;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('باڕکۆد بەکارهێنرا بۆ کاڵاکە'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('بەکارهێنان'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }



void _showDeveloperDialog() {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // سەرپەڕە
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // ناوەڕۆک
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // ئایکۆن
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.code,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'پێویستت بە سیستەمی مۆبایل هەیە؟',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'سیستەمی تایبەت بە کۆگا، چێشتخانە، یان بزنسەکەت دروست بکە',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // کارتی زانیاری
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, color: Colors.blue.shade700, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'کارۆخ غەفور',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'گەشەپێدەری سیستەمی مۆبایل',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // دوگمەی پەیوەندی
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final phone = Uri.parse('tel:+9647502321637');
                              await launchUrl(phone);
                            } catch (e) {
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
                          icon: const Icon(Icons.phone, size: 22),
                          label: const Text(
                            '0750 232 16 37',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // ✅ دوگمەی WhatsApp - چاککراوە
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final whatsapp = Uri.parse(
                                'https://wa.me/9647502321637?text=${Uri.encodeComponent("سڵاو، دەمەوێت سیستەمێک دروست بکەم")}'
                              );
                              // ✅ بێ پشکنین - راستەوخۆ کردنەوە
                              await launchUrl(
                                whatsapp,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              // ئەگەر WhatsApp نەبوو، browser بکەرەوە
                              try {
                                final fallbackUrl = Uri.parse('https://wa.me/9647502321637');
                                await launchUrl(fallbackUrl);
                              } catch (e2) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تکایە WhatsApp دامەزرێنە'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: Icon(Icons.chat, color: Colors.green.shade600),
                          label: Text(
                            'پەیوەندی لە WhatsApp',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.green.shade600, width: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // تێبینی
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber.shade300, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'خزمەتگوزاری پیشەیی و کوالیتی بەرز',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _openBarcodeScannerForSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onBarcodeScanned: (barcode) {
            _searchByBarcode(barcode);
          },
          title: 'سکانی باڕکۆد بۆ گەڕان',
        ),
      ),
    );
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onBarcodeScanned: (barcode) {
            setState(() {
              _searchController.text = barcode;
            });
            _filterProducts();
          },
          title: 'سکانی باڕکۆد بۆ گەڕان',
        ),
      ),
    );
  }

  Future<void> _scanBarcodeInForm(TextEditingController barcodeController) async {
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onBarcodeScanned: (barcode) {
            barcodeController.text = barcode;
            if (mounted) {
              setState(() {});
            }
          },
          title: 'سکانی باڕکۆد بۆ کاڵا',
        ),
      ),
    );
  }

 Future<void> _loadData() async {
  if (!mounted) return;
  setState(() => _isLoading = true);
  
  try {
    final tempProducts = await _dbHelper.getProducts();
    _products = tempProducts.map((p) => Map<String, dynamic>.from(p)).toList();
    _filteredProducts = _products.map((p) => Map<String, dynamic>.from(p)).toList();
    
    _updatePagination(); // ✅ زیاد کردنی پاجنەیشن
    
    final tempPurchases = await _dbHelper.getPurchases();
    _purchases = tempPurchases.map((p) => Map<String, dynamic>.from(p)).toList();
    
    for (var purchase in _purchases) {
      final product = _products.firstWhere(
        (p) => p['id'] == purchase['product_id'],
        orElse: () => {'name': 'نەدۆزرایەوە'},
      );
      purchase['product_name'] = product['name'];
    }
  } catch (e) {
    print('هەڵە لە بارکردنی داتا: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


// گۆڕینی Widget ی پاجنەیشن بۆ دەرخستنی هەمیشەیی

Widget _buildPaginationControls() {
  // ✅ لابردنی شەرتی شاردنەوە
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blue.shade50, Colors.blue.shade100],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.shade200, width: 1.5),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // دوگمەی پێشوو
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _currentPage > 0 
                    ? Colors.blue.shade600 
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _currentPage > 0
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left,
                    color: _currentPage > 0 ? Colors.white : Colors.grey.shade500,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'پێشوو',
                    style: TextStyle(
                      color: _currentPage > 0 ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // زانیاری پەیج
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade300, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                '${_currentPage + 1} / ${_totalPages == 0 ? 1 : _totalPages}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_filteredProducts.length} کاڵا',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // دوگمەی دواتر
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _currentPage < _totalPages - 1 
                ? () => _goToPage(_currentPage + 1) 
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _currentPage < _totalPages - 1 
                    ? Colors.blue.shade600 
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _currentPage < _totalPages - 1
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    'دواتر',
                    style: TextStyle(
                      color: _currentPage < _totalPages - 1 
                          ? Colors.white 
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: _currentPage < _totalPages - 1 
                        ? Colors.white 
                        : Colors.grey.shade500,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
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

void _showAddProductDialog() {
    final nameController = TextEditingController();
    final barcodeController = TextEditingController();
    final buyPriceController = TextEditingController();
    final sellPriceController = TextEditingController();
    final wholesalePriceController = TextEditingController();
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // سەرپەڕە
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'زیادکردنی کاڵای نوێ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'زانیاریەکانی کاڵا پڕ بکەرەوە',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ناوەڕۆک
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // ناوی کاڵا
                      _buildModernTextField(
                        controller: nameController,
                        label: 'ناوی کاڵا',
                        hint: 'نمونەی ناوی کاڵا',
                        icon: Icons.shopping_bag,
                        iconColor: Colors.orange,
                      ),
                      const SizedBox(height: 16),

                      // بارکۆد
                      _buildBarcodeField(barcodeController),
                      const SizedBox(height: 16),

                      // نرخەکان لە Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernTextField(
                              controller: buyPriceController,
                              label: 'نرخی کڕین',
                              hint: '0',
                              icon: Icons.shopping_cart,
                              iconColor: Colors.green,
                              suffix: 'IQD',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernTextField(
                              controller: sellPriceController,
                              label: 'نرخی فرۆشتن',
                              hint: '0',
                              icon: Icons.sell,
                              iconColor: Colors.blue,
                              suffix: 'IQD',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // نرخی جومڵە
                      _buildModernTextField(
                        controller: wholesalePriceController,
                        label: 'نرخی جومڵە (ئارەزوومەندانە)',
                        hint: 'نرخی فرۆشتنی کۆمەڵ',
                        icon: Icons.inventory_2,
                        iconColor: Colors.purple,
                        suffix: 'IQD',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // بڕ
                      _buildModernTextField(
                        controller: quantityController,
                        label: 'بڕی کاڵا',
                        hint: '0',
                        icon: Icons.inventory,
                        iconColor: Colors.teal,
                        suffix: 'دانە',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // دوگمەکان
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('لابردن'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
    buyPriceController.text.isEmpty ||
    sellPriceController.text.isEmpty ||
    quantityController.text.isEmpty) {  // ✅ ئەمە زیاد کرا
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white),
          SizedBox(width: 12),
          Text('تکایە هەموو خانە پێویستەکان پڕ بکەرەوە'),
        ],
      ),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
  return;
}

                          if (barcodeController.text.isNotEmpty) {
                            final existingProduct = _products.firstWhere(
                              (p) => p['barcode']?.toString() == barcodeController.text,
                              orElse: () => {},
                            );
                            if (existingProduct.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text('بارکۆدەکە پێشتر تۆمارکراوە'),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          String cleanBuyPrice = buyPriceController.text.replaceAll(',', '');
                          String cleanSellPrice = sellPriceController.text.replaceAll(',', '');
                          String? cleanWholesalePrice = wholesalePriceController.text.isNotEmpty 
                              ? wholesalePriceController.text.replaceAll(',', '') 
                              : null;

                          final product = {
                            'name': nameController.text,
                            'barcode': barcodeController.text.isEmpty ? null : barcodeController.text,
                            'buy_price': double.parse(cleanBuyPrice),
                            'sell_price': double.parse(cleanSellPrice),
                            'wholesale_price': cleanWholesalePrice != null ? double.parse(cleanWholesalePrice) : null,
                            'quantity': int.parse(quantityController.text),
                            'created_at': DateTime.now().toIso8601String(),
                          };

                          final id = await _dbHelper.insertProduct(product);
                          product['id'] = id;
                          
                          Navigator.pop(context);
                          
                          if (mounted) {
                            setState(() {
                              _products = [..._products.map((p) => Map<String, dynamic>.from(p)), Map<String, dynamic>.from(product)];
                              _filterProducts();
                            });
                          }
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('${nameController.text} بە سەرکەوتوویی زیادکرا'),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                          'زیادکردن',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    String? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            suffixText: suffix,
            suffixStyle: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: iconColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: suffix == 'IQD' || suffix == 'دانە' 
              ? TextInputType.number 
              : TextInputType.text,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }


  Widget _buildBarcodeField(TextEditingController barcodeController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.qr_code_2, size: 18, color: Colors.deepPurple.shade600),
            const SizedBox(width: 8),
            Text(
              'بارکۆد (ئارەزوومەندانە)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: barcodeController,
          decoration: InputDecoration(
            hintText: 'بارکۆد دابنێ یان دروستی بکە',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.deepPurple.shade600, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final newBarcode = _generateUniqueBarcode();
                        _showGeneratedBarcodeDialog(newBarcode, barcodeController);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.green.shade700,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _scanBarcodeInForm(barcodeController),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⭐ دروستکردنی باڕکۆد  📷 سکانی باڕکۆد',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPriceForInput(dynamic price) {
    if (price == null) return '';
    
    if (price is double) {
      if (price == price.truncateToDouble()) {
        return price.toInt().toString();
      }
      return price.toString();
    }
    
    if (price is int) {
      return price.toString();
    }
    
    return price.toString().replaceAll('.0', '');
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name']);
    final barcodeController = TextEditingController(text: product['barcode']?.toString() ?? '');
    
    // ✅ فۆرماتکردنی ژمارەکان بە کۆما
    final buyPriceController = TextEditingController(
      text: _formatNumber(product['buy_price'])
    );
    final sellPriceController = TextEditingController(
      text: _formatNumber(product['sell_price'])
    );
    final wholesalePriceController = TextEditingController(
      text: product['wholesale_price'] != null 
          ? _formatNumber(product['wholesale_price'])
          : ''
    );
    
    final quantityController = TextEditingController(text: product['quantity'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دەستکاری کاڵا'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'ناوی کاڵا',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcodeController,
                decoration: InputDecoration(
                  labelText: 'باڕکۆد',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () => _scanBarcodeInForm(barcodeController),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: buyPriceController,
                decoration: const InputDecoration(
                  labelText: 'نرخی کڕین',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                  suffixText: 'IQD',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(), // ✅ زیادکردنی فۆرماتکەر
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sellPriceController,
                decoration: const InputDecoration(
                  labelText: 'نرخی فرۆشتن',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sell),
                  suffixText: 'IQD',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(), // ✅ زیادکردنی فۆرماتکەر
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wholesalePriceController,
                decoration: const InputDecoration(
                  labelText: 'نرخی جوملە (ئارەزوومەندانە)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                  suffixText: 'IQD',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(), // ✅ زیادکردنی فۆرماتکەر
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'بڕ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
              if (nameController.text.isEmpty ||
                  buyPriceController.text.isEmpty ||
                  sellPriceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە هەموو خانەکان پڕبکەرەوە')),
                );
                return;
              }

              if (barcodeController.text.isNotEmpty) {
                final existingProduct = _products.firstWhere(
                  (p) => p['barcode']?.toString() == barcodeController.text && p['id'] != product['id'],
                  orElse: () => {},
                );
                if (existingProduct.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('باڕکۆدەکە پێشتر بۆ کاڵایەکی تر تۆمارکراوە'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }

              // ✅ لابردنی کۆما پێش پاشەکەوتکردن
              final cleanBuyPrice = buyPriceController.text.replaceAll(',', '');
              final cleanSellPrice = sellPriceController.text.replaceAll(',', '');
              final cleanWholesalePrice = wholesalePriceController.text.isNotEmpty 
                  ? wholesalePriceController.text.replaceAll(',', '')
                  : null;

              final updatedProduct = {
                'id': product['id'],
                'name': nameController.text,
                'barcode': barcodeController.text.isEmpty ? null : barcodeController.text,
                'buy_price': double.parse(cleanBuyPrice),
                'sell_price': double.parse(cleanSellPrice),
                'wholesale_price': cleanWholesalePrice != null 
                    ? double.parse(cleanWholesalePrice) 
                    : null,
                'quantity': int.parse(quantityController.text),
                'created_at': product['created_at'],
              };

              await _dbHelper.updateProduct(product['id'], updatedProduct);
              
              // ✅ نوێکردنەوەی لیستەکان بە شێوەی دروست
              if (mounted) {
                setState(() {
                  // دروستکردنی لیستی نوێ لە جیاتی گۆڕینی راستەوخۆ
                  _products = _products.map((p) {
                    if (p['id'] == product['id']) {
                      return Map<String, dynamic>.from(updatedProduct);
                    }
                    return Map<String, dynamic>.from(p);
                  }).toList();
                  
                  _filterProducts();
                });
              }
              
              Navigator.pop(context);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کاڵاکە بە سەرکەوتوویی نوێکرایەوە')),
                );
              }
            },
            child: const Text('نوێکردنەوە'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوە'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دڵنیایت لە سڕینەوەی "${product['name']}"؟'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مێژووی فرۆشتنەکانی ئەم کاڵایە دەمێنێتەوە',
                      style: TextStyle(fontSize: 12),
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
                Navigator.pop(context);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تکایە چاوەڕێ بە...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                
                final db = await _dbHelper.database;
                
                await db.delete('purchases', where: 'product_id = ?', whereArgs: [product['id']]);
                await db.delete('products', where: 'id = ?', whereArgs: [product['id']]);
                
                await _loadData();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${product['name']}" بە سەرکەوتووی سڕایەوە'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                print('❌ هەڵە لە سڕینەوە: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('هەڵە لە سڕینەوە: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('بەڵێ، بیسڕەوە',style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPurchaseDialog() {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سەرەتا کاڵایەک زیاد بکە')),
      );
      return;
    }

    Map<String, dynamic>? selectedProduct = _products[0];
    final quantityController = TextEditingController();
    final priceController = TextEditingController(
      text: selectedProduct['buy_price'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تۆمارکردنی کڕینی نوێ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedProduct,
                  decoration: const InputDecoration(
                    labelText: 'هەڵبژاردنی کاڵا',
                    border: OutlineInputBorder(),
                  ),
                  items: _products.map((product) {
                    return DropdownMenuItem(
                      value: product,
                      child: Text(product['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedProduct = value;
                      priceController.text = value!['buy_price'].toString();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'بڕی کڕاو',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shopping_cart),
                  ),
                  keyboardType: TextInputType.number,
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
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setStateDialog(() {}),
                ),
                const SizedBox(height: 16),
                if (quantityController.text.isNotEmpty && priceController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'کۆی گشتی:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_formatNumber((int.tryParse(quantityController.text) ?? 0) * (double.tryParse(priceController.text) ?? 0))} IQD',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
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
                if (selectedProduct == null ||
                    quantityController.text.isEmpty ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تکایە هەموو خانەکان پڕبکەرەوە')),
                  );
                  return;
                }

                final quantity = int.parse(quantityController.text);
                final price = double.parse(priceController.text);
                final total = quantity * price;

                final purchase = {
                  'product_id': selectedProduct!['id'],
                  'quantity': quantity,
                  'price': price,
                  'total': total,
                  'date': DateTime.now().toIso8601String(),
                };

                await _dbHelper.insertPurchase(purchase);

                final newQuantity = selectedProduct!['quantity'] + quantity;
                final updatedProduct = {...selectedProduct!, 'quantity': newQuantity};
                await _dbHelper.updateProduct(
                  selectedProduct!['id'],
                  updatedProduct,
                );

                final index = _products.indexWhere((p) => p['id'] == selectedProduct!['id']);
                if (index != -1) {
                  _products[index] = Map<String, dynamic>.from(updatedProduct);
                }

                Navigator.pop(context);

                if (mounted) {
                  setState(() {
                    _filterProducts();
                  });
                }

                _purchases = (await _dbHelper.getPurchases()).map((p) => Map<String, dynamic>.from(p)).toList();
                for (var purchase in _purchases) {
                  final product = _products.firstWhere(
                    (p) => p['id'] == purchase['product_id'],
                    orElse: () => {'name': 'نەدۆزرایەوە'},
                  );
                  purchase['product_name'] = product['name'];
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('کڕینەکە بە سەرکەوتوویی تۆمارکرا')),
                  );
                }
              },
              child: const Text('تۆمارکردن'),
            ),
          ],
        ),
      ),
    );
  }

// گۆڕینی شوێنی کۆنترۆڵی پاجنەیشن بۆ سەرەوە

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 82, 75, 90),
      title: const Text('کەینی کاڵا', style: TextStyle(color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.developer_mode_rounded, color: Colors.white),
          tooltip: 'دەربارەی گەشەپێدەر',
          onPressed: _showDeveloperDialog,
        ),
        IconButton(
          icon: const Icon(Icons.add_business_rounded, color: Colors.white),
          tooltip: 'زیادکردنی کاڵایی نوێ',
          onPressed: _showAddProductDialog,
        ),
      ],
    ),
    body: Column(
      children: [
        // گەڕان
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'گەڕان بە کاڵا یان باڕکۆد...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: _openBarcodeScanner,
                  tooltip: 'سکانی باڕکۆد',
                ),
              ),
            ],
          ),
        ),
        
        // ✅ کۆنترۆڵی پاجنەیشن لە سەرەوە
        _buildPaginationControls(),
        
        // لیستی کاڵاکان
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'هیچ کاڵایەک نییە'
                                : 'کاڵایەک نەدۆزرایەوە',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: _paginatedProducts.length,
                      itemBuilder: (context, index) {
                        final product = _paginatedProducts[index];
                        final isLowStock = product['quantity'] < 10;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          color: isLowStock ? Colors.red.shade50 : null,
                          child: ListTile(
                            onTap: () => _showEditProductDialog(product),
                            leading: CircleAvatar(
                              backgroundColor: isLowStock
                                  ? Colors.red.shade100
                                  : Colors.green.shade100,
                              child: Icon(
                                Icons.inventory,
                                color: isLowStock
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            title: Text(
                              product['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'کەین: ${_formatNumber(product['buy_price'])}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'فرۆشتن: ${_formatNumber(product['sell_price'])}',
                                        style: TextStyle(
                                          fontSize: 11,
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
                                    Icon(
                                      Icons.inventory_2,
                                      size: 14,
                                      color: isLowStock
                                          ? Colors.red
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'بڕی ماوە: ${_formatNumber(product['quantity'])} دانە',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isLowStock
                                            ? Colors.red
                                            : Colors.grey.shade600,
                                        fontWeight: isLowStock
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (isLowStock) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '⚠️ کەمە',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.print, size: 20),
                                  color: Colors.green,
                                  tooltip: 'پرێنتی باڕکۆد',
                                  onPressed: () => _showBarcodePrintDialog(product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _showDeleteConfirmDialog(product),
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
  );
}
}
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final value = int.parse(newValue.text.replaceAll(',', ''));
    final newText = NumberFormat('#,###').format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}