import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'sales_history_screen.dart';
import 'barcode_scanner_screen.dart';
import 'package:flutter/services.dart'; // 🆕 زیادکراوە
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

Future<List<Map<String, dynamic>>> _getUniqueDebtors() async {
  try {
    final db = await _dbHelper.database;
    
    // وەرگرتنی قەرزدارە یەکتاکان کە قەرزیان ماوە
    final debtors = await db.rawQuery('''
      SELECT DISTINCT customer_name, 
             SUM(remaining) as total_remaining,
             MAX(date) as last_date,
             COUNT(*) as debt_count
      FROM debts 
      WHERE remaining > 0
      GROUP BY customer_name
      ORDER BY last_date DESC
    ''');
    
    return debtors;
  } catch (e) {
    print('هەڵە لە وەرگرتنی قەرزداران: $e');
    return [];
  }
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
          'wholesale_price': product['wholesale_price'], // 🆕
          'max_quantity': product['quantity'],
          'cart_quantity': 1,
          'is_wholesale': false, // 🆕
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

// 🔧 فەنکشنی تەواوی دەستکاری نرخ
// لە sales_screen.dart بدۆزەرەوە و بیگۆڕە بەمە:

void _showEditPriceDialog(int index) {
  final item = _cart[index];
  
  // 🆕 فۆرماتکردنی نرخ بۆ پیشاندان (بێ .0 و بە فاریزە)
  String formatPriceForDisplay(dynamic price) {
    if (price == null) return '';
    
    double priceValue;
    if (price is int) {
      priceValue = price.toDouble();
    } else if (price is double) {
      priceValue = price;
    } else {
      priceValue = double.tryParse(price.toString()) ?? 0.0;
    }
    
    // گۆڕینی بۆ int ئەگەر تەواوە
    if (priceValue == priceValue.truncateToDouble()) {
      return NumberFormat('#,###').format(priceValue.toInt());
    }
    
    return NumberFormat('#,###').format(priceValue.toInt());
  }
  
  final priceController = TextEditingController(
    text: formatPriceForDisplay(item['sell_price'])
  );
  
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
          hintText: 'بۆ نموونە: 15,000',
        ),
        keyboardType: TextInputType.number,
        // 🆕 زیادکردنی فۆرماتکەر بۆ نووسین
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly, // تەنها ژمارە
          TextInputFormatter.withFunction((oldValue, newValue) {
            if (newValue.text.isEmpty) return newValue;
            
            // لابردنی فاریزەکان
            final cleanText = newValue.text.replaceAll(',', '');
            final number = int.tryParse(cleanText);
            
            if (number == null) return oldValue;
            
            // زیادکردنی فاریزە
            final formatted = NumberFormat('#,###').format(number);
            
            return TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('پاشگەزبوونەوە'),
        ),
        ElevatedButton(
          onPressed: () {
            // 🆕 لابردنی فاریزە پێش پاشەکەوت
            final cleanPrice = priceController.text.replaceAll(',', '');
            final newPrice = double.tryParse(cleanPrice);
            
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
                const SnackBar(content: Text('تکایە نرخێکی دروست بنووسە')),
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
    final isWholesale = item['is_wholesale'] ?? false;
    final currentPrice = isWholesale && item['wholesale_price'] != null
        ? item['wholesale_price']
        : item['sell_price'];
    total += currentPrice * item['cart_quantity'];
  }
  return total;
}

double _getCartProfit() {
  double profit = 0;
  for (var item in _cart) {
    final isWholesale = item['is_wholesale'] ?? false;
    final currentPrice = isWholesale && item['wholesale_price'] != null
        ? item['wholesale_price']
        : item['sell_price'];
    profit += (currentPrice - item['buy_price']) * item['cart_quantity'];
  }
  return profit;
}

  // 🆕 فەنکشنی فرۆشتنی جوملە
// 🆕 فەنکشنی پشکنینی قەرزی ماوە بۆ کەسێک
Future<double> _getCustomerRemainingDebt(String customerName) async {
  try {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT SUM(remaining) as total_remaining
      FROM debts 
      WHERE customer_name = ? AND remaining > 0
    ''', [customerName]);
    
    final total = result.first['total_remaining'];
    return total != null ? (total as num).toDouble() : 0.0;
  } catch (e) {
    print('هەڵە لە وەرگرتنی قەرزی ماوە: $e');
    return 0.0;
  }
}

// 🆕 نوێکردنەوەی فەنکشنی فرۆشتنی جوملە
Future<void> _completeBulkSale({bool isCash = true, String customerName = ''}) async {
  if (_cart.isEmpty) return;

  final bulkSaleId = 'BULK_${DateTime.now().millisecondsSinceEpoch}';
  final totalAmount = _getCartTotal();

  try {
    for (var item in _cart) {
      final isWholesale = item['is_wholesale'] ?? false;
      final salePrice = isWholesale && item['wholesale_price'] != null
          ? item['wholesale_price']
          : item['sell_price'];
          
      final sale = {
        'product_id': item['id'],
        'product_name': item['name'],
        'buy_price': item['buy_price'],
        'quantity': item['cart_quantity'],
        'price': salePrice,
        'total': salePrice * item['cart_quantity'],
        'date': DateTime.now().toIso8601String(),
        'bulk_sale_id': bulkSaleId,
      };
      await _dbHelper.insertSale(sale);

      final product = _products.firstWhere((p) => p['id'] == item['id']);
      final newQuantity = product['quantity'] - item['cart_quantity'];
      await _dbHelper.updateProduct(
        item['id'],
        {...product, 'quantity': newQuantity},
      );
    }

    if (!isCash && customerName.isNotEmpty) {
      // 🆕 پشکنینی قەرزی پێشوو
      final existingDebtAmount = await _getCustomerRemainingDebt(customerName);
      
      if (existingDebtAmount > 0) {
        // ئەگەر قەرزی پێشوو هەیە، زیادیکەی بکە بۆ قەرزە کۆنەکە
        final debts = await _dbHelper.getDebts();
        final customerDebts = debts.where((debt) => 
            debt['customer_name'] == customerName && (debt['remaining'] as double) > 0).toList();
        
        if (customerDebts.isNotEmpty) {
          // زیادکردنی بۆ کۆنترین قەرزی ماوە
          final oldestDebt = customerDebts.reduce((a, b) => 
              DateTime.parse(a['date'] as String).isBefore(DateTime.parse(b['date'] as String)) ? a : b);
          
          final newAmount = (oldestDebt['amount'] as double) + totalAmount;
          final newPaid = oldestDebt['paid'] as double;
          final newRemaining = newAmount - newPaid;
          
          await _dbHelper.updateDebt(oldestDebt['id'] as int, {
            ...oldestDebt,
            'amount': newAmount,
            'remaining': newRemaining,
            'description': '${oldestDebt['description'] ?? ''} | فرۆشتنی زیاتر: $bulkSaleId',
          });
        }
      } else {
        // ئەگەر قەرزی پێشوو نییە، دروستی بکە
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
    }

    setState(() => _cart.clear());
    await _loadData();

    if (mounted) {
      final existingDebtAmount = await _getCustomerRemainingDebt(customerName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCash
              ? '✅ فرۆشتنی جوملە بە سەرکەوتوویی تۆمارکرا'
              : existingDebtAmount > 0 
                ? '📋 فرۆشتنی جوملە زیادکرا بۆ قەرزی پێشووی $customerName'
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
  bool isNewCustomer = false;
  String? selectedCustomer;
  List<Map<String, dynamic>> debtors = [];

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        // 🆕 فەنکشنی نوێ بۆ وەرگرتنی قەرزداران کاتێک پێویستە
        Future<void> loadDebtors() async {
          if (!isCash && debtors.isEmpty) {
            final loadedDebtors = await _getUniqueDebtors();
            setDialogState(() {
              debtors = loadedDebtors;
            });
          }
        }

        // 🆕 بارکردنی خۆکار کاتێک قەرز هەڵدەبژێردرێت
        if (!isCash) {
          loadDebtors();
        }

        return Dialog(
          // 🆕 زیادکردنی ڕێکخستنەکان بۆ شاشەی بچووک
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🆕 سەرپەڕەی جیاکراو
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
                      const Icon(Icons.shopping_cart, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'سەبەتەی فرۆشتن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        onPressed: () {
                          setState(() => _cart.clear());
                          Navigator.pop(dialogContext);
                        },
                        tooltip: 'بەتاڵکردنەوەی سەبەتە',
                      ),
                    ],
                  ),
                ),

                // 🆕 ناوەڕۆکی سکرۆڵکراو
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ئاگادارکردنەوە بۆ فرۆشتنی جومڵە
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
                                Icon(Icons.inventory, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'فرۆشتنی جومڵە',
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

                        // 🆕 لیستی کاڵاکان - بەرزیکردنەوەی سنوور
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              final isWholesale = item['is_wholesale'] ?? false;
                              final currentPrice = isWholesale && item['wholesale_price'] != null
                                  ? item['wholesale_price']
                                  : item['sell_price'];
                              final itemTotal = currentPrice * item['cart_quantity'];

                              return Container(
                                decoration: BoxDecoration(
                                  border: index < _cart.length - 1
                                      ? Border(
                                          bottom: BorderSide(color: Colors.grey.shade200),
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isWholesale && item['wholesale_price'] != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.inventory_2, 
                                                size: 10, 
                                                color: Colors.blue.shade700
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                'جومڵە',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // دوگمەی کەمکردن
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                                            onPressed: () {
                                              setState(() => _updateCartQuantity(
                                                  index, item['cart_quantity'] - 1));
                                              setDialogState(() {});
                                            },
                                            color: Colors.red,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          
                                          // بڕی کاڵا
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${item['cart_quantity']}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          
                                          // دوگمەی زیادکردن
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 20),
                                            onPressed: () {
                                              setState(() => _updateCartQuantity(
                                                  index, item['cart_quantity'] + 1));
                                              setDialogState(() {});
                                            },
                                            color: Colors.green,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          
                                          const Spacer(),
                                          
                                          // نرخ و کۆ
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showEditPriceDialog(index),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _formatNumber(currentPrice),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                    const Icon(Icons.edit, 
                                                      size: 12, 
                                                      color: Colors.blue
                                                    ),
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
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit_price',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 16),
                                            SizedBox(width: 6),
                                            Text('دەستکاری نرخ'),
                                          ],
                                        ),
                                      ),
                                      if (item['wholesale_price'] != null)
                                        PopupMenuItem(
                                          value: 'toggle_wholesale',
                                          child: Row(
                                            children: [
                                              Icon(
                                                isWholesale ? Icons.person : Icons.inventory_2,
                                                size: 16,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(isWholesale ? 'گۆڕین بە تاک' : 'گۆڕین بە جومڵە'),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 16, color: Colors.red),
                                            SizedBox(width: 6),
                                            Text('سڕینەوە'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit_price') {
                                        _showEditPriceDialog(index);
                                      } else if (value == 'toggle_wholesale') {
                                        setState(() {
                                          _cart[index]['is_wholesale'] = !isWholesale;
                                        });
                                        setDialogState(() {});
                                      } else if (value == 'remove') {
                                        setState(() => _removeFromCart(index));
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // کۆی گشتی
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade50, Colors.orange.shade100],
                            ),
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
                                '${_formatNumber(_getCartTotal())} IQD',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🆕 بەشی قەرز - ڕێکخستنی باشتر
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                // سەرپەڕەی جۆری پارە
                                Row(
                                  children: [
                                    Icon(Icons.payment, 
                                      color: Colors.orange.shade700, 
                                      size: 20
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'جۆری وەرگرتنی پارە',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: isCash,
                                      activeThumbColor: Colors.green,
                                      onChanged: (value) async {
                                        isCash = value;
                                        if (!isCash) {
                                          debtors = await _getUniqueDebtors();
                                        }
                                        setDialogState(() {});
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // نیشاندانی جۆری پارە
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isCash ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isCash ? Icons.money : Icons.credit_card,
                                        color: isCash ? Colors.green : Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isCash ? '💵 کاش' : '📋 قەرز',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isCash ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🆕 بەشی قەرز (تەنها کاتێک قەرز هەڵبژێردراوە)
                                if (!isCash) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),

                                  // تابەکانی قەرزداری پێشوو/نوێ
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => setDialogState(() => isNewCustomer = false),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: !isNewCustomer 
                                                    ? Colors.orange.shade600 
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.history,
                                                    color: !isNewCustomer ? Colors.white : Colors.orange.shade700,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'قەرزداری پێشوو',
                                                    style: TextStyle(
                                                      color: !isNewCustomer ? Colors.white : Colors.orange.shade700,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => setDialogState(() => isNewCustomer = true),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isNewCustomer 
                                                    ? Colors.orange.shade600 
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.person_add,
                                                    color: isNewCustomer ? Colors.white : Colors.orange.shade700,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'قەرزداری نوێ',
                                                    style: TextStyle(
                                                      color: isNewCustomer ? Colors.white : Colors.orange.shade700,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // بەشی ناوەڕۆک بەپێی هەڵبژاردن
                                  if (isNewCustomer)
                                    TextField(
                                      controller: customerNameController,
                                      decoration: InputDecoration(
                                        labelText: 'ناوی قەرزداری نوێ',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.person_add),
                                        hintText: 'ناوی کەسی قەرزەکە بنووسە',
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      constraints: BoxConstraints(
                                        maxHeight: MediaQuery.of(context).size.height * 0.2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: debtors.isEmpty
                                          ? const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.people_outline, 
                                                      color: Colors.grey, 
                                                      size: 40
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'هیچ قەرزدارێک نییە',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(color: Colors.grey),
                                                    ),
                                                    Text(
                                                      '"قەرزداری نوێ" هەڵبژێرە',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: debtors.length,
                                              itemBuilder: (context, index) {
                                                final debtor = debtors[index];
                                                final isSelected = selectedCustomer == debtor['customer_name'];
                                                
                                                return ListTile(
                                                  dense: true,
                                                  onTap: () {
                                                    selectedCustomer = debtor['customer_name'];
                                                    customerNameController.text = selectedCustomer!;
                                                    setDialogState(() {});
                                                  },
                                                  selected: isSelected,
                                                  leading: CircleAvatar(
                                                    backgroundColor: isSelected 
                                                        ? Colors.orange.shade600 
                                                        : Colors.red.shade100,
                                                    radius: 16,
                                                    child: Icon(
                                                      isSelected ? Icons.check : Icons.person,
                                                      color: isSelected ? Colors.white : Colors.red.shade700,
                                                      size: 16,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    debtor['customer_name'],
                                                    style: TextStyle(
                                                      fontWeight: isSelected 
                                                          ? FontWeight.bold 
                                                          : FontWeight.normal,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    'ماوە: ${_formatNumber(debtor['total_remaining'])} IQD',
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                  trailing: Icon(
                                                    isSelected 
                                                        ? Icons.check_circle 
                                                        : Icons.radio_button_unchecked,
                                                    color: isSelected 
                                                        ? Colors.orange.shade600 
                                                        : Colors.grey,
                                                    size: 18,
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🆕 بەشی کردارەکان
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
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('پاشگەزبوونەوە'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!isCash && customerNameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تکایە ناوی کڕیاری قەرز بنووسە یان هەڵبژێرە'),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(
                            _cart.length > 1 ? Icons.inventory : Icons.sell,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            _cart.length > 1 ? 'فرۆشتنی جومڵە' : 'تەواوکردن',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('فرۆشتنی کاڵا',style: TextStyle(color: Colors.white),),
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
          icon: const Icon(Icons.refresh,color: Colors.white,),
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
                icon: const Icon(Icons.shopping_cart,color: Colors.white,),
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
          icon: const Icon(Icons.arrow_circle_right,color: Colors.white,),
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
                                      /*    Container(
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
                                          ), */
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