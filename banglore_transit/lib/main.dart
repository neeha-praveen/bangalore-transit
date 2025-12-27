import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangalore Transit',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class ResultScreen extends StatefulWidget {
  final List steps;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final List metroRoute;

  const ResultScreen({
    super.key,
    required this.steps,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.metroRoute,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  GoogleMapController? _mapController;

  List<LatLng> getRoutePoints() {
    return widget.metroRoute.map<LatLng>((s) {
      final lat = (s["lat"] as num).toDouble();
      final lon = (s["lon"] as num).toDouble();
      return LatLng(lat, lon);
    }).toList();
  }

  Set<Polyline> get polylines {
    return {
      Polyline(
        polylineId: const PolylineId("metro_route"),
        points: getRoutePoints(),
        width: 5,
        color: Colors.purple,
      ),
    };
  }

  LatLngBounds getBounds() {
    final start = LatLng(widget.startLat, widget.startLon);
    final end = LatLng(widget.endLat, widget.endLon);

    return LatLngBounds(
      southwest: LatLng(
        start.latitude < end.latitude ? start.latitude : end.latitude,
        start.longitude < end.longitude ? start.longitude : end.longitude,
      ),
      northeast: LatLng(
        start.latitude > end.latitude ? start.latitude : end.latitude,
        start.longitude > end.longitude ? start.longitude : end.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId("start"),
        position: LatLng(widget.startLat, widget.startLon),
        infoWindow: const InfoWindow(title: "Start Station"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId("end"),
        position: LatLng(widget.endLat, widget.endLon),
        infoWindow: const InfoWindow(title: "End Station"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Route"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Steps", icon: Icon(Icons.list)),
              Tab(text: "Map", icon: Icon(Icons.map)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Steps View
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions),
                    title: Text(widget.steps[index]),
                  ),
                );
              },
            ),

            // Map View
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;

                // Fit both markers after map loads
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      getBounds(),
                      80, // padding
                    ),
                  );
                });
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.startLat, widget.startLon),
                zoom: 10, // temporary, will be overridden
              ),
              markers: markers,
              zoomControlsEnabled: false,
              polylines: polylines,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final fromController = TextEditingController();
  final toController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bangalore Transit")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: fromController,
              decoration: const InputDecoration(
                labelText: "From Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: "To Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final response = await http.post(
                    Uri.parse("http://10.0.2.2:4000/route"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "from": fromController.text,
                      "to": toController.text,
                    }),
                  );

                  final data = jsonDecode(response.body);
                  final route = List<Map<String, dynamic>>.from(
                    data["metroRoute"],
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        steps: List<String>.from(data["directions"]),
                        startLat: (data["from"]["lat"] as num).toDouble(),
                        startLon: (data["from"]["lon"] as num).toDouble(),
                        endLat: (data["to"]["lat"] as num).toDouble(),
                        endLon: (data["to"]["lon"] as num).toDouble(),
                        metroRoute: route,
                      ),
                    ),
                  );
                },

                child: const Text("Find Route"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
