import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DataExportService {
  Future<File?> exportMyDataAndShare() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    final Map<String, dynamic> export = {
      'userId': uid,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    Future<List<Map<String, dynamic>>> q(String collection) async {
      final qs = await db.collection(collection).where('userId', isEqualTo: uid).get();
      return qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    try {
      export['dietAssessments'] = await q('dietAssessments');
      export['chatNutritionLogs'] = await q('chatNutritionLogs');
      export['lowIncomeMeals'] = await q('lowIncomeMeals');
      export['subscriptions'] = await q('subscriptions');
      export['consents'] = await q('consents');

      final userDoc = await db.collection('users').doc(uid).get();
      export['userProfile'] = userDoc.data();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/commontable_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(export));

      await Share.shareXFiles([XFile(file.path)], text: 'My Commontable AI data export');
      return file;
    } catch (_) {
      rethrow;
    }
  }
}
