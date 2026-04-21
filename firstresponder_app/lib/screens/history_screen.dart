import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header
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
              child: const Text('Response History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                )),
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('incidents')
                    .where('assigned_doctor_id', isEqualTo: doctorId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFDC2626)));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading history',
                        style: TextStyle(color: Colors.grey.shade500)));
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                            color: Colors.grey.shade300, size: 64),
                          const SizedBox(height: 16),
                          const Text('No responses yet',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 16,
                            )),
                          const SizedBox(height: 8),
                          const Text(
                            'Your response history will appear here',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            )),
                        ],
                      ),
                    );
                  }

                  final incidents = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: incidents.length,
                    itemBuilder: (context, index) {
                      final data = incidents[index].data()
                        as Map<String, dynamic>;
                      final status = data['status'] ?? 'unknown';
                      final isCompleted = status == 'resolved';
                      final isNotified = status == 'pending';
                      final createdAt = data['created_at'] as Timestamp?;
                      final date = createdAt != null
                        ? '${createdAt.toDate().day} ${_monthName(createdAt.toDate().month)} ${createdAt.toDate().year}'
                        : 'Unknown date';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Top row
                            Row(
                              mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  data['emergency_type'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  )),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isCompleted
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFF9CA3AF),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isCompleted
                                      ? 'COMPLETED'
                                      : isNotified
                                        ? 'NOTIFIED'
                                        : status.toUpperCase(),
                                    style: TextStyle(
                                      color: isCompleted
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFF9CA3AF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Location
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                  color: Color(0xFF9CA3AF), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${data['lat']?.toStringAsFixed(4) ?? ''}, ${data['lng']?.toStringAsFixed(4) ?? ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                  )),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Date
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                  color: Color(0xFF9CA3AF), size: 13),
                                const SizedBox(width: 4),
                                Text(date,
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  )),
                              ],
                            ),

                            // Completed details
                            if (isCompleted) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Text('Response: ',
                                      style: TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      )),
                                    Text('Completed',
                                      style: TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontSize: 12,
                                      )),
                                    SizedBox(width: 12),
                                    Text('Outcome: ',
                                      style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      )),
                                    Text('Stable',
                                      style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 12,
                                      )),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}