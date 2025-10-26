/// Health sync integration points.
///
/// Implement pulling nutrition data from Google Fit (Android) or
/// HealthKit (iOS) using appropriate packages (e.g., `health`).
/// This class currently returns an empty map and shows how to extend.
class HealthSyncService {
  /// Pulls daily nutrition aggregates (calories, macros) from device.
  /// Return empty map if not available.
  Future<Map<String, num>> pullNutrition() async {
    // TODO: Integrate with `health` or platform channels to read:
    // - energyConsumed
    // - protein, carbs, fat
    // - fiber, sodium
    // Make sure to request permissions at runtime.

    return {};
  }
}
