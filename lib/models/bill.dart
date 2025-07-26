import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  final String productId;
  final String productName;
  final String subtypeId;
  final String subtypeName;
  final int quantity;
  final double unitPrice; // Selling Price at the time of sale
  final double itemTotal;
  final double purchaseRateAtSale; // New: Purchase rate of the item at the time of sale

  BillItem({
    required this.productId,
    required this.productName,
    required this.subtypeId,
    required this.subtypeName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
    required this.purchaseRateAtSale, // New parameter
  });

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      subtypeId: map['subtypeId'] ?? '',
      subtypeName: map['subtypeName'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      itemTotal: (map['itemTotal'] as num?)?.toDouble() ?? 0.0,
      purchaseRateAtSale: (map['purchaseRateAtSale'] as num?)?.toDouble() ?? 0.0, // New field from map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'subtypeId': subtypeId,
      'subtypeName': subtypeName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'itemTotal': itemTotal,
      'purchaseRateAtSale': purchaseRateAtSale, // New field to map
    };
  }
}

class Bill {
  final String id;
  final String? billNumber;
  final String? customerName;
  final String? customerPhone;
  final DateTime billDate;
  final double totalAmount; // Subtotal before discount and GST
  final double discount;
  final double finalAmount; // Amount after discount and including GST
  final List<BillItem> items;
  final String status; // e.g., "Completed", "Draft", "Cancelled"

  Bill({
    required this.id,
    this.billNumber,
    this.customerName,
    this.customerPhone,
    required this.billDate,
    required this.totalAmount,
    this.discount = 0.0,
    required this.finalAmount,
    required this.items,
    this.status = 'Completed',
  });

  factory Bill.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Bill(
      id: doc.id,
      billNumber: data['billNumber'],
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
      billDate: (data['billDate'] as Timestamp).toDate(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: (data['finalAmount'] as num?)?.toDouble() ?? 0.0,
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => BillItem.fromMap(item as Map<String, dynamic>))
          .toList() ??
          [],
      status: data['status'] ?? 'Completed',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'billNumber': billNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'billDate': billDate,
      'totalAmount': totalAmount,
      'discount': discount,
      'finalAmount': finalAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status,
    };
  }
}