import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'navigation_screen.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ✅ ADDED

class AlertScreen extends StatefulWidget {
  final String incidentId;
  final String emergencyType;
  final double lat;
  final double lng;
  final String ambulanceEta;
  final String doctorId;

  const AlertScreen({
    super.key,
    required this.incidentId,
    required this.emergencyType,
    required this.lat,
    required this.lng,
    required this.ambulanceEta,
    required this.doctorId,
  });

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  bool _responding = false;

  // ✅ ADDED
  String _address = 'Fetching address...';

  @override
  void initState() {
    super.initState();
    _getAddress(); // ✅ CALL FUNCTION
  }

  // ✅ ADDED FUNCTION
  Future<void> _getAddress() async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(widget.lat, widget.lng);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _address =
              '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}';
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Near incident area';
      });
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  Future<void> _respond() async {
    setState(() {
      _responding = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(widget.incidentId)
          .update({
        'status': 'accepted',
        'assigned_doctor_id': widget.doctorId,
      });
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => NavigationScreen(
                incidentId: widget.incidentId,
                emergencyType: widget.emergencyType,
                lat: widget.lat,
                lng: widget.lng,
                ambulanceEta: widget.ambulanceEta,
                doctorId: widget.doctorId,
              ),
            ));
      }
    } catch (e) {
      setState(() {
        _responding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance =
        _calculateDistance(13.0827, 80.2707, widget.lat, widget.lng);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Red Alert Banner
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFDC2626),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('112',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        )),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency dispatch',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            )),
                        Text('Control room verified · auto-triggered',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('● 112',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.emergencyType,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _infoCard('Distance',
                            '${distance.toStringAsFixed(1)} km',
                            const Color(0xFFDC2626)),
                        const SizedBox(width: 12),
                        _infoCard('Your ETA', '~1 min',
                            const Color(0xFF059669)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // ✅ UPDATED HERE
                        _infoCard('Location', _address,
                            const Color(0xFF1A1A1A)),
                        const SizedBox(width: 12),
                        _infoCard('Ambulance ETA',
                            '${widget.ambulanceEta} min',
                            const Color(0xFFD97706)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(widget.lat, widget.lng),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('incident'),
                              position:
                                  LatLng(widget.lat, widget.lng),
                              icon: BitmapDescriptor
                                  .defaultMarkerWithHue(
                                      BitmapDescriptor.hueRed),
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          myLocationEnabled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons (unchanged)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _responding ? null : _respond,
                      child: _responding
                          ? const CircularProgressIndicator()
                          : const Text('respond'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('pass'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(value),
          ],
        ),
      ),
    );
  }
}