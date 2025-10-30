import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:commontable_ai_app/firebase_options.dart';

/// Seeds Firestore and Realtime Database with low-income feature data from assets.
/// Run with:
///   flutter pub run tool/seed_low_income_data.dart
///
/// Requirements:
/// - Firebase configured for the app (mobile SDK credentials).
/// - Firestore security rules that allow this client to write the target collections.
/// - Realtime Database rules that allow writing to local_offers/global for your account/environment.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final resources = await _readJsonList('assets/data/resources_mock.json');
  final offers = await _readJsonList('assets/data/promotions_mock.json');

  // Seed Firestore collection: assistance_resources
  try {
    final col = FirebaseFirestore.instance.collection('assistance_resources');
    for (final m in resources) {
      final data = Map<String, dynamic>.from(m);
      // Optional: upsert by name+type
      final q = await col.where('name', isEqualTo: data['name']).limit(1).get();
      if (q.docs.isEmpty) {
        await col.add(data);
      } else {
        await q.docs.first.reference.set(data, SetOptions(merge: true));
      }
    }
    // ignore: avoid_print
    print('Seeded assistance_resources (${resources.length}).');
  } catch (e) {
    // ignore: avoid_print
    print('Failed to seed Firestore: $e');
  }

  // Seed Realtime Database: local_offers/global
  try {
    final ref = FirebaseDatabase.instance.ref('local_offers/global');
    await ref.set(offers);
    // ignore: avoid_print
    print('Seeded RTDB local_offers/global (${offers.length}).');
  } catch (e) {
    // ignore: avoid_print
    print('Failed to seed RTDB: $e');
  }
}

Future<List<dynamic>> _readJsonList(String relativePath) async {
  try {
    final file = File(relativePath);
    final raw = await file.readAsString();
    final list = jsonDecode(raw);
    if (list is List) return list;
  } catch (e) {
    // ignore: avoid_print
    print('Read assets failed for $relativePath: $e');
  }
  return const [];
}
