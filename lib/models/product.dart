class Product {
  final int? id;
  final String name;
  final String? barcode;
  final double buyPrice;
  final double sellPrice;
  final int quantity;
  final String createdAt;

  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      buyPrice: map['buy_price'],
      sellPrice: map['sell_price'],
      quantity: map['quantity'],
      createdAt: map['created_at'],
    );
  }
}

// purchase.dart
class Purchase {
  final int? id;
  final int productId;
  final int quantity;
  final double price;
  final double total;
  final String date;

  Purchase({
    this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.total,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      'total': total,
      'date': date,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      price: map['price'],
      total: map['total'],
      date: map['date'],
    );
  }
}

// sale.dart
class Sale {
  final int? id;
  final int productId;
  final int quantity;
  final double price;
  final double total;
  final String date;

  Sale({
    this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.total,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      'total': total,
      'date': date,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      price: map['price'],
      total: map['total'],
      date: map['date'],
    );
  }
}

// debt.dart
class Debt {
  final int? id;
  final String customerName;
  final double amount;
  final double paid;
  final double remaining;
  final String? description;
  final String date;

  Debt({
    this.id,
    required this.customerName,
    required this.amount,
    this.paid = 0.0,
    required this.remaining,
    this.description,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'amount': amount,
      'paid': paid,
      'remaining': remaining,
      'description': description,
      'date': date,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      customerName: map['customer_name'],
      amount: map['amount'],
      paid: map['paid'] ?? 0.0,
      remaining: map['remaining'],
      description: map['description'],
      date: map['date'],
    );
  }
}