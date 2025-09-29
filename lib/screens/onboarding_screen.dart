import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Tourist Safety',
      description: 'Your personal safety companion for exploring new places with confidence and peace of mind.',
      icon: Icons.security_outlined,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Live Location Tracking',
      description: 'Stay connected with real-time location sharing and automatic safety updates for your loved ones.',
      icon: Icons.location_on_outlined,
      color: Colors.green,
    ),
    OnboardingPage(
      title: 'Safety Dashboard',
      description: 'Monitor your safety score, view restricted areas, and get personalized safety recommendations.',
      icon: Icons.dashboard_outlined,
      color: Colors.orange,
    ),
    OnboardingPage(
      title: 'Emergency Features',
      description: 'Quick access to panic button, emergency contacts, and instant alert system for critical situations.',
      icon: Icons.emergency_outlined,
      color: Colors.red,
    ),
    OnboardingPage(
      title: 'Trip Management',
      description: 'Plan and track your trips, maintain location history, and manage your travel itineraries.',
      icon: Icons.trip_origin_outlined,
      color: Colors.purple,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
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
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? AppColors.redPrimary 
                          : AppColors.greyLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: Text(
                        'Previous',
                        style: TextStyle(
                          color: AppColors.greyText,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                  
                  // Next/Get Started button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.redPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: 48),
          
          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.greyText,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Feature highlights based on page
          if (_currentPage == 1) _buildLocationFeatures(),
          if (_currentPage == 2) _buildSafetyFeatures(),
          if (_currentPage == 3) _buildEmergencyFeatures(),
          if (_currentPage == 4) _buildTripFeatures(),
        ],
      ),
    );
  }

  Widget _buildLocationFeatures() {
    return Column(
      children: [
        _buildFeatureItem(Icons.my_location, 'Real-time GPS tracking'),
        _buildFeatureItem(Icons.share_location, 'Location sharing'),
        _buildFeatureItem(Icons.history, 'Location history'),
      ],
    );
  }

  Widget _buildSafetyFeatures() {
    return Column(
      children: [
        _buildFeatureItem(Icons.score, 'Safety score monitoring'),
        _buildFeatureItem(Icons.warning, 'Risk area alerts'),
        _buildFeatureItem(Icons.lightbulb, 'Safety recommendations'),
      ],
    );
  }

  Widget _buildEmergencyFeatures() {
    return Column(
      children: [
        _buildFeatureItem(Icons.emergency, 'One-tap panic button'),
        _buildFeatureItem(Icons.contacts, 'Emergency contacts'),
        _buildFeatureItem(Icons.notification_important, 'Instant alerts'),
      ],
    );
  }

  Widget _buildTripFeatures() {
    return Column(
      children: [
        _buildFeatureItem(Icons.trip_origin, 'Trip planning'),
        _buildFeatureItem(Icons.route, 'Route tracking'),
        _buildFeatureItem(Icons.history, 'Trip history'),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.redPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}