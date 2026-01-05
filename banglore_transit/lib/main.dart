import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/timeline_step.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

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
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  final List<Map<String, dynamic>> steps;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final List metroRoute;
  final List<Map<String, dynamic>> segments;

  const ResultScreen({
    super.key,
    required this.steps,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.metroRoute,
    required this.segments,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  GoogleMapController? _mapController;
  String? _mapStyle;
  BitmapDescriptor? _startMarker;
  BitmapDescriptor? _endMarker;
  BitmapDescriptor? _interchangeMarker;

  @override
  void initState() {
    super.initState();
    _loadMapAssets();
  }

  Future<void> _loadMapAssets() async {
    // Load improved map style
    final style = await rootBundle.loadString('assets/map_style.json');
    setState(() => _mapStyle = style);

    // Create custom markers
    _startMarker = await _createCircleMarker(
      color: const Color(0xFF4CAF50),
      size: 80,
      borderColor: Colors.white,
    );

    _endMarker = await _createCircleMarker(
      color: const Color(0xFFF44336),
      size: 80,
      borderColor: Colors.white,
    );

    _interchangeMarker = await _createCircleMarker(
      color: const Color(0xFF2196F3),
      size: 60,
      borderColor: Colors.white,
    );

    setState(() {});
  }

  Future<BitmapDescriptor> _createCircleMarker({
    required Color color,
    required double size,
    required Color borderColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.12;

    final radius = size / 2;
    canvas.drawCircle(
      Offset(radius, radius),
      radius - borderPaint.strokeWidth / 2,
      paint,
    );
    canvas.drawCircle(
      Offset(radius, radius),
      radius - borderPaint.strokeWidth / 2,
      borderPaint,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  List<LatLng> getRoutePoints() {
    return widget.metroRoute.map<LatLng>((s) {
      final lat = (s["lat"] as num).toDouble();
      final lon = (s["lon"] as num).toDouble();
      return LatLng(lat, lon);
    }).toList();
  }

  String getLineName(dynamic line) {
    if (line is List && line.isNotEmpty) {
      return line.first.toString();
    }
    return line?.toString() ?? "";
  }

  Set<Polyline> buildMetroPolylines() {
    final Set<Polyline> polylines = {};

    const Map<String, Color> lineColors = {
      'Purple': Color(0xFF9C27B0),
      'Green': Color(0xFF4CAF50),
      'Yellow': Color(0xFFFFC107),
      'Blue': Color(0xFF2196F3),
      'Pink': Color(0xFFE91E63),
    };

    for (int i = 0; i < widget.segments.length; i++) {
      final segment = widget.segments[i];
      final from = segment['from'];
      final to = segment['to'];
      final String? lineName = segment['line'];

      final Color color = lineColors[lineName] ?? Colors.grey;

      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_$i'),
          points: [
            LatLng(from['lat'], from['lon']),
            LatLng(to['lat'], to['lon']),
          ],
          color: color,
          width: 4,
          geodesic: true,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );
    }

    return polylines;
  }

  LatLngBounds getBoundsWithBias() {
    final points = widget.metroRoute
        .map<LatLng>((s) => LatLng(s["lat"], s["lon"]))
        .toList();

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }

    final lngPadding = (maxLng - minLng) * 0.35;

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng + lngPadding),
    );
  }

  String getTitle(Map step) {
    switch (step["type"]) {
      case "walk":
        return "Walk";
      case "metro":
        return "${getLineName(step["line"])} Line";
      case "transfer":
        return "Change";
      case "exit":
        return "Exit";
      default:
        return "";
    }
  }

  String getSubtitle(Map step) {
    switch (step["type"]) {
      case "walk":
        return "Walk to ${step["to"]} Metro Station";
      case "metro":
        return "${step["from"]} → ${step["to"]}";
      case "transfer":
        return "Change at ${step["at"]}";
      case "exit":
        return "Exit at ${step["at"]}";
      default:
        return "";
    }
  }

  Color getStepColor(Map step) {
    if (step["type"] == "metro") {
      switch (getLineName(step["line"])) {
        case "Purple":
          return const Color(0xFF9C27B0);
        case "Green":
          return const Color(0xFF4CAF50);
        case "Yellow":
          return const Color(0xFFFFC107);
        case "Blue":
          return const Color(0xFF2196F3);
        case "Pink":
          return const Color(0xFFE91E63);
      }
    }
    return Colors.grey;
  }

  IconData getStepIcon(Map step) {
    switch (step["type"]) {
      case "walk":
        return Icons.directions_walk;
      case "metro":
        return Icons.train;
      case "transfer":
        return Icons.sync_alt;
      case "exit":
        return Icons.flag;
      default:
        return Icons.directions;
    }
  }

  List<LatLng> getInterchangePoints() {
    final List<LatLng> result = [];

    for (int i = 1; i < widget.steps.length; i++) {
      if (widget.steps[i]["type"] == "transfer") {
        final name = widget.steps[i]["at"];

        for (final s in widget.metroRoute) {
          if (s["name"] == name) {
            result.add(LatLng(s["lat"], s["lon"]));
            break;
          }
        }
      }
    }
    return result;
  }

  String _getTotalDuration() {
    int totalMinutes = 0;
    for (var step in widget.steps) {
      if (step['duration'] != null) {
        totalMinutes += (step['duration'] as num).toInt();
      }
    }
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }

  int _getTotalStops() {
    int stops = 0;
    for (var step in widget.steps) {
      if (step['type'] == 'metro' && step['stops'] != null) {
        stops += (step['stops'] as num).toInt();
      }
    }
    return stops;
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    if (_startMarker != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("start"),
          position: LatLng(widget.startLat, widget.startLon),
          icon: _startMarker!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (_endMarker != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("end"),
          position: LatLng(widget.endLat, widget.endLon),
          icon: _endMarker!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (_interchangeMarker != null) {
      for (final p in getInterchangePoints()) {
        markers.add(
          Marker(
            markerId: MarkerId("interchange_${p.latitude}_${p.longitude}"),
            position: p,
            icon: _interchangeMarker!,
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }
    }

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
                final step = widget.steps[index];

                return TimelineStep(
                  title: getTitle(step),
                  subtitle: getSubtitle(step),
                  isLast: index == widget.steps.length - 1,
                  isTransfer: step["type"] == "transfer",
                  color: getStepColor(step),
                  icon: getStepIcon(step),
                );
              },
            ),

            // Map view with legend
            Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;

                    if (_mapStyle != null) {
                      _mapController!.setMapStyle(_mapStyle);
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(getBoundsWithBias(), 80),
                      );
                    });
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.startLat, widget.startLon),
                    zoom: 10,
                  ),
                  markers: markers,
                  zoomControlsEnabled: false,
                  polylines: buildMetroPolylines(),
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Map Legend
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem(const Color(0xFF4CAF50), 'Start'),
                        const SizedBox(height: 8),
                        _buildLegendItem(const Color(0xFFF44336), 'End'),
                        const SizedBox(height: 8),
                        _buildLegendItem(const Color(0xFF2196F3), 'Change'),
                      ],
                    ),
                  ),
                ),

                // Re-center button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngBounds(getBoundsWithBias(), 80),
                      );
                    },
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  bool isLoading = false;

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
              child: isLoading
                  ? Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          "Waking up server…\nThis may take up to 30 seconds on first request",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () async {
                        setState(() => isLoading = true);
                        try {
                          final response = await http.post(
                            Uri.parse(
                              "https://bangalore-transit-backend.onrender.com/route",
                            ),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              "from": fromController.text,
                              "to": toController.text,
                            }),
                          );

                          if (response.statusCode != 200) {
                            debugPrint("Server error: ${response.body}");
                            return;
                          }

                          final data = jsonDecode(response.body);

                          final steps = (data["steps"] as List)
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList();

                          final route =
                              (data["metroRoute"] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              [];

                          final segments =
                              (data["segments"] as List?)
                                  ?.map((e) => Map<String, dynamic>.from(e))
                                  .toList() ??
                              [];

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultScreen(
                                steps: steps,
                                startLat: (data["from"]["lat"] as num)
                                    .toDouble(),
                                startLon: (data["from"]["lon"] as num)
                                    .toDouble(),
                                endLat: (data["to"]["lat"] as num).toDouble(),
                                endLon: (data["to"]["lon"] as num).toDouble(),
                                metroRoute: route,
                                segments: segments,
                              ),
                            ),
                          );
                        } catch (e, stack) {
                          debugPrint("ERROR: $e");
                          debugPrintStack(stackTrace: stack);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Network error")),
                          );
                        } finally {
                          setState(() => isLoading = false);
                        }
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
