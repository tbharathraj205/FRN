import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'report_screen.dart';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';

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
  
  // ✅ Route related variables
  List<LatLng> _polylineCoordinates = [];
  String _routeDistance = '';
  String _routeDuration = '';
  bool _routeLoaded = false;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _startCountdown();
    _getRoute(); // ✅ Get route on init
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

    try {
      final position = await Geolocator.getCurrentPosition();

      setState(() {
        _currentPosition = position;
      });

      _updateLocationToBackend(position.latitude, position.longitude);
    } catch (e) {}

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition();

        setState(() {
          _currentPosition = position;
        });

        _updateLocationToBackend(position.latitude, position.longitude);
      } catch (e) {
        _updateLocationToBackend(13.0827, 80.2707);
      }
    });
  }

  Future<void> _updateLocationToBackend(double lat, double lng) async {
    try {
      await http.post(
        Uri.parse('https://update-doctor-location-kl4browlmq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctorId': widget.doctorId,
          'lat': lat,
          'lng': lng,
        }),
      );
    } catch (e) {}
  }

  // ✅ Fetch route from backend
  Future<void> _getRoute() async {
    if (_currentPosition == null) {
      // Try again in a moment
      await Future.delayed(const Duration(seconds: 1));
      if (_currentPosition == null) return;
    }

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
          // Decode polyline
          final polylinePoints = PolylinePoints();
          final decodedPolyline = polylinePoints.decodePolyline(result['polyline']);
          
          setState(() {
            _polylineCoordinates = decodedPolyline
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
            _routeDistance = '${(result['distanceKm'] as num).toStringAsFixed(1)} km';
            _routeDuration = '${(result['durationMinutes'] as num).toInt()} min';
            _routeLoaded = true;
          });
        }
      }
    } catch (e) {
      // Silent fail - route is optional
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
    if (seconds >= 60) {
      return '${(seconds / 60).floor()}:${(seconds % 60).toString().padLeft(2, '0')}';
    }
    return '0:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // 🗺️ MAP
          GoogleMap(
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
                  position: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
            },
            polylines: {
              if (_polylineCoordinates.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _polylineCoordinates,
                  color: const Color(0xFF2563EB),
                  width: 5,
                ),
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          // ⏱️ TOP INFO WITH HORIZONTAL BLACK BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ⏱️ TIMER ON LEFT
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(_secondsLeft),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'to scene',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // 📍 LOCATION & EMERGENCY TYPE ON RIGHT
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.emergencyType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Text(
                          'Anna Nagar, Chennai',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ⬇️ BOTTOM BAR - ENHANCED
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency Type & Distance
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.emergencyType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              '1.2 km away',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'In Transit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ETA Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_taxi_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ambulance arriving in ${widget.ambulanceEta} min',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ Route Info Display
                  if (_routeLoaded && _routeDistance.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xEFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Distance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _routeDistance,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          Column(
                            children: [
                              const Text(
                                'ETA',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _routeDuration,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _markOnScene,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Mark as On Scene',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}