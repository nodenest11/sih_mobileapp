import 'package:flutter/material.dart';
import '../models/tourist.dart';
import '../widgets/modern_sidebar.dart';
import '../screens/home_screen.dart';

class ModernAppWrapper extends StatefulWidget {
  final Tourist tourist;
  final Widget? initialScreen;

  const ModernAppWrapper({
    super.key,
    required this.tourist,
    this.initialScreen,
  });

  @override
  State<ModernAppWrapper> createState() => _ModernAppWrapperState();
}

class _ModernAppWrapperState extends State<ModernAppWrapper>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Widget _currentScreen;
  late AnimationController _drawerAnimationController;
  late Animation<double> _drawerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _currentScreen = widget.initialScreen ?? HomeScreen(tourist: widget.tourist);
    
    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _drawerSlideAnimation = CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _drawerAnimationController.dispose();
    super.dispose();
  }

  void _navigateToScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
    _drawerAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: ModernSidebar(
        tourist: widget.tourist,
        onNavigate: _navigateToScreen,
      ),
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          _drawerAnimationController.forward();
        } else {
          _drawerAnimationController.reverse();
        }
      },
      body: Stack(
        children: [
          // Main content
          _currentScreen,
          
          // Modern floating menu button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: _buildFloatingMenuButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingMenuButton() {
    return AnimatedBuilder(
      animation: _drawerSlideAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (_drawerSlideAnimation.value * 0.1),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _openDrawer,
                child: Center(
                  child: AnimatedRotation(
                    turns: _drawerSlideAnimation.value * 0.125,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.menu_rounded,
                      color: const Color(0xFF2D3748),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}