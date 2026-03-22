import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      accentColor: AppColors.pastelBlue,
      accentDark: AppColors.pastelBlueDark,
      icon: Icons.how_to_vote_rounded,
      title: 'Make decisions\ntogether',
      subtitle:
          'Create polls in seconds. Your team votes, you get instant results — no more WhatsApp chaos.',
      tag: 'Decision Polls',
    ),
    _OnboardingData(
      accentColor: AppColors.mint,
      accentDark: AppColors.mintDark,
      icon: Icons.schedule_rounded,
      title: 'Track attendance\neffortlessly',
      subtitle:
          'Staff clock in with a tap. See who\'s working, for how long, every single day — all in real time.',
      tag: 'Attendance Tracking',
    ),
    _OnboardingData(
      accentColor: AppColors.lavender,
      accentDark: AppColors.lavenderDark,
      icon: Icons.insights_rounded,
      title: 'Run your team\nwith data',
      subtitle:
          'Weekly hours, update streaks, poll participation — everything you need for fair, confident decisions.',
      tag: 'Insights Hub',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDots(),
                  if (_currentPage < _pages.length - 1)
                    GestureDetector(
                      onTap: _goToLogin,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) =>
                    _OnboardingPage(data: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].accentDark,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      children: List.generate(
        _pages.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 6),
          width: _currentPage == i ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == i
                ? _pages[_currentPage].accentDark
                : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: data.accentColor,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: Icon(
                  data.icon,
                  size: 80,
                  color: data.accentDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: data.accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.tag,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: data.accentDark,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.title,
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final Color accentColor;
  final Color accentDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;

  const _OnboardingData({
    required this.accentColor,
    required this.accentDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
  });
}