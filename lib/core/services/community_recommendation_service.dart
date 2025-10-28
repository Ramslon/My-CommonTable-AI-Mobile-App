import 'package:commontable_ai_app/core/models/community_models.dart';

class CommunityRecommendationService {
  // Placeholder for AI-powered recommendations (e.g., personalize by tags/users)
  Future<List<CommunityPost>> recommendForUser(
    String? userId,
    List<CommunityPost> recent,
  ) async {
    // Simple heuristic: prioritize posts with higher engagement
    final sorted = [...recent]
      ..sort(
        (a, b) => (b.likesCount + b.commentsCount).compareTo(
          a.likesCount + a.commentsCount,
        ),
      );
    return sorted.take(10).toList();
  }
}
