import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';
import 'package:flutter/services.dart' show rootBundle;

class LowIncomeFeaturesScreen extends StatefulWidget {
	const LowIncomeFeaturesScreen({super.key});

	@override
	State<LowIncomeFeaturesScreen> createState() => _LowIncomeFeaturesScreenState();
}

class _LowIncomeFeaturesScreenState extends State<LowIncomeFeaturesScreen> {
	final _budgetCtrl = TextEditingController(text: '5.00');
	late NumberFormat _currency;
	bool _loadingOffers = false;
	bool _loadingResources = false;
	bool _recommending = false;
	List<_AffordableMeal> _meals = [];
	List<_LocalOffer> _offers = [];
	List<_LocalResource> _resources = [];
		Position? _position;
		Set<Marker> _markers = {};

		static const String _mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

	@override
	void initState() {
		super.initState();
		_currency = NumberFormat.simpleCurrency();
		_init();
	}

	Future<void> _init() async {
		await _loadCurrency();
		if (Firebase.apps.isEmpty) {
			try { await Firebase.initializeApp(); } catch (_) {}
		}
		await _loadCachedOffers();
		await _refreshOffers();
		await _loadCachedResources();
		await _refreshResources();
		await _resolveLocation();
		await _loadMapMarkers();
	}

	Future<void> _loadCurrency() async {
		try {
			final code = (await AppSettings().getCurrencyCode()).toUpperCase();
			final fmt = NumberFormat.simpleCurrency(name: code);
			if (mounted) setState(() { _currency = fmt; });
		} catch (_) {
			// fallback to default locale currency
			if (mounted) setState(() { _currency = NumberFormat.simpleCurrency(); });
		}
	}

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
		} catch (_) {/* ignore */}
	}

	Future<void> _refreshOffers() async {
		setState(() { _loadingOffers = true; });
		try {
			if (Firebase.apps.isEmpty) {
				setState(() { _loadingOffers = false; });
				return;
			}
			final p = await PrivacySettingsService().load();
			if (p.offlineMode) {
				// Respect offline mode: rely on cache only
				if (_offers.isEmpty) {
					// fallback to bundled mock
					final list = await _loadOffersFromAssets();
								var sorted = list;
								if (_position != null) {
									sorted = [...list];
									sorted.sort((a, b) => _compareByDistanceOffer(a, b));
									sorted = _filterWithinRadiusOffers(sorted, 50);
								}
								setState(() { _offers = sorted; });
				}
				setState(() { _loadingOffers = false; });
				return;
			}
			final conn = await Connectivity().checkConnectivity();
			if (conn.contains(ConnectivityResult.none)) {
								if (_offers.isEmpty) {
										final list = await _loadOffersFromAssets();
										var sorted = list;
										if (_position != null) {
											sorted = [...list];
											sorted.sort((a, b) => _compareByDistanceOffer(a, b));
											sorted = _filterWithinRadiusOffers(sorted, 50);
										}
										setState(() { _offers = sorted; });
								}
				setState(() { _loadingOffers = false; });
				return;
			}
			// Read global offers (simple schema: /local_offers/global -> List<Map>)
			final snap = await FirebaseDatabase.instance.ref('local_offers/global').get();
			final val = snap.value;
			final list = <_LocalOffer>[];
			if (val is List) {
				for (final item in val) {
					if (item is Map) list.add(_LocalOffer.fromMap(Map<String, dynamic>.from(item)));
				}
			} else if (val is Map) {
				val.forEach((key, item) {
					if (item is Map) list.add(_LocalOffer.fromMap(Map<String, dynamic>.from(item)));
				});
			}
						var sorted = list;
						if (_position != null) {
							sorted = [...list];
							sorted.sort((a, b) => _compareByDistanceOffer(a, b));
							sorted = _filterWithinRadiusOffers(sorted, 50);
						}
						setState(() { _offers = sorted; });
			await _cacheOffers();
		} catch (_) {
			// silently rely on cache or assets
						if (_offers.isEmpty) {
								final list = await _loadOffersFromAssets();
								var sorted = list;
								if (_position != null) {
									sorted = [...list];
									sorted.sort((a, b) => _compareByDistanceOffer(a, b));
									sorted = _filterWithinRadiusOffers(sorted, 50);
								}
								setState(() { _offers = sorted; });
						}
		} finally {
			if (mounted) setState(() { _loadingOffers = false; });
		}
	}

	Future<List<_LocalOffer>> _loadOffersFromAssets() async {
		try {
			final raw = await rootBundle.loadString('assets/data/promotions_mock.json');
			final arr = (jsonDecode(raw) as List).cast<Map>();
			return arr.map((e) => _LocalOffer.fromMap(Map<String, dynamic>.from(e))).toList();
		} catch (_) { return const <_LocalOffer>[]; }
	}

	Future<void> _cacheOffers() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final encoded = jsonEncode(_offers.map((e) => e.toJson()).toList());
			await prefs.setString('cached_offers', encoded);
			await prefs.setInt('cached_offers_ts', DateTime.now().millisecondsSinceEpoch);
		} catch (_) {}
	}

	Future<void> _loadCachedOffers() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final raw = prefs.getString('cached_offers');
			if (raw != null) {
				final list = (jsonDecode(raw) as List).cast<Map>().map((m) => _LocalOffer.fromMap(Map<String, dynamic>.from(m))).toList();
				setState(() { _offers = list; });
			}
		} catch (_) {}
	}

	Future<void> _refreshResources() async {
		setState(() { _loadingResources = true; });
		try {
			final p = await PrivacySettingsService().load();
			if (p.offlineMode) {
				if (_resources.isEmpty) {
					final list = await _loadResourcesFromAssets();
					setState(() { _resources = list; });
				}
				return;
			}
			final conn = await Connectivity().checkConnectivity();
			if (conn.contains(ConnectivityResult.none)) {
				if (_resources.isEmpty) {
					final list = await _loadResourcesFromAssets();
					setState(() { _resources = list; });
				}
				return;
			}
			// Prefer Firestore collection if available
			final col = FirebaseFirestore.instance.collection('assistance_resources');
			final qs = await col.limit(200).get();
			final list = <_LocalResource>[];
			for (final d in qs.docs) {
				list.add(_LocalResource.fromMap(d.data()));
			}
						if (list.isEmpty) {
								final assets = await _loadResourcesFromAssets();
								var sorted = assets;
								if (_position != null) {
									sorted = [...assets];
									sorted.sort((a, b) => _compareByDistanceResource(a, b));
									sorted = _filterWithinRadiusResources(sorted, 50);
								}
								setState(() { _resources = sorted; });
						} else {
								var sorted = list;
								if (_position != null) {
									sorted = [...list];
									sorted.sort((a, b) => _compareByDistanceResource(a, b));
									sorted = _filterWithinRadiusResources(sorted, 50);
								}
								setState(() { _resources = sorted; });
						}
			await _cacheResources();
		} catch (_) {
						if (_resources.isEmpty) {
								final assets = await _loadResourcesFromAssets();
								var sorted = assets;
								if (_position != null) {
									sorted = [...assets];
									sorted.sort((a, b) => _compareByDistanceResource(a, b));
									sorted = _filterWithinRadiusResources(sorted, 50);
								}
								setState(() { _resources = sorted; });
						}
		} finally {
			if (mounted) setState(() { _loadingResources = false; });
		}
	}

	Future<void> _cacheResources() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final encoded = jsonEncode(_resources.map((e) => e.toJson()).toList());
			await prefs.setString('cached_resources', encoded);
			await prefs.setInt('cached_resources_ts', DateTime.now().millisecondsSinceEpoch);
		} catch (_) {}
	}

	Future<void> _loadCachedResources() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final raw = prefs.getString('cached_resources');
			if (raw != null) {
				final list = (jsonDecode(raw) as List).cast<Map>().map((m) => _LocalResource.fromMap(Map<String, dynamic>.from(m))).toList();
				setState(() { _resources = list; });
			}
		} catch (_) {}
	}

	Future<List<_LocalResource>> _loadResourcesFromAssets() async {
		try {
			final raw = await rootBundle.loadString('assets/data/resources_mock.json');
			final arr = (jsonDecode(raw) as List).cast<Map>();
			return arr.map((e) => _LocalResource.fromMap(Map<String, dynamic>.from(e))).toList();
		} catch (_) { return const <_LocalResource>[]; }
	}

	// Simulated AI: given budget, propose 3 affordable, healthy meal options.
	Future<void> _recommendMeals() async {
		final budget = double.tryParse(_budgetCtrl.text) ?? 0;
		if (budget <= 0) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid daily budget.')));
			return;
		}
		setState(() { _recommending = true; });
		await Future.delayed(const Duration(milliseconds: 500));
		final meals = _AffordableMeal.simulateForBudget(budget);
		setState(() { _meals = meals; _recommending = false; });
	}

	Future<void> _saveMeal(_AffordableMeal meal) async {
		try {
			if (Firebase.apps.isEmpty) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud sync unavailable.')));
				}
				return;
			}
			final userId = FirebaseAuth.instance.currentUser?.uid;
			await FirebaseFirestore.instance.collection('lowIncomeMeals').add({
				'title': meal.title,
				'cost': meal.cost,
				'ingredients': meal.ingredients,
				'createdAt': DateTime.now().toIso8601String(),
				'userId': userId,
			});
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal saved.')));
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save meal: $e')));
		}
	}

	void _showShoppingList(_AffordableMeal meal) {
		showDialog(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('Shopping List'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(meal.title, style: const TextStyle(fontWeight: FontWeight.w600)),
						const SizedBox(height: 8),
						for (final ing in meal.ingredients) Text('• $ing'),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
				],
			),
		);
	}

	Future<void> _loadMapMarkers() async {
		// If Maps key present and location known, optionally query Places Text Search for "food bank near me".
		final offline = await (() async { try { return (await PrivacySettingsService().load()).offlineMode; } catch (_) { return false; } })();
		if (!offline && _mapsKey.isNotEmpty && _position != null) {
			try {
				final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
					'query': 'food bank near me',
					'location': '${_position!.latitude},${_position!.longitude}',
					'radius': '5000',
					  'key': _mapsKey,
				});
				final res = await http.get(uri);
				if (res.statusCode == 200) {
					final data = jsonDecode(res.body);
					final results = (data['results'] as List?) ?? [];
					final markers = <Marker>{};
					for (final r in results) {
						final loc = r['geometry']?['location'];
						if (loc != null) {
							final lat = (loc['lat'] as num).toDouble();
							final lng = (loc['lng'] as num).toDouble();
							final name = r['name'] ?? 'Food Bank';
											markers.add(Marker(
												markerId: MarkerId('${lat}_${lng}_$name'),
								position: LatLng(lat, lng),
								infoWindow: InfoWindow(title: name),
							));
						}
					}
					setState(() { _markers = markers; });
				}
			} catch (_) {/* ignore */}
		} else {
			// Fallback: place markers from offers if lat/lng present
			final markers = <Marker>{};
			for (final o in _offers) {
				if (o.lat != null && o.lng != null) {
					markers.add(Marker(
						markerId: MarkerId('offer_${o.name}_${o.lat}_${o.lng}'),
						position: LatLng(o.lat!, o.lng!),
						infoWindow: InfoWindow(title: o.name, snippet: o.offer),
					));
				}
			}
			setState(() { _markers = markers; });
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Affordable Food Finder'),
				backgroundColor: Colors.green,
				foregroundColor: Colors.white,
			),
			body: DefaultTabController(
				length: 4,
				child: Column(
					children: [
						const TabBar(
							tabs: [
								Tab(icon: Icon(Icons.restaurant), text: 'Meals'),
								Tab(icon: Icon(Icons.local_offer), text: 'Offers'),
								Tab(icon: Icon(Icons.map), text: 'Food Banks'),
								Tab(icon: Icon(Icons.handshake), text: 'Resources'),
							],
							labelColor: Colors.green,
							unselectedLabelColor: Colors.black54,
						),
						Expanded(
							child: TabBarView(
								children: [
									_buildMealsTab(),
									_buildOffersTab(),
									_buildMapTab(),
									_buildResourcesTab(),
								],
							),
						),
					],
				),
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: _recommending ? null : _recommendMeals,
				label: Text(_recommending ? 'Recommending…' : 'Recommend Meals'),
				icon: const Icon(Icons.auto_awesome),
				backgroundColor: Colors.green,
			),
		);
	}

	Widget _buildResourcesTab() {
		return RefreshIndicator(
			onRefresh: () async { await _refreshResources(); },
			child: ListView.builder(
				padding: const EdgeInsets.all(16),
				itemCount: _resources.length + 1,
				itemBuilder: (context, index) {
					if (index == 0) {
						return Padding(
							padding: const EdgeInsets.only(bottom: 12.0),
							child: Row(
								children: [
									const Expanded(child: Text('Resources & Assistance', style: TextStyle(fontWeight: FontWeight.w700))),
									if (_loadingResources) const SizedBox(width: 12),
									if (_loadingResources) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
								],
							),
						);
					}
					  final r = _resources[index - 1];
					  final distanceText = _position != null && r.lat != null && r.lng != null
						  ? '${_distanceKm(_position!.latitude, _position!.longitude, r.lat!, r.lng!).toStringAsFixed(1)} km'
						  : null;
					final icon = switch (r.type) {
						'food_bank' => Icons.volunteer_activism,
						'community_garden' => Icons.grass,
						'aid_program' => Icons.support,
						_ => Icons.place,
					};
					return Card(
						child: ListTile(
							leading: Icon(icon),
							title: Text(r.name),
							  subtitle: Text(((r.address ?? '') + (distanceText != null ? '  •  $distanceText' : '')).trim()),
							trailing: r.phone != null ? IconButton(
								icon: const Icon(Icons.call),
								onPressed: () async {
									final uri = Uri.parse('tel:${r.phone}');
									if (await canLaunchUrl(uri)) { await launchUrl(uri); }
								},
							) : null,
							onTap: () async {
								if (r.url != null) {
									final uri = Uri.parse(r.url!);
									if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); return; }
								}
								if (r.lat != null && r.lng != null) {
									final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${r.lat},${r.lng}');
									if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
								}
							},
						),
					);
				},
			),
		);
	}

	Widget _buildMealsTab() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(16),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text('Daily Budget', style: TextStyle(fontWeight: FontWeight.w600)),
					const SizedBox(height: 8),
					LayoutBuilder(
						builder: (context, constraints) {
							// Ensure the row never overflows by reserving space for the button.
							const double buttonWidth = 140; // enough for label and icon
							final double tfWidth = (constraints.maxWidth - buttonWidth - 12).clamp(160, constraints.maxWidth);
							return Row(
								children: [
									SizedBox(
										width: tfWidth,
										child: TextField(
											controller: _budgetCtrl,
											keyboardType: const TextInputType.numberWithOptions(decimal: true),
											decoration: InputDecoration(
												hintText: 'e.g., 5.00',
												border: const OutlineInputBorder(),
												prefixText: '${_currency.currencySymbol} ',
											),
										),
									),
									const SizedBox(width: 12),
									SizedBox(
										width: buttonWidth,
										child: ElevatedButton.icon(
											onPressed: _recommending ? null : _recommendMeals,
											icon: const Icon(Icons.search),
											label: const Text('Find Meals', overflow: TextOverflow.ellipsis),
											style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
										),
									),
								],
							);
						},
					),
					const SizedBox(height: 12),
					if (_meals.isEmpty)
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
							),
							child: const Text('Enter your budget and tap Find Meals to get affordable, healthy suggestions.'),
						),
					for (final meal in _meals) ...[
						Card(
							elevation: 2,
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
							child: Padding(
								padding: const EdgeInsets.all(12),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												Expanded(child: Text(meal.title, style: const TextStyle(fontWeight: FontWeight.w700))),
												Text(_currency.format(meal.cost), style: const TextStyle(color: Colors.black54)),
											],
										),
										const SizedBox(height: 8),
										Text(meal.description),
										const SizedBox(height: 8),
										Wrap(
											spacing: 8,
											runSpacing: 6,
											children: meal.ingredients.map((e) => Chip(label: Text(e))).toList(),
										),
										const SizedBox(height: 8),
										Wrap(
											spacing: 12,
											runSpacing: 8,
											children: [
												OutlinedButton.icon(
													onPressed: () => _saveMeal(meal),
													icon: const Icon(Icons.bookmark_add_outlined),
													label: const Text('Save this meal', overflow: TextOverflow.ellipsis),
												),
												ElevatedButton.icon(
													onPressed: () => _showShoppingList(meal),
													icon: const Icon(Icons.list_alt),
													label: const Text('Get shopping list', overflow: TextOverflow.ellipsis),
												),
											],
										)
									],
								),
							),
						),
						const SizedBox(height: 8),
					],
				],
			),
		);
	}

	Widget _buildOffersTab() {
		return RefreshIndicator(
			onRefresh: () async { await _refreshOffers(); await _loadMapMarkers(); },
			child: ListView.builder(
				padding: const EdgeInsets.all(16),
				itemCount: _offers.length + 1,
				itemBuilder: (context, index) {
					if (index == 0) {
						return Padding(
							padding: const EdgeInsets.only(bottom: 12.0),
							child: Row(
								children: [
									const Expanded(child: Text('Local Markets & Offers', style: TextStyle(fontWeight: FontWeight.w700))),
									if (_loadingOffers) const SizedBox(width: 12),
									if (_loadingOffers) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
								],
							),
						);
					}
								final o = _offers[index - 1];
								final distanceText = _position != null && o.lat != null && o.lng != null
										? '${_distanceKm(_position!.latitude, _position!.longitude, o.lat!, o.lng!).toStringAsFixed(1)} km'
										: null;
								return Card(
						child: ListTile(
							leading: const Icon(Icons.store),
							title: Text(o.name),
										subtitle: Text(o.offer + (distanceText != null ? '  •  $distanceText' : '')),
										trailing: o.price != null ? Text(_currency.format(o.price)) : (distanceText != null ? Text(distanceText) : null),
							onTap: () async {
								if (o.lat != null && o.lng != null) {
									final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${o.lat},${o.lng}');
									if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
								}
							},
						),
					);
				},
			),
		);
	}

	Widget _buildMapTab() {
		if (_position == null && _mapsKey.isEmpty) {
			return Center(
				child: Padding(
					padding: const EdgeInsets.all(16.0),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
							const SizedBox(height: 12),
							const Text('Location or Maps key unavailable.'),
							const SizedBox(height: 8),
							ElevatedButton.icon(
								onPressed: () async {
									const query = 'food bank near me';
									final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
									if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
								},
								icon: const Icon(Icons.open_in_new),
								label: const Text('Open in Google Maps'),
							)
						],
					),
				),
			);
		}

		final center = _position != null ? LatLng(_position!.latitude, _position!.longitude) : const LatLng(37.7749, -122.4194);
		return Stack(
			children: [
				GoogleMap(
					initialCameraPosition: CameraPosition(target: center, zoom: 12),
					myLocationEnabled: true,
					myLocationButtonEnabled: true,
					markers: _markers,
					  onMapCreated: (c) {},
				),
				Positioned(
					right: 12, top: 12,
					child: Card(
						elevation: 2,
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
						child: IconButton(
							icon: const Icon(Icons.refresh),
							onPressed: () async { await _loadMapMarkers(); },
							tooltip: 'Refresh nearby',
						),
					),
				),
			],
		);
	}
}

