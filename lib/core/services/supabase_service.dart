import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal Supabase integration for fetching recipe items.
/// Reads SUPABASE_URL and SUPABASE_ANON_KEY from --dart-define or .env via flutter_dotenv if present.
class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient? get client => _client;

  static bool get isConfigured => _client != null;

  static Future<void> init({String? url, String? anonKey}) async {
    try {
      final resolvedUrl = url ?? const String.fromEnvironment('SUPABASE_URL');
      final resolvedKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY');
      if (resolvedUrl.isEmpty || resolvedKey.isEmpty) {
        // Not configured; skip
        return;
      }
      await Supabase.initialize(url: resolvedUrl, anonKey: resolvedKey);
      _client = Supabase.instance.client;
    } catch (e) {
      if (kDebugMode) {
        // Log but don't crash app if supabase init fails
        // ignore: avoid_print
        print('Supabase init failed: $e');
      }
      _client = null;
    }
  }

  /// Fetch a lightweight list of recipe-like items that can be mapped to meal items.
  /// Expects a table `recipes` with columns: name (text), calories (int), protein (int), carbs (int), fats (int)
  static Future<List<Map<String, dynamic>>> fetchRecipeItems({int limit = 20}) async {
    final c = _client;
    if (c == null) return [];
    try {
      final resp = await c
          .from('recipes')
          .select('name, calories, protein, carbs, fats')
          .limit(limit);
      return (resp as List)
          .map((e) => (e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }
}
