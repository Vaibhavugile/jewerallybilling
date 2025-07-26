// lib/screens/billing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // For bill ID
import 'package:intl/intl.dart'; // For date formatting

import 'package:jewellery_billing_app/models/product.dart';
import 'package:jewellery_billing_app/models/bill.dart';
import 'package:jewellery_billing_app/providers/bill_provider.dart';
import 'package:jewellery_billing_app/utils/pdf_generator.dart';

class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final Uuid _uuid = Uuid();

  Product? _selectedProduct;
  Subtype? _selectedSubtype;
  final TextEditingController _quantityController = TextEditingController();

  bool _isSavingBill = false;
  String? _selectedSpecialRateType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billProvider = Provider.of<BillProvider>(context, listen: false);
      billProvider.clearBill();
      _discountController.text = billProvider.discount.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addItemToBill() {
    if (_selectedProduct == null || _selectedSubtype == null || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select product, subtype, and quantity.')));
      return;
    }

    final int quantityEntered = int.tryParse(_quantityController.text) ?? 0; // Renamed for clarity
    if (quantityEntered <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be positive.')));
      return;
    }

    double unitPrice = 0.0;
    int actualQuantity = quantityEntered; // Initialize actual quantity with entered quantity

    if (_selectedSpecialRateType != null) {
      unitPrice = _selectedSubtype!.sellingRates[_selectedSpecialRateType!] ?? 0.0;
      if (_selectedSpecialRateType == 'box') {
        // If "box" rate is selected, interpret quantityEntered as number of boxes
        // and calculate actual individual items.
        if (_selectedSubtype!.itemsPerBox == null || _selectedSubtype!.itemsPerBox! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items per box not configured for this subtype.')));
          return;
        }
        actualQuantity = quantityEntered * _selectedSubtype!.itemsPerBox!;
      }
    } else {
      if (quantityEntered >= 1 && quantityEntered <= 6) { // Use quantityEntered here for standard rates
        unitPrice = _selectedSubtype!.sellingRates['1-6'] ?? 0.0;
      } else if (quantityEntered >= 7 && quantityEntered <= 12) { // Typo fixed: quantityEntered <= 12
        unitPrice = _selectedSubtype!.sellingRates['6-12'] ?? 0.0;
      } else if (quantityEntered >= 13) {
        unitPrice = _selectedSubtype!.sellingRates['12+'] ?? 0.0;
      }
    }

    if (unitPrice == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid selling price found for the selected quantity/rate type.')));
      return;
    }

    // Stock check based on actualQuantity
    if (actualQuantity > _selectedSubtype!.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough stock. Available: ${_selectedSubtype!.currentStock} (Needed: $actualQuantity)')));
      return;
    }

    final double purchaseRate = _selectedSubtype!.purchaseRate;

    Provider.of<BillProvider>(context, listen: false).addBillItem(
      _selectedSubtype!,
      actualQuantity, // Pass actualQuantity for stock deduction and item count
      _selectedProduct!.id,
      _selectedProduct!.name,
      unitPrice,
      purchaseRate,
    );

    setState(() {
      _quantityController.clear();
      _selectedSpecialRateType = null;
    });
  }

  Future<void> _saveBill() async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);

    if (billProvider.currentBillItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items in the bill.')));
      return;
    }

    setState(() {
      _isSavingBill = true;
    });

    final String billId = _uuid.v4();
    final String billNumber = 'INV-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}-${billId.substring(0, 4).toUpperCase()}';

    final billData = Bill(
      id: billId,
      billNumber: billNumber,
      customerName: _customerNameController.text.trim().isEmpty ? null : _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim().isEmpty ? null : _customerPhoneController.text.trim(),
      billDate: DateTime.now(),
      totalAmount: billProvider.totalAmount,
      discount: billProvider.discount,
      finalAmount: billProvider.finalAmount,
      items: billProvider.currentBillItems,
      status: 'Completed',
    );

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final Map<String, int> subtypeCurrentStock = {};
        final Map<String, DocumentReference> subtypeRefs = {};

        for (var item in billProvider.currentBillItems) {
          final subtypeRef = FirebaseFirestore.instance
              .collection('products')
              .doc(item.productId)
              .collection('subtypes')
              .doc(item.subtypeId);
          subtypeRefs[item.subtypeId] = subtypeRef;

          final subtypeSnapshot = await transaction.get(subtypeRef);

          if (!subtypeSnapshot.exists) {
            throw Exception("Subtype ${item.subtypeName} not found!");
          }
          subtypeCurrentStock[item.subtypeId] = (subtypeSnapshot.data()?['currentStock'] ?? 0) as int;
        }

        transaction.set(FirebaseFirestore.instance.collection('bills').doc(billId), billData.toFirestore());

        for (var item in billProvider.currentBillItems) {
          final currentStock = subtypeCurrentStock[item.subtypeId]!;
          final newStock = currentStock - item.quantity;

          if (newStock < 0) {
            throw Exception("Not enough stock for ${item.subtypeName}! Available: $currentStock");
          }

          transaction.update(subtypeRefs[item.subtypeId]!, {'currentStock': newStock});
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill generated and stock updated!')));

      final pdfFile = await PdfGenerator.generateBillPdf(billData);
      if (pdfFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bill PDF generated!'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                // await OpenFilex.open(pdfFile.path);
              },
            ),
          ),
        );
      }

      billProvider.clearBill();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _discountController.clear();
      setState(() {
        _selectedProduct = null;
        _selectedSubtype = null;
        _quantityController.clear();
        _selectedSpecialRateType = null;
      });
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving bill: ${e.toString()}')));
      print('Error saving bill: $e');
    } finally {
      setState(() {
        _isSavingBill = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BillProvider>(
      builder: (context, billProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('New Bill'),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(labelText: 'Customer Name (Optional)'),
                        onChanged: (value) => billProvider.setCustomerDetails(value, _customerPhoneController.text),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customerPhoneController,
                        decoration: const InputDecoration(labelText: 'Customer Phone (Optional)'),
                        keyboardType: TextInputType.phone,
                        onChanged: (value) => billProvider.setCustomerDetails(_customerNameController.text, value),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('products').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
                          return DropdownButtonFormField<Product>(
                            decoration: const InputDecoration(labelText: 'Select Product'),
                            value: _selectedProduct,
                            items: products.map((product) => DropdownMenuItem(
                              value: product,
                              child: Text(product.name),
                            )).toList(),
                            onChanged: (product) {
                              setState(() {
                                _selectedProduct = product;
                                _selectedSubtype = null;
                                _quantityController.clear();
                                _selectedSpecialRateType = null;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _selectedProduct == null
                          ? DropdownButtonFormField<Subtype>(
                        decoration: const InputDecoration(labelText: 'Select Subtype'),
                        items: const [],
                        onChanged: null,
                        hint: const Text('Select a product first'),
                      )
                          : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('products')
                            .doc(_selectedProduct!.id)
                            .collection('subtypes')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final subtypes = snapshot.data!.docs.map((doc) => Subtype.fromFirestore(doc)).toList();
                          return DropdownButtonFormField<Subtype>(
                            decoration: const InputDecoration(labelText: 'Select Subtype'),
                            value: _selectedSubtype,
                            items: subtypes.map((subtype) {
                              return DropdownMenuItem(
                                value: subtype,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min, // Shrink-wrap the row horizontally
                                  children: [
                                    Flexible( // Use Flexible with FlexFit.loose instead of Expanded
                                      fit: FlexFit.loose,
                                      child: Text(
                                        '${subtype.name}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Stock and Purchase Rate displayed on the right
                                    Text('Stock: ${subtype.currentStock}, Pur: ${subtype.purchaseRate.toStringAsFixed(2)}'),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (subtype) {
                              setState(() {
                                _selectedSubtype = subtype;
                                _quantityController.clear();
                                _selectedSpecialRateType = null;
                              });
                            },
                            hint: const Text('Select a subtype'),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                suffixText: _selectedSubtype != null
                                    ? (_selectedSpecialRateType == 'box' && _selectedSubtype!.itemsPerBox != null
                                    ? '(Boxes: ${(_selectedSubtype!.currentStock / _selectedSubtype!.itemsPerBox!).floor()})'
                                    : '(Stock: ${_selectedSubtype!.currentStock})')
                                    : '',                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addItemToBill,
                            child: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedSubtype != null && (_selectedSubtype!.sellingRates.containsKey('bulk') || _selectedSubtype!.sellingRates.containsKey('box')))
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Select Special Rate (Optional)'),
                          value: _selectedSpecialRateType,
                          items: _selectedSubtype?.sellingRates.keys
                              .where((key) => key == 'bulk' || key == 'box')
                              .map((key) => DropdownMenuItem(
                            value: key,
                            child: Text(key.toUpperCase()),
                          ))
                              .toList() ?? [],
                          onChanged: (rateType) {
                            setState(() {
                              _selectedSpecialRateType = rateType;
                            });
                          },
                          hint: const Text('Select Bulk/Box Rate'),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: billProvider.currentBillItems.length,
                  itemBuilder: (context, index) {
                    final item = billProvider.currentBillItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('${item.productName} - ${item.subtypeName}'),
                        subtitle: Text('Qty: ${item.quantity} x ₹${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${item.itemTotal.toStringAsFixed(2)}'),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => billProvider.removeBillItem(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Subtotal: ₹${billProvider.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _discountController,
                        decoration: const InputDecoration(labelText: 'Discount Amount (₹)'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          billProvider.setDiscount(double.tryParse(value) ?? 0.0);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Apply GST (3.5%)', style: TextStyle(fontSize: 16)),
                          Checkbox(
                            value: billProvider.applyGst,
                            onChanged: (bool? value) {
                              billProvider.toggleGst(value);
                            },
                          ),
                        ],
                      ),
                      Text('Discount: ₹${billProvider.discount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red)),
                      const SizedBox(height: 8),
                      Text('GST (3.5%): ₹${billProvider.gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.green)),
                      const SizedBox(height: 8),
                      Text('Final Amount: ₹${billProvider.finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _isSavingBill
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                        onPressed: billProvider.currentBillItems.isEmpty ? null : _saveBill,
                        icon: const Icon(Icons.save),
                        label: const Text('Generate Bill'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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
    );
  }
}