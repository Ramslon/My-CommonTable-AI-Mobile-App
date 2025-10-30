import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:commontable_ai_app/routes/app_route.dart';

/// Affordable Meal Suggestions (Student-focused)
/// - Budget-friendly ideas using common, low-cost staples
/// - Simple filters (budget, meals per day, vegetarian, local staples)
/// - Select meals and view an aggregated shopping list with estimated total cost
class StudentFeaturesScreen extends StatefulWidget {
	const StudentFeaturesScreen({super.key});

	@override
	State<StudentFeaturesScreen> createState() => _StudentFeaturesScreenState();
}

class _StudentFeaturesScreenState extends State<StudentFeaturesScreen> {
	final TextEditingController _budgetCtrl = TextEditingController(text: '3000');
	int _mealsPerDay = 3;
	bool _vegetarianOnly = false;
	bool _useLocalStaples = true;
	bool _loading = false;
	String _region = 'Default';

	// Deals & Dining
	final _currency = NumberFormat.simpleCurrency();
	bool _loadingDeals = false;
	List<_LocalOffer> _deals = [];
	Position? _position;
	List<CafeteriaEntry> _cafeterias = [];

	late List<MealSuggestion> _allSuggestions;
	late List<MealSuggestion> _mentalHealth; // curated list: mood-boosting, stress-reducing
	List<MealSuggestion> _generated = [];
	final Set<String> _selected = {};

	// Mood + AI advice state
	String? _selectedMoodKey;
	String? _selectedMoodLabel;
	String? _selectedMoodEmoji;
	String? _aiMoodAdvice;
	bool _adviceLoading = false;
	final List<_MoodEntry> _moodHistory = [];

	static const List<MoodOption> _moodOptions = [
		MoodOption(key: 'stressed', emoji: '😓', label: 'Stressed'),
		MoodOption(key: 'anxious', emoji: '😟', label: 'Anxious'),
		MoodOption(key: 'low_energy', emoji: '😴', label: 'Low energy'),
		MoodOption(key: 'sad', emoji: '😔', label: 'Sad'),
		MoodOption(key: 'overwhelmed', emoji: '😵', label: 'Overwhelmed'),
		MoodOption(key: 'okay', emoji: '🙂', label: 'Okay'),
		MoodOption(key: 'happy', emoji: '😄', label: 'Happy'),
	];

	@override
	void initState() {
		super.initState();
		_allSuggestions = _buildSuggestionCatalog(_region);
		_mentalHealth = _buildMentalHealthSuggestions(_region);
		_loadRecentMoodLogs();
		_initLocalContext();
	}

	Future<void> _initLocalContext() async {
		await _loadCachedDeals();
		await _refreshDeals();
		await _resolveLocation();
		await _loadCafeteriasFromAssets();
	}

	Future<void> _loadRecentMoodLogs() async {
		try {
			if (Firebase.apps.isEmpty) {
				await Firebase.initializeApp();
			}
				final uid = FirebaseAuth.instance.currentUser?.uid;
				if (uid == null) {
					// No user: skip remote fetch
					return;
				}
				cf.Query<Map<String, dynamic>> q = cf.FirebaseFirestore.instance
						.collection('studentMoodLogs')
						.where('userId', isEqualTo: uid)
						.orderBy('createdAt', descending: true)
						.limit(10);
				final qs = await q.get();
			final items = qs.docs.map((d) {
				final data = d.data();
				final created = DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now();
				return _MoodEntry(
					key: data['moodKey'] ?? '',
					label: data['moodLabel'] ?? '',
					emoji: data['emoji'] ?? '🙂',
					createdAt: created,
				);
			}).toList();
			setState(() {
				_moodHistory
					..clear()
					..addAll(items);
			});
		} catch (_) {
			// silently ignore if Firestore unavailable
		}
	}

	String _friendlyTime(DateTime dt) {
		final now = DateTime.now();
		final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
		if (isToday) {
			final hh = dt.hour.toString().padLeft(2, '0');
			final mm = dt.minute.toString().padLeft(2, '0');
			return 'Today $hh:$mm';
		}
		return '${dt.month}/${dt.day}';
	}

	Future<void> _getAiMoodAdvice() async {
		if (_selectedMoodLabel == null) return;
		setState(() {
			_adviceLoading = true;
			_aiMoodAdvice = null;
		});
		try {
			final provider = await AppSettings().getInsightsProvider();
			final budgetPerDay = double.tryParse(_budgetCtrl.text.trim());
			final svc = NutritionInsightsService();
			final advice = await svc.generateMoodSupport(
				mood: _selectedMoodLabel!,
				region: _region,
				vegetarianOnly: _vegetarianOnly,
				useLocalStaples: _useLocalStaples,
				budgetPerDay: budgetPerDay,
				provider: provider,
			);
			setState(() {
				_aiMoodAdvice = advice;
				_moodHistory.insert(
					0,
					_MoodEntry(
						key: _selectedMoodKey ?? '',
						label: _selectedMoodLabel ?? '',
						emoji: _selectedMoodEmoji ?? '🙂',
						createdAt: DateTime.now(),
					),
				);
			});
			await _saveMoodLogToFirestore(
				key: _selectedMoodKey ?? '',
				label: _selectedMoodLabel ?? '',
				emoji: _selectedMoodEmoji ?? '🙂',
				advice: advice,
			); 
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get AI suggestions: $e')));
		} finally {
			if (mounted) {
				setState(() => _adviceLoading = false);
			}
		}
	}

