import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/models/analytics_model.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registerCompany() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final analyticsService = Provider.of<AnalyticsService>(context, listen: false);
        
        // In a real implementation, you would combine this with the user data
        // from the previous step and register both the user and company
        final success = await authService.registerCompanyAndUser(
          _companyNameController.text.trim(),
          _emailController.text.trim(),
        );

        if (success) {
          // Record registration activity
          await analyticsService.recordActivity(ActivityType.userLoggedIn);
          
          if (mounted) {
            context.go('/');
          }
        } else {
          setState(() {
            _errorMessage = 'Registration failed. Please try again.';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Factory/industrial background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg_image.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Content
          Row(
            children: [
              // Left side (logo and company info)
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.all(50),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Text(
                        "elmo's",
                        style: TextStyle(
                          color: Colors.red[800],
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "F U R N I T U R E",
                        style: TextStyle(
                          fontSize: 24,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Manufacturers of solid wood\nfurniture since 1993.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Visit our Site button
                      ElevatedButton(
                        onPressed: () {
                          // Add your website URL action here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text("Visit our Site"),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Right side (register company form)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 50),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            "Register Company",
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Register Your Company & Take Control of SOP Operations!",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Company Name field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Name :",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: TextFormField(
                                        controller: _companyNameController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter company name',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            borderSide: BorderSide.none,
                                          ),
                                          suffixIcon: const Icon(Icons.business_outlined),
                                          contentPadding: const EdgeInsets.all(20),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter company name';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                
                                // Email field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Email :",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: TextFormField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter company email',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            borderSide: BorderSide.none,
                                          ),
                                          suffixIcon: const Icon(Icons.email_outlined),
                                          contentPadding: const EdgeInsets.all(20),
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter company email';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                
                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                
                                // Next button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _registerCompany,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[800],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Next',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                ),
                                
                                // Add padding at the bottom
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 