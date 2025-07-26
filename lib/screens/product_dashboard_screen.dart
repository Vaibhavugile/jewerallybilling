import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jewellery_billing_app/models/product.dart';
import 'package:jewellery_billing_app/screens/add_product_screen.dart';
import 'package:jewellery_billing_app/screens/manage_subtypes_screen.dart';

class ProductDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No products found. Add some!'));
          }

          final products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: product.description != null
                      ? Text(product.description!)
                      : null,
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // Implement delete product (and its subtypes!)
                      final confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Product'),
                          content: Text('Are you sure you want to delete ${product.name} and all its subtypes? This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        // Use a batch write or cloud function to delete product AND all its subtypes
                        _deleteProductAndSubtypes(product.id,context);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ManageSubtypesScreen(product: product),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddProductScreen(),
          ));
        },
        child: Icon(Icons.add),
        tooltip: 'Add New Product Category',
      ),
    );
  }

  Future<void> _deleteProductAndSubtypes(String productId,BuildContext context) async {
    try {
      // This requires more advanced handling, ideally a Cloud Function
      // to delete all subcollection documents safely.
      // For direct client-side deletion, you'd fetch and delete each subtype first,
      // then delete the product document. This can be slow for many subtypes.

      // Option 1 (Simple but less safe for large subcollections):
      // Get all subtypes and delete them
      QuerySnapshot subtypeSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('subtypes')
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (DocumentSnapshot doc in subtypeSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Then delete the main product document
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();

      ScaffoldMessenger.of(context).showSnackBar( // <-- Now 'context' is defined
        const SnackBar(content: Text('Product and subtypes deleted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar( // <-- Now 'context' is defined
        SnackBar(content: Text('Failed to delete product: $e')),
      );

    }
  }
}