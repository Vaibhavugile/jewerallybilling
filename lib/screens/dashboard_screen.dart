import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jewellery_billing_app/screens/login_screen.dart'; // For logout
import 'package:jewellery_billing_app/screens/product_dashboard_screen.dart';
import 'package:jewellery_billing_app/screens/billing_screen.dart';
import 'package:jewellery_billing_app/screens/reports_screen.dart';
import 'package:jewellery_billing_app/screens/customer_dashboard_screen.dart'; // New import

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jewellery Shop Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildDashboardCard(
              context,
              icon: Icons.inventory_2,
              title: 'Product Management',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProductDashboardScreen()));
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.receipt_long,
              title: 'New Bill',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => BillingScreen()));
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.analytics,
              title: 'Reports',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ReportsScreen()));
              },
            ),
            _buildDashboardCard( // New Customer Management Card
              context,
              icon: Icons.people,
              title: 'Customer Management',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CustomerDashboardScreen()));
              },
            ),
            // Add more cards as needed
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
        required String title,
        required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Theme.of(context).primaryColor),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}