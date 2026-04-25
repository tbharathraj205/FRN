import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'alert_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- CORE LOGIC (UNTOUCHED) ---
  bool _isOnDuty = false;
  int _responses = 0;
  int _credits = 0;
  String _doctorName = '';
  String _specialization = '';
  String _doctorId = '';
  Map<String, dynamic> _doctorProfile = {};
  int _currentIndex = 0;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _listenForAlerts();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
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
        _doctorProfile = data;
        _doctorName = data['name'] ?? user.email ?? 'Doctor';
        _specialization = data['specialization'] ?? 'First Aid Volunteer';
        _isOnDuty = data['is_on_duty'] ?? false;
      });
    } else {
      final fallbackDoctor = {
        'name': user.email?.split('@')[0] ?? 'Doctor',
        'email': user.email ?? '',
        'phone': '',
        'specialization': 'First Aid Volunteer',
        'license_number': '',
        'is_approved': true,
        'is_on_duty': false,
        'current_lat': 13.0827,
        'current_lng': 80.2707,
        'fcm_token': '',
        'current_incident': null,
        'photo_url': '',
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .set(fallbackDoctor);
      setState(() {
        _doctorProfile = { ...fallbackDoctor, 'created_at': null };
        _doctorName = user.email?.split('@')[0] ?? 'Doctor';
        _specialization = 'First Aid Volunteer';
      });
    }

    final incidents = await FirebaseFirestore.instance
        .collection('incidents')
        .where('assigned_doctor_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'resolved')
        .get();
    setState(() {
      _responses = incidents.size;
      _credits = incidents.size * 10;
    });

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .update({'fcm_token': fcmToken});
      setState(() { _doctorProfile['fcm_token'] = fcmToken; });
    }

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
      setState(() {
        _doctorProfile['current_lat'] = position.latitude;
        _doctorProfile['current_lng'] = position.longitude;
      });
    } catch (e) {}
  }

  Future<void> _toggleDuty(bool value) async {
    setState(() { _isOnDuty = value; });
    _locationUpdateTimer?.cancel();
    if (value) {
      await _updateDoctorLocation();
      _locationUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        await _updateDoctorLocation();
      });
    }
    await FirebaseFirestore.instance
        .collection('doctors')
        .doc(_doctorId)
        .update({'is_on_duty': value});
  }

  Future<void> _updateDoctorLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(_doctorId)
          .update({
        'current_lat': position.latitude,
        'current_lng': position.longitude,
      });
      setState(() {
        _doctorProfile['current_lat'] = position.latitude;
        _doctorProfile['current_lng'] = position.longitude;
      });
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  void _showProfileView() {
    final profile = _doctorProfile;
    final photoUrl = (profile['photo_url'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                const Text('RESPONDER PROFILE', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), letterSpacing: 1.2, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: const Color(0xFFDC2626),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty ? Text(_getInitials(_doctorName), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)) : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_doctorName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        Text(_specialization, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 24),
                _profileDetailRow('Email Address', profile['email']),
                _profileDetailRow('Medical License', profile['license_number']),
                _profileDetailRow('Registry Phone', profile['phone']),
                _profileDetailRow('System Status', (profile['is_approved'] ?? false) ? 'Active & Verified' : 'Pending Verification'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value?.toString() ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _toggleDuty(false);
    await FirebaseAuth.instance.signOut();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'DR';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  int min(int a, int b) => a < b ? a : b;

  // --- UI REWRITE (BRAND COLOR SCHEME) ---
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
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Logs'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBrandHeader(),
          const SizedBox(height: 24),
          _buildStatGrid(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _showProfileView,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 22, backgroundColor: Colors.white,
                        child: Text(_getInitials(_doctorName), style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. $_doctorName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('System ID: ${_doctorId.substring(0, 6).toUpperCase()}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 32),
          _buildDutyControl(),
        ],
      ),
    );
  }

  Widget _buildDutyControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _isOnDuty ? const Color(0xFF22C55E) : Colors.white38,
                      shape: BoxShape.circle,
                      boxShadow: _isOnDuty ? [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.5), blurRadius: 10)] : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_isOnDuty ? 'ON DUTY' : 'OFF DUTY', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 4),
              Text(_isOnDuty ? 'Ready for nearby dispatch' : 'Go on-duty to receive alerts', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ],
          ),
          Switch.adaptive(
            value: _isOnDuty,
            onChanged: _toggleDuty,
            activeTrackColor: const Color(0xFF22C55E).withOpacity(0.4),
            activeColor: const Color(0xFF22C55E),
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _statTile('RESOLVED', '$_responses', Icons.verified_user_rounded),
          const SizedBox(width: 16),
          _statTile('CREDITS', '$_credits', Icons.account_balance_wallet_rounded),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFDC2626), size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT ACTIVITY', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 1.5, fontSize: 11)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('incidents').where('assigned_doctor_id', isEqualTo: _doctorId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyActivity();
              }
              final docs = snapshot.data!.docs.take(3).toList();
              return Column(children: docs.map((doc) => _incidentItem(doc.data() as Map<String, dynamic>)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _incidentItem(Map<String, dynamic> data) {
    final bool isDone = data['status'] == 'resolved';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: (isDone ? const Color(0xFF22C55E) : const Color(0xFFDC2626)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(isDone ? Icons.check_circle_outline : Icons.emergency_rounded, color: isDone ? const Color(0xFF22C55E) : const Color(0xFFDC2626), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['emergency_type'] ?? 'Emergency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
                Text('Location ID: ${data['lat']?.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          Text(isDone ? 'Completed' : 'Active', style: TextStyle(color: isDone ? const Color(0xFF22C55E) : const Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(children: [Icon(Icons.inbox_outlined, color: Colors.grey[300], size: 40), const SizedBox(height: 12), const Text('No recent logs available', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))]),
    );
  }



  Widget _buildHistory() {
    return const HistoryScreen();
  }
}