import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final String? topic; // optional topic label
  final String? sessionId; // thread id (e.g., per topic or custom)
  final DateTime createdAt;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.sessionId,
    this.topic,
  });

  Map<String, dynamic> toMap({required String userId}) => {
        'userId': userId,
        'role': role,
        'text': text,
        if (topic != null) 'topic': topic,
        if (sessionId != null) 'sessionId': sessionId,
        // Prefer server timestamp for ordering; keep ISO for debugging
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtIso': createdAt.toIso8601String(),
      };

  static ChatMessage fromMap(Map<String, dynamic> m) => ChatMessage(
        role: (m['role'] ?? 'assistant') as String,
        text: (m['text'] ?? '') as String,
        topic: m['topic'] as String?,
        sessionId: m['sessionId'] as String?,
        createdAt: () {
          final raw = m['createdAt'];
          if (raw is Timestamp) return raw.toDate();
          final iso = m['createdAtIso'] ?? m['createdAt'];
          return DateTime.tryParse(iso ?? '') ?? DateTime.now();
        }(),
      );
}

class ChatHistoryService {
  final FirebaseFirestore _fs;
  ChatHistoryService({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('aiCoachMessages');

  Future<void> addMessage({
    required String userId,
    required String role,
    required String text,
    String? topic,
    String? sessionId,
    DateTime? createdAt,
  }) async {
    final msg = ChatMessage(role: role, text: text, topic: topic, sessionId: sessionId, createdAt: createdAt ?? DateTime.now());
    await _col.add(msg.toMap(userId: userId));
  }

  Stream<List<ChatMessage>> watch({required String userId, String? sessionId, int limit = 200}) {
    Query<Map<String, dynamic>> q = _col.where('userId', isEqualTo: userId);
    if (sessionId != null) {
      q = q.where('sessionId', isEqualTo: sessionId);
    }
    q = q.orderBy('createdAt', descending: false).limit(limit);
    return q.snapshots().map((snap) => snap.docs.map((d) => ChatMessage.fromMap(d.data())).toList());
  }

  /// Clear all messages for a user. If [sessionId] is provided, limit to that thread.
  Future<int> clear({required String userId, String? sessionId}) async {
    Query<Map<String, dynamic>> q = _col.where('userId', isEqualTo: userId);
    if (sessionId != null) q = q.where('sessionId', isEqualTo: sessionId);
    final snap = await q.get();
    if (snap.docs.isEmpty) return 0;
    int count = 0;
    WriteBatch batch = _fs.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
      count++;
      if (count % 450 == 0) { // keep under 500 per batch
        await batch.commit();
        batch = _fs.batch();
      }
    }
    await batch.commit();
    return count;
  }
}
