import 'package:flutter/material.dart';

class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Progress Dashboard"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Overview stats
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    title: 'Calories',
                    value: '1,920 kcal',
                    color: Colors.orange,
                    icon: Icons.local_fire_department,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Protein',
                    value: '95 g',
                    color: Colors.green,
                    icon: Icons.fitness_center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    title: 'Carbs',
                    value: '210 g',
                    color: Colors.blue,
                    icon: Icons.bakery_dining,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Fats',
                    value: '58 g',
                    color: Colors.purple,
                    icon: Icons.opacity,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 🔹 Daily intake ring
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    _RingProgress(
                      label: 'Daily Intake',
                      valueLabel: '1,920 / 2,400',
                      value: 0.80,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Today\'s Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          _MacroRow(label: 'Protein', percent: 0.40, color: Colors.green),
                          SizedBox(height: 8),
                          _MacroRow(label: 'Carbs', percent: 0.35, color: Colors.blue),
                          SizedBox(height: 8),
                          _MacroRow(label: 'Fats', percent: 0.25, color: Colors.purple),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Text(
              "Your Weekly Nutrition Summary",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 📊 Calories (simple bar display)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Calorie Intake (kcal)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _SimpleBarChart(
                      labels: const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
                      values: const [1800, 2000, 1750, 2200, 1900, 2500, 2100],
                      maxValue: 2600,
                      barColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🥗 Macronutrient Breakdown (simple progress rows)
            const Text(
              "Macronutrient Breakdown",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: const [
                    _MacroRow(label: 'Protein', percent: 0.40, color: Colors.green),
                    SizedBox(height: 10),
                    _MacroRow(label: 'Carbs', percent: 0.35, color: Colors.orange),
                    SizedBox(height: 10),
                    _MacroRow(label: 'Fats', percent: 0.25, color: Colors.redAccent),
                    SizedBox(height: 12),
                    Text("Balanced macros for your goals", style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 💪 Daily Goals Summary
            const Text(
              "Daily Goal Progress",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _goalTile("Water Intake", "2.3L / 3L", 0.76, Colors.blue),
            _goalTile("Protein Target", "95g / 120g", 0.79, Colors.green),
            _goalTile("Calories Burned", "450 / 600 kcal", 0.75, Colors.orange),

            const SizedBox(height: 24),

            // 🔹 Trends (simple line chart)
            const Text(
              "2-Week Trend",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  height: 160,
                  child: _SimpleLineChart(
                    points: [
                      1800, 1950, 2100, 2000, 2200, 2350, 2100,
                      2050, 2150, 2250, 2400, 2300, 2200, 2100,
                    ],
                    maxValue: 2500,
                    lineColor: Colors.green,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalTile(String title, String value, double progress, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              color: color,
              backgroundColor: Colors.grey.shade300,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

// Simple bar chart using Rows and Containers
class _SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final int maxValue;
  final Color barColor;

  const _SimpleBarChart({
    required this.labels,
    required this.values,
    required this.maxValue,
    this.barColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < values.length; i++)
              _Bar(
                heightFactor: values[i] / maxValue,
                label: labels[i],
                color: barColor,
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double heightFactor;
  final String label;
  final Color color;

  const _Bar({
    required this.heightFactor,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 18,
          height: 160 * heightFactor.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text("${(percent * 100).round()}%", style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  const _RingProgress({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                color: color,
                backgroundColor: Colors.grey.shade300,
              ),
            ),
            Text("${(value * 100).round()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(valueLabel, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _SimpleLineChart extends StatelessWidget {
  final List<int> points;
  final int maxValue;
  final Color lineColor;

  const _SimpleLineChart({
    required this.points,
    required this.maxValue,
    this.lineColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points: points, maxValue: maxValue, color: lineColor),
      size: Size.infinite,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> points;
  final int maxValue;
  final Color color;

  _LineChartPainter({required this.points, required this.maxValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double dxStep = size.width / (points.length - 1);

    double x = 0;
    double y = size.height - (points.first / maxValue) * size.height;
    path.moveTo(x, y);

    for (int i = 1; i < points.length; i++) {
      x = dxStep * i;
      y = size.height - (points[i] / maxValue) * size.height;
      path.lineTo(x, y);
    }

    // Draw axes baseline (optional subtle)
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
