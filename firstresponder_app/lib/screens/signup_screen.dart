import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
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
      setState(() { _error = 'Please fill all required fields'; });
      return;
    }

    setState(() { _loading = true; _error = ''; });

    try {
      // Create auth account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Save doctor profile to Firestore
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(credential.user!.uid)
          .set({
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
        'photo_url': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nameController.text.trim())}&background=DC2626&color=fff',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Sign out — wait for admin approval
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text('Registration Submitted'),
                ),
              ],
            ),
            content: const Text(
              'Your account has been submitted for verification. '
              'You will be able to login once an admin approves your account.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK',
                  style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
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
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // Red Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_ios,
                            color: Colors.white70, size: 16),
                          Text('Back',
                            style: TextStyle(
                              color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      )),
                    const SizedBox(height: 4),
                    const Text('Register as a First Responder doctor',
                      style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFED7AA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                            color: Color(0xFFD97706), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your account will be verified by admin before activation.',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 12,
                              )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    _fieldLabel('Full Name *'),
                    _textField(_nameController, 'Dr. John Smith',
                      Icons.person_outline),
                    const SizedBox(height: 16),

                    // Email
                    _fieldLabel('Email *'),
                    _textField(_emailController, 'doctor@example.com',
                      Icons.email_outlined,
                      type: TextInputType.emailAddress),
                    const SizedBox(height: 16),

                    // Phone
                    _fieldLabel('Phone Number *'),
                    _textField(_phoneController, '+91 9999999999',
                      Icons.phone_outlined,
                      type: TextInputType.phone),
                    const SizedBox(height: 16),

                    // Specialization
                    _fieldLabel('Specialization *'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSpecialization,
                          isExpanded: true,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A), fontSize: 14),
                          items: _specializations.map((s) =>
                            DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            )).toList(),
                          onChanged: (val) => setState(() {
                            _selectedSpecialization = val!;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // License Number
                    _fieldLabel('Medical License Number *'),
                    _textField(_licenseController, 'MH/12345',
                      Icons.badge_outlined),
                    const SizedBox(height: 16),

                    // Password
                    _fieldLabel('Password *'),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                      decoration: InputDecoration(
                        hintText: 'Min. 6 characters',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFF9CA3AF), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                            color: const Color(0xFF9CA3AF), size: 20,
                          ),
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDC2626), width: 2)),
                      ),
                    ),

                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                              color: Color(0xFFDC2626), size: 16),
                            const SizedBox(width: 8),
                            Text(_error,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                              )),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Text('Submit for Verification',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              )),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        )),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626), width: 2)),
      ),
    );
  }
}