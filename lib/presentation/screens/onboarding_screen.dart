import 'package:flutter/material.dart';
import 'package:commontable_ai_app/routes/app_route.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Welcome to Commontable AI 🍽️',
      description:
          'Your AI-powered nutrition companion. Snap a meal photo and instantly get calorie and nutrient insights.',
      imagePath: 'assets/images/food_scan.png',
    ),
    _OnboardingPage(
      title: 'Personalized Meal Plans 🥗',
      description:
          'Get meal suggestions tailored to your health goals, preferences, and budget.',
      imagePath: 'assets/images/meal_plan.png',
    ),
    _OnboardingPage(
      title: 'AI Nutrition Coach 🤖',
      description:
          'Chat with our smart coach for personalized tips, motivation, and guidance on healthy eating habits.',
      imagePath: 'assets/images/chatbot.png',
    ),
    _OnboardingPage(
      title: 'Track Progress 📈',
      description:
          'Visualize your nutrition journey, monitor your progress, and achieve your health goals.',
      imagePath: 'assets/images/progress.png',
    ),
  ];

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _OnboardingCard(page: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 20 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.green : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                onPressed: _nextPage,
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String description;
  final String imagePath;

  _OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class _OnboardingCard extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingCard({required this.page});

  IconData _getIconForPage(String title) {
    if (title.contains('Welcome')) return Icons.restaurant;
    if (title.contains('Meal Plans')) return Icons.restaurant_menu;
    if (title.contains('AI Nutrition')) return Icons.chat_bubble_outline;
    if (title.contains('Track Progress')) return Icons.show_chart;
    return Icons.food_bank;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Icon(
              _getIconForPage(page.title),
              size: 120,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
