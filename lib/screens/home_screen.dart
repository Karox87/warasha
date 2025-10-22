import 'package:flutter/material.dart';
import 'purchases_screen.dart';
import 'sales_screen.dart';
import 'debts_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 1; // ← دەستپێکردن لە تابی فرۆشتن (index 1)
  late PageController _pageController;
  late AnimationController _animationController;

  final List<Widget> _screens = [
    const PurchasesScreen(),
    const SalesScreen(),
    const DebtsScreen(),
    const ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1); // ← کردنەوەی لاپەڕەی فرۆشتن
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _animationController.reset();
          _animationController.forward();
        },
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(25),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFF1976D2),
            unselectedItemColor: const Color.fromARGB(255, 124, 124, 124),
            selectedFontSize: 13,
            unselectedFontSize: 12,
            elevation: 0,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            items: [
              _buildNavItem(
                icon: Icons.shopping_cart_rounded,
                label: 'کڕین',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.shopify_rounded,
                label: 'فرۆشتن',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'قەرز',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.assessment_rounded,
                label: 'ڕاپۆرت',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.all(isSelected ? 8 : 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1976D2).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutBack,
            ),
          ),
          child: Icon(
            icon,
            size: isSelected ? 28 : 24,
          ),
        ),
      ),
      label: label,
    );
  }
}