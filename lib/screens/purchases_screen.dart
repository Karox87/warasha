import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:flutter/services.dart';
import 'barcode_scanner_screen.dart';
import 'package:url_launcher/url_launcher.dart';
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
      });
    }
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
      // ✅ گۆڕین بۆ List<Map<String, dynamic>> بۆ ئەوەی بتوانرێت بگۆڕدرێت
      final tempProducts = await _dbHelper.getProducts();
      _products = tempProducts.map((p) => Map<String, dynamic>.from(p)).toList();
      _filteredProducts = _products.map((p) => Map<String, dynamic>.from(p)).toList();
      
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
      builder: (context) => AlertDialog(
        title: const Text('زیادکردنی کاڵای نوێ'),
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
                  labelText: 'باڕکۆد (ئارەزوومەندانە)',
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
                  CurrencyInputFormatter(),
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
                  CurrencyInputFormatter(),
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
                  hintText: 'نرخی فرۆشتنی کۆمەڵ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'بڕ (ژمارەی کاڵا)',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
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
                  (p) => p['barcode']?.toString() == barcodeController.text,
                  orElse: () => {},
                );
                if (existingProduct.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('باڕکۆدەکە پێشتر تۆمارکراوە'),
                      backgroundColor: Colors.orange,
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
                  // ✅ دروستکردنی لیستی نوێ بە Map.from
                  _products = [..._products.map((p) => Map<String, dynamic>.from(p)), Map<String, dynamic>.from(product)];
                  _filterProducts();
                });
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کاڵاکە بە سەرکەوتوویی زیادکرا')),
                );
              }
            },
            child: const Text('زیادکردن'),
          ),
        ],
      ),
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 82, 75, 90),
      title: const Text('کڕینی کاڵا', style: TextStyle(color: Colors.white)),
      actions: [
        IconButton(
    icon: const Icon(Icons.developer_mode_rounded, color: Colors.white),
    tooltip: 'دەربارەی گەشەپێدەر',
    onPressed: _showDeveloperDialog,
  ),

        IconButton(
          icon: const Icon(Icons.add_business_rounded, color: Colors.white),
          tooltip: 'زیادکردنی کاڵای نوێ',
          onPressed: _showAddProductDialog,
        ),
        
      ],
    ),
      body: Column(
        children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
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
                                      if (product['barcode'] != null) ...[
                                        const SizedBox(width: 4),
                                      ],
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
                                          'کڕین: ${_formatNumber(product['buy_price'])}',
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
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: Colors.blue,
                                    onPressed: () => _showEditProductDialog(product),
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