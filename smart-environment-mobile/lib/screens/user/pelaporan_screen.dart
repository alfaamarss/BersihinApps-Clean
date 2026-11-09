import 'package:beresin_app/utils/app_log.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/notification_helper.dart';
import '../../services/complaint_service.dart';
import '../../services/service_account_service.dart';
import '../../models/complaint.dart';
import '../../models/service_account.dart';
import '../../config/api_config.dart';
import '../../utils/file.dart' as custom_file;
import '../../utils/file.dart'; // Import untuk createFileFromBytes
import '../../utils/image_builder.dart';
import '../../widgets/resolution_photos_gallery.dart';
import '../../widgets/auto_fill_demo_button.dart';

// Fungsi utama untuk menjalankan aplikasi
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Pelaporan',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        // Mengatur tema warna primer
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal),
        useMaterial3: true,
      ),
      home: const PelaporanScreen(), // Mulai dari layar utama
    );
  }
}

// ====================================================================
// BAGIAN 0: MODEL DATA
// ====================================================================

// Model data untuk menyimpan satu laporan
class Laporan {
  final String id;
  final String kota;
  final String kategori;
  final String lokasi;
  final String waktuPelanggaran;
  final String ciriCiri;
  final String? serviceAccount; // Service account ID yang dilaporkan
  final String? serviceAccountName; // Service account name untuk display
  final custom_file.File? imageFile;
  final String? photoUrl; // URL foto dari API (deprecated - use photoUrls)
  final List<String> photoUrls; // Multiple photo URLs dari API
  final List<String>
  resolutionPhotoUrls; // ✅ Multiple foto resolution dari collector
  final bool isAsset;
  final DateTime createdAt;
  final DateTime updatedAt; // ✅ NEW: Waktu update terakhir dari API
  final String
  status; // Status dari database: 'open', 'in_progress', 'pending_confirmation', 'resolved', 'rejected'
  final String? type; // ✅ NEW: Tipe asli dari API (sampah_tidak_diangkut, dll)
  final String? rejectionReason; // ✅ NEW: Alasan penolakan

