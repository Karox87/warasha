import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'sales_history_screen.dart';
import 'barcode_scanner_screen.dart';
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final List<Map<String, dynamic>> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;



    // 🆕 فەنکشنی سکانی باڕکۆد بۆ فرۆشتن
 // ✅ کۆدی ڕاست
Future<void> _openBarcodeScannerForSale() async {
  if (!mounted) return;
  
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BarcodeScannerScreen(
        onBarcodeScanned: (barcode) {
          Navigator.pop(context); // داخستنی سکانەر
          
          try {
            final product = _products.firstWhere(
              (p) => p['barcode']?.toString() == barcode && p['quantity'] > 0,
            );

            _addToCart(product);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('کاڵا زیادکرا بۆ سەبەتە: ${product['name']}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کاڵایەک بەم باڕکۆدە نەدۆزرایەوە'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        },
        title: 'سکانی باڕکۆد بۆ فرۆشتن',
      ),
    ),
  );
}

  // 🆕 فەنکشنی سکانی باڕکۆد بۆ گەڕان
Future<void> _openBarcodeScannerForSearch() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BarcodeScannerScreen(
        onBarcodeScanned: (barcode) {
          // گەڕان بە باڕکۆد
          _searchByBarcodeForSale(barcode);
        },
        title: 'سکانی باڕکۆد بۆ گەڕان',
      ),
    ),
  );
}



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
  setState(() {
    if (query.isEmpty) {
      _filteredProducts = _products.where((p) => p['quantity'] > 0).toList();
    } else {
      _filteredProducts = _products.where((product) {
        final name = product['name'].toString().toLowerCase();
        final barcode = product['barcode']?.toString().toLowerCase() ?? '';
        
        // 🆕 گەڕان بە ناو یان باڕکۆد + پشکنینی بڕ
        return (name.contains(query) || barcode.contains(query)) && 
               product['quantity'] > 0;
      }).toList();
    }
  });
}


