/// Health sync integration placeholder.
///
/// The `health` package API varies by version. To avoid breaking builds across
/// environments, this placeholder returns an empty map by default. When ready,
/// we can finalize the implementation against the confirmed package version
/// (e.g., map nutrition types and use Health/HealthFactory as appropriate).
class HealthSyncService {
  Future<Map<String, num>> pullNutrition() async {
    // TODO: Implement using `package:health/health.dart` after confirming
    // which HealthDataType constants are available in the chosen version.
    // Then request authorization and read aggregates for today.
    return {};
  }
}