  Laporan({
    String? id, // ✅ FIXED: Accept ID from API
    required this.kota,
    required this.kategori,
    required this.lokasi,
    required this.waktuPelanggaran,
    required this.ciriCiri,
    this.serviceAccount,
    this.serviceAccountName,
    this.imageFile,
    this.photoUrl,
    this.photoUrls = const [], // Default empty list
    this.resolutionPhotoUrls =
        const [], // ✅ Multiple foto resolution dari collector
    required this.isAsset,
    this.status = 'open', // Default status
    this.type, // ✅ NEW
    this.rejectionReason, // ✅ NEW
    DateTime? createdAt, // ✅ FIXED: Accept createdAt from API
    DateTime? updatedAt, // ✅ NEW: Accept updatedAt from API
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  // Get status display text in Indonesian
  String get statusText {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Menunggu';
      case 'in_progress':
        return 'Diproses';
      case 'pending_confirmation': // ✅ NEW
        return 'Menunggu Konfirmasi';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  // ✅ NEW: Check if this is "sampah_tidak_diangkut" type complaint
  bool get isSampahTidakDiangkut {
    final typeCheck = type?.toLowerCase() == 'sampah_tidak_diangkut';
    final kategoriCheck =
        kategori.toLowerCase().contains('sampah') &&
        kategori.toLowerCase().contains('tidak') &&
        kategori.toLowerCase().contains('diangkut');
    return typeCheck || kategoriCheck;
  }

  // ✅ NEW: Check if confirmation is needed
  bool get needsConfirmation {
    return isSampahTidakDiangkut &&
        status.toLowerCase() == 'pending_confirmation';
  }

  // Helper untuk mendapatkan deskripsi singkat
  String get shortDescription => "$kategori di $lokasi";

  // Convert to JSON (untuk penyimpanan)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kota': kota,
      'kategori': kategori,
      'lokasi': lokasi,
      'waktuPelanggaran': waktuPelanggaran,
      'ciriCiri': ciriCiri,
      'serviceAccount': serviceAccount,
      'serviceAccountName': serviceAccountName,
      'imagePath': imageFile?.path,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'resolutionPhotoUrls': resolutionPhotoUrls,
      'isAsset': isAsset,
      'status': status,
      'type': type,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON (untuk load data)
  factory Laporan.fromJson(Map<String, dynamic> json) {
    return Laporan(
      kota: json['kota'] as String,
      kategori: json['kategori'] as String,
      lokasi: json['lokasi'] as String,
      waktuPelanggaran: json['waktuPelanggaran'] as String,
      ciriCiri: json['ciriCiri'] as String,
      serviceAccount: json['serviceAccount'] as String?,
      serviceAccountName: json['serviceAccountName'] as String?,
      imageFile: json['imagePath'] != null
          ? custom_file.File(json['imagePath'] as String)
          : null,
      photoUrl: json['photoUrl'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      resolutionPhotoUrls:
          (json['resolutionPhotoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      isAsset: json['isAsset'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
      type: json['type'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

// ====================================================================
// BAGIAN 1: SCREEN FORM PENGISIAN LAPORAN (BuatLaporanScreen)
// ====================================================================

class BuatLaporanScreen extends StatefulWidget {
  final custom_file.File? imageFile;
  final bool isAsset;
  final String? initialType;
  final String? initialLocation;
  final String? initialServiceAccountId;
  final String? initialServiceAccountName;
  final bool
  fromRiwayatPengambilan; // ✅ NEW: Flag untuk menandai dari riwayat pengambilan

  const BuatLaporanScreen({
    super.key,
    required this.imageFile,
    required this.isAsset,
    this.initialType,
    this.initialLocation,
    this.initialServiceAccountId,
    this.initialServiceAccountName,
    this.fromRiwayatPengambilan =
        false, // ✅ Default false (dari menu pelaporan biasa)
  });

  @override
  State<BuatLaporanScreen> createState() => _BuatLaporanScreenState();
}

class _BuatLaporanScreenState extends State<BuatLaporanScreen> {
  // Controller untuk mengelola input text
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();

  // ✅ Pilihan Kategori - dinamis berdasarkan sumber navigasi
  // "Sampah Tidak Diangkut" hanya muncul jika dari riwayat pengambilan
  List<Map<String, String>> get _types {
    if (widget.fromRiwayatPengambilan) {
      // Dari riwayat pengambilan (konfirmasi sampah belum diambil) - semua kategori
      return const [
        {'value': 'sampah_tidak_diangkut', 'label': 'Sampah Tidak Diangkut'},
        {'value': 'sampah_menumpuk', 'label': 'Sampah Menumpuk'},
        {'value': 'jadwal_tidak_sesuai', 'label': 'Jadwal Tidak Sesuai'},
        {'value': 'pelayanan_buruk', 'label': 'Pelayanan Buruk'},
        {'value': 'petugas_tidak_datang', 'label': 'Petugas Tidak Datang'},
        {'value': 'lainnya', 'label': 'Lainnya'},
      ];
    } else {
      // Dari menu pelaporan biasa - TANPA "Sampah Tidak Diangkut"
      return const [
        {'value': 'sampah_menumpuk', 'label': 'Sampah Menumpuk'},
        {'value': 'jadwal_tidak_sesuai', 'label': 'Jadwal Tidak Sesuai'},
        {'value': 'pelayanan_buruk', 'label': 'Pelayanan Buruk'},
        {'value': 'petugas_tidak_datang', 'label': 'Petugas Tidak Datang'},
        {'value': 'lainnya', 'label': 'Lainnya'},
      ];
    }
  }

  // State untuk menyimpan tipe yang dipilih
  String? _selectedType;

  // State untuk service account
  List<ServiceAccount> _serviceAccounts = [];
  String? _selectedServiceAccountId; // Tidak set default, biarkan null
  bool _isLoadingServiceAccounts = false;

  // State untuk map
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  bool _isLoadingLocation = false;
  double _currentZoom = 15.0;
  Timer? _debounceTimer;

  // Kunci form untuk validasi
  final _formKey = GlobalKey<FormState>();

  // Warna Utama
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _loadServiceAccounts();
    // Tambahkan image dari parent jika ada
    if (widget.imageFile != null) {
      _selectedImages.add(widget.imageFile!);
    }
    // Set initial values jika ada
    if (widget.initialType != null) {
      _selectedType = widget.initialType;
    }
    if (widget.initialLocation != null) {
      _lokasiController.text = widget.initialLocation!;
    }
    // Load service accounts terlebih dahulu
    _loadServiceAccounts().then((_) {
      // Set service account ID setelah data dimuat
      if (widget.initialServiceAccountId != null) {
        setState(() {
          _selectedServiceAccountId = widget.initialServiceAccountId;
        });
      }
    });

    // Tambahkan debouncing listener untuk geocoding
    _lokasiController.addListener(() {
      // Cancel previous timer if exists
      _debounceTimer?.cancel();

      // Set new timer untuk geocoding setelah 1 detik user berhenti mengetik
      _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
        if (_lokasiController.text.isNotEmpty && _shouldShowMap()) {
          _geocodeAddress(_lokasiController.text);
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _deskripsiController.dispose();
    _lokasiController.dispose();
    super.dispose();
  }

  // Fungsi untuk mendapatkan lokasi saat ini
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Izin lokasi ditolak permanen. Aktifkan di pengaturan.',
        );
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.medium,
                forceLocationManager: true,
                timeLimit: const Duration(seconds: 15),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 15),
              ),
      );

      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Lokasi Saat Ini';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address =
            '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}';
      }

      setState(() {
        _selectedLocation = location;
        _lokasiController.text = address;
        _isLoadingLocation = false;
      });

      // Move map to location
      _mapController.move(location, _currentZoom);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lokasi tidak tersedia. Silakan ketuk peta untuk memilih lokasi manual.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // Fungsi untuk pick location dari map
  Future<void> _pickLocationFromMap(LatLng location) async {
    if (!mounted) return;

    try {
      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      String address = '${location.latitude}, ${location.longitude}';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address =
            '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}'
                .replaceAll(
                  RegExp(r'^,\s*|,\s*$'),
                  '',
                ) // Remove leading/trailing commas
                .replaceAll(RegExp(r',\s*,'), ','); // Remove double commas
        if (address.isEmpty) {
          address = '${location.latitude}, ${location.longitude}';
        }
      }

      setState(() {
        _selectedLocation = location;
        _lokasiController.text = address;
      });
    } catch (e) {
      appLog('Error getting address: $e');
      setState(() {
        _selectedLocation = location;
        _lokasiController.text = '${location.latitude}, ${location.longitude}';
      });
    }
  }

  // Fungsi untuk geocoding dari alamat ke koordinat
  Future<void> _geocodeAddress(String address) async {
    if (address.isEmpty || !mounted) return;

    try {
      setState(() {
        _isLoadingLocation = true;
      });

      final locations = await locationFromAddress(address);

      if (locations.isNotEmpty && mounted) {
        final location = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );

        setState(() {
          _selectedLocation = location;
          _isLoadingLocation = false;
        });

        // Move map to the new location
        _mapController.move(location, _currentZoom);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        // Show error if address not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Alamat tidak ditemukan. Silakan coba lagi atau pilih di peta.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fungsi untuk memuat service accounts dari API
  Future<void> _loadServiceAccounts() async {
    setState(() {
      _isLoadingServiceAccounts = true;
    });

    try {
      final serviceAccountService = ServiceAccountService();
      final accounts = await serviceAccountService.fetchAccounts();

      setState(() {
        _serviceAccounts = accounts;
        _isLoadingServiceAccounts = false;
      });

      appLog('[OK] Loaded ${accounts.length} service accounts');
    } catch (e) {
      setState(() {
        _isLoadingServiceAccounts = false;
      });

      appLog('[ERROR] Error loading service accounts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'Gagal memuat service account: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  // Fungsi Navigasi ke DetailLaporanScreen
  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // Pastikan dropdown terisi
      if (_selectedType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Mohon pilih kategori laporan.",
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        return;
      }

      // Validasi foto hanya untuk kategori yang membutuhkan foto
      if (_shouldShowPhotoAndLocation() && _selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Mohon tambahkan foto bukti laporan.",
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        return;
      }

      // Debug print
      appLog('[SEARCH] _selectedType: $_selectedType');
      appLog(
        '[SEARCH] _deskripsiController.text: ${_deskripsiController.text}',
      );
      appLog('[SEARCH] _selectedServiceAccountId: $_selectedServiceAccountId');

      // Ambil data dari state dan controller
      final reportData = <String, String>{
        'type': _selectedType ?? '', // API field: type - dengan fallback
        'deskripsi': _deskripsiController.text.isNotEmpty
            ? _deskripsiController.text
            : 'Tidak ada deskripsi', // API field: description - dengan fallback
        // Lokasi hanya diisi jika kategori membutuhkannya
        'lokasi': _shouldShowPhotoAndLocation()
            ? _lokasiController.text
            : '', // API field: location
      };

      // Tambahkan service account hanya jika dipilih
      if (_selectedServiceAccountId != null &&
          _selectedServiceAccountId!.isNotEmpty) {
        reportData['serviceAccount'] = _selectedServiceAccountId!;
      }

      appLog('[SEARCH] reportData: $reportData');

      // Navigasi ke DetailLaporanScreen dengan list images
      final navigator = Navigator.of(context);
      navigator
          .push(
            MaterialPageRoute<Laporan>(
              builder: (ctx) => DetailLaporanScreen(
                reportData: reportData,
                imageFiles: _selectedImages,
                isAsset: widget.isAsset,
              ),
            ),
          )
          .then((newReport) {
            // Jika DetailLaporanScreen me-return objek Laporan
            if (newReport is Laporan && navigator.mounted) {
              // Kirim objek Laporan kembali ke PelaporanScreen
              navigator.pop(newReport);
            }
          });
    }
  }

  Future<bool> _autoFillDemo() async {
    try {
      final imageData = await rootBundle.load('assets/images/dummy.jpg');
      final demoImage = await custom_file.createFileFromDemoAsset(
        'complaint-demo.jpg',
        imageData.buffer.asUint8List(
          imageData.offsetInBytes,
          imageData.lengthInBytes,
        ),
      );
      final demoType = _types.firstWhere(
        (type) => type['value'] == 'sampah_menumpuk',
      );

      if (!mounted) return false;
      setState(() {
        _selectedType = demoType['value'];
        _selectedLocation = null;
        _lokasiController.text =
            'Jl. Melati No. 12, RT 03/RW 05, Jakarta Selatan';
        _deskripsiController.text =
            'Sampah menumpuk di area permukiman.\n'
            'Tumpukan sampah rumah tangga belum diangkut selama beberapa hari '
            'dan mulai menimbulkan bau di sekitar permukiman.';
        _selectedImages
          ..clear()
          ..add(demoImage);
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data contoh: $error')),
      );
      return false;
    }
  }

  // Fungsi untuk memilih foto (galeri/kamera)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final customFile = createFileFromBytes(pickedFile.path, bytes);

        setState(() {
          _selectedImages.add(customFile);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Gagal mengambil gambar: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  // Helper untuk mendapatkan nama service account yang dipilih
  String _getSelectedServiceAccountName() {
    if (_selectedServiceAccountId == null) return 'Tidak dipilih';

    final account = _serviceAccounts.firstWhere(
      (a) => a.id == _selectedServiceAccountId,
      orElse: () => ServiceAccount(
        id: _selectedServiceAccountId!,
        name: _selectedServiceAccountId!,
        address: '',
        latitude: 0,
        longitude: 0,
        status: 'active',
      ),
    );

    String name = account.name;
    if (account.rwName != null && account.rwName!.isNotEmpty) {
      final rwDisplay = account.rwName!.toUpperCase().startsWith('RW')
          ? account.rwName!
          : 'RW ${account.rwName}';
      name = '$name ($rwDisplay)';
    }
    return name;
  }

  // Fungsi untuk menampilkan dialog pilihan foto
  void _showPickerOptions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pilih Foto',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionButton(
              icon: Icons.photo_library,
              label: 'Pilih dari Galeri',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
            _OptionButton(
              icon: Icons.camera_alt,
              label: 'Ambil Foto',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  final List<custom_file.File> _selectedImages = [];

  // Helper untuk cek apakah kategori butuh map
  bool _shouldShowMap() {
    return _selectedType == 'sampah_menumpuk' || _selectedType == 'lainnya';
  }

  // Helper untuk cek apakah kategori butuh foto dan lokasi
  // Tampilkan untuk "sampah_tidak_diangkut", "sampah_menumpuk", dan "lainnya"
  bool _shouldShowPhotoAndLocation() {
    return _selectedType == 'sampah_tidak_diangkut' ||
        _selectedType == 'sampah_menumpuk' ||
        _selectedType == 'lainnya';
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;

    // Gunakan foto yang sudah dipilih
    final hasImages = _selectedImages.isNotEmpty;

    if (hasImages) {
      // Tampilkan horizontal scroll untuk multiple images
      imageWidget = Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _selectedImages.length + 1, // +1 untuk tombol tambah
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              // Tombol untuk tambah foto
              return GestureDetector(
                onTap: _showPickerOptions,
                child: Container(
                  width: 160,
                  height: 200,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tambah Foto',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Tampilkan foto yang sudah dipilih
            return Container(
              width: 280,
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: buildPlatformImage(
                        _selectedImages[index],
                        fit: BoxFit.cover,
                        width: 280,
                        height: 200,
                      ),
                    ),
                  ),
                  // Badge nomor foto
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}/${_selectedImages.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Tombol hapus foto
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      // Placeholder untuk upload foto pertama
      imageWidget = GestureDetector(
        onTap: _showPickerOptions,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/camera-plus.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback jika gambar tidak ditemukan
                return Icon(
                  Icons.add_a_photo,
                  size: 80,
                  color: Colors.grey.shade400,
                );
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoFillDemoButton(
                isFormEmpty:
                    _selectedType == null &&
                    _deskripsiController.text.trim().isEmpty &&
                    _lokasiController.text.trim().isEmpty &&
                    _selectedServiceAccountId == null &&
                    _selectedImages.isEmpty,
                onFill: _autoFillDemo,
              ),
              const SizedBox(height: 16),

              // Area Foto dengan Tombol Ubah Foto - HANYA untuk Sampah Tidak Diangkut & Sampah Menumpuk
              if (_shouldShowPhotoAndLocation()) ...[
                Container(
                  width: double.infinity,
                  height: 200, // Fixed height untuk menjaga konsistensi
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit:
                          StackFit.expand, // Memastikan stack mengisi container
                      children: [
                        // Pastikan image mengisi seluruh area
                        SizedBox(
                          width: double.infinity,
                          height: 200,
                          child: imageWidget,
                        ),
                        // Tombol Ubah Foto dengan posisi absolut
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _showPickerOptions,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(
                                color: Color(
                                  0xFF3D3D3D,
                                ), // Warna dark gray solid seperti di Figma
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Text(
                                "UBAH FOTO",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Info jumlah foto jika ada multiple images
                if (_selectedImages.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedImages.length} foto siap diupload',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],

              // --- FORM FIELDS YANG DIPERLUKAN API ---

              // Dropdown KATEGORI/TYPE
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: "Kategori",
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(
                      type['label']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
                hint: const Text('Pilih Kategori'),
                validator: (value) =>
                    value == null ? 'Kategori wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              // Map Picker untuk kategori Sampah Menumpuk dan Lainnya
              if (_shouldShowMap()) ...[
                Text(
                  'Pilih Lokasi di Peta',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:
                                _selectedLocation ??
                                const LatLng(-6.2088, 106.8456),
                            initialZoom: _currentZoom,
                            minZoom: 3.0,
                            maxZoom: 19.0,
                            onTap: (tapPosition, point) {
                              if (!mounted) return;
                              _pickLocationFromMap(point);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.beresin_app',
                              maxNativeZoom: 19,
                            ),
                            if (_selectedLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLocation!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: primaryColor,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        // Fullscreen Button
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => _FullscreenMapScreen(
                                      initialLocation:
                                          _selectedLocation ??
                                          const LatLng(-6.2088, 106.8456),
                                      initialZoom: _currentZoom,
                                      onLocationSelected: (location) {
                                        _pickLocationFromMap(location);
                                      },
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.black87,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Zoom Controls
                        Positioned(
                          right: 16,
                          bottom: 80,
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _currentZoom = (_currentZoom + 1).clamp(
                                        3.0,
                                        19.0,
                                      );
                                    });
                                    _mapController.move(
                                      _selectedLocation ??
                                          const LatLng(-6.2088, 106.8456),
                                      _currentZoom,
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.add, size: 18),
                                  ),
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 1,
                                color: Colors.grey.shade300,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _currentZoom = (_currentZoom - 1).clamp(
                                        3.0,
                                        19.0,
                                      );
                                    });
                                    _mapController.move(
                                      _selectedLocation ??
                                          const LatLng(-6.2088, 106.8456),
                                      _currentZoom,
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.remove, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tombol Get Current Location
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            elevation: 2,
                            child: InkWell(
                              onTap: _isLoadingLocation
                                  ? null
                                  : _getCurrentLocation,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: _isLoadingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ketuk peta untuk memilih lokasi atau klik tombol lokasi untuk menggunakan GPS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Field Lokasi - HANYA untuk Sampah Tidak Diangkut & Sampah Menumpuk
              if (_shouldShowPhotoAndLocation()) ...[
                // Tampilkan info jika lokasi sudah dipilih otomatis
                if (widget.initialLocation != null &&
                    widget.initialLocation!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lokasi sudah terisi otomatis dari data service account',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextFormField(
                  controller: _lokasiController,
                  decoration: InputDecoration(
                    labelText: "Lokasi",
                    hintText: "Masukkan alamat lokasi kejadian",
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: widget.initialLocation != null
                        ? "Anda dapat mengubah lokasi jika diperlukan"
                        : "Contoh: Jl. Sudirman No. 123, Jakarta",
                    helperMaxLines: 2,
                  ),
                  maxLength: 255,
                  validator: (value) {
                    // Validasi hanya jika field ini ditampilkan
                    if (value == null || value.trim().isEmpty) {
                      return 'Lokasi wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Service Account Dropdown (Opsional)
              // Tampilkan info jika service account sudah dipilih otomatis
              if (widget.initialServiceAccountId != null &&
                  widget.initialServiceAccountId!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Service Account sudah dipilih otomatis dari data pengambilan sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tampilkan sebagai read-only field (bukan dropdown) jika sudah dipilih dari menu daftar layanan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_circle,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service Account',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getSelectedServiceAccountName(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.lock, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ),
              ] else ...[
                // Dropdown normal jika tidak ada initial service account
                DropdownButtonFormField<String>(
                  initialValue: _selectedServiceAccountId,
                  decoration: InputDecoration(
                    labelText: "Service Account (Opsional)",
                    prefixIcon: const Icon(Icons.account_circle),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: widget.initialServiceAccountId != null
                        ? "Anda dapat mengubah pilihan jika diperlukan"
                        : "Kosongkan jika tidak tahu ID service account",
                    helperMaxLines: 2,
                  ),
                  isExpanded: true, // ✅ PENTING: Agar dropdown full width
                  items: _serviceAccounts.isEmpty
                      ? [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Tidak ada service account tersedia'),
                          ),
                        ]
                      : [
                          // Option untuk tidak memilih service account
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('-- Pilih Service Account --'),
                          ),
                          // Service accounts dari API
                          ..._serviceAccounts.map((account) {
                            return DropdownMenuItem<String>(
                              value: account.id,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_city,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          account.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (account.rwName != null &&
                                            account.rwName!.isNotEmpty)
                                          Text(
                                            // ✅ PERBAIKAN: Cek apakah rwName sudah mengandung "RW"
                                            account.rwName!
                                                    .toUpperCase()
                                                    .startsWith('RW')
                                                ? account.rwName!
                                                : 'RW ${account.rwName}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                  onChanged: _isLoadingServiceAccounts
                      ? null
                      : (value) {
                          appLog('[SEARCH] Service Account Selected: $value');
                          setState(() {
                            // ✅ PERBAIKAN: Set ke null jika empty string
                            _selectedServiceAccountId =
                                (value == null || value.isEmpty) ? null : value;
                          });
                        },
                  selectedItemBuilder: (BuildContext context) {
                    // ✅ PENTING: Custom builder untuk menampilkan selected value
                    return [
                      // Empty option
                      Text(
                        '-- Pilih Service Account --',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      // Service accounts
                      ..._serviceAccounts.map((account) {
                        return Text(
                          account.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ];
                  },
                  hint: _isLoadingServiceAccounts
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Memuat service account...',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ],
                        )
                      : Text(
                          _serviceAccounts.isEmpty
                              ? 'Tidak ada data'
                              : 'Pilih Service Account',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                  // Tidak ada validator - field ini opsional
                ),
              ], // Penutup else untuk dropdown Service Account
              const SizedBox(height: 16),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                maxLines: 5,
                maxLength: 1000, // Sesuai validasi API
                decoration: InputDecoration(
                  labelText: "Deskripsi",
                  hintText: "Jelaskan detail keluhan Anda...",
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) => value!.isEmpty
                    ? 'Ciri-ciri wajib diisi.'
                    : null, // Tambahkan validasi
              ),
              const SizedBox(height: 32),

              // Tombol BUAT LAPORAN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport, // Panggil fungsi submit
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "BUAT LAPORAN",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// BAGIAN 1.5: SCREEN DETAIL LAPORAN (DetailLaporanScreen)
// ====================================================================

class DetailLaporanScreen extends StatelessWidget {
  final Map<String, String> reportData;
  final List<custom_file.File> imageFiles;
  final bool isAsset;

  const DetailLaporanScreen({
    super.key,
    required this.reportData,
    required this.imageFiles,
    required this.isAsset,
  });

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // Type mapping untuk mendapatkan label dari value
  static const List<Map<String, String>> _types = [
    {'value': 'sampah_tidak_diangkut', 'label': 'Sampah Tidak Diangkut'},
    {'value': 'sampah_menumpuk', 'label': 'Sampah Menumpuk'},
    {'value': 'jadwal_tidak_sesuai', 'label': 'Jadwal Tidak Sesuai'},
    {'value': 'pelayanan_buruk', 'label': 'Pelayanan Buruk'},
    {'value': 'petugas_tidak_datang', 'label': 'Petugas Tidak Datang'},
    {'value': 'lainnya', 'label': 'Lainnya'},
  ];

  // Fungsi: Menampilkan modal konfirmasi dan mengirim laporan ke API
  void _confirmReport(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Mengirim laporan...",
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        );
      },
    );

    try {
      // 🔹 Kirim ke API menggunakan ComplaintService
      appLog('[SEND] Sending complaint to API...');
      appLog('  Type: ${reportData['type']}');
      appLog('  Description: ${reportData['deskripsi']}');
      appLog('  Location: ${reportData['lokasi']}');
      appLog('  Service Account: ${reportData['serviceAccount']}');
      appLog('  Has Images: ${imageFiles.length}');

      // Kirim semua foto ke API
      final (success, message, data) = await ComplaintService.createComplaint(
        type: reportData['type']!, // Langsung dari dropdown value
        description: reportData['deskripsi']!,
        location: reportData['lokasi']!, // Tambahkan lokasi
        serviceAccountId: reportData['serviceAccount'] != null
            ? int.tryParse(reportData['serviceAccount']!)
            : null, // Convert String to int
        images: imageFiles, // Kirim semua foto
      );

      appLog('[RECV] API Response - Success: $success, Message: $message');

      // Tutup loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (success && data != null) {
        // 1. Parse response menjadi Complaint object (optional - tidak critical untuk flow)
        appLog('[OK] API Success! Data: $data');
        Complaint? complaint;
        try {
          complaint = Complaint.fromJson(data);
          appLog('[OK] Complaint parsed: ${complaint.id}');
        } catch (e) {
          appLog('[WARN] Warning: Could not parse Complaint: $e');
          // Continue anyway, complaint parsing tidak critical
        }

        // 2. Buat objek Laporan untuk kompatibilitas UI (temporary mapping)
        // Note: Laporan model masih menggunakan struktur lama untuk backward compatibility
        appLog('[LIST] reportData: $reportData');

        final String typeValue = reportData['type'] ?? 'lainnya';
        appLog('[LIST] typeValue from reportData: $typeValue');

        final typeLabel =
            _types.firstWhere(
              (t) => t['value'] == typeValue,
              orElse: () => {'value': typeValue, 'label': 'Lainnya'},
            )['label'] ??
            'Lainnya';
        appLog('[OK] typeLabel: $typeLabel');

        final newReport = Laporan(
          kota: 'Jakarta', // Default
          kategori: typeLabel, // Gunakan label untuk display
          lokasi: reportData['lokasi'] ?? '', // Ambil dari form
          waktuPelanggaran: DateFormat(
            'dd MMMM yyyy HH:mm',
          ).format(DateTime.now()),
          ciriCiri:
              reportData['deskripsi'] ??
              'Tidak ada deskripsi', // Fallback jika null
          serviceAccount: reportData['serviceAccount'], // Ambil dari form
          imageFile: imageFiles.isNotEmpty ? imageFiles.first : null,
          isAsset: imageFiles.isNotEmpty,
        );
        appLog('[OK] newReport created: ${newReport.id}');

        // 3. Trigger notifikasi pelaporan berhasil dibuat (optional - jangan block flow)
        try {
          final helper = NotificationHelper();
          await helper.notifyReportCreated(
            category: typeLabel,
            location: reportData['lokasi'] ?? 'Jakarta',
          );
        } catch (e) {
          appLog('[WARN] Notifikasi gagal: $e');
          // Ignore notification error, don't block the flow
        }

        // 4. Tampilkan Dialog "Pelaporan Selesai"
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 32),
                    // Ikon Centang Hijau
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 40,
                        color: Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Judul
                    Text(
                      "Pelaporan Selesai",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subteks
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        "Pelaporan anda telah berhasil kami terima dan akan kami proses",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ID Complaint (jika ada)
                    if (complaint != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          "ID: ${complaint.id}",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Tombol OK
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: ElevatedButton(
                          onPressed: () {
                            // 1. Tutup Dialog
                            Navigator.of(dialogContext).pop();

                            // 2. Pop dari DetailLaporanScreen dan kirim objek Laporan
                            Navigator.of(context).pop(newReport);

                            // Pesan sukses:
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: primaryColor,
                                content: Text(
                                  "Laporan berhasil dikirim!",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              68,
                              180,
                              219,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "OK",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        }
      } else {
        // Gagal mengirim ke API
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(message, style: GoogleFonts.poppins()),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Tutup loading dialog jika masih ada
      if (context.mounted) Navigator.of(context).pop();

      // Tampilkan error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Terjadi kesalahan: $e',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Helper untuk mendapatkan label dari type value
  String _getTypeLabel(String typeValue) {
    final type = _types.firstWhere(
      (t) => t['value'] == typeValue,
      orElse: () => {'value': typeValue, 'label': typeValue},
    );
    return type['label'] ?? typeValue;
  }

  // Widget untuk menampilkan sepasang Label dan Value
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Helper untuk cek apakah kategori butuh foto dan lokasi
  // Tampilkan untuk "sampah_tidak_diangkut", "sampah_menumpuk", dan "lainnya"
  bool _shouldShowPhotoAndLocation() {
    final type = reportData['type'];
    return type == 'sampah_tidak_diangkut' ||
        type == 'sampah_menumpuk' ||
        type == 'lainnya';
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan - hanya jika kategori membutuhkan foto
    Widget? imageWidget;

    if (_shouldShowPhotoAndLocation()) {
      if (imageFiles.isNotEmpty) {
        imageWidget = _InstagramStylePhotoGallery(
          imageFiles: imageFiles,
          isAsset: isAsset,
        );
      } else {
        imageWidget = Container(
          height: 200,
          width: double.infinity,
          color: Colors.grey.shade300,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text("Tidak ada gambar"),
              ],
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Area Foto - hanya tampilkan jika kategori membutuhkan foto
            if (imageWidget != null) ...[
              imageWidget,
              const SizedBox(height: 24),
            ],

            Text(
              "Detail Laporan",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Detail Data - Hanya yang diperlukan API
            _buildDetailRow(
              "Kategori",
              reportData['type'] != null
                  ? _getTypeLabel(reportData['type']!)
                  : 'Tidak ada kategori',
            ),
            // Lokasi - hanya tampilkan jika kategori membutuhkan lokasi
            if (_shouldShowPhotoAndLocation())
              _buildDetailRow(
                "Lokasi",
                reportData['lokasi'] ?? 'Tidak ada lokasi',
              ),
            // Service Account - hanya tampilkan jika ada
            if (reportData['serviceAccount'] != null &&
                reportData['serviceAccount']!.isNotEmpty)
              _buildDetailRow("Service Account", reportData['serviceAccount']!),
            _buildDetailRow(
              "Deskripsi",
              reportData['deskripsi'] ?? 'Tidak ada deskripsi',
            ),

            const SizedBox(height: 32),

            // Tombol KONFIRMASI
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    _confirmReport(context), // Panggil fungsi konfirmasi
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "KONFIRMASI",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BAGIAN 1.6: SCREEN DETAIL LAPORAN TERKIRIM (DetailLaporanTerkirimScreen)
// ====================================================================

class DetailLaporanTerkirimScreen extends StatefulWidget {
  final Laporan laporan;

  const DetailLaporanTerkirimScreen({super.key, required this.laporan});

  @override
  State<DetailLaporanTerkirimScreen> createState() =>
      _DetailLaporanTerkirimScreenState();
}

class _DetailLaporanTerkirimScreenState
    extends State<DetailLaporanTerkirimScreen> {
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  bool _isConfirming = false;
  final TextEditingController _rejectionNoteController =
      TextEditingController();

  @override
  void dispose() {
    _rejectionNoteController.dispose();
    super.dispose();
  }

  // Helper untuk cek apakah kategori butuh foto dan lokasi
  // Tampilkan untuk "sampah_tidak_diangkut", "sampah_menumpuk", dan "lainnya"
  bool _shouldShowPhotoAndLocation() {
    final type = widget.laporan.type?.toLowerCase();
    return type == 'sampah_tidak_diangkut' ||
        type == 'sampah_menumpuk' ||
        type == 'lainnya';
  }

  // Widget untuk menampilkan sepasang Label dan Value dengan Icon
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk membuat progress timeline sesuai Figma
  Widget _buildProgressTimeline(String currentStatus) {
    // Status flow: Menunggu -> Diproses -> Menunggu Konfirmasi -> Selesai/Ditolak
    final isOpen = currentStatus.toLowerCase() == 'open';
    final isInProgress = currentStatus.toLowerCase() == 'in_progress';
    final isPendingConfirmation =
        currentStatus.toLowerCase() == 'pending_confirmation';
    final isResolved = currentStatus.toLowerCase() == 'resolved';
    final isRejected = currentStatus.toLowerCase() == 'rejected';

    // pending_confirmation dianggap sudah melewati tahap "Diproses"
    final hasPassedInProgress =
        isInProgress || isPendingConfirmation || isResolved || isRejected;
    final hasPassedResolved = isResolved || isRejected;

    final Color pendingColor =
        (isOpen || hasPassedInProgress || hasPassedResolved)
        ? primaryColor
        : Colors.grey.shade300;

    final Color inProgressColor = hasPassedInProgress
        ? primaryColor
        : Colors.grey.shade300;

    final Color resolvedColor = isResolved
        ? primaryColor
        : (isRejected
              ? Colors.red
              : (isPendingConfirmation ? Colors.orange : Colors.grey.shade300));

    // Line color logic
    final Color line1Color = hasPassedInProgress
        ? primaryColor
        : Colors.grey.shade300;

    final Color line2Color = hasPassedResolved
        ? primaryColor
        : (isPendingConfirmation ? Colors.orange : Colors.grey.shade300);

    // Format manual untuk menghindari locale issue
    String formatDate(DateTime date) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Oct',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    String formatTime(DateTime date) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // ✅ Waktu dibuat (status Menunggu)
    final createdDate = formatDate(widget.laporan.createdAt);
    final createdTime = formatTime(widget.laporan.createdAt);

    // ✅ FIXED: Gunakan updatedAt dari API untuk waktu perubahan status
    // Jika status sudah berubah dari 'open', gunakan updatedAt sebagai estimasi waktu proses
    final lastUpdateTime = widget.laporan.updatedAt;

    // Untuk status "Diproses" - gunakan waktu update jika sudah melewati tahap ini
    final processDate = hasPassedInProgress ? formatDate(lastUpdateTime) : '-';
    final processTime = hasPassedInProgress ? formatTime(lastUpdateTime) : '';

    // Untuk status "Selesai/Ditolak" - gunakan waktu update terakhir
    final completedDate = hasPassedResolved || isPendingConfirmation
        ? formatDate(lastUpdateTime)
        : '-';
    final completedTime = hasPassedResolved || isPendingConfirmation
        ? formatTime(lastUpdateTime)
        : '';

    return Column(
      children: [
        // Row untuk progress dots dan lines
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pending (Menunggu)
            Expanded(
              child: Column(
                children: [
                  // Tanggal dan Waktu
                  Text(
                    createdDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    createdTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOpen ? pendingColor : Colors.white,
                      border: Border.all(
                        color: pendingColor,
                        width: isOpen ? 3 : 2,
                      ),
                    ),
                    child: isOpen
                        ? const Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 24,
                          )
                        : hasPassedInProgress
                        ? Icon(Icons.check, color: pendingColor, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Menunggu",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "Laporan sedang menunggu untuk diproses",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Line 1
            Expanded(
              flex: 1,
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: 65),
                color: line1Color,
              ),
            ),

            // 2. On Progress (Diproses)
            Expanded(
              child: Column(
                children: [
                  // Tanggal dan Waktu
                  Text(
                    processDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: hasPassedInProgress
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    processTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: hasPassedInProgress
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInProgress ? inProgressColor : Colors.white,
                      border: Border.all(
                        color: inProgressColor,
                        width: isInProgress ? 3 : 2,
                      ),
                    ),
                    child: isInProgress
                        ? const Icon(
                            Icons.autorenew,
                            color: Colors.white,
                            size: 24,
                          )
                        : (isPendingConfirmation || hasPassedResolved)
                        ? Icon(Icons.check, color: inProgressColor, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Di-proses",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasPassedInProgress
                          ? Colors.black87
                          : Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      hasPassedInProgress
                          ? "Sampah telah di proses oleh admin"
                          : "",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Line 2
            Expanded(
              flex: 1,
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: 65),
                color: line2Color,
              ),
            ),

            // 3. Resolve (Selesai) - hijau, orange (pending), atau merah tergantung status
            Expanded(
              child: Column(
                children: [
                  // Tanggal dan Waktu
                  Text(
                    completedDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: hasPassedResolved || isPendingConfirmation
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    completedTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: hasPassedResolved || isPendingConfirmation
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (hasPassedResolved || isPendingConfirmation)
                          ? resolvedColor
                          : Colors.white,
                      border: Border.all(
                        color: resolvedColor,
                        width: (hasPassedResolved || isPendingConfirmation)
                            ? 3
                            : 2,
                      ),
                    ),
                    child: hasPassedResolved
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          )
                        : isPendingConfirmation
                        ? const Icon(
                            Icons.hourglass_empty,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPendingConfirmation ? "Konfirmasi" : "Selesai",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (hasPassedResolved || isPendingConfirmation)
                          ? Colors.black87
                          : Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      isResolved
                          ? "Laporan berhasil diselesaikan"
                          : isRejected
                          ? "Laporan ditolak"
                          : isPendingConfirmation
                          ? "Menunggu konfirmasi dari warga"
                          : "",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: isPendingConfirmation
                            ? Colors.orange
                            : primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method untuk menampilkan gallery foto resolution dengan notifikasi
  void _showResolutionPhotosGallery(
    BuildContext context,
    List<String> photoUrls,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return ResolutionPhotosGalleryDialog(photoUrls: photoUrls);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;

    // Prioritaskan photoUrls (multiple photos dari API)
    if (widget.laporan.photoUrls.isNotEmpty) {
      appLog(
        '[IMG] Loading ${widget.laporan.photoUrls.length} images from API',
      );
      imageWidget = _InstagramStylePhotoGalleryNetwork(
        photoUrls: widget.laporan.photoUrls,
      );
    } else if (widget.laporan.photoUrl != null) {
      // Fallback untuk single photo (backward compatibility)
      appLog('[IMG] Loading single image from URL: ${widget.laporan.photoUrl}');
      imageWidget = _InstagramStylePhotoGalleryNetwork(
        photoUrls: [widget.laporan.photoUrl!],
      );
    } else if (widget.laporan.imageFile != null) {
      // File dari local (jarang digunakan untuk detail terkirim)
      imageWidget = AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: buildPlatformImage(
              widget.laporan.imageFile!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      );
    } else {
      // No image available
      imageWidget = AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade200, Colors.grey.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 60,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 12),
                Text(
                  "Tidak ada gambar",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          "Detail Laporan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Progress Timeline Status (Sesuai Figma)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Keterlambatan
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Keterlambatan",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Subtitle lokasi/kategori dan service account
                    Text(
                      widget.laporan.lokasi.isNotEmpty
                          ? (widget.laporan.serviceAccountName != null &&
                                    widget
                                        .laporan
                                        .serviceAccountName!
                                        .isNotEmpty
                                ? "${widget.laporan.lokasi} • ${widget.laporan.serviceAccountName}"
                                : widget.laporan.lokasi)
                          : (widget.laporan.serviceAccountName != null &&
                                    widget
                                        .laporan
                                        .serviceAccountName!
                                        .isNotEmpty
                                ? "${widget.laporan.kategori} • ${widget.laporan.serviceAccountName}"
                                : widget.laporan.kategori),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Bar dengan 4 Status
                    _buildProgressTimeline(widget.laporan.status),

                    // Foto Penyelesaian dari Kolektor (tampil di bawah status Selesai)
                    if (widget.laporan.status.toLowerCase() == 'resolved' &&
                        widget.laporan.resolutionPhotoUrls.isNotEmpty) ...[
                      const SizedBox(height: 24),

                      // Container untuk Tombol Lihat Foto
                      Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _showResolutionPhotosGallery(
                                context,
                                widget.laporan.resolutionPhotoUrls,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade600,
                                    Colors.green.shade700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.shade300.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Lihat Foto (${widget.laporan.resolutionPhotoUrls.length})',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ✅ Alasan Penolakan (di dalam container status, di bawah timeline)
                    if (widget.laporan.status.toLowerCase() == 'rejected' &&
                        widget.laporan.rejectionReason != null &&
                        widget.laporan.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildInlineRejectionReason(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Card Deskripsi (sesuai Figma)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Deskripsi dengan icon
                    Row(
                      children: [
                        Icon(Icons.menu, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Deskripsi",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Area Foto di dalam Deskripsi - hanya untuk kategori yang membutuhkan foto
                    if (_shouldShowPhotoAndLocation()) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageWidget,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Isi Deskripsi
                    Text(
                      widget.laporan.ciriCiri,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Card Informasi dengan Design Modern
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Informasi Laporan",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                "ID: ${widget.laporan.id.length > 12 ? widget.laporan.id.substring(0, 12) : widget.laporan.id}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Detail Data dengan Icon (TANPA Deskripsi karena sudah terpisah)
                    _buildDetailRow(
                      "Kota",
                      widget.laporan.kota,
                      Icons.location_city,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      "Kategori",
                      widget.laporan.kategori,
                      Icons.category,
                    ),
                    if (widget.laporan.lokasi.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        "Lokasi",
                        widget.laporan.lokasi,
                        Icons.location_on,
                      ),
                    ],
                    if (widget.laporan.serviceAccount != null &&
                        widget.laporan.serviceAccount!.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        "Service Account",
                        widget.laporan.serviceAccount!,
                        Icons.business,
                      ),
                    ],
                    const Divider(height: 24),
                    _buildDetailRow(
                      "Waktu Pelanggaran",
                      widget.laporan.waktuPelanggaran,
                      Icons.access_time,
                    ),
                  ],
                ),
              ),
            ),

            // ✅ NEW: Tombol Konfirmasi untuk status pending_confirmation
            if (widget.laporan.needsConfirmation) ...[
              const SizedBox(height: 20),
              _buildConfirmationSection(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build Confirmation Section Widget
  Widget _buildConfirmationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Konfirmasi Penyelesaian",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        "Petugas sudah mengangkut sampah Anda",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resolution photo preview if available
            if (widget.laporan.resolutionPhotoUrls.isNotEmpty) ...[
              InkWell(
                onTap: () => _showResolutionPhotosGallery(
                  context,
                  widget.laporan.resolutionPhotoUrls,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Lihat Foto Bukti dari Petugas",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.orange.shade400,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              "Apakah sampah Anda sudah benar-benar diangkut?",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // Reject Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isConfirming ? null : () => _showRejectDialog(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _isConfirming ? Colors.grey : Colors.red.shade600,
                    ),
                    label: Text(
                      "Belum",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _isConfirming
                            ? Colors.grey
                            : Colors.red.shade600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: _isConfirming
                            ? Colors.grey.shade300
                            : Colors.red.shade300,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConfirming
                        ? null
                        : () => _confirmResolution(true),
                    icon: _isConfirming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(
                      _isConfirming ? "Memproses..." : "Ya, Sudah",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build Inline Rejection Reason (di dalam container status)
  Widget _buildInlineRejectionReason() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade50,
            Colors.red.shade100.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan icon dan title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Laporan Ditolak",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade800,
                      ),
                    ),
                    Text(
                      "Admin memberikan alasan berikut",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Alasan penolakan dalam container dengan quote style
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: Colors.red.shade400, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade100.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: Colors.red.shade300,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.laporan.rejectionReason ??
                        'Tidak ada alasan yang diberikan',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade700,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Info tambahan dengan icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Silakan buat laporan baru dengan informasi yang lebih lengkap",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Show Reject Dialog with rejection note
  void _showRejectDialog() {
    _rejectionNoteController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Text(
                "Sampah Belum Diangkut?",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Berikan alasan kenapa pengaduan belum selesai:",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rejectionNoteController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText:
                      "Contoh: Sampah masih ada sebagian yang belum diangkut...",
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmResolution(
                  false,
                  rejectionNote: _rejectionNoteController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Kirim",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ NEW: Confirm Resolution API Call
  Future<void> _confirmResolution(
    bool confirmed, {
    String? rejectionNote,
  }) async {
    setState(() {
      _isConfirming = true;
    });

    try {
      final (success, message, data) = await ComplaintService.confirmResolution(
        id: widget.laporan.id,
        confirmed: confirmed,
        rejectionNote: rejectionNote,
      );

      if (!mounted) return;

      setState(() {
        _isConfirming = false;
      });

      if (success) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: confirmed
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      confirmed
                          ? Icons.check_circle_rounded
                          : Icons.refresh_rounded,
                      color: confirmed
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    confirmed ? "Terima Kasih!" : "Pengaduan Dilanjutkan",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(
                        context,
                        true,
                      ); // Return to list with refresh flag
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "OK",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConfirming = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
}

// ====================================================================
// BAGIAN 2: LAYAR UTAMA PEMILIH FOTO (PelaporanScreen)
// ====================================================================

class PelaporanScreen extends StatefulWidget {
  final String? initialServiceAccountId;
  final String? initialServiceAccountName;

  const PelaporanScreen({
    super.key,
    this.initialServiceAccountId,
    this.initialServiceAccountName,
  });

  @override
  State<PelaporanScreen> createState() => _PelaporanScreenState();
}

class _PelaporanScreenState extends State<PelaporanScreen> {
  custom_file.File? _selectedImageFile;
  bool _isDummyImage = false;
  bool _isLoading = false; // Loading state untuk API call

  // State untuk menyimpan daftar laporan yang sudah dikirim
  final List<Laporan> _submittedReports = [];

  // Cache untuk service account names (serviceAccountId -> name)
  final Map<String, String> _serviceAccountNames = {};

  // Initial service account dari home screen
  String? _initialServiceAccountId;
  String? _initialServiceAccountName;

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil arguments dari route jika ada (prioritas), atau dari widget
    if (_initialServiceAccountId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _initialServiceAccountId = args['serviceAccountId']?.toString();
        _initialServiceAccountName = args['serviceAccountName']?.toString();
        appLog(
          '[PELAPORAN] Received from route: $_initialServiceAccountName (ID: $_initialServiceAccountId)',
        );
      } else if (widget.initialServiceAccountId != null) {
        _initialServiceAccountId = widget.initialServiceAccountId;
        _initialServiceAccountName = widget.initialServiceAccountName;
        appLog(
          '[PELAPORAN] Received from widget: $_initialServiceAccountName (ID: $_initialServiceAccountId)',
        );
      }
    }
  }

  /// 🔹 Load laporan dari API
  Future<void> _loadSavedReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ambil data dari API
      final (success, message, data) = await ComplaintService.getComplaints(
        perPage: 100, // Ambil maksimal 100 laporan per page
      );

      if (success && data != null) {
        // Load service accounts untuk mapping ID ke nama
        await _loadServiceAccountNames();

        // Convert API response ke Laporan objects untuk kompatibilitas UI
        final List<Laporan> loadedReports = data.map((item) {
          final complaint = Complaint.fromJson(item);
          return _convertComplaintToLaporan(complaint);
        }).toList();

        // ✅ Sort berdasarkan status: Menunggu > Proses > Selesai > Ditolak
        loadedReports.sort((a, b) {
          int getStatusOrder(String status) {
            switch (status.toLowerCase()) {
              case 'open':
                return 0; // Menunggu
              case 'in_progress':
                return 1; // Diproses
              case 'pending_confirmation':
                return 2; // Menunggu Konfirmasi
              case 'resolved':
                return 3; // Selesai
              case 'rejected':
                return 4; // Ditolak
              default:
                return 5;
            }
          }

          final orderA = getStatusOrder(a.status);
          final orderB = getStatusOrder(b.status);
          if (orderA != orderB) {
            return orderA.compareTo(orderB);
          }
          // Jika status sama, urutkan berdasarkan tanggal terbaru
          return b.createdAt.compareTo(a.createdAt);
        });

        setState(() {
          _submittedReports.clear();
          _submittedReports.addAll(loadedReports);
          _isLoading = false;
        });

        appLog(
          '[OK] Loaded ${loadedReports.length} reports from API (sorted by status)',
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      appLog('[ERROR] Error loading reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data laporan: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// 🔹 Load service account names untuk mapping
  Future<void> _loadServiceAccountNames() async {
    try {
      final serviceAccountService = ServiceAccountService();
      final accounts = await serviceAccountService.fetchAccounts();

      // Build mapping dari ID ke nama
      _serviceAccountNames.clear(); // Clear existing cache
      for (var account in accounts) {
        _serviceAccountNames[account.id] = account.name;
        appLog(
          '[LIST] Mapped Service Account: ID=${account.id}, Name=${account.name}',
        );
      }

      appLog('[OK] Loaded ${accounts.length} service account names');
      appLog('[LIST] Service Account Cache: $_serviceAccountNames');
    } catch (e) {
      appLog('[ERROR] Error loading service account names: $e');
      // Continue even if this fails
    }
  }

  /// Helper untuk convert Complaint (API) ke Laporan (UI model)
  Laporan _convertComplaintToLaporan(Complaint complaint) {
    // Default values karena Complaint API tidak punya field ini lagi
    const kota = 'Jakarta'; // Default kota
    final waktuPelanggaran = DateFormat(
      'dd MMMM yyyy HH:mm',
    ).format(complaint.createdAt);

    // 📍 Debug lokasi dari API
    appLog('[LOC] Location from API: ${complaint.location}');
    appLog('[LOC] Is location empty? ${complaint.location?.isEmpty ?? true}');

    // Ambil semua URL foto dari API
    String? photoUrl; // Backward compatibility
    List<String> photoUrls = [];
    if (complaint.photos.isNotEmpty) {
      // Ambil foto pertama untuk backward compatibility
      photoUrl = complaint.photos.first.url;
      appLog('[IMG] Original Photo URL from API: $photoUrl');

      // Process semua foto
      for (var photo in complaint.photos) {
        String fullUrl = photo.url;

        // Jika URL relatif (dimulai dengan /), tambahkan base URL
        if (fullUrl.isNotEmpty && fullUrl.startsWith('/')) {
          final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
          fullUrl = '$baseUrlWithoutApi$fullUrl';
        } else if (fullUrl.isNotEmpty && !fullUrl.startsWith('http')) {
          // Jika relatif tanpa slash awal
          final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
          fullUrl = '$baseUrlWithoutApi/$fullUrl';
        }

        photoUrls.add(fullUrl);
      }

      // Update photoUrl untuk backward compatibility
      if (photoUrls.isNotEmpty) {
        photoUrl = photoUrls.first;
      }

      appLog('[IMG] Loaded ${photoUrls.length} photos from API');
    } else {
      appLog('[IMG] No photos available for this complaint');
    }

    // Get service account name from cache
    String? serviceAccountName;
    if (complaint.serviceAccountId != null &&
        complaint.serviceAccountId!.isNotEmpty) {
      serviceAccountName = _serviceAccountNames[complaint.serviceAccountId];
      appLog('[LIST] Service Account Lookup:');
      appLog('   - ID from API: ${complaint.serviceAccountId}');
      appLog(
        '   - Name from cache: ${serviceAccountName ?? "NOT FOUND IN CACHE"}',
      );
      appLog('   - Cache has ${_serviceAccountNames.length} entries');

      // If not found, try to reload service accounts
      if (serviceAccountName == null) {
        appLog(
          '[WARN] Service account name not found in cache, will show ID as fallback',
        );
        // Fallback: use ID as display name
        serviceAccountName = 'Service Account #${complaint.serviceAccountId}';
      }
    } else {
      appLog('[LIST] No service account ID in complaint');
    }

    // \u2705 Process resolution photo dari collector
    String? resolutionPhotoUrl;
    if (complaint.resolutionPhoto != null &&
        complaint.resolutionPhoto!.isNotEmpty) {
      resolutionPhotoUrl = complaint.resolutionPhoto;

      // Convert relative URL to absolute
      if (resolutionPhotoUrl!.startsWith('/')) {
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
        resolutionPhotoUrl = '$baseUrlWithoutApi$resolutionPhotoUrl';
      } else if (!resolutionPhotoUrl.startsWith('http')) {
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
        resolutionPhotoUrl = '$baseUrlWithoutApi/$resolutionPhotoUrl';
      }

      appLog('\ud83d\udcf8 [Resolution] Photo URL: $resolutionPhotoUrl');
    } else {
      appLog('\ud83d\udcf8 [Resolution] No resolution photo available');
    }

    final laporan = Laporan(
      id: complaint.id.toString(), // ✅ FIXED: Use ID from API
      kota: kota,
      kategori: complaint.typeText, // Gunakan getter typeText untuk display
      lokasi: complaint.location ?? '', // Ambil lokasi dari API
      waktuPelanggaran: waktuPelanggaran,
      ciriCiri: complaint.description,
      serviceAccount: complaint.serviceAccountId, // Service account ID dari API
      serviceAccountName: serviceAccountName, // Service account name dari cache
      imageFile: null, // API returns URL, bukan File
      photoUrl: photoUrl, // Simpan URL foto pertama (backward compatibility)
      photoUrls: photoUrls, // Simpan semua URL foto
      resolutionPhotoUrls: resolutionPhotoUrl != null
          ? [resolutionPhotoUrl]
          : [],
      isAsset: complaint.photos.isNotEmpty, // Ada foto dari API
      status: complaint.status, // Ambil status dari database
      type: complaint.type, // ✅ NEW: Simpan tipe asli dari API
      rejectionReason: complaint.rejectionReason, // ✅ NEW: Alasan penolakan
      createdAt: complaint.createdAt, // ✅ FIXED: Use createdAt from API
      updatedAt: complaint.updatedAt, // ✅ NEW: Use updatedAt from API
    );

    appLog('[LIST] Laporan ID from API: ${laporan.id}');
    appLog('[LOC] Laporan object lokasi: ${laporan.lokasi}');
    appLog('[LOC] Laporan lokasi isEmpty: ${laporan.lokasi.isEmpty}');
    appLog('[LIST] Laporan type: ${laporan.type}');
    appLog('[LIST] Laporan status: ${laporan.status}');
    appLog('[LIST] Laporan needsConfirmation: ${laporan.needsConfirmation}');

    return laporan;
  }

  /// 🔹 Fungsi navigasi ke halaman Buat Laporan
  void _goToBuatLaporan() {
    // Langsung navigasi ke BuatLaporanScreen (tidak perlu foto dulu)
    // User bisa upload foto di dalam form
    Navigator.of(context)
        .push(
          MaterialPageRoute<Laporan>(
            // Tentukan tipe kembalian adalah Laporan
            builder: (ctx) => BuatLaporanScreen(
              imageFile: _selectedImageFile, // bisa null
              isAsset: _isDummyImage,
              initialServiceAccountId: _initialServiceAccountId,
              initialServiceAccountName: _initialServiceAccountName,
            ),
          ),
        )
        .then((newReport) {
          // Membersihkan gambar di layar ini
          _removeImage();

          // Jika laporan berhasil dikirim, refresh list dari API
          if (newReport != null) {
            _loadSavedReports(); // Refresh data dari API
            // SnackBar sudah ditangani di DetailLaporanScreen
          }
        });
  }

  /// 🔹 Reset gambar
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _isDummyImage = false;
    });
  }

  /// 🔹 Widget untuk menampilkan gambar (File atau daftar laporan)
  Widget _imageDisplayWidget() {
    // 1. Jika ada gambar dari perangkat
    if (_selectedImageFile != null) {
      return buildPlatformImage(
        _selectedImageFile!,
        width: 280,
        height: 280,
        fit: BoxFit.contain,
      );
    } else {
      // 2. Tampilkan loading indicator saat memuat data
      if (_isLoading) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat laporan...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      }

      // 3. Jika tidak ada gambar, tampilkan daftar laporan atau empty state
      if (_submittedReports.isNotEmpty) {
        return _ReportList(
          reports: _submittedReports,
          onRefresh: _loadSavedReports, // ✅ Pass refresh callback
        );
      }

      return const _PelaporanEmptyState(
        text: "Ketuk '+' untuk memilih foto dan mulai melapor.",
        color: primaryColor,
      );
    }
  }

  // 🔹 Widget untuk tombol FAB - selalu buka form
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      backgroundColor: primaryColor,
      // Langsung buka form BuatLaporanScreen (user upload foto di dalam form)
      onPressed: _goToBuatLaporan,
      child: const Icon(Icons.add), // Selalu icon plus
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      // Selalu tampilkan list laporan atau empty state (tidak ada preview gambar)
      body: RefreshIndicator(
        onRefresh: _loadSavedReports,
        color: primaryColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _imageDisplayWidget(),
          ),
        ),
      ),

      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

// ====================================================================
// BAGIAN 3: WIDGET REUSABLE
// ====================================================================

// Widget untuk menampilkan daftar laporan yang sudah dikirim
class _ReportList extends StatelessWidget {
  final List<Laporan> reports;
  final VoidCallback? onRefresh; // ✅ NEW: Callback untuk refresh

  const _ReportList({required this.reports, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // ⭐️ Menggunakan Column dan Expanded agar ListView bisa memenuhi sisa ruang
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Laporan Terakhir (${reports.length})",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _PelaporanScreenState.primaryColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(
              bottom: 80.0,
            ), // Berikan padding di bawah agar FAB tidak menutupi list terakhir
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportCard(
                report: report,
                onTap: () async {
                  // Navigasi ke detail laporan yang sudah terkirim
                  final shouldRefresh = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (ctx) =>
                          DetailLaporanTerkirimScreen(laporan: report),
                    ),
                  );

                  // ✅ Refresh list jika ada perubahan (konfirmasi/reject)
                  if (shouldRefresh == true && onRefresh != null) {
                    onRefresh!();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Widget Card untuk setiap laporan (sesuai desain Figma)
class _ReportCard extends StatelessWidget {
  final Laporan report;
  final Future<void> Function() onTap; // ✅ Changed to async function

  const _ReportCard({required this.report, required this.onTap});

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // Fungsi untuk mendapatkan text color badge
  Color _getBadgeTextColor() {
    switch (report.status.toLowerCase()) {
      case 'open':
        return Colors.orange.shade700; // Menunggu
      case 'in_progress':
        return primaryColor; // Diproses
      case 'resolved':
        return Colors.green.shade700; // Selesai
      case 'rejected':
        return Colors.red.shade700; // Ditolak
      default:
        return Colors.grey.shade700;
    }
  }

  // Fungsi untuk mendapatkan status text dari database
  String _getStatusText() {
    return report.statusText;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(), // ✅ Call async function
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail Image dengan Border Gradient
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withValues(alpha: 0.3),
                        primaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade100,
                      child: report.photoUrl != null
                          ? Image.network(
                              report.photoUrl!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey.shade300,
                                        Colors.grey.shade200,
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 40,
                                    color: Colors.grey.shade500,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2.5,
                                          color: primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                            )
                          : report.imageFile != null
                          ? buildPlatformImage(
                              report.imageFile!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade300,
                                    Colors.grey.shade200,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Colors.grey.shade500,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge dengan Gradient
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getBadgeTextColor(),
                              _getBadgeTextColor().withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: _getBadgeTextColor().withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _getStatusText().toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title dengan Icon
                      Row(
                        children: [
                          const Icon(
                            Icons.report_problem_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              report.kategori.isNotEmpty
                                  ? report.kategori
                                  : 'Sampah belum diambil',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Date dengan Background
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd MMM yyyy HH:mm',
                              ).format(report.createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lokasi jika ada
                      if (report.lokasi.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                report.lokasi,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow Icon dengan Gradient Background
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withValues(alpha: 0.1),
                        primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔹 Reusable tombol pilihan (Untuk Popup Gallery/Camera)
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: primaryColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Instagram-style Photo Gallery dengan PageView dan Dot Indicators
class _InstagramStylePhotoGallery extends StatefulWidget {
  final List<custom_file.File> imageFiles;
  final bool isAsset;

  const _InstagramStylePhotoGallery({
    required this.imageFiles,
    required this.isAsset,
  });

  @override
  State<_InstagramStylePhotoGallery> createState() =>
      _InstagramStylePhotoGalleryState();
}

class _InstagramStylePhotoGalleryState
    extends State<_InstagramStylePhotoGallery> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // PageView untuk foto
            AspectRatio(
              aspectRatio: 4 / 3, // Aspect ratio standar foto
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: widget.imageFiles.length,
                itemBuilder: (context, index) {
                  return buildPlatformImage(
                    widget.imageFiles[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
              ),
            ),

            // Counter badge di kanan atas (seperti Instagram)
            if (widget.imageFiles.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.imageFiles.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Dot indicators di bawah (seperti Instagram)
            if (widget.imageFiles.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.imageFiles.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kiri (muncul jika bukan foto pertama)
            if (widget.imageFiles.length > 1 && _currentPage > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kanan (muncul jika bukan foto terakhir)
            if (widget.imageFiles.length > 1 &&
                _currentPage < widget.imageFiles.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Instagram-style Photo Gallery untuk Network Images (dari API)
class _InstagramStylePhotoGalleryNetwork extends StatefulWidget {
  final List<String> photoUrls;

  const _InstagramStylePhotoGalleryNetwork({required this.photoUrls});

  @override
  State<_InstagramStylePhotoGalleryNetwork> createState() =>
      _InstagramStylePhotoGalleryNetworkState();
}

class _InstagramStylePhotoGalleryNetworkState
    extends State<_InstagramStylePhotoGalleryNetwork> {
  late PageController _pageController;
  int _currentPage = 0;
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // PageView untuk foto dari network
            AspectRatio(
              aspectRatio: 4 / 3, // Aspect ratio standar foto
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: widget.photoUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    widget.photoUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 3,
                            color: primaryColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 60,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Gagal memuat gambar',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Counter badge di kanan atas (seperti Instagram)
            if (widget.photoUrls.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.photoUrls.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Dot indicators di bawah (seperti Instagram)
            if (widget.photoUrls.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.photoUrls.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kiri (muncul jika bukan foto pertama)
            if (widget.photoUrls.length > 1 && _currentPage > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kanan (muncul jika bukan foto terakhir)
            if (widget.photoUrls.length > 1 &&
                _currentPage < widget.photoUrls.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Widget reusable untuk empty state (Sesuai Gambar 1)
class _PelaporanEmptyState extends StatelessWidget {
  final String text;
  final Color color;

  const _PelaporanEmptyState({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gambar tanpa container circle background
        Image.asset(
          'assets/images/pelaporan.png',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info, size: 60, color: color),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// 🔹 Fullscreen Map Screen untuk memilih lokasi
class _FullscreenMapScreen extends StatefulWidget {
  final LatLng initialLocation;
  final double initialZoom;
  final Function(LatLng) onLocationSelected;

  const _FullscreenMapScreen({
    required this.initialLocation,
    required this.initialZoom,
    required this.onLocationSelected,
  });

  @override
  State<_FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<_FullscreenMapScreen> {
  late MapController _mapController;
  late LatLng _selectedLocation;
  late double _currentZoom;
  bool _isLoadingAddress = false;
  String _currentAddress = '';

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
    _currentZoom = widget.initialZoom;
    _loadAddress(_selectedLocation);
  }

  Future<void> _loadAddress(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address =
            '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}'
                .replaceAll(RegExp(r'^,\\s*|,\\s*\$'), '')
                .replaceAll(RegExp(r',\\s*,'), ',');

        setState(() {
          _currentAddress = address.isEmpty
              ? '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'
              : address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress =
            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        _isLoadingAddress = false;
      });
    }
  }

  void _handleTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _loadAddress(location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pilih Lokasi',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              widget.onLocationSelected(_selectedLocation);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: primaryColor, size: 28),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: _currentZoom,
              minZoom: 3.0,
              maxZoom: 19.0,
              onTap: (tapPosition, point) {
                _handleTap(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.beresin_app',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: primaryColor,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Zoom Controls
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
                      });
                      _mapController.move(_selectedLocation, _currentZoom);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ),
                Container(width: 40, height: 1, color: Colors.grey.shade300),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
                      });
                      _mapController.move(_selectedLocation, _currentZoom);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(Icons.remove, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Address Info Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lokasi Terpilih',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingAddress)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Memuat alamat...',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ],
                    )
                  else
                    Text(
                      _currentAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
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
