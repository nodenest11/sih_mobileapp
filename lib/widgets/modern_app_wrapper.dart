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

class _ModernAppWrapperState extends State<ModernAppWrapper> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Widget _currentScreen;
  // Keep track of created screens to avoid recreating them
  final Map<Type, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();
    _currentScreen = widget.initialScreen ?? HomeScreen(tourist: widget.tourist);
    _screenCache[_currentScreen.runtimeType] = _currentScreen;
  }

  void _navigateToScreen(Widget screen) {
    // Cache the screen to avoid recreating it
    final screenType = screen.runtimeType;
    if (!_screenCache.containsKey(screenType)) {
      _screenCache[screenType] = screen;
    }
    
    setState(() {
      _currentScreen = _screenCache[screenType]!;
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _navigateToHome() {
    setState(() {
      _currentScreen = _screenCache[HomeScreen] ?? HomeScreen(tourist: widget.tourist);
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isHomeScreen = _currentScreen is HomeScreen;
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: ModernSidebar(
        tourist: widget.tourist,
        onNavigate: _navigateToScreen,
      ),
      body: isHomeScreen
          ? HomeScreen(
              tourist: widget.tourist,
              onMenuTap: _openDrawer,
            )
          : _currentScreen,
    );
  }
}
