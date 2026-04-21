import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'alert_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnDuty = false;
  int _responses = 0;
  int _credits = 0;
  String _doctorName = '';
  String _specialization = '';
  String _doctorId = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _listenForAlerts();
  }

  void _listenForAlerts() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (mounted && data['incident_id'] != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlertScreen(
            incidentId: data['incident_id'],
            emergencyType: data['emergency_type'] ?? 'Emergency',
            lat: double.tryParse(data['lat'] ?? '13.0827') ?? 13.0827,
            lng: double.tryParse(data['lng'] ?? '80.2707') ?? 80.2707,
            ambulanceEta: '12',
            doctorId: _doctorId,
          ),
        ));
      }
    });
  }

  Future<void> _loadDoctorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _doctorId = user.uid; });

    final doc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _doctorName = data['name'] ?? user.email ?? 'Doctor';
        _specialization = data['specialization'] ?? 'First Aid Volunteer';
        _isOnDuty = data['is_on_duty'] ?? false;
      });
    } else {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .set({
        'name': user.email?.split('@')[0] ?? 'Doctor',
        'phone': '',
        'specialization': 'First Aid Volunteer',
        'is_approved': true,
        'is_on_duty': false,
        'current_lat': 13.0827,
        'current_lng': 80.2707,
        'fcm_token': '',
        'current_incident': null,
        'photo_url': '',
      });
      setState(() {
        _doctorName = user.email?.split('@')[0] ?? 'Doctor';
        _specialization = 'First Aid Volunteer';
      });
    }

    // Count responses
    final incidents = await FirebaseFirestore.instance
        .collection('incidents')
        .where('assigned_doctor_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'resolved')
        .get();
    setState(() {
      _responses = incidents.size;
      _credits = incidents.size * 10; // 10 credits per response
    });

    // Save FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .update({'fcm_token': fcmToken});
    }

    // Update current location
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .update({
        'current_lat': position.latitude,
        'current_lng': position.longitude,
      });
    } catch (e) {
      // Use default location
    }
  }

  Future<void> _toggleDuty(bool value) async {
    setState(() { _isOnDuty = value; });
    await FirebaseFirestore.instance
        .collection('doctors')
        .doc(_doctorId)
        .update({'is_on_duty': value});
  }

  Future<void> _logout() async {
    await _toggleDuty(false);
    await FirebaseAuth.instance.signOut();
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: _currentIndex == 0 ? _buildHome() : _buildHistory(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() { _currentIndex = i; }),
        selectedItemColor: const Color(0xFFDC2626),
        unselectedItemColor: const Color(0xFF9CA3AF),
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      child: Column(
        children: [

          // Red Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // Top row
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _doctorName.isEmpty ? 'DR' : _getInitials(_doctorName),
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dr. $_doctorName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            )),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(_specialization,
                                style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 8),
                              if (_isOnDuty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.circle,
                                        color: Colors.white, size: 6),
                                      SizedBox(width: 4),
                                      Text('live',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        )),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout,
                        color: Colors.white70, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // On Duty Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnDuty ? 'On duty' : 'Off duty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              )),
                            const SizedBox(height: 2),
                            Text(
                              _isOnDuty
                                ? 'Receiving alerts within 2 km'
                                : 'Toggle on to receive alerts',
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isOnDuty,
                        onChanged: _toggleDuty,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF22C55E),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.white30,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stats Row
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _statCard('$_responses', 'responses',
                  const Color(0xFFDC2626)),
                const SizedBox(width: 12),
                _statCard('$_credits', 'credits',
                  const Color(0xFFD97706)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Activity
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RECENT ACTIVITY',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  )),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('incidents')
                      .where('assigned_doctor_id', isEqualTo: _doctorId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('No recent activity',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 14)),
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs.take(3).toList();
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final data = docs[index].data()
                            as Map<String, dynamic>;
                          final isResolved = data['status'] == 'resolved';
                          return ListTile(
                            leading: Icon(Icons.circle,
                              color: isResolved
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFDC2626),
                              size: 10),
                            title: Text(
                              '${data['emergency_type']} · ${data['lat']?.toStringAsFixed(2) ?? ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              )),
                            trailing: Text(
                              isResolved ? 'Completed' : 'Active',
                              style: TextStyle(
                                color: isResolved
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFDC2626),
                                fontSize: 12,
                              )),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Test Alert Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AlertScreen(
                    incidentId: '93uUSPPQEuTlQaivvE33',
                    emergencyType: 'Cardiac Arrest',
                    lat: 13.0337,
                    lng: 80.18,
                    ambulanceEta: '12',
                    doctorId: _doctorId,
                  ))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white),
                label: const Text('Test Emergency Alert',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return const HistoryScreen();
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 4),
            Text(label,
              style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}