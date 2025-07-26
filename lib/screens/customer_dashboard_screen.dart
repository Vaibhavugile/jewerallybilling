import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jewellery_billing_app/models/customer.dart';
import 'package:jewellery_billing_app/screens/customer_details_screen.dart'; // New screen

class CustomerDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          final customers = snapshot.data!.docs
              .map((doc) => Customer.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(customer.name),
                  subtitle: Text(customer.phone),
                  trailing: customer.lastPurchaseDate != null
                      ? Text('Last Purchase: ${customer.lastPurchaseDate!.toLocal().toShortDateString()}')
                      : const Text('No recent purchases'),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => CustomerDetailsScreen(customer: customer),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Extension to format DateTime for display
extension DateTimeExtension on DateTime {
  String toShortDateString() {
    return '${this.day}/${this.month}/${this.year}';
  }
}