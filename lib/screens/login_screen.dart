import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/tourist.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    final touristId = prefs.getString('tourist_id');
    final name = prefs.getString('tourist_name');
    
    if (touristId != null && name != null) {
      // User already logged in, navigate to home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              tourist: Tourist(
                id: touristId,
                name: name,
                email: prefs.getString('tourist_email'),
                phone: prefs.getString('tourist_phone'),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.registerTourist(
        name: _nameController.text.trim(),
        contact: _phoneController.text.trim(),
        emergencyContact: _phoneController.text.trim(), // Using same phone as emergency for now
        tripInfo: null, // No default trip info - let backend handle
      );

      if (response['success'] == true) {
        final touristData = response['tourist'];
        
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tourist_id', touristData['id'].toString());
        await prefs.setString('tourist_name', _nameController.text.trim());
        await prefs.setString('tourist_phone', _phoneController.text.trim());
        if (_emailController.text.trim().isNotEmpty) {
          await prefs.setString('tourist_email', _emailController.text.trim());
        }

        // Create tourist object
        final tourist = Tourist(
          id: touristData['id'].toString(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          phone: _phoneController.text.trim(),
          registrationDate: DateTime.now(),
        );

        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(tourist: tourist),
            ),
          );
        }
      } else {
        _showErrorDialog(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showErrorDialog('Registration failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2196F3),
              Color(0xFF21CBF3),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 60,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title
                  const Text(
                    'Tourist Safety',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your safety companion for travel',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Welcome Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome! Let\'s get you started 👋',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your safety profile to start tracking your location and ensure help is always available.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Form instructions
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fill in your details below',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Form within the welcome card
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Full Name *',
                              hintText: 'Enter your full name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '👤 Please enter your full name';
                              }
                              if (value.trim().length < 2) {
                                return '👤 Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Phone Field
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: '9876543210',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              prefixText: '+91 ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              helperText: 'This will be used for emergency contact',
                              helperStyle: TextStyle(color: Colors.grey[600]),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '📱 Phone number is required for safety';
                              }
                              if (value.trim().length != 10) {
                                return '📱 Please enter a valid 10-digit phone number';
                              }
                              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value.trim())) {
                                return '📱 Please enter a valid Indian mobile number';
                              }
                              return null;
                            },
                          ),

                          // Email Field (Optional)
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (Optional)',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'Please enter a valid email';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone Field (Optional)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number (Optional)',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (value.trim().length < 10) {
                                  return 'Please enter a valid phone number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // Register Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Register & Continue',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}