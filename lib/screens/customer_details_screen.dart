import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:jewellery_billing_app/models/customer.dart';
import 'package:jewellery_billing_app/models/bill.dart'; // Import Bill model
import 'package:jewellery_billing_app/models/product.dart'; // Import Product models for BillItem details

class CustomerDetailsScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailsScreen({Key? key, required this.customer}) : super(key: key);

  // Helper function to calculate profit for a single bill
  double _calculateBillProfit(Bill bill) {
    double totalProfit = 0.0;
    for (var item in bill.items) {
      totalProfit += (item.unitPrice - item.purchaseRateAtSale) * item.quantity;
    }
    return totalProfit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${customer.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Phone: ${customer.phone}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Last Purchase: ${customer.lastPurchaseDate != null ? DateFormat('dd MMM yyyy HH:mm').format(customer.lastPurchaseDate!) : 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 30),
            const Text('Purchase History:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bills')
                    .where('customerPhone', isEqualTo: customer.phone)
                    .orderBy('billDate', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No purchase history for this customer.'));
                  }

                  final bills = snapshot.data!.docs.map((doc) => Bill.fromFirestore(doc)).toList();

                  return ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      final billProfit = _calculateBillProfit(bill);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile( // Using ExpansionTile to show/hide items
                          title: Text('Bill #${bill.billNumber} - ${DateFormat('dd MMM yyyy').format(bill.billDate)}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Final Amount: ₹${bill.finalAmount.toStringAsFixed(2)}'),
                              Text('Profit: ₹${billProfit.toStringAsFixed(2)}',
                                  style: TextStyle(color: billProfit >= 0 ? Colors.green : Colors.red)),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: bill.items.map((item) {
                                  final itemProfit = (item.unitPrice - item.purchaseRateAtSale) * item.quantity;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item.productName} - ${item.subtypeName} (Qty: ${item.quantity})',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('  Selling Price: ₹${item.unitPrice.toStringAsFixed(2)}/item'),
                                        Text('  Purchase Price: ₹${item.purchaseRateAtSale.toStringAsFixed(2)}/item'),
                                        Text('  Item Total: ₹${item.itemTotal.toStringAsFixed(2)}'),
                                        Text('  Item Profit: ₹${itemProfit.toStringAsFixed(2)}',
                                            style: TextStyle(color: itemProfit >= 0 ? Colors.green : Colors.red, fontSize: 12)),
                                        const SizedBox(height: 4),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}