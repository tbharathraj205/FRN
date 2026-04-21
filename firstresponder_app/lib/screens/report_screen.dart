import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
      await http.post(
        Uri.parse('https://submit-report-kl4browlmq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'incidentId': widget.incidentId,
          'doctorId': widget.doctorId,
          'vitals': _selectedActions,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // Red Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('On scene',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    )),
                  const SizedBox(height: 4),
                  Text(widget.emergencyType,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    )),
                ],
              ),
            ),

            // Scrollable Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Actions Taken
                    const Text('ACTIONS TAKEN',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      )),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _actions.map((action) {
                        final selected = _selectedActions.contains(action);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedActions.remove(action);
                              } else {
                                _selectedActions.add(action);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: selected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(action,
                              style: TextStyle(
                                color: selected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Patient Outcome
                    const Text('PATIENT OUTCOME',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      )),
                    const SizedBox(height: 12),
                    Column(
                      children: _outcomes.map((outcome) {
                        final selected = _selectedOutcome == outcome;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedOutcome = outcome;
                          }),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selected
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: selected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFE5E7EB),
                                width: selected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                  color: selected
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF9CA3AF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(outcome,
                                  style: TextStyle(
                                    color: selected
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF374151),
                                    fontSize: 14,
                                    fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Notes
                    const Text('NOTES',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      )),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                      decoration: InputDecoration(
                        hintText: 'Additional observations (optional)...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDC2626), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Text('submit report',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              )),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}