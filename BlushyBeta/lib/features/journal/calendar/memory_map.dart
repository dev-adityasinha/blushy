import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LocationPrivacyMode { off, approximateCity, preciseGps }

class MapPinMemory {
  final String id;
  final String title;
  final String cityName;
  final Offset mapCoordinates;
  final String previewSnippet;

  MapPinMemory({
    required this.id,
    required this.title,
    required this.cityName,
    required this.mapCoordinates,
    required this.previewSnippet,
  });
}

class MemoryMapWidget extends StatefulWidget {
  const MemoryMapWidget({super.key});

  @override
  State<MemoryMapWidget> createState() => _MemoryMapWidgetState();
}

class _MemoryMapWidgetState extends State<MemoryMapWidget> {
  LocationPrivacyMode _locationPrivacy = LocationPrivacyMode.approximateCity;

  final List<MapPinMemory> _pins = [
    MapPinMemory(id: '1', title: 'Sunset Beach Walk 🌊', cityName: 'Chennai Coast', mapCoordinates: const Offset(120, 180), previewSnippet: 'Felt so calm listening to ocean waves.'),
    MapPinMemory(id: '2', title: 'Mountain Coffee Shop ☕', cityName: 'Ooty Hills', mapCoordinates: const Offset(220, 100), previewSnippet: 'Warm herbal tea on a misty morning.'),
    MapPinMemory(id: '3', title: 'Old Town Bookstore 📚', cityName: 'Bangalore', mapCoordinates: const Offset(180, 260), previewSnippet: 'Discovered rare poetry books.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
        title: Text('Interactive Memory Map 📍', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE0F2FE),
        elevation: 0,
        actions: [
          PopupMenuButton<LocationPrivacyMode>(
            icon: const Icon(Icons.security_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Location Privacy Mode',
            onSelected: (mode) => setState(() => _locationPrivacy = mode),
            itemBuilder: (context) => const [
              PopupMenuItem(value: LocationPrivacyMode.off, child: Text('Location Off')),
              PopupMenuItem(value: LocationPrivacyMode.approximateCity, child: Text('Approximate City Only')),
              PopupMenuItem(value: LocationPrivacyMode.preciseGps, child: Text('Precise GPS')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Stylized Map Canvas Simulation
          Positioned.fill(
            child: Container(
              color: const Color(0xFFBAE6FD),
              child: CustomPaint(
                painter: _MapGridPainter(),
              ),
            ),
          ),

          if (_locationPrivacy != LocationPrivacyMode.off)
            ..._pins.map((pin) {
              return Positioned(
                left: pin.mapCoordinates.dx,
                top: pin.mapCoordinates.dy,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(pin.title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                        content: Text('${pin.cityName}\n\n"${pin.previewSnippet}"', style: GoogleFonts.caveat(fontSize: 18)),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: Text(
                          _locationPrivacy == LocationPrivacyMode.approximateCity ? pin.cityName : '${pin.cityName} (13.08° N)',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1)),
                        ),
                      ),
                      const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 28),
                    ],
                  ),
                ),
              );
            }),

          if (_locationPrivacy == LocationPrivacyMode.off)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Text('Location features are currently turned OFF for privacy.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
