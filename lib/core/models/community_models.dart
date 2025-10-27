import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<String> tags;

  CommunityPost({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.tags = const [],
  });

  factory CommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CommunityPost(
      id: doc.id,
      userId: d['userId'] ?? '',
      content: d['content'] ?? '',
      imageUrl: d['imageUrl'],
      createdAt: DateTime.tryParse(d['createdAt'] ?? '') ?? DateTime.now(),
      likesCount: (d['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (d['commentsCount'] as num?)?.toInt() ?? 0,
      tags: (d['tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'tags': tags,
      };
}

class CommunityComment {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime createdAt;

  CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory CommunityComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CommunityComment(
      id: doc.id,
      postId: d['postId'] ?? '',
      userId: d['userId'] ?? '',
      text: d['text'] ?? '',
      createdAt: DateTime.tryParse(d['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'postId': postId,
        'userId': userId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}

class UserProfile {
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final int posts;
  final int likesGiven;
  final int challengesJoined;
  final int streakDays;
  final List<String> badges;

  UserProfile({
    required this.userId,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.posts = 0,
    this.likesGiven = 0,
    this.challengesJoined = 0,
    this.streakDays = 0,
    this.badges = const [],
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserProfile(
      userId: doc.id,
      displayName: d['displayName'],
      photoUrl: d['photoUrl'],
      bio: d['bio'],
      posts: (d['posts'] as num?)?.toInt() ?? 0,
      likesGiven: (d['likesGiven'] as num?)?.toInt() ?? 0,
      challengesJoined: (d['challengesJoined'] as num?)?.toInt() ?? 0,
      streakDays: (d['streakDays'] as num?)?.toInt() ?? 0,
      badges: (d['badges'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (bio != null) 'bio': bio,
        'posts': posts,
        'likesGiven': likesGiven,
        'challengesJoined': challengesJoined,
        'streakDays': streakDays,
        'badges': badges,
      };
}

class GroupChallenge {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int participants;

  GroupChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.participants = 0,
  });

  factory GroupChallenge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return GroupChallenge(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      startDate: DateTime.tryParse(d['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(d['endDate'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      participants: (d['participants'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'participants': participants,
      };
}
