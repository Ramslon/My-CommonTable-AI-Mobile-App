import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:commontable_ai_app/core/services/health_sync_service.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';
import 'package:commontable_ai_app/core/services/chat_coach_service.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:commontable_ai_app/core/services/currency_service.dart';

class PremiumFeaturesScreen extends StatefulWidget {
	const PremiumFeaturesScreen({super.key});

	@override
	State<PremiumFeaturesScreen> createState() => _PremiumFeaturesScreenState();
}

class _PremiumFeaturesScreenState extends State<PremiumFeaturesScreen> {
	final _health = HealthSyncService();
	final _insights = NutritionInsightsService();
	final _chat = ChatCoachService();

	Map<String, double> vitals = {}; // e.g., hr_avg, hr_rest
	Map<String, double> activity = {}; // steps, active_min
	Map<String, double> sleep = {}; // sleep_hours, sleep_efficiency
	double? dietScore; // last health score from assessments
	String? wellnessReport;
	bool _generating = false;
  String _currency = 'usd';
  String? _tier; // basic|plus|premium

	// Mini chat
	final List<_Msg> _msgs = [];
	final _controller = TextEditingController();

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		if (Firebase.apps.isEmpty) {
			try { await Firebase.initializeApp(); } catch (_) {}
		}
    _currency = await AppSettings().getCurrencyCode();
    _tier = await AppSettings().getSubscriptionTier();
		await _loadLatestAssessment();
		await _syncWearablesOrSimulate();
	}

  bool get _hasPlus => _tier == 'plus' || _tier == 'premium';

	Future<void> _loadLatestAssessment() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			Query<Map<String, dynamic>> q = FirebaseFirestore.instance
					.collection('dietAssessments')
					.orderBy('createdAt', descending: true)
					.limit(1);
			if (uid != null) q = q.where('userId', isEqualTo: uid);
			final snap = await q.get();
			if (snap.docs.isNotEmpty) {
				final data = snap.docs.first.data();
				final score = (data['healthScore'] as num?)?.toDouble();
				setState(() => dietScore = score);
			}
		} catch (_) {}
	}

	Future<void> _syncWearablesOrSimulate() async {
		try {
			final nutrition = await _health.pullNutrition(); // placeholder; may be empty
			// Simulate wearable metrics if none
			if (nutrition.isEmpty) {
				final rnd = Random();
				vitals = {'hr_avg': 68 + rnd.nextInt(10).toDouble(), 'hr_rest': 60 + rnd.nextInt(6).toDouble()};
				activity = {'steps': 5500 + rnd.nextInt(4000).toDouble(), 'active_min': 32 + rnd.nextInt(30).toDouble()};
				sleep = {'sleep_hours': 6 + rnd.nextDouble() * 2, 'sleep_efficiency': 85 + rnd.nextDouble() * 10};
			} else {
				// Map nutrition map heuristically to activity/vitals if available (demo only)
				activity = {
					'steps': (nutrition['Calories (kcal)'] ?? 2000) * 1.5, // nonsense mapping, placeholder
					'active_min': 30,
				};
				vitals = {'hr_avg': 72, 'hr_rest': 62};
				sleep = {'sleep_hours': 7.2, 'sleep_efficiency': 88};
			}
			if (mounted) setState(() {});
		} catch (_) {}
	}

	Future<void> _generateReport() async {
		setState(() { _generating = true; });
		try {
			final text = await _insights.generateWellnessReport(
				vitals: vitals,
				activity: activity,
				sleep: sleep,
				dietHealthScore: dietScore,
			);
			setState(() { wellnessReport = text; });
		} catch (e) {
			setState(() { wellnessReport = 'Could not generate report: $e'; });
		} finally {
			if (mounted) setState(() { _generating = false; });
		}
	}

	Future<void> _saveSubscription(String tier) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required to save subscription.')));
			return;
		}
		try {
			await FirebaseFirestore.instance.collection('subscriptions').doc(uid).set({
				'tier': tier,
				'updatedAt': DateTime.now().toIso8601String(),
			}, SetOptions(merge: true));
			await AppSettings().setSubscriptionTier(tier);
			if (mounted) setState(() => _tier = tier);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subscription set to $tier.')));
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
		}
	}

	void _requirePlus(VoidCallback action) {
		if (_hasPlus) {
			action();
			return;
		}
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Upgrade to Plus'),
				content: const Text('This feature is available on Plus and Premium plans.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
					TextButton(
						onPressed: () {
							Navigator.pop(ctx);
							// Scroll to subscription section if in view; for now, just show a hint
							ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scroll to Subscription to upgrade.')));
						},
						child: const Text('View plans'),
					),
				],
			),
		);
	}

	Future<void> _askWithReportContext() async {
		final ctx = _contextString();
		await _sendChat('Considering my data: $ctx\nWhat should I focus on next?');
	}

	String _contextString() {
		String f(Map<String, double> m) => m.entries.map((e) => '${e.key}=${e.value.toStringAsFixed(0)}').join(', ');
		return 'vitals(${f(vitals)}), activity(${f(activity)}), sleep(${f(sleep)}), dietScore=${dietScore?.toStringAsFixed(0) ?? 'n/a'}';
	}

	Future<void> _sendChat(String text) async {
		final trimmed = text.trim();
		if (trimmed.isEmpty) return;
		setState(() => _msgs.add(_Msg(trimmed, true)));
		try {
			final turns = _msgs.map((m) => ChatTurn(role: m.isUser ? 'user' : 'assistant', content: m.text)).toList();
			final reply = await _chat.reply(history: turns);
			setState(() => _msgs.add(_Msg(reply.text, false)));
		} catch (e) {
			setState(() => _msgs.add(_Msg('Sorry, I cannot respond right now. ($e)', false)));
		}
	}

	@override
	Widget build(BuildContext context) {
		final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
		final platformLabel = isIOS ? 'Apple HealthKit' : 'Google Fit';

		return Scaffold(
			appBar: AppBar(
				title: const Text('Premium Wellness'),
				backgroundColor: Colors.green,
				foregroundColor: Colors.white,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						// Connected devices
						const Text('Connected Health Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						Wrap(
							spacing: 8,
							children: [
								Chip(avatar: const Icon(Icons.watch), label: Text(platformLabel)),
								const Chip(avatar: Icon(Icons.favorite), label: Text('Blood Pressure (optional)')),
								],
							),
						const SizedBox(height: 16),

						// Wearable metrics quick view
						_MetricsGrid(vitals: vitals, activity: activity, sleep: sleep),

						const SizedBox(height: 16),
						// Wellness report
												Wrap(
													spacing: 12,
													runSpacing: 8,
													children: [
														ElevatedButton.icon(
															onPressed: _generating
																? null
																: () => _requirePlus(_generateReport),
															icon: const Icon(Icons.auto_awesome),
															label: Text(_generating ? 'Generating…' : 'Generate AI Wellness Report'),
															style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
														),
														if (dietScore != null)
															Chip(
																label: Text('Diet Score: ${dietScore!.toStringAsFixed(0)}'),
																avatar: const Icon(Icons.health_and_safety, color: Colors.green),
															),
													],
												),
						if (wellnessReport != null) ...[
							const SizedBox(height: 12),
							Card(
								elevation: 2,
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Text(wellnessReport!),
								),
							),
						],

						const SizedBox(height: 20),
						const Text('Premium Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						_benefitTile(Icons.support_agent, '1:1 Coaching', 'Personal guidance, check-ins, and tailored nudges.'),
						_benefitTile(Icons.delivery_dining, 'Healthy Meal Delivery', 'Curated options that match your plan.'),
						_benefitTile(Icons.biotech, 'Genetic Insights', 'Optional DNA-based nutrition insights.'),

						const SizedBox(height: 20),
						const Text('Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						_Tiers(onSelect: _saveSubscription, currencyCode: _currency),
									Align(
										alignment: Alignment.centerLeft,
										child: TextButton.icon(
											onPressed: () => Navigator.pushNamed(context, '/billing'),
											icon: const Icon(Icons.credit_card),
											label: const Text('Manage Billing'),
										),
									),

						const SizedBox(height: 20),
						const Text('AI Nutritionist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
												Wrap(
													spacing: 12,
													runSpacing: 8,
													children: [
														ElevatedButton.icon(
															onPressed: () => _requirePlus(_askWithReportContext),
															icon: const Icon(Icons.question_answer),
															label: const Text('Ask with report context'),
														),
														TextButton(
															onPressed: () {
																final ctx = _contextString();
																_controller.text = 'Considering my data: $ctx';
															},
															child: const Text('Insert context'),
														),
													],
												),
						Container(
							decoration: BoxDecoration(color: Colors.teal.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
							padding: const EdgeInsets.all(8),
							child: Column(
								children: [
									SizedBox(
										height: 150,
										child: ListView.builder(
											reverse: true,
											itemCount: _msgs.length,
											itemBuilder: (context, i) {
												final m = _msgs[_msgs.length - 1 - i];
												final align = m.isUser ? Alignment.centerRight : Alignment.centerLeft;
												final bg = m.isUser ? Colors.green.withOpacity(0.18) : Colors.teal.withOpacity(0.10);
												return Align(
													alignment: align,
													child: Container(
														margin: const EdgeInsets.symmetric(vertical: 4),
														padding: const EdgeInsets.all(10),
														decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
														child: Text(m.text),
													),
												);
											},
										),
									),
									Row(
										children: [
											Expanded(
												child: TextField(
													controller: _controller,
													decoration: const InputDecoration(hintText: 'Ask the nutritionist…'),
													onSubmitted: _sendChat,
												),
											),
											IconButton(onPressed: () => _sendChat(_controller.text), icon: const Icon(Icons.send, color: Colors.green)),
										],
									)
								],
							),
						),
					],
				),
			),
		);
	}
}