class _AffordableMeal {
	final String title;
	final String description;
	final double cost;
	final List<String> ingredients;

	_AffordableMeal({required this.title, required this.description, required this.cost, required this.ingredients});

	static List<_AffordableMeal> simulateForBudget(double budget) {
		// Simple tiers based on budget. Prices in USD-equivalent for demo.
		if (budget <= 3) {
			return [
				_AffordableMeal(
					title: 'Bean & Rice Bowl',
					description: 'Black beans, rice, onions, tomatoes. High fiber and protein.',
					cost: 2.2,
					ingredients: ['Rice', 'Black beans', 'Onion', 'Tomato', 'Spices'],
				),
				_AffordableMeal(
					title: 'Veggie Omelette',
					description: 'Eggs with spinach and onions on toast.',
					cost: 2.8,
					ingredients: ['Eggs', 'Spinach', 'Onion', 'Bread slice'],
				),
				_AffordableMeal(
					title: 'Peanut Butter Banana Sandwich',
					description: 'Whole wheat bread with peanut butter and banana.',
					cost: 1.9,
					ingredients: ['Whole wheat bread', 'Peanut butter', 'Banana'],
				),
			];
		} else if (budget <= 6) {
			return [
				_AffordableMeal(
					title: 'Chickpea Curry & Rice',
					description: 'Chickpeas, tomatoes, onions, spices on rice.',
					cost: 3.8,
					ingredients: ['Chickpeas', 'Rice', 'Onion', 'Tomato', 'Curry spices'],
				),
				_AffordableMeal(
					title: 'Tuna Pasta Salad',
					description: 'Pasta with canned tuna, corn, and peas.',
					cost: 4.5,
					ingredients: ['Pasta', 'Canned tuna', 'Corn', 'Peas', 'Light mayo'],
				),
				_AffordableMeal(
					title: 'Chicken & Veggie Stir-fry',
					description: 'Small chicken portion with mixed vegetables and rice.',
					cost: 5.5,
					ingredients: ['Chicken (small)', 'Mixed veggies', 'Rice', 'Soy sauce'],
				),
			];
		} else {
			return [
				_AffordableMeal(
					title: 'Turkey Chili',
					description: 'Lean turkey, beans, tomatoes; hearty and protein-rich.',
					cost: 6.8,
					ingredients: ['Lean turkey', 'Beans', 'Tomato', 'Onion', 'Spices'],
				),
				_AffordableMeal(
					title: 'Salmon & Veg Bowl',
					description: 'Small salmon portion with broccoli and brown rice.',
					cost: 7.4,
					ingredients: ['Salmon (small)', 'Broccoli', 'Brown rice', 'Lemon'],
				),
				_AffordableMeal(
					title: 'Greek Yogurt Parfait',
					description: 'Yogurt with oats, banana, and peanut butter drizzle.',
					cost: 6.2,
					ingredients: ['Greek yogurt', 'Oats', 'Banana', 'Peanut butter'],
				),
			];
		}
	}
}

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

