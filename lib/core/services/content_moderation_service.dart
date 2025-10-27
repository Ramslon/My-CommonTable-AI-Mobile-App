class ContentModerationService {
  // Placeholder moderation logic. In production, route to an AI model or API.
  Future<bool> isHealthyContent(String text) async {
    final banned = ['crash diet', 'starve', 'pro-ana'];
    final lower = text.toLowerCase();
    for (final b in banned) {
      if (lower.contains(b)) return false;
    }
    return true;
  }
}
