import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum BillingProvider { simulated, inAppPurchase }

class PaymentsService {
  static const _basicId = String.fromEnvironment('IAP_BASIC_ID', defaultValue: 'commontable.basic');
  static const _plusId = String.fromEnvironment('IAP_PLUS_ID', defaultValue: 'commontable.plus');
  static const _premiumId = String.fromEnvironment('IAP_PREMIUM_ID', defaultValue: 'commontable.premium');

  final InAppPurchase _iap = InAppPurchase.instance;
  late final BillingProvider _provider;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  Set<String> get productIds => {_basicId, _plusId, _premiumId};

  PaymentsService() {
    // If IAP is available at runtime, prefer it; otherwise use simulated.
    _provider = BillingProvider.inAppPurchase; // Optimistically choose; will fallback on init.
  }

  Future<BillingProvider> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      _provider = BillingProvider.simulated;
      return _provider;
    }
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(_onPurchasesUpdated, onDone: () => _sub?.cancel(), onError: (_) {});
    _provider = BillingProvider.inAppPurchase;
    return _provider;
  }

  Future<List<ProductDetails>> loadProducts() async {
    if (_provider != BillingProvider.inAppPurchase) return const [];
    final resp = await _iap.queryProductDetails(productIds);
    return resp.productDetails;
  }

  Future<bool> buy({required String tierName, ProductDetails? product}) async {
    if (_provider != BillingProvider.inAppPurchase || product == null) {
      // Simulated purchase
      await _saveSubscription(tierName);
      return true;
    }
    final purchaseParam = PurchaseParam(productDetails: product);
    final ok = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    return ok;
  }

  Future<void> restore() async {
    if (_provider != BillingProvider.inAppPurchase) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        // Map productId to tier
        final tier = _mapProductToTier(p.productID);
        await _saveSubscription(tier);
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
      // Handle error/canceled as needed
    }
  }

  String _mapProductToTier(String productId) {
    if (productId == _premiumId) return 'premium';
    if (productId == _plusId) return 'plus';
    return 'basic';
  }

  Future<void> _saveSubscription(String tier) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('subscriptions').doc(uid ?? 'anonymous').set({
      'tier': tier,
      'updatedAt': DateTime.now().toIso8601String(),
      'provider': _provider.name,
    }, SetOptions(merge: true));
  }

  void dispose() {
    _sub?.cancel();
  }
}