class _LocalResource {
	final String type; // food_bank | community_garden | aid_program
	final String name;
	final String? address;
	final String? phone;
	final String? url;
	final double? lat;
	final double? lng;

	_LocalResource({required this.type, required this.name, this.address, this.phone, this.url, this.lat, this.lng});

	factory _LocalResource.fromMap(Map<String, dynamic> m) {
		return _LocalResource(
			type: (m['type'] ?? 'resource').toString(),
			name: (m['name'] ?? 'Resource').toString(),
			address: (m['address'] as String?)?.toString(),
			phone: (m['phone'] as String?)?.toString(),
			url: (m['url'] as String?)?.toString(),
			lat: (m['lat'] is num) ? (m['lat'] as num).toDouble() : null,
			lng: (m['lng'] is num) ? (m['lng'] as num).toDouble() : null,
		);
	}

	Map<String, dynamic> toJson() => {
		'type': type,
		'name': name,
		'address': address,
		'phone': phone,
		'url': url,
		'lat': lat,
		'lng': lng,
	};
}

// ==== Geo helpers for sorting and filtering ====
extension _GeoHelpers on _LowIncomeFeaturesScreenState {
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

	int _compareByDistanceOffer(_LocalOffer a, _LocalOffer b) {
		if (_position == null) return 0;
		final pa = (a.lat != null && a.lng != null)
				? _distanceKm(_position!.latitude, _position!.longitude, a.lat!, a.lng!)
				: double.infinity;
		final pb = (b.lat != null && b.lng != null)
				? _distanceKm(_position!.latitude, _position!.longitude, b.lat!, b.lng!)
				: double.infinity;
		return pa.compareTo(pb);
	}

