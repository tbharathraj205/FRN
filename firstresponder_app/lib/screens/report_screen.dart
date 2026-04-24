import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class ReportScreen extends StatefulWidget {
  final String incidentId;
  final String emergencyType;
  final String doctorId;

  const ReportScreen({
    super.key,
    required this.incidentId,
    required this.emergencyType,
    required this.doctorId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // --- LOGIC & STATE (UNTOUCHED) ---
  final List<String> _actions = [
    'CPR administered', 'AED used', 'Airway cleared',
    'Bleeding ctrl.', 'Recovery pos.', 'Oxygen given',
  ];

  final List<String> _outcomes = [
    'Stable',
    'Critical — handed to ambulance',
    'Unresponsive',
    'Recovered',
  ];

  final List<String> _selectedActions = [];
  String _selectedOutcome = '';
  final _notesController = TextEditingController();
  bool _loading = false;

  Future<void> _submitReport() async {
    setState(() { _loading = true; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      await http.post(
        Uri.parse('https://us-central1-first-responder-network.cloudfunctions.net/submit_report'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'incidentId': widget.incidentId,
          'doctorId': widget.doctorId,
          'vitals': _selectedActions,
          'actions': _selectedActions,
          'notes': _notesController.text,
          'outcome': _selectedOutcome,
        }),
      );
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(widget.incidentId)
          .update({'status': 'resolved'});
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  // --- REFINED UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFDC2626);
    const Color bgSlate = Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgSlate,
      body: Column(
        children: [
          // 1. REFINED HERO HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: const BoxDecoration(
              color: primaryRed,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ON SCENE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('LIVE REPORT',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.emergencyType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    )),
                const SizedBox(height: 4),
                Text('Incident ID: ${widget.incidentId.substring(0, 8).toUpperCase()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),

          // 2. SCROLLABLE FORM SECTION
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ACTIONS TAKEN ---
                  _buildSectionHeader('ACTIONS TAKEN'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _actions.map((action) {
                      final isSelected = _selectedActions.contains(action);
                      return FilterChip(
                        label: Text(action),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            val ? _selectedActions.add(action) : _selectedActions.remove(action);
                          });
                        },
                        showCheckmark: false,
                        selectedColor: primaryRed,
                        disabledColor: Colors.white,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? primaryRed : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        elevation: isSelected ? 2 : 0,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // --- PATIENT OUTCOME ---
                  _buildSectionHeader('PATIENT OUTCOME'),
                  const SizedBox(height: 16),
                  ..._outcomes.map((outcome) {
                    final isSelected = _selectedOutcome == outcome;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedOutcome = outcome),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? primaryRed : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? primaryRed.withOpacity(0.1) : Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? primaryRed : const Color(0xFFD1D5DB),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(outcome,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF111827) : const Color(0xFF4B5563),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 15,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 32),

                  // --- NOTES ---
                  _buildSectionHeader('REPORT NOTES'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    cursorColor: primaryRed,
                    decoration: InputDecoration(
                      hintText: 'Describe patient condition, medications administered, or context...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(20),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: primaryRed, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- SUBMIT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: primaryRed.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('COMPLETE MISSION',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              )),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}