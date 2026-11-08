import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/tps.dart';
import '../../services/tps_deposit_service.dart';

/// Screen untuk menampilkan peta lokasi TPS menggunakan OpenStreetMap
class TPSMapScreen extends StatefulWidget {
  final TPS tps;

  const TPSMapScreen({super.key, required this.tps});

  @override
  State<TPSMapScreen> createState() => _TPSMapScreenState();
}

class _TPSMapScreenState extends State<TPSMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSubmitting = false;
  final TextEditingController _noteController = TextEditingController();

  // Colors
  static const Color primaryColor = Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackbar('Izin lokasi ditolak');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackbar(
          'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.',
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Move camera to show both markers
      _fitBounds();
    } catch (e) {
      appLog('[ERROR] Error getting location: $e');
      setState(() => _isLoadingLocation = false);
      _showErrorSnackbar('Gagal mendapatkan lokasi: $e');
    }
  }

  void _fitBounds() {
    if (_currentPosition == null) return;
    if (widget.tps.latitude == null || widget.tps.longitude == null) return;

    try {
      final bounds = LatLngBounds(
        LatLng(
          _currentPosition!.latitude < widget.tps.latitude!
              ? _currentPosition!.latitude
              : widget.tps.latitude!,
          _currentPosition!.longitude < widget.tps.longitude!
              ? _currentPosition!.longitude
              : widget.tps.longitude!,
        ),
        LatLng(
          _currentPosition!.latitude > widget.tps.latitude!
              ? _currentPosition!.latitude
              : widget.tps.latitude!,
          _currentPosition!.longitude > widget.tps.longitude!
              ? _currentPosition!.longitude
              : widget.tps.longitude!,
        ),
      );

      // Add some padding
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    } catch (e) {
      appLog('Error fitting bounds: $e');
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // TPS Marker (Green)
    if (widget.tps.latitude != null && widget.tps.longitude != null) {
      markers.add(
        Marker(
          point: LatLng(widget.tps.latitude!, widget.tps.longitude!),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _showMarkerInfo(
                widget.tps.name,
                widget.tps.address,
                isCurrentLocation: false,
              );
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Current location marker (Blue)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _showMarkerInfo(
                'Lokasi Anda',
                'Posisi saat ini',
                isCurrentLocation: true,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_pin,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_currentPosition == null ||
        widget.tps.latitude == null ||
        widget.tps.longitude == null) {
      return [];
    }

    return [
      Polyline(
        points: [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(widget.tps.latitude!, widget.tps.longitude!),
        ],
        color: primaryColor,
        strokeWidth: 4,
        pattern: const StrokePattern.dotted(),
      ),
    ];
  }

  void _showMarkerInfo(
    String title,
    String subtitle, {
    required bool isCurrentLocation,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isCurrentLocation ? Icons.person_pin : Icons.delete_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isCurrentLocation ? Colors.blue : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _calculateDistance() {
    if (_currentPosition == null ||
        widget.tps.latitude == null ||
        widget.tps.longitude == null) {
      return 0;
    }

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.tps.latitude!,
      widget.tps.longitude!,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  Future<void> _submitDeposit() async {
    if (_currentPosition == null) {
      _showErrorSnackbar('Lokasi belum tersedia. Coba lagi.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final (success, message, deposit) = await TPSDepositService.submitDeposit(
        garbageDumpId: widget.tps.id,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        notes: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (!mounted) return;

      if (success && deposit != null) {
        _showSuccessDialog(deposit);
      } else {
        _showErrorSnackbar(message ?? 'Gagal menyimpan data setor');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Konfirmasi Setor',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TPS Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tps.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.tps.address,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Note input
            Text(
              'Catatan (opsional):',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 16),

            Text(
              'Apakah Anda yakin telah menyerahkan sampah ke TPS ini?',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitDeposit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Ya, Setor Sampah',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(dynamic deposit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Berhasil!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sampah berhasil disetor ke ${widget.tps.name}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Return to previous screen with success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidCoordinates =
        widget.tps.latitude != null && widget.tps.longitude != null;

    // Default center (Jakarta) if no coordinates
    const defaultCenter = LatLng(-6.2088, 106.8456);
    final tpsLocation = hasValidCoordinates
        ? LatLng(widget.tps.latitude!, widget.tps.longitude!)
        : defaultCenter;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Lokasi TPS',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_currentPosition != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () {
                _mapController.move(
                  LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  15,
                );
              },
              tooltip: 'Lokasi Saya',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Lokasi',
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: hasValidCoordinates
                ? Stack(
                    children: [
                      // OpenStreetMap
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: tpsLocation,
                          initialZoom: 15,
                          minZoom: 3,
                          maxZoom: 18,
                          onMapReady: () {
                            if (_currentPosition != null) {
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                _fitBounds,
                              );
                            }
                          },
                        ),
                        children: [
                          // OpenStreetMap Tile Layer
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.beresin_app',
                            maxZoom: 19,
                          ),
                          // Polyline Layer (route)
                          PolylineLayer(polylines: _buildPolylines()),
                          // Markers Layer
                          MarkerLayer(markers: _buildMarkers()),
                        ],
                      ),

                      // Loading overlay
                      if (_isLoadingLocation)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: primaryColor,
                                    ),
                                    SizedBox(height: 16),
                                    Text('Mendapatkan lokasi...'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Zoom controls
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoom_in',
                              backgroundColor: Colors.white,
                              onPressed: () {
                                final currentZoom = _mapController.camera.zoom;
                                _mapController.move(
                                  _mapController.camera.center,
                                  currentZoom + 1,
                                );
                              },
                              child: const Icon(
                                Icons.add,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom_out',
                              backgroundColor: Colors.white,
                              onPressed: () {
                                final currentZoom = _mapController.camera.zoom;
                                _mapController.move(
                                  _mapController.camera.center,
                                  currentZoom - 1,
                                );
                              },
                              child: const Icon(
                                Icons.remove,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Legend
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLegendItem(
                                  color: Colors.green,
                                  label: 'Lokasi TPS',
                                ),
                                const SizedBox(height: 8),
                                _buildLegendItem(
                                  color: Colors.blue,
                                  label: 'Lokasi Anda',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Attribution
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '© OpenStreetMap',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Koordinat TPS tidak tersedia',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Bottom panel
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TPS Info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // TPS Image
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: widget.tps.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    widget.tps.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.delete_outline,
                                      size: 30,
                                      color: primaryColor,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                  size: 30,
                                  color: primaryColor,
                                ),
                        ),
                        const SizedBox(width: 12),

                        // TPS Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.tps.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.tps.address,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (_currentPosition != null &&
                                  hasValidCoordinates) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.straighten,
                                      size: 14,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Jarak: ${_formatDistance(_calculateDistance())}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.tps.status == 'active'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.tps.status == 'active'
                                ? 'Aktif'
                                : 'Nonaktif',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.tps.status == 'active'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  const Divider(height: 1),

                  // Submit button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || !hasValidCoordinates
                            ? null
                            : _showConfirmDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.local_shipping, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Setor Sampah ke TPS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 11)),
      ],
    );
  }
}
