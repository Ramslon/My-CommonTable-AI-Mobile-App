import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:commontable_ai_app/core/models/community_models.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';

class CommunityService {
  final _fs = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<CommunityPost>> streamFeed() {
    if (!FirebaseBoot.available) {
      // Local simulated feed
      final demo = [
        CommunityPost(
          id: 'local1',
          userId: 'demo',
          content: 'Welcome to the community! Share your healthy lunch ideas 🥗',
          createdAt: DateTime.now(),
          likesCount: 3,
          commentsCount: 1,
          tags: const ['welcome', 'healthy']
        ),
      ];
      return Stream<List<CommunityPost>>.value(demo);
    }
    return _fs
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CommunityPost.fromDoc(d)).toList());
  }

  Future<void> createPost(String content, {String? imageUrl, List<String> tags = const []}) async {
    if (!FirebaseBoot.available) return; // no-op in local-only mode
    final uid = _uid;
    await _fs.collection('posts').add({
      'userId': uid ?? 'anon',
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': DateTime.now().toIso8601String(),
      'likesCount': 0,
      'commentsCount': 0,
      'tags': tags,
    });
    if (uid != null) {
      await _fs.collection('profiles').doc(uid).set({'posts': FieldValue.increment(1)}, SetOptions(merge: true));
    }
  }

  Future<void> likePost(String postId) async {
    if (!FirebaseBoot.available) return;
    final uid = _uid;
    final likeRef = _fs.collection('posts').doc(postId).collection('likes').doc(uid ?? 'anon');
    final likeDoc = await likeRef.get();
    if (!likeDoc.exists) {
      await likeRef.set({'createdAt': DateTime.now().toIso8601String()});
      await _fs.collection('posts').doc(postId).update({'likesCount': FieldValue.increment(1)});
      if (uid != null) {
        await _fs.collection('profiles').doc(uid).set({'likesGiven': FieldValue.increment(1)}, SetOptions(merge: true));
      }
    }
  }

  Stream<List<CommunityComment>> streamComments(String postId) {
    if (!FirebaseBoot.available) {
      final demo = [
        CommunityComment(
          id: 'c1', postId: postId, userId: 'demo', text: 'Great idea!', createdAt: DateTime.now(),
        ),
      ];
      return Stream.value(demo);
    }
    return _fs
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CommunityComment.fromDoc(d)).toList());
  }

  Future<void> addComment(String postId, String text) async {
    if (!FirebaseBoot.available) return;
    final uid = _uid ?? 'anon';
    final ref = _fs.collection('posts').doc(postId).collection('comments');
    await ref.add({
      'postId': postId,
      'userId': uid,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _fs.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(1)});
  }

  Stream<List<GroupChallenge>> streamChallenges() {
    if (!FirebaseBoot.available) {
      final now = DateTime.now();
      final demo = [
        GroupChallenge(
          id: 'ch1',
          title: '7-Day Healthy Lunch Challenge',
          description: 'Share one balanced lunch each day for a week.',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          participants: 24,
        )
      ];
      return Stream.value(demo);
    }
    return _fs
        .collection('challenges')
        .orderBy('startDate', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GroupChallenge.fromDoc(d)).toList());
  }

  Future<void> joinChallenge(String challengeId) async {
    if (!FirebaseBoot.available) return;
    final uid = _uid ?? 'anon';
    final ref = _fs.collection('challenges').doc(challengeId).collection('participants').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({'joinedAt': DateTime.now().toIso8601String()});
      await _fs.collection('challenges').doc(challengeId).update({'participants': FieldValue.increment(1)});
      if (_uid != null) {
        await _fs.collection('profiles').doc(_uid).set({'challengesJoined': FieldValue.increment(1)}, SetOptions(merge: true));
      }
    }
  }

  Stream<UserProfile> streamMyProfile() {
    if (!FirebaseBoot.available || _uid == null) {
      return Stream.value(UserProfile(userId: _uid ?? 'anon', displayName: 'Guest'));
    }
    return _fs.collection('profiles').doc(_uid).snapshots().map((d) {
      if (!d.exists) return UserProfile(userId: _uid!, displayName: 'User');
      return UserProfile.fromDoc(d);
    });
  }
}
