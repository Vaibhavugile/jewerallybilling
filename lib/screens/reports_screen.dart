import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:jewellery_billing_app/models/bill.dart'; // Ensure Bill and BillItem models are imported

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _endDate = DateTime.now();

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (picked != null && picked != (isStart ? _startDate : _endDate)) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate; // Ensure end date is not before start date
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate; // Ensure start date is not after end date
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bills')
                  .where('billDate', isGreaterThanOrEqualTo: _startDate)
                  .where('billDate', isLessThanOrEqualTo: _endDate.add(Duration(days: 1))) // Include end date
                  .orderBy('billDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No bills found for this period.'));
                }

                final bills = snapshot.data!.docs.map((doc) => Bill.fromFirestore(doc)).toList();

                double totalProfitForPeriod = 0.0;
                double totalSalesForPeriod = 0.0; // New: Total sales
                double totalDiscountForPeriod = 0.0; // New: Total discount
                double totalGstCollectedForPeriod = 0.0; // New: Total GST

                for (var bill in bills) {
                  totalSalesForPeriod += bill.finalAmount;
                  totalDiscountForPeriod += bill.discount;

                  // Calculate GST for this bill: finalAmount - (subtotal - discount)
                  // If GST was applied, finalAmount should be greater than (totalAmount - discount)
                  double amountAfterSubtotalAndDiscount = bill.totalAmount - bill.discount;
                  if (amountAfterSubtotalAndDiscount < 0) amountAfterSubtotalAndDiscount = 0; // Prevent negative base for GST

                  if (bill.finalAmount > amountAfterSubtotalAndDiscount) {
                    totalGstCollectedForPeriod += (bill.finalAmount - amountAfterSubtotalAndDiscount);
                  }


                  for (var item in bill.items) {
                    final itemProfit = item.itemTotal - (item.purchaseRateAtSale * item.quantity);
                    totalProfitForPeriod += itemProfit;
                  }
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Sales for Period: ₹${totalSalesForPeriod.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Discount for Period: ₹${totalDiscountForPeriod.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16, color: Colors.red[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total GST Collected: ₹${totalGstCollectedForPeriod.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16, color: Colors.orange[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Profit for Period: ₹${totalProfitForPeriod.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: bills.length,
                        itemBuilder: (context, index) {
                          final bill = bills[index];
                          // Calculate profit for this specific bill
                          double billTotalProfit = 0.0;
                          for (var item in bill.items) {
                            billTotalProfit += (item.unitPrice - item.purchaseRateAtSale) * item.quantity;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 3,
                            child: ExpansionTile(
                              title: Text('Bill No: ${bill.billNumber ?? bill.id.substring(0, 8)}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(bill.billDate)}\n'
                                          'Customer: ${bill.customerName ?? 'N/A'}\n'
                                          'Final Amount: ₹${bill.finalAmount.toStringAsFixed(2)}'),
                                  Text(
                                    'Bill Profit: ₹${billTotalProfit.toStringAsFixed(2)}', // Display bill-level profit
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                                  ),
                                ],
                              ),
                              children: bill.items.map((item) {
                                final itemProfit = (item.unitPrice - item.purchaseRateAtSale) * item.quantity;
                                return ListTile(
                                  title: Text('${item.productName} - ${item.subtypeName}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Qty: ${item.quantity} x SP: ₹${item.unitPrice.toStringAsFixed(2)} (PP: ₹${item.purchaseRateAtSale.toStringAsFixed(2)})'),
                                      Text('Item Total: ₹${item.itemTotal.toStringAsFixed(2)}'),
                                      Text(
                                        'Profit: ₹${itemProfit.toStringAsFixed(2)}', // Display individual item profit
                                        style: const TextStyle(color: Colors.green, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}