// ✅ کۆدی ڕاست
void _searchByBarcodeForSale(String barcode) {
  try {
    final product = _products.firstWhere(
      (p) => p['barcode']?.toString() == barcode && p['quantity'] > 0,
    );

    _addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('کاڵا زیادکرا بۆ سەبەتە: ${product['name']}'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('کاڵایەک بەم باڕکۆدە نەدۆزرایەوە یان بەتاڵە'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}


  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      _products = await _dbHelper.getProducts();
      _filteredProducts = _products.where((p) => p['quantity'] > 0).toList();
      _sales = await _dbHelper.getSales();
      
      for (var sale in _sales) {
        final product = _products.firstWhere(
          (p) => p['id'] == sale['product_id'],
          orElse: () => {'name': 'نەدۆزراوە'},
        );
        sale['product_name'] = product['name'];
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

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item['id'] == product['id']);
      
      if (existingIndex != -1) {
        final currentQty = _cart[existingIndex]['cart_quantity'];
        if (currentQty < product['quantity']) {
          _cart[existingIndex]['cart_quantity'] = currentQty + 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('بەی بەردەست تەنها ${product['quantity']} دانەیە!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        _cart.add({
          'id': product['id'],
          'name': product['name'],
          'sell_price': product['sell_price'],
          'buy_price': product['buy_price'],
          'max_quantity': product['quantity'],
          'cart_quantity': 1,
        });
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _updateCartQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
    } else if (newQuantity <= _cart[index]['max_quantity']) {
      setState(() {
        _cart[index]['cart_quantity'] = newQuantity;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بەی بەردەست تەنها ${_cart[index]['max_quantity']} دانەیە!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showEditPriceDialog(int index) {
    final item = _cart[index];
    final priceController = TextEditingController(text: item['sell_price'].toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دەستکاری نرخ'),
        content: TextField(
          controller: priceController,
          decoration: const InputDecoration(
            labelText: 'نرخی نوێ',
            border: OutlineInputBorder(),
            suffixText: 'IQD',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                setState(() {
                  _cart[index]['sell_price'] = newPrice;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('نرخی کاڵا نوێکرایەوە')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە نرخێکی دروست بنوووسە')),
                );
              }
            },
            child: const Text('نوێکردنەوە'),
          ),
        ],
      ),
    );
  }

  double _getCartTotal() {
    double total = 0;
    for (var item in _cart) {
      total += item['sell_price'] * item['cart_quantity'];
    }
    return total;
  }

  double _getCartProfit() {
    double profit = 0;
    for (var item in _cart) {
      profit += (item['sell_price'] - item['buy_price']) * item['cart_quantity'];
    }
    return profit;
  }

  // 🆕 فەنکشنی فرۆشتنی جوملە
  Future<void> _completeBulkSale({bool isCash = true, String customerName = ''}) async {
    if (_cart.isEmpty) return;

    // دروستکردنی ID-ی یەکتا بۆ فرۆشتنی جوملە
    final bulkSaleId = 'BULK_${DateTime.now().millisecondsSinceEpoch}';
    final totalAmount = _getCartTotal();

    try {
      // پاراستنی هەموو کاڵاکانی سەبەتە بە یەک bulk_sale_id
      for (var item in _cart) {
        final sale = {
          'product_id': item['id'],
          'product_name': item['name'],
          'buy_price': item['buy_price'],
          'quantity': item['cart_quantity'],
          'price': item['sell_price'],
          'total': item['sell_price'] * item['cart_quantity'],
          'date': DateTime.now().toIso8601String(),
          'bulk_sale_id': bulkSaleId, // 🆕 ID-ی فرۆشتنی جوملە
        };
        await _dbHelper.insertSale(sale);

        // کەمکردنەوەی بڕی کاڵا
        final product = _products.firstWhere((p) => p['id'] == item['id']);
        final newQuantity = product['quantity'] - item['cart_quantity'];
        await _dbHelper.updateProduct(
          item['id'],
          {...product, 'quantity': newQuantity},
        );
      }

      // زیادکردنی قەرز ئەگەر بە قەرز بێت
      if (!isCash) {
        final debt = {
          'customer_name': customerName,
          'amount': totalAmount,
          'paid': 0.0,
          'remaining': totalAmount,
          'description': 'فرۆشتنی جوملە ${_cart.length} جۆر - $bulkSaleId',
          'date': DateTime.now().toIso8601String(),
        };
        await _dbHelper.insertDebt(debt);
      }

      setState(() => _cart.clear());
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCash
                ? '✅ فرۆشتنی جوملە بە سەرکەوتوویی تۆمارکرا'
                : '📋 فرۆشتنی جوملە وەک قەرز بە $customerName تۆمارکرا'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
  }

  void _showCartDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سەبەتە بەتاڵە! کاڵایەک زیاد بکە')),
      );
      return;
    }

    bool isCash = true;
    final customerNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('سەبەتەی فرۆشتن'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() => _cart.clear());
                  Navigator.pop(dialogContext);
                },
                tooltip: 'بەتاڵکردنەوەی سەبەتە',
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🆕 بانەری فرۆشتنی جوملە
                if (_cart.length > 1)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'فرۆشتنی جوملە',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${_cart.length} جۆری کاڵا لە یەک فرۆشتندا',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      final itemTotal = item['sell_price'] * item['cart_quantity'];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit_price',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18),
                                            SizedBox(width: 8),
                                            Text('دەستکاری نرخ'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
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
                                      if (value == 'edit_price') {
                                        _showEditPriceDialog(index);
                                      } else if (value == 'remove') {
                                        setState(() => _removeFromCart(index));
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () {
                                          setState(() => _updateCartQuantity(
                                              index, item['cart_quantity'] - 1));
                                          setDialogState(() {});
                                        },
                                        color: Colors.red,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${item['cart_quantity']}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () {
                                          setState(() => _updateCartQuantity(
                                              index, item['cart_quantity'] + 1));
                                          setDialogState(() {});
                                        },
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showEditPriceDialog(index),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${_formatNumber(item['sell_price'])} IQD',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const Icon(Icons.edit, size: 14, color: Colors.blue),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${_formatNumber(itemTotal)} IQD',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24, thickness: 2),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.orange.shade100],
                    ),
                    borderRadius: BorderRadius.circular(8),
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
                            '${_formatNumber(_getCartTotal())} IQD',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('قازانج:', style: TextStyle(fontSize: 14)),
                          Text(
                            '${_formatNumber(_getCartProfit())} IQD',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('جۆری وەرگرتنی پارە'),
                  subtitle: Text(
                    isCash ? '💵 کاش' : '📋 قەرز',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCash ? Colors.green : Colors.orange,
                    ),
                  ),
                  value: isCash,
                  activeThumbColor: Colors.green,
                  onChanged: (value) => setDialogState(() => isCash = value),
                ),
                if (!isCash) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'ناوی کڕیار (قەرز)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: 'ناوی کەسی قەرزەکە بنوووسە',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('پاشگەزبوونەوە'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!isCash && customerNameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تکایە ناوی کڕیاری قەرز بنوووسە'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);
                
                await _completeBulkSale(
                  isCash: isCash,
                  customerName: customerNameController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: Icon(_cart.length > 1 ? Icons.inventory : Icons.sell),
              label: Text(
                _cart.length > 1 ? 'فرۆشتنی جوملە' : 'تەواوکردنی فرۆشتن',
                style: const TextStyle(fontSize: 16),
              ),
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
      title: const Text('فرۆشتنی کاڵا'),
      backgroundColor: Colors.orange,
      actions: [
        // دوگمەی سکانی باڕکۆد بۆ فرۆشتن
      /*  Container(
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: _openBarcodeScannerForSale,
            tooltip: 'سکانی باڕکۆد بۆ فرۆشتن',
          ),
        ),
        const SizedBox(width: 8), */
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('داتاکان نوێکرانەوە'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          tooltip: 'نوێکردنەوە',
        ),
        if (_cart.isNotEmpty)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _showCartDialog,
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesHistoryScreen(),
              ),
            ).then((_) => _loadData());
          },
          tooltip: 'مێژووی فرۆشتن',
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
                              _filterProducts();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.orange.shade50,
                  ),
                  onChanged: (value) {
                    _filterProducts();
                  },
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
                  onPressed: _openBarcodeScannerForSearch,
                  tooltip: 'سکانی باڕکۆد بۆ گەڕان',
                ),
              ),
            ],
          ),
        ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: Colors.orange,
                    child: _filteredProducts.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined,
                                          size: 80, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchController.text.isEmpty
                                            ? 'هیچ کاڵایەکی بەردەست نییە'
                                            : 'کاڵایەک نەدۆزرایەوە',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'ڕاکێشە بە خوارەوە بۆ نوێکردنەوە',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _filteredProducts.length > 3 ? 3 : _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              final isLowStock = product['quantity'] < 10;
                              final profit = product['sell_price'] - product['buy_price'];
                              final inCart = _cart.any((item) => item['id'] == product['id']);

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                elevation: 2,
                                color: inCart ? Colors.orange.shade50 : null,
                                child: ListTile(
                                  onTap: () => _addToCart(product),
                                  leading: CircleAvatar(
                                    backgroundColor: inCart
                                        ? Colors.orange.shade200
                                        : Colors.orange.shade100,
                                    child: Icon(
                                      inCart ? Icons.shopping_cart : Icons.sell,
                                      color: Colors.orange.shade700,
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
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'نرخ: ${_formatNumber(product['sell_price'])}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
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
                                              'قازانج: ${_formatNumber(profit)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green.shade700,
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
                                            'بەردەست: ${_formatNumber(product['quantity'])} دانە',
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
                                      if (inCart) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.shopping_cart,
                                                size: 12,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'لە سەبەتە: ${_cart.firstWhere((item) => item['id'] == product['id'])['cart_quantity']}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      inCart ? Icons.add_shopping_cart : Icons.add_circle,
                                      size: 28,
                                    ),
                                    color: Colors.orange,
                                    onPressed: () => _addToCart(product),
                                    tooltip: 'زیادکردن بۆ سەبەتە',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCartDialog,
              icon: Stack(
                children: [
                  Icon(_cart.length > 1 ? Icons.inventory : Icons.shopping_cart),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_cart.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              label: Text('${_formatNumber(_getCartTotal())} IQD'),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }
}