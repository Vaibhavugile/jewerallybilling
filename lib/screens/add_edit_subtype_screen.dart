import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jewellery_billing_app/models/product.dart';

class AddEditSubtypeScreen extends StatefulWidget {
  final String productId;
  final Subtype? subtype;

  AddEditSubtypeScreen({required this.productId, this.subtype});

  @override
  _AddEditSubtypeScreenState createState() => _AddEditSubtypeScreenState();
}

class _AddEditSubtypeScreenState extends State<AddEditSubtypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _purchaseRateController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _itemsPerBoxController = TextEditingController(); // Add this
  final Map<String, TextEditingController> _sellingRateControllers = {
    '1-6': TextEditingController(),
    '6-12': TextEditingController(),
    '12+': TextEditingController(),
    'box': TextEditingController(),
    'bulk': TextEditingController(),
  };
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.subtype != null) {
      _nameController.text = widget.subtype!.name;
      _materialController.text = widget.subtype!.material ?? '';
      _weightController.text = widget.subtype!.weight?.toString() ?? '';
      _purchaseRateController.text = widget.subtype!.purchaseRate.toString();
      _stockController.text = widget.subtype!.currentStock.toString();
      _itemsPerBoxController.text = widget.subtype!.itemsPerBox?.toString() ?? ''; // Initialize
      widget.subtype!.sellingRates.forEach((key, value) {
        _sellingRateControllers[key]?.text = value.toString();
      });
    }
  }

  Future<void> _saveSubtype() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final Map<String, double> sellingRates = {};
        _sellingRateControllers.forEach((key, controller) {
          sellingRates[key] = double.tryParse(controller.text) ?? 0.0;
        });

        final Map<String, dynamic> subtypeData = {
          'name': _nameController.text.trim(),
          'material': _materialController.text.trim().isEmpty ? null : _materialController.text.trim(),
          'weight': double.tryParse(_weightController.text),
          'purchaseRate': double.parse(_purchaseRateController.text),
          'sellingRates': sellingRates,
          'currentStock': int.parse(_stockController.text),
          'itemsPerBox': int.tryParse(_itemsPerBoxController.text), // Add this
        };

        if (widget.subtype == null) {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(widget.productId)
              .collection('subtypes')
              .add({
            ...subtypeData,
            'createdAt': FieldValue.serverTimestamp(),
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subtype added successfully!')));
        } else {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(widget.productId)
              .collection('subtypes')
              .doc(widget.subtype!.id)
              .update({
            ...subtypeData,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subtype updated successfully!')));
        }
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving subtype: $e')));
        print('Error saving subtype: $e');
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
        title: Text(widget.subtype == null ? 'Add New Subtype' : 'Edit Subtype'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Subtype Name (e.g., Speed Quick, More)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a subtype name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _materialController,
                decoration: InputDecoration(labelText: 'Material (Optional, e.g., Gold, Silver)'),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: InputDecoration(labelText: 'Weight (Optional, in grams)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _purchaseRateController,
                decoration: InputDecoration(labelText: 'Purchase Rate (Cost Price)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Please enter a valid purchase rate';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              Text('Selling Rates:', style: Theme.of(context).textTheme.headlineMedium),
              ..._sellingRateControllers.keys.map((key) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextFormField(
                  controller: _sellingRateControllers[key],
                  decoration: InputDecoration(labelText: 'Rate for $key'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null) {
                      return 'Please enter a valid rate for $key';
                    }
                    return null;
                  },
                ),
              )).toList(),
              SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(labelText: 'Current Stock'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || int.tryParse(value) == null) {
                    return 'Please enter a valid stock quantity';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16), // Add space
              TextFormField( // Add this
                controller: _itemsPerBoxController,
                decoration: InputDecoration(labelText: 'Items per Box (Optional, for "box" rate)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_sellingRateControllers['box']!.text.isNotEmpty && (value == null || int.tryParse(value) == null || int.parse(value) <= 0)) {
                    return 'Please enter a valid number of items per box if "box" rate is set.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _saveSubtype,
                child: Text(widget.subtype == null ? 'Add Subtype' : 'Update Subtype'),
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
    _materialController.dispose();
    _weightController.dispose();
    _purchaseRateController.dispose();
    _stockController.dispose();
    _itemsPerBoxController.dispose(); // Dispose controller
    _sellingRateControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
}