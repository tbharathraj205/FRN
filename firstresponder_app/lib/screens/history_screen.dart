import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
                    final data = incidents[index].data() as Map<String, dynamic>;
                    return _buildIncidentCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // REFINED INCIDENT CARD
  Widget _buildIncidentCard(Map<String, dynamic> data) {
    final status = data['status'] ?? 'unknown';
    final isCompleted = status == 'resolved';
    final createdAt = data['created_at'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day} ${_monthName(createdAt.toDate().month)} ${createdAt.toDate().year}'
        : 'Unknown date';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
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

          // Response Summary Section
          if (isCompleted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 14),
                  SizedBox(width: 8),
                  Text('PATIENT STABILIZED', 
                    style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  Spacer(),
                  Text('Outcome: SUCCESS', 
                    style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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