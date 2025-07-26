// lib/providers/bill_provider.dart
import 'package:flutter/material.dart';
import 'package:jewellery_billing_app/models/bill.dart';
import 'package:jewellery_billing_app/models/product.dart';

class BillProvider with ChangeNotifier {
  final List<BillItem> _currentBillItems = [];
  double _totalAmount = 0.0; // This acts as subtotal
  double _discount = 0.0;
  double _gstAmount = 0.0;
  double _finalAmount = 0.0;
  String? _customerName;
  String? _customerPhone;
  bool _applyGst = false;

  List<BillItem> get currentBillItems => [..._currentBillItems];
  double get totalAmount => _totalAmount;
  double get discount => _discount;
  double get gstAmount => _gstAmount;
  double get finalAmount => _finalAmount;
  String? get customerName => _customerName;
  String? get customerPhone => _customerPhone;
  bool get applyGst => _applyGst;

  void setCustomerDetails(String name, String phone) {
    _customerName = name.trim().isEmpty ? null : name.trim();
    _customerPhone = phone.trim().isEmpty ? null : phone.trim();
    notifyListeners();
  }

  // Modified: add purchaseRateAtSale parameter
  void addBillItem(Subtype subtype, int quantity, String productId, String productName, double unitPrice, double purchaseRateAtSale) {
    final existingItemIndex = _currentBillItems.indexWhere(
          (item) => item.subtypeId == subtype.id && item.productId == productId,
    );

    if (existingItemIndex != -1) {
      final existingItem = _currentBillItems[existingItemIndex];
      final updatedQuantity = existingItem.quantity + quantity;
      final updatedItemTotal = updatedQuantity * unitPrice;
      // For simplicity, if adding to an existing item, assume purchase rate remains the same as the first time it was added.
      // A more complex scenario might average or use the latest rate.
      _currentBillItems[existingItemIndex] = BillItem(
        productId: productId,
        productName: productName,
        subtypeId: subtype.id,
        subtypeName: subtype.name,
        unitPrice: unitPrice,
        quantity: updatedQuantity,
        itemTotal: updatedItemTotal,
        purchaseRateAtSale: existingItem.purchaseRateAtSale, // Keep existing rate for combined items
      );
    } else {
      _currentBillItems.add(
        BillItem(
          productId: productId,
          productName: productName,
          subtypeId: subtype.id,
          subtypeName: subtype.name,
          unitPrice: unitPrice,
          quantity: quantity,
          itemTotal: quantity * unitPrice,
          purchaseRateAtSale: purchaseRateAtSale, // Pass the new purchase rate
        ),
      );
    }
    _calculateTotals();
    notifyListeners();
  }

  void removeBillItem(BillItem itemToRemove) {
    _currentBillItems.removeWhere((item) =>
    item.productId == itemToRemove.productId &&
        item.subtypeId == itemToRemove.subtypeId);
    _calculateTotals();
    notifyListeners();
  }

  void setDiscount(double newDiscount) {
    _discount = newDiscount;
    _calculateTotals();
    notifyListeners();
  }

  void toggleGst(bool? value) {
    _applyGst = value ?? false;
    _calculateTotals();
    notifyListeners();
  }

  void clearBill() {
    _currentBillItems.clear();
    _totalAmount = 0.0;
    _discount = 0.0;
    _gstAmount = 0.0;
    _finalAmount = 0.0;
    _customerName = null;
    _customerPhone = null;
    _applyGst = false;
    notifyListeners();
  }

  void _calculateTotals() {
    _totalAmount = _currentBillItems.fold(0.0, (sum, item) => sum + item.itemTotal);

    double amountAfterDiscount = _totalAmount - _discount;
    if (amountAfterDiscount < 0) amountAfterDiscount = 0;

    if (_applyGst) {
      _gstAmount = amountAfterDiscount * 0.035;
    } else {
      _gstAmount = 0.0;
    }

    _finalAmount = amountAfterDiscount + _gstAmount;
  }
}