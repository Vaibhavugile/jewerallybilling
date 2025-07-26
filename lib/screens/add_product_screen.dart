import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductScreen extends StatefulWidget {
  final String? productId; // Optional, for editing
  final String? initialName;
  final String? initialDescription;

  AddProductScreen({this.productId, this.initialName, this.initialDescription});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _nameController.text = widget.initialName ?? '';
      _descriptionController.text = widget.initialDescription ?? '';
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        if (widget.productId == null) {
          // Add new product
          await FirebaseFirestore.instance.collection('products').add({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product added successfully!')));
        } else {
          // Edit existing product
          await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product updated successfully!')));
        }
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving product: $e')));
        print('Error saving product: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add New Product Category' : 'Edit Product Category'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Product Name (e.g., Rings, Necklaces)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _saveProduct,
                child: Text(widget.productId == null ? 'Add Product' : 'Update Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}