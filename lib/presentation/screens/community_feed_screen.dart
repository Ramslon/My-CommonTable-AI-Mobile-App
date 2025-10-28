import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:commontable_ai_app/core/models/community_models.dart';
import 'package:commontable_ai_app/core/services/community_service.dart';
import 'package:commontable_ai_app/core/services/community_recommendation_service.dart';
import 'package:commontable_ai_app/core/services/content_moderation_service.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';
import 'package:image_picker/image_picker.dart';
import 'package:commontable_ai_app/core/services/storage_service.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with SingleTickerProviderStateMixin {
  final _svc = CommunityService();
  final _rec = CommunityRecommendationService();
  final _mod = ContentModerationService();
  final _postCtrl = TextEditingController();
  late final TabController _tabController;
  List<CommunityPost> _latest = [];
  Uint8List? _pendingImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;
    final ok = await _mod.isHealthyContent(text);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post flagged by moderation policy.')),
      );
      return;
    }
    String? imageUrl;
    if (_pendingImage != null) {
      try {
        final url = await StorageService().uploadImageBytes(_pendingImage!);
        imageUrl = url;
      } catch (_) {
        // ignore upload failure silently; still post text
      }
    }
    await _svc.createPost(text, imageUrl: imageUrl);
    _postCtrl.clear();
    setState(() => _pendingImage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Community',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feed', icon: Icon(Icons.forum_outlined)),
            Tab(text: 'Challenges', icon: Icon(Icons.flag_outlined)),
            Tab(text: 'Profile', icon: Icon(Icons.person_outline)),
            Tab(
              text: 'Notifications',
              icon: Icon(Icons.notifications_outlined),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed(),
          _buildChallenges(),
          _buildProfile(),
          _buildNotifications(),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: FirebaseBoot.available
                        ? 'Share a healthy tip or recipe…'
                        : 'Local mode: posting disabled',
                    border: const OutlineInputBorder(),
                  ),
                  enabled: FirebaseBoot.available,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add photo',
                onPressed: FirebaseBoot.available
                    ? () async {
                        final picker = ImagePicker();
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (x != null) {
                          final bytes = await x.readAsBytes();
                          setState(() => _pendingImage = bytes);
                        }
                      }
                    : null,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
              ElevatedButton.icon(
                onPressed: FirebaseBoot.available ? _submitPost : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Post'),
              ),
            ],
          ),
        ),
        if (_pendingImage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _pendingImage!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<CommunityPost>>(
            stream: _svc.streamFeed(),
            builder: (context, snap) {
              final posts = snap.data ?? [];
              _latest = posts;
              return ListView.separated(
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, i) => _PostCard(
                  post: posts[i],
                  onLike: () => _svc.likePost(posts[i].id),
                  onComment: () => _openComments(posts[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openComments(CommunityPost p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CommentsSheet(post: p, svc: _svc),
    );
  }

  Widget _buildChallenges() {
    return StreamBuilder<List<GroupChallenge>>(
      stream: _svc.streamChallenges(),
      builder: (context, snap) {
        final challenges = snap.data ?? [];
        if (challenges.isEmpty) {
          return const Center(
            child: Text('No challenges yet. Check back soon!'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ...List.generate(challenges.length, (i) {
              final c = challenges[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(c.description),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_outlined, size: 18),
                            const SizedBox(width: 4),
                            Text('${c.participants} joined'),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: FirebaseBoot.available
                                  ? () => _svc.joinChallenge(c.id)
                                  : null,
                              child: const Text('Join'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            const Text(
              'Leaderboard',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<UserProfile>>(
              stream: _svc.streamLeaderboard(),
              builder: (context, snapLb) {
                final lb = snapLb.data ?? [];
                if (lb.isEmpty) {
                  return const Text('No participants yet.');
                }
                return Column(
                  children: lb.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final u = e.value;
                    return ListTile(
                      leading: CircleAvatar(child: Text('$idx')),
                      title: Text(
                        u.displayName ?? u.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Challenges: ${u.challengesJoined} • Streak: ${u.streakDays}d',
                      ),
                      trailing: const Icon(
                        Icons.emoji_events_outlined,
                        color: Colors.amber,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfile() {
    return StreamBuilder<UserProfile>(
      stream: _svc.streamMyProfile(),
      builder: (context, snap) {
        final p =
            snap.data ??
            UserProfile(
              userId: FirebaseAuth.instance.currentUser?.uid ?? 'anon',
            );
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: p.photoUrl != null
                        ? NetworkImage(p.photoUrl!)
                        : null,
                    child: p.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.displayName ?? 'Member',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${p.userId}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: FirebaseBoot.available
                        ? () => _openEditProfile(p)
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _stat('Posts', p.posts),
                  _stat('Likes Given', p.likesGiven),
                  _stat('Challenges', p.challengesJoined),
                  _stat('Streak', p.streakDays),
                ],
              ),
              const SizedBox(height: 16),
              if (p.badges.isNotEmpty) ...[
                const Text(
                  'Badges',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.badges.map((b) => Chip(label: Text(b))).toList(),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Recommendations',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              FutureBuilder<List<CommunityPost>>(
                future: _rec.recommendForUser(p.userId, _latest),
                builder: (context, snap) {
                  final recs = snap.data ?? [];
                  if (recs.isEmpty) {
                    return const Text(
                      'Follow the feed to see personalized posts here.',
                    );
                  }
                  return Column(
                    children: recs
                        .take(3)
                        .map(
                          (r) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.recommend_outlined),
                            title: Text(
                              r.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${r.likesCount} likes • ${r.commentsCount} comments',
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEditProfile(UserProfile p) {
    final nameCtrl = TextEditingController(text: p.displayName ?? '');
    final bioCtrl = TextEditingController(text: p.bio ?? '');
    Uint8List? avatarBytes;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: avatarBytes != null
                          ? MemoryImage(avatarBytes!)
                          : (p.photoUrl != null
                                    ? NetworkImage(p.photoUrl!)
                                    : null)
                                as ImageProvider<Object>?,
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (x != null) {
                          final bytes = await x.readAsBytes();
                          setSheet(() => avatarBytes = bytes);
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Change avatar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bioCtrl,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      String? photoUrl;
                      if (avatarBytes != null) {
                        try {
                          photoUrl = await StorageService().uploadImageBytes(
                            avatarBytes!,
                            folder: 'avatars',
                          );
                        } catch (_) {}
                      }
                      await _svc.updateProfile(
                        displayName: nameCtrl.text.trim().isEmpty
                            ? null
                            : nameCtrl.text.trim(),
                        bio: bioCtrl.text.trim().isEmpty
                            ? null
                            : bioCtrl.text.trim(),
                        photoUrl: photoUrl,
                      );
                      if (mounted) nav.pop();
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotifications() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_none, size: 48, color: Colors.black38),
            SizedBox(height: 8),
            Text('Notifications will appear here when enabled.'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          Text(
            '$v',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'User ${post.userId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _fmtTime(post.createdAt),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.content),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags
                    .map((t) => Chip(label: Text('#$t')))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                ),
                Text('${post.likesCount}'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${post.commentsCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final CommunityPost post;
  final CommunityService svc;
  const _CommentsSheet({required this.post, required this.svc});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: FirebaseBoot.available
                        ? () async {
                            final txt = _ctrl.text.trim();
                            if (txt.isEmpty) return;
                            await widget.svc.addComment(widget.post.id, txt);
                            _ctrl.clear();
                          }
                        : null,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<List<CommunityComment>>(
                stream: widget.svc.streamComments(widget.post.id),
                builder: (context, snap) {
                  final comments = snap.data ?? [];
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(comments[i].text),
                      subtitle: Text(_fmtTime(comments[i].createdAt)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
