import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'navigation_screen.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ✅ ADDED
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
  bool _responding = false;

  // ✅ ADDED
  String _address = 'Fetching address...';
  
  // ✅ Route related variables
  List<LatLng> _polylineCoordinates = [];
  String _routeDistance = '';
  String _routeDuration = '';
  bool _loadingRoute = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getAddress();
    _getCurrentLocation();
    // Auto-load route
    Future.delayed(const Duration(milliseconds: 500), _getRoute);
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

  // ✅ Get doctor's current location
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Use default location if permission denied
      setState(() {
        _currentPosition = Position(
          latitude: 13.0827,
          longitude: 80.2707,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      });
    }
  }

  // ✅ Fetch route from backend
  Future<void> _getRoute() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting your location...')),
      );
      return;
    }

    setState(() {
      _loadingRoute = true;
      _polylineCoordinates = [];
    });

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
            _loadingRoute = false;
          });
        }
      } else {
        throw Exception('Failed to get route: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _loadingRoute = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting route: $e')),
        );
      }
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
      // Call Cloud Function to handle acceptance with distance-based assignment
      final response = await http.post(
        Uri.parse('https://us-central1-first-responder-network.cloudfunctions.net/accept_incident_handler'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctorId': widget.doctorId,
          'incidentId': widget.incidentId,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success']) {
          // Successfully assigned to this doctor
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
        } else {
          // Another doctor is closer
          setState(() => _responding = false);
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Another Doctor Closer'),
                content: Text(
                  'A closer doctor (${result['closer_doctor_distance']} km away) has been assigned instead.\n\nYour distance: ${result['your_distance']} km',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } else if (response.statusCode == 409) {
        // Conflict: another doctor already assigned and closer
        final result = jsonDecode(response.body);
        setState(() => _responding = false);
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Another Doctor Closer'),
              content: Text(
                'A closer doctor has accepted this incident.\n\nYour distance: ${result['your_distance']} km\nCloser doctor: ${result['closer_doctor_distance']} km',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() => _responding = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error accepting incident')),
          );
        }
      }
    } catch (e) {
      setState(() => _responding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
                          polylines: {
                            if (_polylineCoordinates.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId('route'),
                                points: _polylineCoordinates,
                                color: const Color(0xFF2563EB),
                                width: 5,
                              ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          myLocationEnabled: true,
                        ),
                      ),
                    ),

                    // ✅ Route info if available
                    if (_routeDistance.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xEFF0F9FF),
                          border: Border.all(color: const Color(0xFF2563EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                const Text('Distance',
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_routeDistance,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Duration',
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_routeDuration,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Buttons
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