class _Msg {
	final String text;
	final bool isUser;
	_Msg(this.text, this.isUser);
}

class _MetricsGrid extends StatelessWidget {
	final Map<String, double> vitals;
	final Map<String, double> activity;
	final Map<String, double> sleep;
	const _MetricsGrid({required this.vitals, required this.activity, required this.sleep});

	@override
	Widget build(BuildContext context) {
		String v(double? x, {String? unit}) => x == null ? '—' : unit == null ? x.toStringAsFixed(0) : '${x.toStringAsFixed(0)}$unit';
		return Card(
			elevation: 2,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					children: [
						Row(
							children: const [
								Text('Today\'s Metrics', style: TextStyle(fontWeight: FontWeight.w700)),
							],
						),
						const SizedBox(height: 8),
						Row(
							children: [
								Expanded(child: _MetricTile(title: 'HR Avg', value: v(vitals['hr_avg']))),
								const SizedBox(width: 8),
								Expanded(child: _MetricTile(title: 'HR Rest', value: v(vitals['hr_rest']))),
							],
						),
						const SizedBox(height: 8),
						Row(
							children: [
								Expanded(child: _MetricTile(title: 'Steps', value: v(activity['steps']))),
								const SizedBox(width: 8),
								Expanded(child: _MetricTile(title: 'Active Min', value: v(activity['active_min']))),
							],
						),
						const SizedBox(height: 8),
						Row(
							children: [
								Expanded(child: _MetricTile(title: 'Sleep (h)', value: v(sleep['sleep_hours']))),
								const SizedBox(width: 8),
								Expanded(child: _MetricTile(title: 'Sleep Eff%', value: v(sleep['sleep_efficiency']))),
							],
						),
					],
				),
			),
		);
	}
}