	Future<void> _saveMoodLogToFirestore({required String key, required String label, required String emoji, required String advice}) async {
		try {
			if (Firebase.apps.isEmpty) {
				await Firebase.initializeApp();
			}
				final uid = FirebaseAuth.instance.currentUser?.uid;
				await cf.FirebaseFirestore.instance.collection('studentMoodLogs').add({
				'createdAt': DateTime.now().toIso8601String(),
				'moodKey': key,
				'moodLabel': label,
				'emoji': emoji,
				'region': _region,
				'vegetarianOnly': _vegetarianOnly,
				'useLocalStaples': _useLocalStaples,
				'budgetPerDay': double.tryParse(_budgetCtrl.text.trim()),
				'advice': advice,
					'userId': uid,
			});
		} catch (_) {
			// non-blocking
		}
	}
	@override
	void dispose() {
		_budgetCtrl.dispose();
		super.dispose();
	}

	Future<void> _generate() async {
		FocusScope.of(context).unfocus();
		final budgetPerDay = _parseNumber(_budgetCtrl.text.trim()) ?? 3000.0;
		final targetPerMeal = (budgetPerDay / _mealsPerDay);

		setState(() {
			_loading = true;
			_generated = [];
			_selected.clear();
		});

		await Future<void>.delayed(const Duration(milliseconds: 200));

		List<MealSuggestion> pool = _allSuggestions
				.where((m) => (!_vegetarianOnly || m.vegetarian))
				.where((m) => !_useLocalStaples || m.usesLocalStaples)
				.toList();

		// Progressive relaxation if pool is too small
		if (pool.isEmpty) {
			pool = _allSuggestions.where((m) => (!_vegetarianOnly || m.vegetarian)).toList();
		}
		if (pool.isEmpty) {
			pool = List.of(_allSuggestions); // last resort: ignore filters
		}

		// Keep meals that fit target per meal with a small tolerance
		pool.sort((a, b) => a.totalCost.compareTo(b.totalCost));
		final withinBudget = pool.where((m) => m.totalCost <= targetPerMeal * 1.1).toList();
		// If too few, relax constraint slightly
		List<MealSuggestion> candidates = withinBudget.isNotEmpty
				? withinBudget
				: pool.where((m) => m.totalCost <= targetPerMeal * 1.35).toList();

		// If still none (very low budget), pick the cheapest few overall
		if (candidates.isEmpty) {
			candidates = pool.take(8).toList();
		}

		// Return up to 6 varied suggestions
		final chosen = <MealSuggestion>[];
		for (final m in candidates) {
			chosen.add(m);
			if (chosen.length >= 6) break;
		}

		setState(() {
			_generated = chosen;
			_loading = false;
		});
		if (chosen.isEmpty && mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No meals matched your filters. Showing budget-friendly options.')),
			);
		}
	}

	double? _parseNumber(String raw) {
		// Accept common formats like "3,000" or "3000" or "3000.50"
		final cleaned = raw.replaceAll(RegExp(r'[^0-9\.]'), '');
		return double.tryParse(cleaned);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Affordable Meal Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
				centerTitle: true,
				backgroundColor: Colors.teal,
				foregroundColor: Colors.white,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						_buildForm(),
						const SizedBox(height: 16),
						_buildMoodSection(),
						const SizedBox(height: 16),
						if (_loading) const Center(child: CircularProgressIndicator()),
						if (!_loading && _generated.isNotEmpty) _buildResults(),
						const SizedBox(height: 16),
						_buildDealsSection(),
						const SizedBox(height: 16),
						_buildCafeteriaGuidanceSection(),
						const SizedBox(height: 16),
						_buildSocialSection(),
						// Mental health nutrition section (always visible)
						const SizedBox(height: 16),
						_buildMentalHealthSection(),
					],
				),
			),
			bottomNavigationBar: _selected.isEmpty
					? null
					: SafeArea(
							child: Padding(
								padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										ElevatedButton.icon(
											style: ElevatedButton.styleFrom(
												backgroundColor: Colors.teal,
												foregroundColor: Colors.white,
												minimumSize: const Size.fromHeight(48),
											),
											onPressed: _showShoppingList,
											icon: const Icon(Icons.shopping_basket_outlined),
											label: Text('View Shopping List (${_selected.length} selected)'),
										),
										const SizedBox(height: 8),
										OutlinedButton.icon(
											onPressed: _saveSelectionToFirestore,
											icon: const Icon(Icons.cloud_upload_outlined),
											label: const Text('Save selection to Firestore'),
										),
									],
								),
							),
						),
		);
	}

	// ===== Deals: highlight current supermarket/local offers =====
	Future<void> _resolveLocation() async {
		try {
			final perm = await Geolocator.checkPermission();
			if (perm == LocationPermission.denied) {
				await Geolocator.requestPermission();
			}
			if (await Geolocator.isLocationServiceEnabled()) {
				_position = await Geolocator.getCurrentPosition();
				if (mounted) setState(() {});
			}
		} catch (_) {}
	}

	Future<void> _refreshDeals() async {
		setState(() => _loadingDeals = true);
		try {
			if (Firebase.apps.isEmpty) {
				await Firebase.initializeApp();
			}
			final conn = await Connectivity().checkConnectivity();
			if (conn.contains(ConnectivityResult.none)) {
				if (_deals.isEmpty) {
					final list = await _loadDealsFromAssets();
					setState(() => _deals = _sortByDistance(list));
				}
				return;
			}
			final snap = await FirebaseDatabase.instance.ref('local_offers/global').get();
			final list = <_LocalOffer>[];
			final val = snap.value;
			if (val is List) {
				for (final item in val) {
					if (item is Map) list.add(_LocalOffer.fromMap(Map<String, dynamic>.from(item)));
				}
			} else if (val is Map) {
				val.forEach((key, item) {
					if (item is Map) list.add(_LocalOffer.fromMap(Map<String, dynamic>.from(item)));
				});
			}
			setState(() => _deals = _sortByDistance(list));
			await _cacheDeals();
		} catch (_) {
			if (_deals.isEmpty) {
				final list = await _loadDealsFromAssets();
				setState(() => _deals = _sortByDistance(list));
			}
		} finally {
			if (mounted) setState(() => _loadingDeals = false);
		}
	}

	List<_LocalOffer> _sortByDistance(List<_LocalOffer> list) {
		if (_position == null) return list;
		final sorted = [...list];
		sorted.sort((a, b) {
			final da = (a.lat != null && a.lng != null) ? _distanceKm(_position!.latitude, _position!.longitude, a.lat!, a.lng!) : double.infinity;
			final db = (b.lat != null && b.lng != null) ? _distanceKm(_position!.latitude, _position!.longitude, b.lat!, b.lng!) : double.infinity;
			return da.compareTo(db);
		});
		return sorted;
	}

	Future<void> _cacheDeals() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('student_cached_deals', jsonEncode(_deals.map((e) => e.toJson()).toList()));
		} catch (_) {}
	}

	Future<void> _loadCachedDeals() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final raw = prefs.getString('student_cached_deals');
			if (raw != null) {
				final arr = (jsonDecode(raw) as List).cast<Map>();
				_deals = arr.map((e) => _LocalOffer.fromMap(Map<String, dynamic>.from(e))).toList();
				if (mounted) setState(() {});
			}
		} catch (_) {}
	}

	Future<List<_LocalOffer>> _loadDealsFromAssets() async {
		try {
			final raw = await rootBundle.loadString('assets/data/promotions_mock.json');
			final arr = (jsonDecode(raw) as List).cast<Map>();
			return arr.map((e) => _LocalOffer.fromMap(Map<String, dynamic>.from(e))).toList();
		} catch (_) {
			return const <_LocalOffer>[];
		}
	}

	Widget _buildDealsSection() {
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								const Icon(Icons.local_offer_outlined, color: Colors.teal),
								const SizedBox(width: 8),
								const Expanded(
									child: Text('Nearby Supermarket Deals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
								),
								IconButton(
									tooltip: 'Refresh',
									onPressed: _loadingDeals ? null : _refreshDeals,
									icon: _loadingDeals
										? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
										: const Icon(Icons.refresh),
								),
							],
						),
						const SizedBox(height: 8),
						if (_deals.isEmpty)
							Text('No deals yet. Pull to refresh or try again later.', style: TextStyle(color: Colors.black.withValues(alpha: 0.7))),
						..._deals.take(5).map((d) => ListTile(
							leading: const Icon(Icons.store_mall_directory_outlined),
							title: Text(d.name),
							subtitle: Text(d.offer),
							trailing: d.price != null ? Text(_currency.format(d.price)) : null,
							onTap: () async {
								if (d.lat != null && d.lng != null) {
									final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${d.lat},${d.lng}');
									if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
								}
							},
						)),
					],
				),
			),
		);
	}

	// ===== Cafeteria & Restaurant Guidance =====
	Future<void> _loadCafeteriasFromAssets() async {
		try {
			final raw = await rootBundle.loadString('assets/data/cafeterias_mock.json');
			final arr = (jsonDecode(raw) as List).cast<Map>();
			_cafeterias = arr.map((e) => CafeteriaEntry.fromMap(Map<String, dynamic>.from(e))).toList();
			if (mounted) setState(() {});
		} catch (_) {
			_cafeterias = const [];
		}
	}

	Widget _buildCafeteriaGuidanceSection() {
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(children: const [
							Icon(Icons.restaurant_outlined, color: Colors.teal),
							SizedBox(width: 8),
							Expanded(child: Text('Cafeteria & Nearby Eateries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
						]),
						const SizedBox(height: 8),
						Text('Find healthier picks at campus dining or restaurants near you.', style: TextStyle(color: Colors.black.withValues(alpha: 0.7))),
						const SizedBox(height: 8),
						SizedBox(
							width: double.infinity,
							child: OutlinedButton.icon(
								onPressed: () async {
									const query = 'healthy restaurant near me';
									final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
									if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
								},
								icon: const Icon(Icons.map_outlined),
								label: const Text('Open in Google Maps'),
							),
						),
						const SizedBox(height: 8),
						if (_cafeterias.isNotEmpty) const Text('Campus cafeterias', style: TextStyle(fontWeight: FontWeight.w700)),
						..._cafeterias.take(5).map((c) => ListTile(
							title: Text(c.name),
							subtitle: Text(c.healthiest?.join(', ') ?? 'Healthy picks available'),
							trailing: c.hours != null ? Text(c.hours!) : null,
							onTap: () async {
								if (c.url != null) {
									final uri = Uri.parse(c.url!);
									if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); return; }
								}
								if (c.lat != null && c.lng != null) {
									final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}');
									if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
								}
							},
						)),
					],
				),
			),
		);
	}

	// ===== Social & Gamified =====
	Widget _buildSocialSection() {
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(children: const [
							Icon(Icons.groups_outlined, color: Colors.teal),
							SizedBox(width: 8),
							Expanded(child: Text('Social & Challenges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
						]),
						const SizedBox(height: 8),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: [
    								ElevatedButton.icon(
									style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
									onPressed: () => Navigator.of(context).pushNamed(AppRoutes.socialCommunity),
									icon: const Icon(Icons.flag_outlined),
									label: const Text('Join a group challenge'),
								),
								OutlinedButton.icon(
									onPressed: () => Navigator.of(context).pushNamed(AppRoutes.socialCommunity),
									icon: const Icon(Icons.share_outlined),
									label: const Text('Share a recipe'),
								),
								OutlinedButton.icon(
									onPressed: () => Navigator.of(context).pushNamed(AppRoutes.socialCommunity),
									icon: const Icon(Icons.emoji_events_outlined),
									label: const Text('View leaderboard'),
								),
							],
						),
					],
				),
			),
		);
	}

	Widget _buildMoodSection() {
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: const [
								Icon(Icons.emoji_emotions_outlined, color: Colors.teal),
								SizedBox(width: 8),
								Expanded(
									child: Text('How are you feeling today?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
								),
							],
						),
						const SizedBox(height: 8),
						Text('Choose a mood to get supportive nutrition ideas', style: TextStyle(color: Colors.black.withValues(alpha: 0.7))),
						const SizedBox(height: 12),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: _moodOptions.map((m) {
								final selected = m.key == _selectedMoodKey;
								return ChoiceChip(
									selected: selected,
									label: Row(
										mainAxisSize: MainAxisSize.min,
										children: [Text(m.emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 6), Text(m.label)],
									),
									selectedColor: Colors.teal.withValues(alpha: 0.15),
									onSelected: (_) {
									setState(() {
										_selectedMoodKey = m.key;
										_selectedMoodLabel = m.label;
										_selectedMoodEmoji = m.emoji;
									});
								},
								shape: StadiumBorder(side: BorderSide(color: selected ? Colors.teal : Colors.grey.shade300)),
							);
							}).toList(),
						),
						const SizedBox(height: 12),
						SizedBox(
							width: double.infinity,
							child: ElevatedButton.icon(
								style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
								onPressed: (_selectedMoodKey == null || _adviceLoading) ? null : _getAiMoodAdvice,
								icon: const Icon(Icons.auto_awesome),
								label: Text(_adviceLoading ? 'Getting suggestions…' : 'Get AI Suggestions for My Mood'),
							),
						),
						if (_aiMoodAdvice != null) ...[
							const SizedBox(height: 12),
							Container(
								width: double.infinity,
								padding: const EdgeInsets.all(12),
								decoration: BoxDecoration(
									color: Colors.teal.withValues(alpha: 0.06),
									borderRadius: BorderRadius.circular(12),
								),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('You\'ve got this 💛', style: TextStyle(fontWeight: FontWeight.w700)),
										const SizedBox(height: 6),
										Text(_aiMoodAdvice!),
									],
								),
							),
						],
						const SizedBox(height: 12),
						const Text('Recent moods', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 8),
						if (_moodHistory.isEmpty)
							Text('No recent moods yet', style: TextStyle(color: Colors.black.withValues(alpha: 0.6)))
						else
							SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: _moodHistory
										.map((e) => Padding(
											padding: const EdgeInsets.only(right: 12),
											child: Column(
												children: [
													Text(e.emoji, style: const TextStyle(fontSize: 20)),
													Text(_friendlyTime(e.createdAt), style: const TextStyle(fontSize: 12, color: Colors.black54)),
												],
											),
										))
										.toList(),
								),
							),
					],
				),
			),
		);
	}

	Widget _buildForm() {
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text('Plan on a Student Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
						const SizedBox(height: 12),
										LayoutBuilder(
											builder: (context, constraints) {
												final isNarrow = constraints.maxWidth < 360;
												final budgetField = TextFormField(
													controller: _budgetCtrl,
													keyboardType: TextInputType.number,
													decoration: const InputDecoration(
														labelText: 'Budget per day (approx.)',
														helperText: 'Enter a number in your local currency',
													),
												);
												final mealsField = DropdownButtonFormField<int>(
													initialValue: _mealsPerDay,
													items: const [
														DropdownMenuItem(value: 2, child: Text('2 meals / day')),
														DropdownMenuItem(value: 3, child: Text('3 meals / day')),
														DropdownMenuItem(value: 4, child: Text('4 meals / day')),
													],
													onChanged: (v) => setState(() => _mealsPerDay = v ?? _mealsPerDay),
													decoration: const InputDecoration(labelText: 'Meals per day'),
												);

												if (isNarrow) {
													return Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [budgetField, const SizedBox(height: 12), mealsField],
													);
												}
												return Row(
													children: [
														Expanded(child: budgetField),
														const SizedBox(width: 12),
														Expanded(child: mealsField),
													],
												);
											},
										),
						const SizedBox(height: 12),
										LayoutBuilder(
											builder: (context, constraints) {
												final isNarrow = constraints.maxWidth < 360;
												final regionField = DropdownButtonFormField<String>(
													initialValue: _region,
													items: const [
														DropdownMenuItem(value: 'Default', child: Text('Region: Default')),
														DropdownMenuItem(value: 'Nigeria', child: Text('Region: Nigeria')),
														DropdownMenuItem(value: 'Ghana', child: Text('Region: Ghana')),
														DropdownMenuItem(value: 'Kenya', child: Text('Region: Kenya')),
														DropdownMenuItem(value: 'USA', child: Text('Region: USA')),
													],
													onChanged: (v) {
														if (v == null) return;
														setState(() {
															_region = v;
															_allSuggestions = _buildSuggestionCatalog(_region);
															_mentalHealth = _buildMentalHealthSuggestions(_region);
															_generated = [];
															_selected.clear();
														});
													},
													decoration: const InputDecoration(labelText: 'Region presets (local staples)'),
												);
												if (isNarrow) {
													return regionField;
												}
												return Row(children: [Expanded(child: regionField)]);
											},
										),
						const SizedBox(height: 8),
						SwitchListTile(
							contentPadding: EdgeInsets.zero,
							title: const Text('Vegetarian only'),
							value: _vegetarianOnly,
							onChanged: (v) => setState(() => _vegetarianOnly = v),
						),
						SwitchListTile(
							contentPadding: EdgeInsets.zero,
							title: const Text('Use local staples (e.g., rice, beans, plantain, oats)'),
							value: _useLocalStaples,
							onChanged: (v) => setState(() => _useLocalStaples = v),
						),
						const SizedBox(height: 8),
						SizedBox(
							width: double.infinity,
							child: ElevatedButton.icon(
								style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
								onPressed: _loading ? null : _generate,
								icon: const Icon(Icons.auto_awesome),
								label: const Text('Generate Affordable Meals'),
							),
						),
					],
				),
			),
		);
	}

	Widget _buildResults() {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				const Text('Suggestions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
				const SizedBox(height: 8),
				..._generated.map((m) => _MealSuggestionCard(
							suggestion: m,
							selected: _selected.contains(m.name),
							onToggle: () {
								setState(() {
									if (_selected.contains(m.name)) {
										_selected.remove(m.name);
									} else {
										_selected.add(m.name);
									}
								});
							},
						)),
			],
		);
	}

	void _showShoppingList() {
		final allPools = <MealSuggestion>[..._generated, ..._mentalHealth];
		final selectedMeals = allPools.where((m) => _selected.contains(m.name));
		final Map<String, double> aggCosts = {};
		for (final m in selectedMeals) {
			for (final ing in m.ingredients) {
				aggCosts.update(ing.name, (v) => v + ing.cost, ifAbsent: () => ing.cost);
			}
		}

		final total = aggCosts.values.fold<double>(0, (s, c) => s + c);

		showModalBottomSheet(
			context: context,
			isScrollControlled: true,
			shape: const RoundedRectangleBorder(
				borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
			),
			builder: (context) {
				return Padding(
					padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: [
									const Text('Shopping List (estimated)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
									Text('${aggCosts.length} items', style: const TextStyle(color: Colors.black54)),
								],
							),
							const SizedBox(height: 12),
							Flexible(
								child: ListView(
									shrinkWrap: true,
									children: [
										...aggCosts.entries.map((e) => ListTile(
													dense: true,
													contentPadding: EdgeInsets.zero,
													title: Text(e.key),
													trailing: Text(_formatCost(e.value)),
												)),
									],
								),
							),
							const Divider(),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: [
									const Text('Estimated total', style: TextStyle(fontWeight: FontWeight.w700)),
									Text(_formatCost(total), style: const TextStyle(fontWeight: FontWeight.w700)),
								],
							),
							const SizedBox(height: 8),
							SizedBox(
								width: double.infinity,
								child: OutlinedButton(
									onPressed: () => Navigator.pop(context),
									child: const Text('Close'),
								),
							)
						],
					),
				);
			},
		);
	}

	Future<void> _saveSelectionToFirestore() async {
		try {
			if (Firebase.apps.isEmpty) {
				await Firebase.initializeApp();
			}
				final firestore = cf.FirebaseFirestore.instance;
				final uid = FirebaseAuth.instance.currentUser?.uid;

			final allPools = <MealSuggestion>[..._generated, ..._mentalHealth];
			final selectedMeals = allPools.where((m) => _selected.contains(m.name));
			final Map<String, double> aggCosts = {};
			for (final m in selectedMeals) {
				for (final ing in m.ingredients) {
					aggCosts.update(ing.name, (v) => v + ing.cost, ifAbsent: () => ing.cost);
				}
			}
			final total = aggCosts.values.fold<double>(0, (s, c) => s + c);

					final doc = {
				'createdAt': DateTime.now().toIso8601String(),
				'region': _region,
				'budgetPerDay': double.tryParse(_budgetCtrl.text.trim()) ?? 3000.0,
				'mealsPerDay': _mealsPerDay,
				'vegetarianOnly': _vegetarianOnly,
				'useLocalStaples': _useLocalStaples,
				'selectedMeals': _selected.toList(),
				'estimatedTotalCost': total,
				'ingredients': aggCosts.entries
						.map((e) => {'name': e.key, 'cost': e.value})
						.toList(),
						if (uid != null) 'userId': uid,
			};

			await firestore.collection('studentMealSelections').add(doc);

			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Selection saved to Firestore')),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to save: $e')),
			);
		}
	}

	// Curated Student Mental Health Nutrition suggestions
	Widget _buildMentalHealthSection() {
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: const [
								Icon(Icons.psychology_alt_outlined, color: Colors.teal),
								SizedBox(width: 8),
								Expanded(
									child: Text(
										'Student Mental Health Nutrition',
										style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
									),
								),
							],
						),
						const SizedBox(height: 8),
						Text(
							"Foods rich in omega-3s, complex carbs, magnesium, and probiotics may support mood and reduce stress.",
							style: TextStyle(color: Colors.black.withValues(alpha: 0.7)),
						),
						const SizedBox(height: 12),
						..._mentalHealth.map(
							(m) => _MealSuggestionCard(
								suggestion: m,
								selected: _selected.contains(m.name),
								onToggle: () {
									setState(() {
										if (_selected.contains(m.name)) {
											_selected.remove(m.name);
										} else {
											_selected.add(m.name);
										}
									});
								},
							),
						),
						const SizedBox(height: 4),
						Text(
							'This information is educational and not a substitute for professional medical advice.',
							style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.6)),
						),
					],
				),
			),
		);
	}

	List<MealSuggestion> _buildSuggestionCatalog([String region = 'Default']) {
		// Costs are approximate per-serving placeholders; adjust to your locale as needed.
		final defaultMeals = [
			MealSuggestion(
				name: 'Rice & Beans with Fried Plantain',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 650,
				ingredients: const [
					IngredientItem(name: 'Rice (1 cup cooked)', cost: 120.0),
					IngredientItem(name: 'Beans (1/2 cup cooked)', cost: 90.0),
					IngredientItem(name: 'Plantain (1/2)', cost: 100.0),
					IngredientItem(name: 'Oil & spices', cost: 40.0),
				],
			),
			MealSuggestion(
				name: 'Egg Fried Rice (with vegetables)',
				vegetarian: false,
				usesLocalStaples: true,
				kcal: 600,
				ingredients: const [
					IngredientItem(name: 'Rice (1 cup cooked)', cost: 120.0),
					IngredientItem(name: 'Eggs (2)', cost: 150.0),
					IngredientItem(name: 'Mixed veggies', cost: 120.0),
					IngredientItem(name: 'Oil & soy sauce', cost: 50.0),
				],
			),
			MealSuggestion(
				name: 'Oats with Peanut Butter & Banana',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 500,
				ingredients: const [
					IngredientItem(name: 'Oats (1 cup cooked)', cost: 100.0),
					IngredientItem(name: 'Peanut butter (1 tbsp)', cost: 80.0),
					IngredientItem(name: 'Banana (1)', cost: 80.0),
				],
			),
			MealSuggestion(
				name: 'Pasta with Tomato Sauce & Eggs',
				vegetarian: false,
				usesLocalStaples: true,
				kcal: 650,
				ingredients: const [
					IngredientItem(name: 'Pasta (1 cup cooked)', cost: 130.0),
					IngredientItem(name: 'Tomato/onion sauce', cost: 120.0),
					IngredientItem(name: 'Eggs (2)', cost: 150.0),
				],
			),
			MealSuggestion(
				name: 'Bean Stew with Rice',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 600,
				ingredients: const [
					IngredientItem(name: 'Beans (1 cup cooked)', cost: 160.0),
					IngredientItem(name: 'Rice (1 cup cooked)', cost: 120.0),
					IngredientItem(name: 'Oil & spices', cost: 40.0),
				],
			),
			MealSuggestion(
				name: 'Vegetable Stir-fry with Noodles',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 520,
				ingredients: const [
					IngredientItem(name: 'Instant noodles (1 pack)', cost: 120.0),
					IngredientItem(name: 'Mixed veggies', cost: 120.0),
					IngredientItem(name: 'Oil & spices', cost: 40.0),
				],
			),
			MealSuggestion(
				name: 'Lentil Curry with Rice',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 580,
				ingredients: const [
					IngredientItem(name: 'Lentils (1 cup cooked)', cost: 180.0),
					IngredientItem(name: 'Rice (1 cup cooked)', cost: 120.0),
					IngredientItem(name: 'Onion/tomato & spices', cost: 80.0),
				],
			),
			MealSuggestion(
				name: 'Garlic Sardine Pasta',
				vegetarian: false,
				usesLocalStaples: true,
				kcal: 620,
				ingredients: const [
					IngredientItem(name: 'Pasta (1 cup cooked)', cost: 130.0),
					IngredientItem(name: 'Canned sardine (1/2 tin)', cost: 220.0),
					IngredientItem(name: 'Garlic/oil/chilli', cost: 60.0),
				],
			),
			MealSuggestion(
				name: 'Yam or Sweet Potato Porridge',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 640,
				ingredients: const [
					IngredientItem(name: 'Yam or sweet potato', cost: 200.0),
					IngredientItem(name: 'Palm/veg oil & greens', cost: 100.0),
					IngredientItem(name: 'Onion/tomato/pepper', cost: 100.0),
				],
			),
		];

		if (region == 'Nigeria') {
			return [
				MealSuggestion(
					name: 'Jollof Rice with Egg',
					vegetarian: false,
					usesLocalStaples: true,
					kcal: 680,
					ingredients: const [
						IngredientItem(name: 'Rice (1 cup cooked)', cost: 120.0),
						IngredientItem(name: 'Tomato/pepper/onion', cost: 150.0),
						IngredientItem(name: 'Eggs (2)', cost: 150.0),
						IngredientItem(name: 'Oil & spices', cost: 60.0),
					],
				),
				MealSuggestion(
					name: 'Garri & Beans (Ewa Agoyin style)',
					vegetarian: true,
					usesLocalStaples: true,
					kcal: 700,
					ingredients: const [
						IngredientItem(name: 'Beans (1 cup cooked)', cost: 160.0),
						IngredientItem(name: 'Garri (1 cup soaked)', cost: 80.0),
						IngredientItem(name: 'Palm oil & pepper sauce', cost: 100.0),
					],
				),
				...defaultMeals,
			];
		} else if (region == 'Ghana') {
			return [
				MealSuggestion(
					name: 'Waakye (Rice & Beans) with Egg',
					vegetarian: false,
					usesLocalStaples: true,
					kcal: 720,
					ingredients: const [
						IngredientItem(name: 'Rice & beans (1 cup cooked)', cost: 180.0),
						IngredientItem(name: 'Egg (1)', cost: 75.0),
						IngredientItem(name: 'Gari/shito (sides)', cost: 120.0),
					],
				),
				MealSuggestion(
					name: 'Kenkey with Pepper & Fish (small)',
					vegetarian: false,
					usesLocalStaples: true,
					kcal: 650,
					ingredients: const [
						IngredientItem(name: 'Kenkey (1 small ball)', cost: 200.0),
						IngredientItem(name: 'Pepper/onion sauce', cost: 100.0),
						IngredientItem(name: 'Fish (small portion)', cost: 220.0),
					],
				),
				...defaultMeals,
			];
		} else if (region == 'Kenya') {
			return [
				MealSuggestion(
					name: 'Ugali with Sukuma Wiki',
					vegetarian: true,
					usesLocalStaples: true,
					kcal: 600,
					ingredients: const [
						IngredientItem(name: 'Maize flour (ugali portion)', cost: 120.0),
						IngredientItem(name: 'Sukuma wiki (greens)', cost: 120.0),
						IngredientItem(name: 'Onion/tomato & oil', cost: 80.0),
					],
				),
				MealSuggestion(
					name: 'Githeri (Maize & Beans)',
					vegetarian: true,
					usesLocalStaples: true,
					kcal: 650,
					ingredients: const [
						IngredientItem(name: 'Maize & beans (1 cup cooked)', cost: 180.0),
						IngredientItem(name: 'Onion/tomato & oil', cost: 80.0),
						IngredientItem(name: 'Spices', cost: 40.0),
					],
				),
				...defaultMeals,
			];
		} else if (region == 'USA') {
			return [
				MealSuggestion(
					name: 'PB&J Sandwich with Banana',
					vegetarian: true,
					usesLocalStaples: true,
					kcal: 520,
					ingredients: const [
						IngredientItem(name: 'Bread (2 slices)', cost: 120.0),
						IngredientItem(name: 'Peanut butter (1 tbsp)', cost: 80.0),
						IngredientItem(name: 'Jam (1 tbsp)', cost: 60.0),
						IngredientItem(name: 'Banana', cost: 80.0),
					],
				),
				MealSuggestion(
					name: 'Instant Ramen with Egg & Veg',
					vegetarian: false,
					usesLocalStaples: true,
					kcal: 560,
					ingredients: const [
						IngredientItem(name: 'Instant ramen', cost: 150.0),
						IngredientItem(name: 'Egg (1)', cost: 75.0),
						IngredientItem(name: 'Frozen veg', cost: 120.0),
					],
				),
				...defaultMeals,
			];
		}

		return defaultMeals;
	}

	List<MealSuggestion> _buildMentalHealthSuggestions([String region = 'Default']) {
		// Evidence-informed, budget-conscious ideas; adjust costs locally as needed.
		final base = <MealSuggestion>[
			MealSuggestion(
				name: 'Oats, Yogurt, Nuts & Banana Bowl',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 520,
				ingredients: const [
					IngredientItem(name: 'Oats (1 cup cooked)', cost: 100.0),
					IngredientItem(name: 'Plain yogurt (1/2 cup)', cost: 120.0),
					IngredientItem(name: 'Banana (1)', cost: 80.0),
					IngredientItem(name: 'Peanuts or mixed nuts (small handful)', cost: 120.0),
				],
			),
			MealSuggestion(
				name: 'Sardine & Avocado on Wholegrain Bread',
				vegetarian: false,
				usesLocalStaples: true,
				kcal: 600,
				ingredients: const [
					IngredientItem(name: 'Wholegrain bread (2 slices)', cost: 120.0),
					IngredientItem(name: 'Canned sardine (1/2 tin)', cost: 220.0),
					IngredientItem(name: 'Avocado (1/2)', cost: 150.0),
				],
			),
			MealSuggestion(
				name: 'Lentil & Spinach Stew with Rice',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 620,
				ingredients: const [
					IngredientItem(name: 'Lentils (1 cup cooked)', cost: 180.0),
					IngredientItem(name: 'Spinach/leafy greens', cost: 120.0),
					IngredientItem(name: 'Rice (1 cup cooked)', cost: 120.0),
				],
			),
			MealSuggestion(
				name: 'Eggs, Tomatoes & Greens Wrap',
				vegetarian: false,
				usesLocalStaples: true,
				kcal: 580,
				ingredients: const [
					IngredientItem(name: 'Eggs (2)', cost: 150.0),
					IngredientItem(name: 'Leafy greens (small handful)', cost: 80.0),
					IngredientItem(name: 'Tomato & onion', cost: 100.0),
					IngredientItem(name: 'Flatbread/wrap (1)', cost: 120.0),
				],
			),
			MealSuggestion(
				name: 'Yogurt Parfait with Oats & Berries',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 450,
				ingredients: const [
					IngredientItem(name: 'Plain yogurt (3/4 cup)', cost: 160.0),
					IngredientItem(name: 'Oats (1/2 cup)', cost: 80.0),
					IngredientItem(name: 'Seasonal fruit/berries', cost: 150.0),
				],
			),
			MealSuggestion(
				name: 'Dark Chocolate & Nut Trail Mix (study snack)',
				vegetarian: true,
				usesLocalStaples: true,
				kcal: 300,
				ingredients: const [
					IngredientItem(name: 'Dark chocolate (small piece)', cost: 80.0),
					IngredientItem(name: 'Peanuts/mixed nuts (small handful)', cost: 120.0),
					IngredientItem(name: 'Raisins/dried fruit (small handful)', cost: 80.0),
				],
			),
		];

		// Region-specific swap-ins to keep things familiar and affordable.
		if (region == 'Nigeria' || region == 'Ghana' || region == 'Kenya') {
			return [
				...base,
				MealSuggestion(
					name: 'Beans & Plantain with Greens (folate + magnesium)',
					vegetarian: true,
					usesLocalStaples: true,
					kcal: 650,
					ingredients: const [
						IngredientItem(name: 'Beans (1 cup cooked)', cost: 160.0),
						IngredientItem(name: 'Plantain (1/2)', cost: 100.0),
						IngredientItem(name: 'Leafy greens (small handful)', cost: 80.0),
					],
				),
			];
		}

		return base;
	}

	String _formatCost(double v) {
		// Neutral formatting without currency symbol to fit any locale
		return v.toStringAsFixed(0);
	}
}

