import 'package:flutter/material.dart';

class NutritionAnalysisScreen extends StatefulWidget {
  const NutritionAnalysisScreen({super.key});

  @override
  State<NutritionAnalysisScreen> createState() =>
      _NutritionAnalysisScreenState();
}

class _NutritionAnalysisScreenState extends State<NutritionAnalysisScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _nutritionData;

  Future<void> _simulateImageAnalysis() async {
    setState(() => _isLoading = true);

    // 🧠 TODO: Replace this simulated delay + mock data
    // with a real API call to your AI nutrition service.
    await Future.delayed(const Duration(seconds: 2));

    // Example mock AI response
    final mockResponse = {
      'food': 'Grilled Chicken with Rice',
      'calories': 420,
      'protein': 35,
      'carbs': 45,
      'fat': 10,
      'micronutrients': {'Iron': '12%', 'Vitamin B6': '30%', 'Vitamin C': '8%'},
    };

    setState(() {
      _nutritionData = mockResponse;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Food Identification'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Image preview placeholder
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 60,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'AI Food Scanner',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Demo Mode - Click to analyze sample food',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Demo analyze button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simulateImageAnalysis,
                icon: const Icon(Icons.analytics),
                label: const Text('Analyze Sample Food'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Loading indicator
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 10),
                  Text('Analyzing image...'),
                ],
              ),

            // Nutrition results
            if (_nutritionData != null && !_isLoading)
              _NutritionResultCard(nutritionData: _nutritionData!),
          ],
        ),
      ),
    );
  }
}

class _NutritionResultCard extends StatelessWidget {
  final Map<String, dynamic> nutritionData;

  const _NutritionResultCard({required this.nutritionData});

  @override
  Widget build(BuildContext context) {
    final micronutrients =
        nutritionData['micronutrients'] as Map<String, dynamic>;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nutritionData['food'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(thickness: 1.5),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientBox(
                'Calories',
                '${nutritionData['calories']} kcal',
              ),
              _buildNutrientBox('Protein', '${nutritionData['protein']} g'),
              _buildNutrientBox('Carbs', '${nutritionData['carbs']} g'),
              _buildNutrientBox('Fat', '${nutritionData['fat']} g'),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Micronutrients:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...micronutrients.entries.map(
            (e) => Text(
              '• ${e.key}: ${e.value}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBox(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}
