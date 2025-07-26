import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jewellery_billing_app/models/product.dart';
import 'package:jewellery_billing_app/screens/add_edit_subtype_screen.dart';

class ManageSubtypesScreen extends StatelessWidget {
  final Product product;

  ManageSubtypesScreen({required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${product.name} Subtypes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .collection('subtypes')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No subtypes found for ${product.name}. Add some!'));
          }

          final subtypes = snapshot.data!.docs.map((doc) => Subtype.fromFirestore(doc)).toList();

          return ListView.builder(
            itemCount: subtypes.length,
            itemBuilder: (context, index) {
              final subtype = subtypes[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(subtype.name, style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Purchase Rate: ₹${subtype.purchaseRate.toStringAsFixed(2)}'),
                      Text('Stock: ${subtype.currentStock}'),
                      Text('Selling (1-6): ₹${subtype.sellingRates['1-6']?.toStringAsFixed(2) ?? 'N/A'}'),
                      Text('Selling (6-12): ₹${subtype.sellingRates['6-12']?.toStringAsFixed(2) ?? 'N/A'}'),
                      // Add more selling rates as needed
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AddEditSubtypeScreen(
                              productId: product.id,
                              subtype: subtype, // Pass the existing subtype for editing
                            ),
                          ));
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete Subtype'),
                              content: Text('Are you sure you want to delete ${subtype.name}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(product.id)
                                  .collection('subtypes')
                                  .doc(subtype.id)
                                  .delete();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subtype deleted!')));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting subtype: $e')));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddEditSubtypeScreen(productId: product.id),
          ));
        },
        child: Icon(Icons.add),
        tooltip: 'Add New Subtype',
      ),
    );
  }
}