// ===== Support models for this screen =====

class _LocalOffer {
	final String name;
	final String offer;
	final double? price;
	final double? lat;
	final double? lng;

	_LocalOffer({required this.name, required this.offer, this.price, this.lat, this.lng});

	factory _LocalOffer.fromMap(Map<String, dynamic> m) {
		return _LocalOffer(
			name: (m['name'] ?? 'Market').toString(),
			offer: (m['offer'] ?? '').toString(),
			price: (m['price'] is num) ? (m['price'] as num).toDouble() : null,
			lat: (m['lat'] is num) ? (m['lat'] as num).toDouble() : null,
			lng: (m['lng'] is num) ? (m['lng'] as num).toDouble() : null,
		);
	}

	Map<String, dynamic> toJson() => {
				'name': name,
				'offer': offer,
				'price': price,
				'lat': lat,
				'lng': lng,
			};
}

class CafeteriaEntry {
	final String name;
	final List<String>? healthiest;
	final String? hours;
	final String? url;
	final double? lat;
	final double? lng;

	CafeteriaEntry({required this.name, this.healthiest, this.hours, this.url, this.lat, this.lng});

	factory CafeteriaEntry.fromMap(Map<String, dynamic> m) => CafeteriaEntry(
				name: (m['name'] ?? 'Cafeteria').toString(),
				healthiest: (m['healthiest'] is List)
						? (m['healthiest'] as List).map((e) => e.toString()).toList()
						: null,
				hours: (m['hours'] as String?)?.toString(),
				url: (m['url'] as String?)?.toString(),
				lat: (m['lat'] is num) ? (m['lat'] as num).toDouble() : null,
				lng: (m['lng'] is num) ? (m['lng'] as num).toDouble() : null,
			);
}