	int _compareByDistanceResource(_LocalResource a, _LocalResource b) {
		if (_position == null) return 0;
		final pa = (a.lat != null && a.lng != null)
				? _distanceKm(_position!.latitude, _position!.longitude, a.lat!, a.lng!)
				: double.infinity;
		final pb = (b.lat != null && b.lng != null)
				? _distanceKm(_position!.latitude, _position!.longitude, b.lat!, b.lng!)
				: double.infinity;
		return pa.compareTo(pb);
	}

	List<_LocalOffer> _filterWithinRadiusOffers(List<_LocalOffer> list, double radiusKm) {
		if (_position == null) return list;
		final filtered = list.where((o) {
			if (o.lat == null || o.lng == null) return true; // keep unlocated items
			return _distanceKm(_position!.latitude, _position!.longitude, o.lat!, o.lng!) <= radiusKm;
		}).toList();
		return filtered.isEmpty ? list : filtered;
	}

	List<_LocalResource> _filterWithinRadiusResources(List<_LocalResource> list, double radiusKm) {
		if (_position == null) return list;
		final filtered = list.where((r) {
			if (r.lat == null || r.lng == null) return true;
			return _distanceKm(_position!.latitude, _position!.longitude, r.lat!, r.lng!) <= radiusKm;
		}).toList();
		return filtered.isEmpty ? list : filtered;
	}
}

