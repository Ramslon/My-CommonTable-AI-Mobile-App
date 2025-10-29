import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final String? topic; // optional topic label
  final DateTime createdAt;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.topic,
  });

  Map<String, dynamic> toMap({required String userId}) => {
        'userId': userId,
        'role': role,
        'text': text,
        if (topic != null) 'topic': topic,
        'createdAt': createdAt.toIso8601String(),
      };

  static ChatMessage fromMap(Map<String, dynamic> m) => ChatMessage(
        role: (m['role'] ?? 'assistant') as String,
        text: (m['text'] ?? '') as String,
        topic: m['topic'] as String?,
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class ChatHistoryService {
  final FirebaseFirestore _fs;
  ChatHistoryService({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('aiCoachMessages');

  Future<void> addMessage({required String userId, required String role, required String text, String? topic, DateTime? createdAt}) async {
    final msg = ChatMessage(role: role, text: text, topic: topic, createdAt: createdAt ?? DateTime.now());
    await _col.add(msg.toMap(userId: userId));
  }

  Stream<List<ChatMessage>> watch({required String userId, int limit = 200}) {
    final q = _col.where('userId', isEqualTo: userId).orderBy('createdAt', descending: false).limit(limit);
    return q.snapshots().map((snap) => snap.docs.map((d) => ChatMessage.fromMap(d.data())).toList());
  }
}
