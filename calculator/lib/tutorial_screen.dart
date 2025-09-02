// tutorial_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tutorialPages = [
    {
      'title': 'Welcome to CalcNote',
      'description': 'Your powerful calculator with note-taking capabilities.',
      'icon': Icons.calculate,
    },
    {
      'title': 'Basic Calculations',
      'description': 'Type expressions like 2+2 or 15*3 and see results instantly.',
      'icon': Icons.add,
    },
    {
      'title': 'Line References',
      'description': 'Reference previous results using \$1, \$2, etc. Example: \$1 + 5',
      'icon': Icons.link,
    },
    {
      'title': 'Voice Input',
      'description': 'Tap the mic icon to enter expressions using your voice.',
      'icon': Icons.mic,
    },
    {
      'title': 'History & Favorites',
      'description': 'Access your calculation history and save favorite expressions.',
      'icon': Icons.history,
    },
    {
      'title': 'Advanced Features',
      'description': 'Use the graphing calculator, unit converter, and templates.',
      'icon': Icons.star,
    },
  ];

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorialCompleted', true);

    if (mounted) {
      Navigator.pop(context); // Close tutorial
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial'),
        actions: [
          if (_currentPage < _tutorialPages.length - 1)
            TextButton(
              onPressed: () => _pageController.animateToPage(
                _tutorialPages.length - 1,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              ),
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tutorialPages.length,
              onPageChanged: (int page) {
                setState(() => _currentPage = page);
              },
              itemBuilder: (context, index) {
                final page = _tutorialPages[index];
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(page['icon'], size: 80, color: Theme.of(context).primaryColor),
                      const SizedBox(height: 32),
                      Text(
                        page['title'],
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page['description'],
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentPage > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          )
                      : null,
                  child: const Text('Back'),
                ),
                Row(
                  children: List.generate(
                    _tutorialPages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _currentPage < _tutorialPages.length - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          )
                      : _completeTutorial,
                  child: Text(
                    _currentPage < _tutorialPages.length - 1 ? 'Next' : 'Get Started',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
