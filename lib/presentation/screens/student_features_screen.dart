import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

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

	late List<MealSuggestion> _allSuggestions;
	late List<MealSuggestion> _mentalHealth; // curated list: mood-boosting, stress-reducing
	List<MealSuggestion> _generated = [];
	final Set<String> _selected = {};

	@override
	void initState() {
		super.initState();
		_allSuggestions = _buildSuggestionCatalog(_region);
		_mentalHealth = _buildMentalHealthSuggestions(_region);
	}

	@override
	void dispose() {
		_budgetCtrl.dispose();
		super.dispose();
	}

	Future<void> _generate() async {
		FocusScope.of(context).unfocus();
		final budgetPerDay = double.tryParse(_budgetCtrl.text.trim()) ?? 3000.0;
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

		// Keep meals that fit target per meal with a small tolerance
		pool.sort((a, b) => a.totalCost.compareTo(b.totalCost));
		final withinBudget = pool.where((m) => m.totalCost <= targetPerMeal * 1.1).toList();
		// If too few, relax constraint slightly
		final candidates = withinBudget.isNotEmpty ? withinBudget : pool.where((m) => m.totalCost <= targetPerMeal * 1.35).toList();

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
						if (_loading) const Center(child: CircularProgressIndicator()),
						if (!_loading && _generated.isNotEmpty) _buildResults(),
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
						Row(
							children: [
								Expanded(
									child: TextFormField(
										controller: _budgetCtrl,
										keyboardType: TextInputType.number,
										decoration: const InputDecoration(
											labelText: 'Budget per day (approx.)',
											helperText: 'Enter a number in your local currency',
										),
									),
								),
								const SizedBox(width: 12),
								Expanded(
									child: DropdownButtonFormField<int>(
										initialValue: _mealsPerDay,
										items: const [
											DropdownMenuItem(value: 2, child: Text('2 meals / day')),
											DropdownMenuItem(value: 3, child: Text('3 meals / day')),
											DropdownMenuItem(value: 4, child: Text('4 meals / day')),
										],
										onChanged: (v) => setState(() => _mealsPerDay = v ?? _mealsPerDay),
										decoration: const InputDecoration(labelText: 'Meals per day'),
									),
								),
							],
						),
						const SizedBox(height: 12),
						Row(
							children: [
								Expanded(
									child: DropdownButtonFormField<String>(
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
									),
								),
							],
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
			final firestore = FirebaseFirestore.instance;

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
											Row(
												children: [
													Chip(
														label: Text('${suggestion.kcal} kcal'),
														backgroundColor: Colors.teal.withValues(alpha: 0.12),
														side: BorderSide.none,
													),
													const SizedBox(width: 8),
													if (suggestion.vegetarian)
														const Chip(label: Text('Vegetarian'), side: BorderSide.none),
													const SizedBox(width: 8),
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

