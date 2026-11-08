import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'ambil_foto_screen.dart';
import '../../services/pickup_service.dart';

class PengambilanSampahScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String userPhone;
  final String address;
  final String idPengambilan;
  final String distance;
  final String time;
  final double latitude;
  final double longitude;
  final String status; // Tambahkan parameter status
  final bool isOffSchedule; // Flag untuk off-schedule pickup

  const PengambilanSampahScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.userPhone,
    required this.address,
    required this.idPengambilan,
    required this.distance,
    required this.time,
    required this.latitude,
    required this.longitude,
    this.status = 'pending', // Default ke pending
    this.isOffSchedule = false, // Default bukan off-schedule
  });

  @override
  State<PengambilanSampahScreen> createState() =>
      _PengambilanSampahScreenState();
}

class _PengambilanSampahScreenState extends State<PengambilanSampahScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _animController;
  late Animation<double> _markerScale;
  bool _isConfirmed = false; // Status konfirmasi pengambilan

  // Current location tracking
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  // Colors
  static const Color primaryColor = Color(0xFF009688);

  Future<void> _openGoogleMaps(double lat, double lng) async {
    // Format URL dengan query parameter yang lebih jelas untuk navigasi
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    appLog('🗺️ Opening Google Maps with coordinates: $lat, $lng');
    appLog('🔗 URL: $googleMapsUrl');

    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
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

      // Fit bounds to show both markers
      _fitBounds();
    } catch (e) {
      appLog('[ERROR] Error getting location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _fitBounds() {
    if (_currentPosition == null) return;

    try {
      final pickupLat = widget.latitude;
      final pickupLng = widget.longitude;

      final bounds = LatLngBounds(
        LatLng(
          _currentPosition!.latitude < pickupLat
              ? _currentPosition!.latitude
              : pickupLat,
          _currentPosition!.longitude < pickupLng
              ? _currentPosition!.longitude
              : pickupLng,
        ),
        LatLng(
          _currentPosition!.latitude > pickupLat
              ? _currentPosition!.latitude
              : pickupLat,
          _currentPosition!.longitude > pickupLng
              ? _currentPosition!.longitude
              : pickupLng,
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

  double _calculateDistance() {
    if (_currentPosition == null) return 0;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.latitude,
      widget.longitude,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Pickup location marker (Green)
    markers.add(
      Marker(
        point: LatLng(widget.latitude, widget.longitude),
        width: 50,
        height: 50,
        child: ScaleTransition(
          scale: _markerScale,
          child: Container(
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
            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
          ),
        ),
      ),
    );

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
            child: const Icon(Icons.person_pin, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_currentPosition == null) return [];

    return [
      Polyline(
        points: [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(widget.latitude, widget.longitude),
        ],
        color: primaryColor,
        strokeWidth: 4,
        pattern: const StrokePattern.dotted(),
      ),
    ];
  }

  Future<void> _confirmPickup() async {
    // Untuk off-schedule pickup, langsung konfirmasi tanpa API call
    // karena backend belum support endpoint /start untuk off-schedule
    if (widget.isOffSchedule) {
      setState(() {
        _isConfirmed = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengambilan sampah dikonfirmasi!',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show loading untuk regular pickup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Mengkonfirmasi pengambilan...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    // Call API untuk regular pickup
    final (success, message) = await PickupService.startPickup(widget.pickupId);

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    if (success) {
      setState(() {
        _isConfirmed = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengambilan sampah dikonfirmasi!',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Gagal mengkonfirmasi pengambilan',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper method untuk format nomor telepon dari 0xxx menjadi +62xxx
  String _formatPhoneNumber(String phone) {
    // Bersihkan nomor dari spasi, dash, dan tanda kurung
    String formatted = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');

    // Jika diawali dengan 0, ganti dengan +62
    if (formatted.startsWith('0')) {
      return '+62${formatted.substring(1)}';
    }

    // Jika diawali dengan 62 tanpa +, tambahkan +
    if (formatted.startsWith('62') && !formatted.startsWith('+')) {
      return '+$formatted';
    }

    // Jika sudah benar formatnya, return as is
    return formatted;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Format nomor telepon ke format internasional (+62xxx)
    final String formattedPhone = _formatPhoneNumber(phoneNumber);
    final Uri phoneUri = Uri.parse('tel:$formattedPhone');

    if (!await launchUrl(phoneUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi telepon.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openChat(String phoneNumber) async {
    // Format nomor telepon ke format internasional (+62xxx)
    final String formattedPhone = _formatPhoneNumber(phoneNumber);

    // Untuk WhatsApp, hilangkan tanda + (butuh format 62xxx saja)
    final String whatsappNumber = formattedPhone
        .replaceAll('+', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    final Uri whatsappUri = Uri.parse('https://wa.me/$whatsappNumber');

    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<Widget> _buildContactButtons() {
    return [
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => _openChat(widget.userPhone),
          icon: const Icon(Icons.chat_bubble_outline),
          color: Colors.blue[600],
          iconSize: 22,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => _makePhoneCall(widget.userPhone),
          icon: const Icon(Icons.phone_outlined),
          color: Colors.green[600],
          iconSize: 22,
        ),
      ),
    ];
  }

  void _showFullScreenMap(LatLng location) {
    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.beresin_app',
                    maxZoom: 19,
                  ),
                  PolylineLayer(polylines: _buildPolylines()),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
              Positioned(
                top: 40,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              // Legend in fullscreen
              Positioned(
                left: 16,
                top: 80,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem(
                          color: Colors.green,
                          label: 'Lokasi Pengambilan',
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
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _markerScale = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();

    // Cek status - jika sudah on_progress, set _isConfirmed = true
    if (widget.status == 'on_progress') {
      _isConfirmed = true;
    }

    // Get current location
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng pickupLocation = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Pengambilan Sampah',
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
          // Map - Full expanded
          Expanded(
            child: Stack(
              children: [
                // OpenStreetMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: pickupLocation,
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
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: primaryColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Mendapatkan lokasi...',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
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
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        backgroundColor: Colors.white,
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'fullscreen',
                        backgroundColor: Colors.white,
                        onPressed: () => _showFullScreenMap(pickupLocation),
                        child: const Icon(
                          Icons.fullscreen,
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
                            label: 'Lokasi Pengambilan',
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
                  // User Info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User name
                        Text(
                          widget.userName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Address
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
                                widget.address,
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
                        const SizedBox(height: 4),
                        // ID Pengambilan
                        Row(
                          children: [
                            Icon(Icons.tag, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'ID Pengambilan: ${widget.idPengambilan}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Contact buttons
                        if (_isConfirmed &&
                            widget.userPhone.isNotEmpty &&
                            widget.userPhone != '-' &&
                            widget.userPhone != 'Tidak ada nomor' &&
                            widget.userPhone != 'Nomor tidak tersedia')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: _buildContactButtons(),
                          ),
                        // Distance badge (below contact buttons, aligned right)
                        if (_isConfirmed &&
                            widget.userPhone.isNotEmpty &&
                            widget.userPhone != '-' &&
                            widget.userPhone != 'Tidak ada nomor' &&
                            widget.userPhone != 'Nomor tidak tersedia' &&
                            _currentPosition != null)
                          const SizedBox(height: 12),
                        if (_currentPosition != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.straighten,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Jarak: ${_formatDistance(_calculateDistance())}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Divider
                  const Divider(height: 1),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Google Maps button
                        _lihatLokasiButton(primaryColor),
                        const SizedBox(height: 12),
                        // Main action button
                        _isConfirmed
                            ? _ambilFotoButton(primaryColor)
                            : _ambilButton(primaryColor),
                      ],
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

  Widget _lihatLokasiButton(Color primaryColor) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => _openGoogleMaps(widget.latitude, widget.longitude),
      icon: const Icon(Icons.map_outlined, color: Colors.white),
      label: Text(
        'Lihat di Google Maps',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[600],
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
  );

  Widget _ambilButton(Color primaryColor) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _confirmPickup,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        'Ambil',
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _ambilFotoButton(Color primaryColor) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () async {
        // Untuk off-schedule, langsung navigate tanpa API call
        if (widget.isOffSchedule) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AmbilFotoScreen(
                pickupId: widget.pickupId,
                userName: widget.userName,
                address: widget.address,
                idPengambilan: widget.idPengambilan,
                isOffSchedule: true,
              ),
            ),
          );
          return;
        }

        // Untuk regular pickup, panggil API dulu
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Memulai pengambilan...',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );

        // Call API to start pickup
        final (success, message) = await PickupService.startPickup(
          widget.pickupId,
        );

        // Close loading
        if (mounted) Navigator.of(context).pop();

        if (success) {
          // Navigate to photo screen
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AmbilFotoScreen(
                  pickupId: widget.pickupId,
                  userName: widget.userName,
                  address: widget.address,
                  idPengambilan: widget.idPengambilan,
                  isOffSchedule: false,
                ),
              ),
            );
          }
        } else {
          // Show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message ?? 'Gagal memulai pengambilan'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        'Ambil Foto',
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
