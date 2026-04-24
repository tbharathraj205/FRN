import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Track which incident card is currently expanded (by incident doc ID)
  String? _expandedIncidentId;
  // Cache fetched reports so we don't re-fetch on every tap
  final Map<String, Map<String, dynamic>?> _reportCache = {};

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    const Color primaryRed = Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. PREMIUM HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
            decoration: const BoxDecoration(
              color: primaryRed,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESPONSE LOG',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    )),
                SizedBox(height: 4),
                Text('Incident History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    )),
              ],
            ),
          ),

          // 2. INCIDENT LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .where('assigned_doctor_id', isEqualTo: doctorId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryRed));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final incidents = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final doc = incidents[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildIncidentCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // REFINED INCIDENT CARD — now tappable with expandable report dropdown
  Widget _buildIncidentCard(String incidentDocId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'unknown';
    final isCompleted = status == 'resolved';
    final createdAt = data['created_at'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day} ${_monthName(createdAt.toDate().month)} ${createdAt.toDate().year}'
        : 'Unknown date';
    final isExpanded = _expandedIncidentId == incidentDocId;

    return GestureDetector(
      onTap: () => _toggleExpand(incidentDocId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isExpanded
              ? Border.all(color: const Color(0xFFDC2626).withOpacity(0.2), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpanded ? 0.06 : 0.03),
              blurRadius: isExpanded ? 20 : 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: Type & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (data['emergency_type'] ?? 'Unknown').toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                _buildStatusBadge(status, isCompleted),
              ],
            ),
            const SizedBox(height: 12),
            
            // Row: Location & Date
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF9CA3AF), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${data['lat']?.toStringAsFixed(4) ?? ''}, ${data['lng']?.toStringAsFixed(4) ?? ''}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today_outlined, color: Color(0xFF9CA3AF), size: 12),
                const SizedBox(width: 4),
                Text(dateStr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),

            // Tap hint
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF9CA3AF),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? 'Hide report' : 'View report',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            // EXPANDABLE REPORT SECTION
            if (isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE5E7EB), height: 1),
              const SizedBox(height: 16),
              _buildReportSection(incidentDocId),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleExpand(String incidentDocId) {
    setState(() {
      if (_expandedIncidentId == incidentDocId) {
        _expandedIncidentId = null;
      } else {
        _expandedIncidentId = incidentDocId;
        // Fetch report if not already cached
        if (!_reportCache.containsKey(incidentDocId)) {
          _fetchReport(incidentDocId);
        }
      }
    });
  }

  Future<void> _fetchReport(String incidentDocId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('incident_id', isEqualTo: incidentDocId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _reportCache[incidentDocId] =
              querySnapshot.docs.first.data();
        });
      } else {
        setState(() {
          _reportCache[incidentDocId] = null; // No report found
        });
      }
    } catch (e) {
      setState(() {
        _reportCache[incidentDocId] = null;
      });
    }
  }

  Widget _buildReportSection(String incidentDocId) {
    if (!_reportCache.containsKey(incidentDocId)) {
      // Still loading
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFDC2626),
            ),
          ),
        ),
      );
    }

    final report = _reportCache[incidentDocId];
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 16),
            SizedBox(width: 8),
            Text('No report submitted for this incident.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // Extract report fields
    final outcome = report['outcome'] as String? ?? 'N/A';
    final notes = report['notes'] as String? ?? 'No notes';
    final actionsTaken = (report['actions_taken'] as List<dynamic>?)?.cast<String>() ?? [];
    final vitals = (report['vitals'] as List<dynamic>?)?.cast<String>() ?? [];
    final submittedAt = report['submitted_at'] as Timestamp?;
    final submittedStr = submittedAt != null
        ? _formatTimestamp(submittedAt)
        : 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outcome
        _reportDetailRow(
          icon: Icons.flag_outlined,
          label: 'OUTCOME',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _outcomeColor(outcome).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outcomeColor(outcome).withOpacity(0.2)),
            ),
            child: Text(
              outcome,
              style: TextStyle(
                color: _outcomeColor(outcome),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Actions Taken
        if (actionsTaken.isNotEmpty) ...[
          _reportDetailRow(
            icon: Icons.checklist_rounded,
            label: 'ACTIONS TAKEN',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: actionsTaken.map((action) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(action,
                    style: const TextStyle(color: Color(0xFF0369A1), fontSize: 11, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Vitals
        if (vitals.isNotEmpty) ...[
          _reportDetailRow(
            icon: Icons.monitor_heart_outlined,
            label: 'VITALS',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: vitals.map((vital) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(vital,
                    style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Notes
        _reportDetailRow(
          icon: Icons.notes_rounded,
          label: 'NOTES',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              notes,
              style: const TextStyle(color: Color(0xFF374151), fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Submitted At
        _reportDetailRow(
          icon: Icons.access_time_rounded,
          label: 'SUBMITTED AT',
          child: Text(
            submittedStr,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _reportDetailRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Color _outcomeColor(String outcome) {
    final lower = outcome.toLowerCase();
    if (lower.contains('success') || lower.contains('stabilized')) {
      return const Color(0xFF059669);
    } else if (lower.contains('critical') || lower.contains('ambulance')) {
      return const Color(0xFFD97706);
    } else if (lower.contains('fatal') || lower.contains('deceased')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF6B7280);
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate().toLocal();
    final day = dt.day;
    final month = _monthName(dt.month);
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $period';
  }

  Widget _buildStatusBadge(String status, bool isCompleted) {
    final color = isCompleted ? const Color(0xFF059669) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        isCompleted ? 'RESOLVED' : status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.history_toggle_off_rounded, color: Colors.grey.shade300, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('No recorded responses',
              style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Your activity logs will appear here.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}