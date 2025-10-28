import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:commontable_ai_app/core/services/payments_service.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:commontable_ai_app/core/services/currency_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _payments = PaymentsService();
  List<ProductDetails> _products = [];
  bool _loading = true;
  String? _currentTier;
  String _currency = 'usd';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currency = await AppSettings().getCurrencyCode();
    await _loadCurrentTier();
    final provider = await _payments.init();
    if (provider == BillingProvider.inAppPurchase) {
      final prods = await _payments.loadProducts();
      setState(() { _products = prods; });
    }
    setState(() { _loading = false; });
  }

  Future<void> _loadCurrentTier() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('subscriptions').doc(uid).get();
      setState(() { _currentTier = doc.data()?['tier']; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _payments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Subscription'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_currentTier != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                      title: Text('Current plan: ${_currentTier!.toUpperCase()}'),
                      subtitle: const Text('Manage or upgrade your plan below.'),
                    ),
                  ),

                const SizedBox(height: 12),
                const Text('Available Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                if (_products.isNotEmpty)
                  ..._products.map((p) => _planTile(
                        name: p.title,
                        price: p.price,
                        onSubscribe: () => _subscribeWithProduct(p),
                      ))
                else ...[
                  _planTile(name: 'Basic', price: 'Free', onSubscribe: () => _subscribeSimulated('basic')),
                    _planTile(name: 'Plus', price: '${CurrencyService.format(4.99, _currency)}/mo (test)', onSubscribe: () => _subscribeSimulated('plus')),
                    _planTile(name: 'Premium', price: '${CurrencyService.format(14.99, _currency)}/mo (test)', onSubscribe: () => _subscribeSimulated('premium')),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Note: Real in-app products not configured. Using test flow.', style: TextStyle(color: Colors.black54)),
                  )
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(onPressed: _restore, icon: const Icon(Icons.restore), label: const Text('Restore Purchases')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _loadCurrentTier,
                      child: const Text('Refresh status'),
                    )
                  ],
                )
              ],
            ),
    );
  }

  Widget _planTile({required String name, required String price, required VoidCallback onSubscribe}) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star, color: Colors.amber),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(price),
        trailing: ElevatedButton(
          onPressed: onSubscribe,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Subscribe'),
        ),
      ),
    );
  }

  Future<void> _subscribeWithProduct(ProductDetails p) async {
    final tier = p.id.contains('premium')
        ? 'premium'
        : p.id.contains('plus')
            ? 'plus'
            : 'basic';
    final ok = await _payments.buy(tierName: tier, product: p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Subscribed to $tier' : 'Purchase failed')));
    await _loadCurrentTier();
  }

  Future<void> _subscribeSimulated(String tier) async {
    final ok = await _payments.buy(tierName: tier);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Subscribed to $tier (test)' : 'Purchase failed')));
    await _loadCurrentTier();
  }

  Future<void> _restore() async {
    await _payments.restore();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore requested')));
  }
}
