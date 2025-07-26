import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String? id; // Nullable for new customers before saving to Firestore
  final String name;
  final String phone;
  final DateTime? lastPurchaseDate; // Optional, can be updated on bill creation

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.lastPurchaseDate,
  });

  // Factory constructor to create a Customer from a Firestore document
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      lastPurchaseDate: (data['lastPurchaseDate'] as Timestamp?)?.toDate(),
    );
  }

  // Method to convert a Customer object to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'lastPurchaseDate': lastPurchaseDate != null ? Timestamp.fromDate(lastPurchaseDate!) : null,
    };
  }
}