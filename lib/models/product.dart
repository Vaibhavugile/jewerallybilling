// product.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String? description; // Optional
  final List<Subtype> subtypes; // Populated later or through separate queries

  Product({
    required this.id,
    required this.name,
    this.description,
    this.subtypes = const [],
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
    };
  }

  // --- START OF ADDITIONS ---
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Product &&
              runtimeType == other.runtimeType &&
              id == other.id; // Compare by ID

  @override
  int get hashCode => id.hashCode; // Use ID's hash code for consistency
// --- END OF ADDITIONS ---
}

class Subtype {
  final String id;
  final String name;
  final String? material;
  final double? weight;
  final double purchaseRate;
  final Map<String, double> sellingRates;
  int currentStock;
  final int? itemsPerBox; // Add this line

  Subtype({
    required this.id,
    required this.name,
    this.material,
    this.weight,
    required this.purchaseRate,
    required this.sellingRates,
    required this.currentStock,
    this.itemsPerBox, // Add this line
  });

  factory Subtype.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Subtype(
      id: doc.id,
      name: data['name'] ?? '',
      material: data['material'],
      weight: (data['weight'] as num?)?.toDouble(),
      purchaseRate: (data['purchaseRate'] as num?)?.toDouble() ?? 0.0,
      sellingRates: Map<String, double>.from(
          (data['sellingRates'] as Map<dynamic, dynamic>?)?.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {}),
      currentStock: data['currentStock'] ?? 0,
      itemsPerBox: data['itemsPerBox'] as int?, // Add this line
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'material': material,
      'weight': weight,
      'purchaseRate': purchaseRate,
      'sellingRates': sellingRates,
      'currentStock': currentStock,
      'itemsPerBox': itemsPerBox, // Add this line
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Subtype &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}