class _MetricTile extends StatelessWidget {
	final String title;
	final String value;
	const _MetricTile({required this.title, required this.value});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: Colors.grey.shade100,
				borderRadius: BorderRadius.circular(12),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(title, style: const TextStyle(color: Colors.black54)),
					const SizedBox(height: 6),
					Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
				],
			),
		);
	}
}

Widget _benefitTile(IconData icon, String title, String subtitle) {
	return Card(
		child: ListTile(
			leading: Icon(icon, color: Colors.green),
			title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
			subtitle: Text(subtitle),
			trailing: const Icon(Icons.check_circle, color: Colors.green),
		),
	);
}

class _Tiers extends StatelessWidget {
	final void Function(String tier) onSelect;
	final String currencyCode;
	const _Tiers({required this.onSelect, required this.currencyCode});

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				_tierTile('Basic', 'Core insights and tracking', 0, onSelect),
				_tierTile('Plus', 'AI insights + progress dashboards', 4.99, onSelect),
				_tierTile('Premium', 'Coaching, delivery, and genetic insights', 14.99, onSelect),
			],
		);
	}

	Widget _tierTile(String name, String desc, double price, void Function(String) onSelect) {
		final priceStr = price == 0
			? 'Free'
			: '${CurrencyService.format(price, currencyCode)}/mo';
		return Card(
			child: ListTile(
				leading: const Icon(Icons.star, color: Colors.amber),
				title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
				subtitle: Text(desc),
				trailing: TextButton(
					onPressed: () => onSelect(name.toLowerCase()),
					child: Text(price == 0 ? 'Choose' : 'Subscribe ($priceStr)'),
				),
			),
		);
	}
}

