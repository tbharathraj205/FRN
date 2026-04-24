import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui'; // Required for Glassmorphism blur
import 'report_screen.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

class NavigationScreen extends StatefulWidget {
  final String incidentId;
  final String emergencyType;
  final double lat;
  final double lng;
  final String ambulanceEta;
  final String doctorId;

  const NavigationScreen({
    super.key,
    required this.incidentId,
    required this.emergencyType,
    required this.lat,
    required this.lng,
    required this.ambulanceEta,
    required this.doctorId,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Timer? _locationTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 300;
  Position? _currentPosition;
  GoogleMapController? _mapController;

  List<LatLng> _polylineCoordinates = [];
  String _routeDistance = '';
  String _routeDuration = '';
  bool _routeLoaded = false;
  String _address = 'Fetching address...';

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL CALCULATION — Haversine formula
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
  /// network call, so the stats panel always shows a real value.
  void _computeLocalEstimate(double fromLat, double fromLng) {
    final distKm =
        _haversineDistanceKm(fromLat, fromLng, widget.lat, widget.lng);
    final mins = _estimateTravelMinutes(distKm);
    setState(() {
      _routeDistance = '~${distKm.toStringAsFixed(1)} km';
      _routeDuration = '~$mins min';
      _routeLoaded = true;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getAddress();
    _startLocationUpdates();
    _startCountdown();
  }

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

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    double fromLat = 13.0827;
    double fromLng = 80.2707;

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      _updateLocationToBackend(position.latitude, position.longitude);
      fromLat = position.latitude;
      fromLng = position.longitude;
    } catch (e) {
      // GPS unavailable — fall back to default Chennai coordinate
      setState(() => _currentPosition = Position(
            latitude: fromLat,
            longitude: fromLng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ));
    }

    // ✅ Show local estimate IMMEDIATELY — zero network dependency
    _computeLocalEstimate(fromLat, fromLng);

    // Try to refine with the precise route API in the background.
    // If it succeeds, API values replace the local estimate.
    // If it fails, the local estimate stays — no blank "…" ever.
    _getRoute();

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        setState(() => _currentPosition = position);
        _updateLocationToBackend(position.latitude, position.longitude);
        // Refresh local estimate as the doctor moves closer
        _computeLocalEstimate(position.latitude, position.longitude);
      } catch (e) {
        _updateLocationToBackend(13.0827, 80.2707);
      }
    });
  }

  Future<void> _updateLocationToBackend(double lat, double lng) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      await http.post(
        Uri.parse('https://us-central1-first-responder-network.cloudfunctions.net/update_doctor_location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'doctorId': widget.doctorId,
          'lat': lat,
          'lng': lng,
        }),
      );
    } catch (e) {}
  }

  Future<void> _getRoute() async {
    if (_currentPosition == null) return;
    try {
      final response = await http.get(
        Uri.parse(
          'https://us-central1-first-responder-network.cloudfunctions.net/get_route'
          '?fromLat=${_currentPosition!.latitude}'
          '&fromLng=${_currentPosition!.longitude}'
          '&toLat=${widget.lat}'
          '&toLng=${widget.lng}',
        ),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          final polylinePoints = PolylinePoints();
          final decodedPolyline = polylinePoints.decodePolyline(result['polyline']);
          if (mounted) {
            setState(() {
              _polylineCoordinates = decodedPolyline
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList();
              // API values are more accurate — overwrite the local estimate
              _routeDistance = '${(result['distanceKm'] as num).toStringAsFixed(1)} km';
              _routeDuration = '${(result['durationMinutes'] as num).toInt()} min';
              _routeLoaded = true;
            });
          }
        }
      }
    } catch (e) {
      // Keep local estimate if API fails
    } finally {
      if (mounted) {
        setState(() { _routeLoaded = true; });
      }
    }
  }

  Future<void> _markOnScene() async {
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    await FirebaseFirestore.instance
        .collection('incidents')
        .doc(widget.incidentId)
        .update({'status': 'on_scene'});

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReportScreen(
            incidentId: widget.incidentId,
            emergencyType: widget.emergencyType,
            doctorId: widget.doctorId,
          ),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    int mins = (seconds / 60).floor();
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. 🗺️ FULL SCREEN MAP WITH DARK THEME
          GoogleMap(
            style: _mapTheme,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.lat, widget.lng),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: {
              Marker(
                markerId: const MarkerId('incident'),
                position: LatLng(widget.lat, widget.lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
              ),
              if (_currentPosition != null)
                Marker(
                  markerId: const MarkerId('doctor'),
                  position: LatLng(_currentPosition!.latitude,
                      _currentPosition!.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
            },
            polylines: {
              if (_polylineCoordinates.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _polylineCoordinates,
                  color: const Color(0xFF3B82F6),
                  width: 6,
                  jointType: JointType.round,
                ),
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. 🧊 TOP GLASS BAR
          _buildTopHUD(),

          // 3. 🕒 FLOATING MISSION TIMER
          _buildMissionTimerOverlay(),

          // 4. 💳 BOTTOM DASHBOARD
          _buildBottomDashboard(),
        ],
      ),
    );
  }

  Widget _buildTopHUD() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.only(
                top: 50, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.7),
              border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded,
                    color: Color(0xFFF87171), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE RESPONSE: #${widget.incidentId.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2),
                      ),
                      Text(
                        widget.emergencyType,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: const Text('URGENT',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionTimerOverlay() {
    return Positioned(
      top: 130,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            const Text('TIME TO SCENE',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            Text(
              _formatTime(_secondsLeft),
              style: TextStyle(
                color: _secondsLeft < 60
                    ? const Color(0xFFF87171)
                    : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: _secondsLeft / 300,
                backgroundColor: Colors.white10,
                color: _secondsLeft < 60
                    ? Colors.red
                    : const Color(0xFF3B82F6),
                minHeight: 3,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDashboard() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -5))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(
                  'DISTANCE',
                  _routeLoaded ? _routeDistance : '…',
                  Icons.directions,
                ),
                _statDivider(),
                _statItem(
                  'TRAVEL TIME',
                  _routeLoaded ? _routeDuration : '…',
                  Icons.timer_outlined,
                ),
                _statDivider(),
                _statItem(
                    'AMBULANCE', '${widget.ambulanceEta}m', Icons.emergency),
              ],
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _markOnScene,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.red.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text(
                  'CONFIRM ARRIVAL ON SCENE',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold)),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _statDivider() =>
      Container(height: 30, width: 1, color: Colors.grey[200]);

  static const String _mapTheme = '''[
    {"elementType": "geometry","stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},
    {"elementType": "labels.text.stroke","stylers": [{"color": "#242f3e"}]},
    {"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},
    {"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},
    {"featureType": "road","elementType": "geometry","stylers": [{"color": "#38414e"}]},
    {"featureType": "road","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},
    {"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},
    {"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]}
  ]''';
}