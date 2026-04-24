import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'navigation_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; 
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

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
  // --- LOGIC & STATE (UNTOUCHED) ---
  bool _responding = false;
  String _address = 'Fetching address...';
  List<LatLng> _polylineCoordinates = [];
  String _routeDistance = '';
  String _routeDuration = '';
  bool _loadingRoute = false;
  Position? _currentPosition;

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL CALCULATION — Haversine formula (same as NavigationScreen)
  // Computes straight-line distance between two lat/lng points (in km),
  // then applies a 1.3× road-correction factor for a realistic city estimate.
  // ─────────────────────────────────────────────────────────────────────────

  double _haversineDistanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c * 1.3; // 1.3× = city-road correction
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  // Assumes average urban driving speed of 30 km/h
  int _estimateTravelMinutes(double distanceKm) =>
      (distanceKm / 30.0 * 60).ceil();

  /// Called immediately after GPS fix — sets distance & time without any
  /// network call, so the stats cards always show a real value.
  void _computeLocalEstimate(double fromLat, double fromLng) {
    final distKm =
        _haversineDistanceKm(fromLat, fromLng, widget.lat, widget.lng);
    final mins = _estimateTravelMinutes(distKm);
    setState(() {
      _routeDistance = '~${distKm.toStringAsFixed(1)} km';
      _routeDuration = '~$mins min';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getAddress();
    _getCurrentLocationAndEstimate();
  }

  Future<void> _getAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(widget.lat, widget.lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _address = '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}';
        });
      }
    } catch (e) {
      setState(() { _address = 'Near incident area'; });
    }
  }

  Future<void> _getCurrentLocationAndEstimate() async {
    double fromLat = 13.0827;
    double fromLng = 80.2707;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() { _currentPosition = position; });
        fromLat = position.latitude;
        fromLng = position.longitude;
      }
    } catch (e) {
      setState(() {
        _currentPosition = Position(
          latitude: fromLat, longitude: fromLng, timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0,
        );
      });
    }

    // ✅ Show local estimate IMMEDIATELY — zero network dependency
    _computeLocalEstimate(fromLat, fromLng);

    // Try to refine with the precise route API in the background.
    // If it succeeds, API values replace the local estimate.
    // If it fails, the local estimate stays — no blank values ever.
    _getRoute();
  }

  Future<void> _getRoute() async {
    if (_currentPosition == null) return;
    setState(() { _loadingRoute = true; _polylineCoordinates = []; });
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-first-responder-network.cloudfunctions.net/get_route?fromLat=${_currentPosition!.latitude}&fromLng=${_currentPosition!.longitude}&toLat=${widget.lat}&toLng=${widget.lng}'),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          final polylinePoints = PolylinePoints();
          final decodedPolyline = polylinePoints.decodePolyline(result['polyline']);
          setState(() {
            _polylineCoordinates = decodedPolyline.map((point) => LatLng(point.latitude, point.longitude)).toList();
            // API values are more accurate — overwrite the local estimate
            _routeDistance = '${(result['distanceKm'] as num).toStringAsFixed(1)} km';
            _routeDuration = '${(result['durationMinutes'] as num).toInt()} min';
            _loadingRoute = false;
          });
        }
      }
    } catch (e) {
      // Silently keep the local estimate already shown
      setState(() { _loadingRoute = false; });
    }
  }

  // _calculateDistance and _toRad replaced by _haversineDistanceKm and _deg2rad above

  Future<void> _respond() async {
    setState(() { _responding = true; });
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-first-responder-network.cloudfunctions.net/accept_incident_handler'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'doctorId': widget.doctorId, 'incidentId': widget.incidentId}),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NavigationScreen(
            incidentId: widget.incidentId, emergencyType: widget.emergencyType,
            lat: widget.lat, lng: widget.lng, ambulanceEta: widget.ambulanceEta, doctorId: widget.doctorId,
          )));
        } else {
          setState(() => _responding = false);
          _showCloserDoctorDialog(result);
        }
      } else {
        setState(() => _responding = false);
      }
    } catch (e) {
      setState(() => _responding = false);
    }
  }

  void _showCloserDoctorDialog(dynamic result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Priority Reassigned'),
        content: Text('A closer responder was found (${result['closer_doctor_distance']} km). System priority has been shifted to ensure fastest care.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('UNDERSTOOD'))],
      ),
    );
  }

  // --- REFINED UI ---

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // 1. DYNAMIC SYSTEM BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
            color: primaryRed,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: const Text('112', style: TextStyle(color: primaryRed, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRIORITY DISPATCHED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                      Text('Real-time verification active', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
                const Icon(Icons.sensors, color: Colors.white, size: 18),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.emergencyType.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF111827), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const SizedBox(height: 24),

                  // 2. STATS GRID
                  Row(
                    children: [
                      _infoCard('DISTANCE', _routeDistance.isEmpty ? '...' : _routeDistance, primaryRed, Icons.location_on_outlined),
                      const SizedBox(width: 12),
                      _infoCard('YOUR ETA', _routeDuration.isEmpty ? '...' : _routeDuration, const Color(0xFF059669), Icons.timer_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoCard('LOCATION', _address, const Color(0xFF111827), Icons.map_outlined),
                      const SizedBox(width: 12),
                      _infoCard('AMB ETA', '${widget.ambulanceEta} min', const Color(0xFFD97706), Icons.emergency_outlined),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. MAP INTEGRATION
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(target: LatLng(widget.lat, widget.lng), zoom: 15),
                            markers: {
                              Marker(
                                markerId: const MarkerId('incident'),
                                position: LatLng(widget.lat, widget.lng),
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                              ),
                            },
                            polylines: {
                              if (_polylineCoordinates.isNotEmpty)
                                Polyline(
                                  polylineId: const PolylineId('route'),
                                  points: _polylineCoordinates,
                                  color: const Color(0xFF3B82F6),
                                  width: 6,
                                ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            myLocationEnabled: true,
                          ),
                          if (_loadingRoute)
                            Container(
                              color: Colors.white70,
                              child: const Center(child: CircularProgressIndicator(color: primaryRed)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. ACTION PANEL
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _responding ? null : _respond,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      shadowColor: primaryRed.withOpacity(0.4),
                    ),
                    child: _responding
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('RESPOND TO ALERT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('PASS TO NEXT RESPONDER', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value, Color valueColor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)
            ),
          ],
        ),
      ),
    );
  }
}