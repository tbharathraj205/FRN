import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // --- KEEPING ALL ORIGINAL LOGIC & CONTROLLERS ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String _error = '';

  final List<String> _specializations = [
    'General Physician',
    'Cardiologist',
    'Emergency Medicine',
    'Surgeon',
    'Neurologist',
    'First Aid Volunteer',
    'Paramedic',
    'Other',
  ];
  String _selectedSpecialization = 'General Physician';

  Future<void> _signup() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _licenseController.text.isEmpty) {
      setState(() {
        _error = 'Please fill all required fields';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('doctors').doc(credential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialization': _selectedSpecialization,
        'license_number': _licenseController.text.trim(),
        'is_approved': false,
        'is_on_duty': false,
        'current_lat': 13.0827,
        'current_lng': 80.2707,
        'fcm_token': '',
        'current_incident': null,
        'photo_url':
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nameController.text.trim())}&background=DC2626&color=fff',
        'created_at': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _error = 'Email already registered';
        } else if (e.code == 'weak-password') {
          _error = 'Password must be at least 6 characters';
        } else {
          _error = 'Registration failed. Try again.';
        }
      });
    }
    setState(() {
      _loading = false;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Application Sent', textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          'Your medical credentials have been submitted for verification. Please wait for admin approval.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Return to Login'),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI LAYER REWRITE ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFEF4444)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
              ),
              const SizedBox(height: 20),
              const Text(
                'Join our Network',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'Register as a First Responder Doctor',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_pin_rounded, "Personal Information"),
          _textField(_nameController, 'Full Name', Icons.person_outline),
          const SizedBox(height: 16),
          _textField(_emailController, 'Email Address', Icons.alternate_email_rounded,
              type: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _textField(_phoneController, 'Phone Number', Icons.phone_iphone_rounded,
              type: TextInputType.phone),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: Color(0xFFF1F5F9), thickness: 2),
          ),
          
          _sectionHeader(Icons.medical_services_rounded, "Professional Details"),
          _buildSpecializationDropdown(),
          const SizedBox(height: 16),
          _textField(_licenseController, 'Medical License Number', Icons.badge_outlined),
          const SizedBox(height: 16),
          _buildPasswordField(),
          
          if (_error.isNotEmpty) _buildErrorSnippet(),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("  Primary Specialization", 
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSpecialization,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _specializations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedSpecialization = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_open_rounded),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildErrorSnippet() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _loading ? null : _signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B), // Dark Navy for contrast
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.black45,
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('SUBMIT FOR VERIFICATION',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        floatingLabelStyle: const TextStyle(color: Color(0xFFDC2626)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}