// ===== Geo helpers (reuse minimal) =====
extension _GeoHelpers on _StudentFeaturesScreenState {
	double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
		const R = 6371.0; // km
	double dLat = _deg2rad(lat2 - lat1);
	double dLon = _deg2rad(lon2 - lon1);
	double a =
		math.sin(dLat / 2) * math.sin(dLat / 2) +
			math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
				math.sin(dLon / 2) * math.sin(dLon / 2);
		double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
		return R * c;
	}

	double _deg2rad(double deg) => deg * (math.pi / 180.0);
}

class _MealSuggestionCard extends StatelessWidget {
	final MealSuggestion suggestion;
	final bool selected;
	final VoidCallback onToggle;

	const _MealSuggestionCard({
		required this.suggestion,
		required this.selected,
		required this.onToggle,
	});

	@override
	Widget build(BuildContext context) {
		return Card(
			elevation: 2,
			margin: const EdgeInsets.only(bottom: 12),
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			child: Padding(
				padding: const EdgeInsets.all(12),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(suggestion.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
											const SizedBox(height: 4),
																						Wrap(
																							spacing: 8,
																							runSpacing: 6,
																							children: [
																								Chip(
																									label: Text('${suggestion.kcal} kcal'),
																									backgroundColor: Colors.teal.withValues(alpha: 0.12),
																									side: BorderSide.none,
																								),
																								if (suggestion.vegetarian)
																									const Chip(label: Text('Vegetarian'), side: BorderSide.none),
																								if (suggestion.usesLocalStaples)
																									const Chip(label: Text('Local staples'), side: BorderSide.none),
																							],
																						),
										],
									),
								),
								Column(
									children: [
										Text('Est. cost', style: TextStyle(color: Colors.grey.shade600)),
										Text(_formatCost(suggestion.totalCost), style: const TextStyle(fontWeight: FontWeight.w700)),
									],
								)
							],
						),
						const SizedBox(height: 8),
						ExpansionTile(
							dense: true,
							tilePadding: EdgeInsets.zero,
							title: const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.w600)),
							children: [
								...suggestion.ingredients.map(
									(i) => ListTile(
										dense: true,
										contentPadding: EdgeInsets.zero,
										title: Text(i.name),
										trailing: Text(_formatCost(i.cost)),
									),
								),
							],
						),
						const SizedBox(height: 4),
						Align(
							alignment: Alignment.centerRight,
							child: TextButton.icon(
								onPressed: onToggle,
								icon: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank),
								label: Text(selected ? 'Selected' : 'Select'),
							),
						)
					],
				),
			),
		);
	}

	String _formatCost(double v) => v.toStringAsFixed(0);
}

class IngredientItem {
	final String name;
	final double cost; // approximate per recipe serving for this ingredient portion
	const IngredientItem({required this.name, required this.cost});
}

class MealSuggestion {
	final String name;
	final bool vegetarian;
	final bool usesLocalStaples;
	final int kcal;
	final List<IngredientItem> ingredients;

	const MealSuggestion({
		required this.name,
		required this.vegetarian,
		required this.usesLocalStaples,
		required this.kcal,
		required this.ingredients,
	});

	double get totalCost => ingredients.fold(0, (s, i) => s + i.cost);
}

class MoodOption {
	final String key;
	final String emoji;
	final String label;
	const MoodOption({required this.key, required this.emoji, required this.label});
}

class _MoodEntry {
	final String key;
	final String label;
	final String emoji;
	final DateTime createdAt;
	const _MoodEntry({required this.key, required this.label, required this.emoji, required this.createdAt});
}

