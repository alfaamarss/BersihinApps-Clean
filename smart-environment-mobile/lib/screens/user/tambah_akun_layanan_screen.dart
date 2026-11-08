import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/app_settings.dart';
import '../../models/area_option.dart';
import '../../models/service_account.dart';
import '../../services/area_service.dart';
import '../../services/config_service.dart';
import '../../services/service_account_service.dart';
import '../../services/notification_helper.dart';

class TambahAkunLayananScreen extends StatefulWidget {
  const TambahAkunLayananScreen({super.key});

  @override
  State<TambahAkunLayananScreen> createState() =>
      _TambahAkunLayananScreenState();
}

class _TambahAkunLayananScreenState extends State<TambahAkunLayananScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _teleponController = TextEditingController();
  final TextEditingController _detailAlamatController = TextEditingController();
  final TextEditingController _kelurahanController = TextEditingController();
  final TextEditingController _kecamatanController = TextEditingController();
  final TextEditingController _provinsiController = TextEditingController();
  final TextEditingController _kotaController = TextEditingController();
  final TextEditingController _rwController = TextEditingController();

  final AreaService _areaService = AreaService();
  final ServiceAccountService _serviceAccountService = ServiceAccountService();
  final ConfigService _configService = ConfigService();
  final Dio _geocodeClient = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      headers: {
        'User-Agent':
            'smart-environment-mobile/1.0 (https://github.com/citiasia-inc/smart-environment-mobile)',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  double _latitude = -6.2;
  double _longitude = 106.8;
  double _currentZoom = 16.0;

  final MapController _mapController = MapController();

  List<AreaOption> _kecamatanOptions = [];
  List<AreaOption> _kelurahanOptions = [];
  AreaOption? _selectedKecamatanOption;
  AreaOption? _selectedKelurahanOption;

  bool _isLoading = true;
  bool _isKelurahanLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingAddress = false;

  String? _provinceName;
  String? _cityName;

  final double _minZoom = 3.0;
  final double _maxZoom = 19.0;

  // List untuk menyimpan nama akun yang sudah ada
  List<String> _existingAccountNames = [];

  // State untuk menampilkan card notifikasi validasi
  bool _showValidationNotification = false;
  String _validationTitle = '';
  String _validationMessage = '';
  String _validationField = '';

  // State untuk validasi nomor telepon
  String? _phoneValidationError;

  // State untuk loading lokasi saat ini
  bool _isGettingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();

    // Listener untuk validasi nomor telepon real-time
    _teleponController.addListener(_validatePhoneNumber);
  }

  void _validatePhoneNumber() {
    final phoneText = _teleponController.text.trim();

    if (phoneText.isEmpty) {
      setState(() {
        _phoneValidationError = null;
      });
      return;
    }

    if (!phoneText.startsWith('08')) {
      setState(() {
        _phoneValidationError = 'Nomor telepon harus dimulai dengan 08';
      });
    } else {
      setState(() {
        _phoneValidationError = null;
      });
    }
  }

  Future<void> _initializeForm() async {
    try {
      final AppSettingsData? settings = await _configService.fetchAppSettings();
      final kecamatan = await _areaService.fetchKecamatan();

      // Load existing accounts untuk validasi nama
      final existingAccounts = await _serviceAccountService.fetchAccounts();
      final existingNames = existingAccounts
          .map((account) => account.name.toLowerCase().trim())
          .toList();

      if (!mounted) return;

      setState(() {
        _provinceName = settings?.province?.name;
        _cityName = settings?.city?.name;
        _provinsiController.text = _provinceName ?? '';
        _kotaController.text = _cityName ?? '';
        _kecamatanOptions = kecamatan;
        _existingAccountNames = existingNames;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Gagal memuat data awal: ${_errorMessage(error)}');
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map &&
          data['errors'] is Map &&
          data['errors']['message'] != null) {
        return data['errors']['message'].toString();
      }
      return error.message ?? 'Terjadi kesalahan jaringan';
    }
    return error.toString();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mendapatkan lokasi saat ini menggunakan GPS
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      // Cek apakah location service aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showSnackBar('Layanan lokasi tidak aktif. Silakan aktifkan GPS.');
        setState(() {
          _isGettingCurrentLocation = false;
        });
        return;
      }

      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _showSnackBar('Izin lokasi ditolak');
          setState(() {
            _isGettingCurrentLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showSnackBar(
          'Izin lokasi ditolak permanen. Silakan aktifkan di pengaturan.',
        );
        setState(() {
          _isGettingCurrentLocation = false;
        });
        return;
      }

      // Dapatkan posisi saat ini
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingCurrentLocation = false;
      });

      // Pindahkan peta ke lokasi baru
      _mapController.move(LatLng(_latitude, _longitude), _currentZoom);

      // Dapatkan alamat dari koordinat
      await _getAddressFromCoordinates(_latitude, _longitude);

      _showSnackBar('Lokasi berhasil diperbarui');
    } catch (e) {
      appLog('[ERROR] Get current location: $e');
      if (!mounted) return;
      setState(() {
        _isGettingCurrentLocation = false;
      });
      _showSnackBar('Gagal mendapatkan lokasi: ${e.toString()}');
    }
  }

  /// Auto-fill area dari placemark (untuk mobile)
  Future<void> _autoFillAreaFromPlacemark({
    String? subLocality,
    String? locality,
    String? subAdminArea,
  }) async {
    debugPrint(
      '[AUTO-FILL] subLocality: $subLocality, locality: $locality, subAdminArea: $subAdminArea',
    );
    debugPrint(
      '[AUTO-FILL] Kecamatan options count: ${_kecamatanOptions.length}',
    );

    // Daftar kemungkinan nama kecamatan untuk dicoba
    final kecamatanCandidates = <String>[
      if (subAdminArea != null && subAdminArea.isNotEmpty) subAdminArea,
      if (locality != null && locality.isNotEmpty) locality,
      if (subLocality != null && subLocality.isNotEmpty) subLocality,
    ];

    AreaOption? foundKecamatan;

    // Coba setiap kandidat sampai ditemukan
    for (final candidate in kecamatanCandidates) {
      foundKecamatan = _findOptionByNameFuzzy(_kecamatanOptions, candidate);
      if (foundKecamatan != null) {
        debugPrint(
          '[AUTO-FILL] Kecamatan ditemukan dari candidate "$candidate": ${foundKecamatan.name}',
        );
        break;
      }
    }

    if (foundKecamatan != null) {
      setState(() {
        _selectedKecamatanOption = foundKecamatan;
        _kecamatanController.text = foundKecamatan!.name;
      });

      // Load kelurahan options
      await _loadKelurahanOptions(foundKecamatan);

      // Tunggu sebentar agar kelurahan options terload
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint(
        '[AUTO-FILL] Kelurahan options count: ${_kelurahanOptions.length}',
      );

      // Daftar kemungkinan nama kelurahan untuk dicoba
      final kelurahanCandidates = <String>[
        if (subLocality != null && subLocality.isNotEmpty) subLocality,
        if (locality != null && locality.isNotEmpty) locality,
      ];

      AreaOption? foundKelurahan;

      // Coba setiap kandidat sampai ditemukan
      for (final candidate in kelurahanCandidates) {
        foundKelurahan = _findOptionByNameFuzzy(_kelurahanOptions, candidate);
        if (foundKelurahan != null) {
          debugPrint(
            '[AUTO-FILL] Kelurahan ditemukan dari candidate "$candidate": ${foundKelurahan.name}',
          );
          break;
        }
      }

      if (foundKelurahan != null) {
        setState(() {
          _selectedKelurahanOption = foundKelurahan;
          _kelurahanController.text = foundKelurahan!.name;
        });
      } else {
        debugPrint(
          '[AUTO-FILL] Kelurahan tidak ditemukan dari candidates: $kelurahanCandidates',
        );
        // Jika hanya ada satu kelurahan, pilih otomatis
        if (_kelurahanOptions.length == 1) {
          setState(() {
            _selectedKelurahanOption = _kelurahanOptions.first;
            _kelurahanController.text = _kelurahanOptions.first.name;
          });
          debugPrint(
            '[AUTO-FILL] Auto-selected single kelurahan: ${_kelurahanOptions.first.name}',
          );
        }
      }
    } else {
      debugPrint(
        '[AUTO-FILL] Kecamatan tidak ditemukan dari candidates: $kecamatanCandidates',
      );

      // Debug: tampilkan semua opsi kecamatan yang tersedia
      if (_kecamatanOptions.isNotEmpty) {
        debugPrint('[AUTO-FILL] Available kecamatan options:');
        for (final opt in _kecamatanOptions.take(10)) {
          debugPrint('  - ${opt.name}');
        }
      }
    }

    // Set default RW jika kosong
    if (_rwController.text.isEmpty) {
      setState(() {
        _rwController.text = 'RW 001';
      });
    }
  }

  /// Auto-fill area dari Nominatim address details (untuk web)
  Future<void> _autoFillAreaFromAddress(
    Map<String, dynamic> addressDetails,
  ) async {
    debugPrint('[AUTO-FILL WEB] addressDetails: $addressDetails');

    // Nominatim address fields yang mungkin berisi kecamatan/kelurahan:
    // - village, hamlet = desa/kelurahan kecil
    // - suburb = kelurahan di kota
    // - city_district = kecamatan
    // - county = kabupaten/wilayah
    // - municipality = kotamadya

    String? village =
        addressDetails['village']?.toString() ??
        addressDetails['suburb']?.toString() ??
        addressDetails['hamlet']?.toString() ??
        addressDetails['neighbourhood']?.toString();

    String? cityDistrict =
        addressDetails['city_district']?.toString() ??
        addressDetails['district']?.toString() ??
        addressDetails['subdistrict']?.toString() ??
        addressDetails['county']?.toString();

    debugPrint(
      '[AUTO-FILL WEB] Parsed - village: $village, cityDistrict: $cityDistrict',
    );

    await _autoFillAreaFromPlacemark(
      subLocality: village,
      locality: cityDistrict,
      subAdminArea: cityDistrict,
    );
  }

  /// Fuzzy search untuk mencari option berdasarkan nama (lebih fleksibel)
  AreaOption? _findOptionByNameFuzzy(List<AreaOption> options, String name) {
    if (name.isEmpty) return null;

    // Bersihkan query dari prefix umum
    String query = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'^kecamatan\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^kelurahan\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^desa\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^kec\.?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^kel\.?\s*', caseSensitive: false), '')
        .trim();

    debugPrint('[FUZZY SEARCH] Query cleaned: "$query" from original: "$name"');
    debugPrint('[FUZZY SEARCH] Options count: ${options.length}');

    // Cari exact match dulu
    for (final option in options) {
      final optionName = option.name.toLowerCase().trim();
      if (optionName == query) {
        debugPrint('[FUZZY SEARCH] Exact match found: ${option.name}');
        return option;
      }
    }

    // Cari match tanpa spasi
    final queryNoSpace = query.replaceAll(' ', '');
    for (final option in options) {
      final optionNoSpace = option.name.toLowerCase().replaceAll(' ', '');
      if (optionNoSpace == queryNoSpace) {
        debugPrint('[FUZZY SEARCH] NoSpace match found: ${option.name}');
        return option;
      }
    }

    // Cari contains match
    for (final option in options) {
      final optionName = option.name.toLowerCase();
      if (optionName.contains(query) || query.contains(optionName)) {
        debugPrint('[FUZZY SEARCH] Contains match found: ${option.name}');
        return option;
      }
    }

    // Cari partial word match (minimal 4 karakter)
    if (query.length >= 4) {
      for (final option in options) {
        final optionName = option.name.toLowerCase();
        // Cek apakah kata-kata dalam query ada di option name
        final queryWords = query.split(RegExp(r'\s+'));
        for (final word in queryWords) {
          if (word.length >= 4 && optionName.contains(word)) {
            debugPrint(
              '[FUZZY SEARCH] Partial word match found: ${option.name} (word: $word)',
            );
            return option;
          }
        }
      }
    }

    debugPrint('[FUZZY SEARCH] No match found for: "$query"');
    return null;
  }

  AreaOption? _findOptionByName(List<AreaOption> options, String name) {
    final query = name.toLowerCase();
    for (final option in options) {
      if (option.name.toLowerCase() == query) {
        return option;
      }
    }
    return null;
  }

  Future<void> _handleKecamatanSelection(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final option = _findOptionByName(_kecamatanOptions, trimmed);
    if (option == null) {
      _showSnackBar('Kecamatan "$trimmed" tidak ditemukan');
      return;
    }

    if (_selectedKecamatanOption?.id == option.id) {
      _kecamatanController.text = option.name;
      return;
    }

    setState(() {
      _selectedKecamatanOption = option;
      _kecamatanController.text = option.name;
      _kelurahanController.clear();
      _selectedKelurahanOption = null;
      _kelurahanOptions = [];
    });

    await _searchAddress(
      '${option.name}, ${_cityName ?? ''}, ${_provinceName ?? ''}',
    );
    await _loadKelurahanOptions(option);
  }

  Future<void> _loadKelurahanOptions(AreaOption kecamatan) async {
    setState(() {
      _isKelurahanLoading = true;
    });

    try {
      final kelurahan = await _areaService.fetchKelurahan(
        parentId: kecamatan.id,
      );
      if (!mounted) return;

      setState(() {
        _kelurahanOptions = kelurahan;
      });

      if (kelurahan.isEmpty) {
        _showSnackBar('Kelurahan untuk ${kecamatan.name} tidak ditemukan');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Gagal memuat kelurahan: ${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isKelurahanLoading = false;
        });
      }
    }
  }

  Future<void> _handleKelurahanSelection(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final option = _findOptionByName(_kelurahanOptions, trimmed);
    if (option == null) {
      _showSnackBar('Kelurahan "$trimmed" tidak ditemukan');
      return;
    }

    setState(() {
      _selectedKelurahanOption = option;
      _kelurahanController.text = option.name;
    });

    await _searchAddress(
      '${option.name}, ${_selectedKecamatanOption?.name ?? ''}, ${_cityName ?? ''}, ${_provinceName ?? ''}',
    );
  }

  void _showKecamatanPicker() {
    if (_kecamatanOptions.isEmpty) {
      _showSnackBar('Data kecamatan belum tersedia atau sedang dimuat');
      return;
    }
    _showAreaPickerBottomSheet(
      title: 'Pilih Kecamatan',
      options: _kecamatanOptions,
      onSelected: (option) {
        _handleKecamatanSelection(option.name);
      },
    );
  }

  void _showKelurahanPicker() {
    if (_selectedKecamatanOption == null) {
      _showSnackBar('Silakan pilih kecamatan terlebih dahulu');
      return;
    }
    if (_isKelurahanLoading) {
      _showSnackBar('Sedang memuat data kelurahan...');
      return;
    }
    if (_kelurahanOptions.isEmpty) {
      _showSnackBar('Tidak ada kelurahan untuk kecamatan ${_selectedKecamatanOption?.name ?? ''}');
      return;
    }
    _showAreaPickerBottomSheet(
      title: 'Pilih Kelurahan',
      options: _kelurahanOptions,
      onSelected: (option) {
        _handleKelurahanSelection(option.name);
      },
    );
  }

  void _showAreaPickerBottomSheet({
    required String title,
    required List<AreaOption> options,
    required Function(AreaOption) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = options
                .where((o) => o.name.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          filter = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ditemukan',
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Text(
                                    item.name,
                                    style: GoogleFonts.poppins(fontSize: 15),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onSelected(item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    debugPrint('Koordinat dipilih: $lat, $lng');

    setState(() {
      _isLoadingAddress = true;
    });

    try {
      if (kIsWeb) {
        // Gunakan Nominatim API untuk web
        final response = await _geocodeClient.get<Map<String, dynamic>>(
          '/reverse',
          queryParameters: {
            'format': 'json',
            'lat': lat.toString(),
            'lon': lng.toString(),
            'zoom': '18',
            'addressdetails': '1',
          },
        );

        final data = response.data;
        if (data != null && data['display_name'] != null) {
          final address = data['display_name'] as String;
          final addressDetails = data['address'] as Map<String, dynamic>?;

          if (mounted) {
            setState(() {
              _detailAlamatController.text = address;
            });

            // Auto-fill kecamatan dan kelurahan dari addressDetails
            if (addressDetails != null) {
              await _autoFillAreaFromAddress(addressDetails);
            }
          }
          debugPrint('Alamat ditemukan (Web): $address');
        } else {
          _showSnackBar('Alamat tidak ditemukan untuk koordinat ini');
        }
      } else {
        // Gunakan geocoding package untuk mobile
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressParts = <String>[];

          // Simpan info untuk auto-fill
          String? subLocality = place.subLocality; // Kelurahan
          String? locality = place.locality; // Kecamatan
          String? street = place.street;
          String? subAdminArea = place.subAdministrativeArea;

          if (street != null && street.isNotEmpty) {
            addressParts.add(street);
          }
          if (subLocality != null && subLocality.isNotEmpty) {
            addressParts.add(subLocality);
          }
          if (locality != null && locality.isNotEmpty) {
            addressParts.add(locality);
          }
          if (subAdminArea != null && subAdminArea.isNotEmpty) {
            addressParts.add(subAdminArea);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }

          final fullAddress = addressParts.join(', ');

          if (mounted) {
            setState(() {
              _detailAlamatController.text = fullAddress;
            });

            // Auto-fill kecamatan dan kelurahan
            await _autoFillAreaFromPlacemark(
              subLocality: subLocality,
              locality: locality,
              subAdminArea: subAdminArea,
            );
          }
          debugPrint('Alamat ditemukan (Mobile): $fullAddress');
        } else {
          _showSnackBar('Alamat tidak ditemukan untuk koordinat ini');
        }
      }
    } catch (error) {
      debugPrint('Error mendapatkan alamat dari koordinat: $error');
      _showSnackBar('Gagal mendapatkan alamat. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _showValidationError({
    required String title,
    required String message,
    required String field,
  }) {
    setState(() {
      _showValidationNotification = true;
      _validationTitle = title;
      _validationMessage = message;
      _validationField = field;
    });

    // Auto-hide setelah 5 detik
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showValidationNotification = false;
        });
      }
    });
  }

  Future<void> _searchAddress(String address) async {
    if (address.trim().isEmpty) {
      return;
    }

    final LatLng? coordinates = await _resolveCoordinates(address);

    if (!mounted) return;

    if (coordinates == null) {
      _showSnackBar('Alamat tidak ditemukan');
      return;
    }

    setState(() {
      _latitude = coordinates.latitude;
      _longitude = coordinates.longitude;
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  Future<LatLng?> _resolveCoordinates(String address) async {
    try {
      if (kIsWeb) {
        final response = await _geocodeClient.get<List<dynamic>>(
          '/search',
          queryParameters: {'format': 'json', 'limit': 1, 'q': address},
        );

        final data = response.data;
        if (data == null || data.isEmpty) {
          return null;
        }

        final first = data.first;
        if (first is Map<String, dynamic>) {
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
        return null;
      } else {
        final locations = await locationFromAddress(address);
        if (locations.isEmpty) {
          return null;
        }
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (error, stackTrace) {
      debugPrint('Gagal menemukan koordinat untuk "$address": $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  Future<void> _simpanData() async {
    // Validasi Nama Lengkap
    if (_namaController.text.trim().isEmpty) {
      _showValidationError(
        title: 'Nama Lengkap Kosong',
        message: 'Nama lengkap tidak boleh kosong',
        field: _namaController.text.trim(),
      );
      return;
    }

    // Cek duplikat nama
    final nameLower = _namaController.text.toLowerCase().trim();
    if (_existingAccountNames.contains(nameLower)) {
      _showValidationError(
        title: 'Nama Sudah Terdaftar',
        message: 'Nama "${_namaController.text.trim()}" sudah pernah digunakan',
        field: _namaController.text.trim(),
      );
      return;
    }

    // Validasi Nomor Telepon
    if (_teleponController.text.trim().isEmpty) {
      _showValidationError(
        title: 'Nomor Telepon Kosong',
        message: 'Nomor telepon tidak boleh kosong',
        field: 'Nomor Telepon',
      );
      return;
    }

    if (!_teleponController.text.trim().startsWith('08')) {
      _showValidationError(
        title: 'Nomor Telepon Tidak Valid',
        message: 'Nomor telepon harus dimulai dengan 08',
        field: _teleponController.text,
      );
      return;
    }

    if (_teleponController.text.length < 11) {
      _showValidationError(
        title: 'Nomor Telepon Tidak Valid',
        message: 'Nomor telepon minimal 11 digit',
        field: _teleponController.text,
      );
      return;
    }

    if (_teleponController.text.length > 13) {
      _showValidationError(
        title: 'Nomor Telepon Terlalu Panjang',
        message: 'Nomor telepon maksimal 13 digit',
        field: _teleponController.text,
      );
      return;
    }

    // Validasi Kecamatan dan Kelurahan
    if (_selectedKecamatanOption == null) {
      _showValidationError(
        title: 'Kecamatan Belum Dipilih',
        message: 'Silakan pilih kecamatan terlebih dahulu',
        field: 'Kecamatan',
      );
      return;
    }

    if (_selectedKelurahanOption == null) {
      _showValidationError(
        title: 'Kelurahan Belum Dipilih',
        message: 'Silakan pilih kelurahan terlebih dahulu',
        field: 'Kelurahan',
      );
      return;
    }

    // Validasi RW
    if (_rwController.text.trim().isEmpty) {
      _showValidationError(
        title: 'RW Kosong',
        message: 'RW (Rukun Warga) tidak boleh kosong',
        field: 'RW',
      );
      return;
    }

    // Validasi RW tidak boleh 00
    final rwText = _rwController.text.trim().toUpperCase();
    final rwNumber = int.tryParse(rwText.replaceAll(RegExp(r'[^0-9]'), ''));
    if (rwNumber != null && rwNumber == 0) {
      _showValidationError(
        title: 'RW Tidak Valid',
        message: 'RW tidak boleh 00. Minimal harus RW 01',
        field: _rwController.text.trim(),
      );
      return;
    }

    // Validasi Detail Alamat
    if (_detailAlamatController.text.trim().isEmpty) {
      _showValidationError(
        title: 'Detail Alamat Kosong',
        message: 'Detail alamat tidak boleh kosong',
        field: 'Detail Alamat',
      );
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      appLog('📝 [TambahAkunScreen] Submitting account data:');
      appLog('   - Nama: ${_namaController.text}');
      appLog('   - Telepon: ${_teleponController.text}');
      appLog('   - Alamat: ${_detailAlamatController.text}');
      appLog('   - Area ID: ${_selectedKelurahanOption!.id}');
      appLog('   - RW: ${_rwController.text}');
      appLog('   - Lat/Lng: $_latitude, $_longitude');

      final account = await _serviceAccountService.createAccount(
        name: _namaController.text,
        contactPhone: _teleponController.text,
        address: _detailAlamatController.text,
        areaId: _selectedKelurahanOption!.id,
        rwName: _rwController.text.trim().isNotEmpty
            ? _rwController.text.trim()
            : null,
        latitude: _latitude,
        longitude: _longitude,
      );

      appLog('✅ [TambahAkunScreen] Account created successfully');
      appLog('   - ID: ${account.id}');
      appLog('   - Nama: ${account.name}');
      appLog('   - Phone: ${account.contactPhone}');

      if (!mounted) return;

      // Trigger notifikasi akun layanan berhasil dibuat
      final helper = NotificationHelper();
      await helper.notifyServiceAccountCreated(accountName: account.name);

      if (!mounted) return;
      _showSuccessBottomSheet(context, account);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Gagal menyimpan akun: ${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessBottomSheet(BuildContext context, ServiceAccount account) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                'Akun layanan berhasil dibuat!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                account.name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                account.address,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, account);
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  Widget _buildValidationNotificationCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      height: _showValidationNotification ? null : 0,
      child: _showValidationNotification
          ? AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _showValidationNotification ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
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
                  border: Border.all(color: Colors.red.shade400, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.red.shade100.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon dengan animasi pulse
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.red.shade400, Colors.red.shade600],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _validationTitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Error',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_validationField.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: Colors.red.shade700,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '"$_validationField"',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.red.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _validationMessage,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showValidationNotification = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    _teleponController.removeListener(_validatePhoneNumber);
    _namaController.dispose();
    _teleponController.dispose();
    _detailAlamatController.dispose();
    _kelurahanController.dispose();
    _kecamatanController.dispose();
    _provinsiController.dispose();
    _kotaController.dispose();
    _rwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tambahkan Akun Layanan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading ? _buildShimmer() : _buildForm(),
      bottomNavigationBar: !_isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Card Notifikasi Validasi
                  _buildValidationNotificationCard(),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _simpanData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Menyimpan...',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Simpan',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Nama Lengkap'),
              TextFormField(
                controller: _namaController,
                decoration: _inputDecoration(hintText: 'Masukkan nama lengkap')
                    .copyWith(
                      // Tambahkan suffix icon warning jika nama sudah digunakan
                      suffixIcon:
                          _namaController.text.isNotEmpty &&
                              _existingAccountNames.contains(
                                _namaController.text.toLowerCase().trim(),
                              )
                          ? const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 24,
                            )
                          : null,
                      // Helper text merah jika nama sudah digunakan
                      helperText:
                          _namaController.text.isNotEmpty &&
                              _existingAccountNames.contains(
                                _namaController.text.toLowerCase().trim(),
                              )
                          ? 'Nama akun layanan "${_namaController.text}" sudah digunakan.'
                          : null,
                      helperStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                      helperMaxLines: 2,
                      // Border merah jika nama sudah digunakan
                      enabledBorder:
                          _namaController.text.isNotEmpty &&
                              _existingAccountNames.contains(
                                _namaController.text.toLowerCase().trim(),
                              )
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                            )
                          : null,
                      focusedBorder:
                          _namaController.text.isNotEmpty &&
                              _existingAccountNames.contains(
                                _namaController.text.toLowerCase().trim(),
                              )
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            )
                          : null,
                    ),
                onChanged: (value) {
                  // Trigger rebuild untuk update visual feedback
                  setState(() {});
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  // Cek apakah nama sudah ada (case insensitive)
                  final nameLower = value.toLowerCase().trim();
                  if (_existingAccountNames.contains(nameLower)) {
                    return 'Nama akun layanan "$value" sudah digunakan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Nomor Telepon'),
              TextFormField(
                controller: _teleponController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13), // Maksimal 13 digit
                ],
                decoration: _inputDecoration(hintText: 'Contoh: 0812xxxxxxxx')
                    .copyWith(
                      errorText: _phoneValidationError,
                      errorStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.red.shade400,
                          width: 2,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.red.shade400,
                          width: 2,
                        ),
                      ),
                    ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor telepon wajib diisi';
                  }
                  if (!value.startsWith('08')) {
                    return 'Nomor telepon harus dimulai dengan 08';
                  }
                  if (value.length < 11) {
                    return 'Nomor telepon minimal 11 angka';
                  }
                  if (value.length > 13) {
                    return 'Nomor telepon maksimal 13 angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Kota/Kabupaten'),
              _buildReadOnlyTextFormField(
                controller: _kotaController,
                hintText: 'Masukkan kota/kabupaten',
                readOnly: (_cityName ?? '').isNotEmpty,
              ),
              const SizedBox(height: 16),
              _buildLabel('Kecamatan'),
              InkWell(
                onTap: _showKecamatanPicker,
                borderRadius: BorderRadius.circular(10),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _kecamatanController,
                    decoration: _inputDecoration(
                      hintText: 'Pilih kecamatan',
                    ).copyWith(
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Kecamatan wajib diisi' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel('Kelurahan'),
              Column(
                children: [
                  InkWell(
                    onTap: _showKelurahanPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: _kelurahanController,
                        decoration: _inputDecoration(
                          hintText: _selectedKecamatanOption == null
                              ? 'Pilih kecamatan terlebih dahulu'
                              : (_isKelurahanLoading
                                  ? 'Memuat kelurahan...'
                                  : 'Pilih kelurahan'),
                        ).copyWith(
                          suffixIcon: _isKelurahanLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Kelurahan wajib diisi' : null,
                      ),
                    ),
                  ),
                  if (_isKelurahanLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('RW (Rukun Warga)'),
              TextFormField(
                controller: _rwController,
                keyboardType: TextInputType.text,
                decoration:
                    _inputDecoration(
                      hintText: 'Contoh: RW 05 atau ketik 5',
                    ).copyWith(
                      helperText: 'Minimal RW 01, tidak boleh RW 00',
                      helperStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'RW wajib diisi';
                  }
                  // Regex untuk format RW (case insensitive)
                  // Boleh: "RW 5", "rw 05", "5", "05", "RW05"
                  final rwRegex = RegExp(
                    r'^(RW\s*)?\d{1,3}$',
                    caseSensitive: false,
                  );
                  if (!rwRegex.hasMatch(value.trim())) {
                    return 'Format RW tidak valid. Contoh: RW 05 atau 5';
                  }

                  // Validasi tidak boleh RW 00
                  final rwNumber = int.tryParse(
                    value.trim().replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  if (rwNumber != null && rwNumber == 0) {
                    return 'RW tidak boleh 00. Minimal harus RW 01';
                  }

                  return null;
                },
                onChanged: (value) {
                  // Auto-format: jika user ketik angka saja, tambahkan prefix RW
                  if (value.isNotEmpty &&
                      RegExp(r'^\d+$').hasMatch(value.trim())) {
                    final formatted = 'RW ${value.trim().padLeft(2, '0')}';
                    if (_rwController.text != formatted) {
                      _rwController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Preview Lokasi (Titik Merah = Lokasi Dipilih)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '💡 Klik pada peta untuk memilih lokasi',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              _buildMapPreview(),
              const SizedBox(height: 16),
              _buildLabel('Detail Alamat'),
              _buildTextFormField(
                controller: _detailAlamatController,
                hintText: _isLoadingAddress
                    ? 'Sedang mengambil alamat...'
                    : 'Contoh: nama bangunan, nomor unit',
                onFieldSubmitted: _searchAddress,
              ),
              if (_isLoadingAddress)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mengambil alamat dari peta...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14.0,
        horizontal: 12.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? validatorMessage,
    Function(String)? onFieldSubmitted,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(hintText: hintText),
      validator: (value) {
        if (validatorMessage != null && (value == null || value.isEmpty)) {
          return validatorMessage;
        }
        return null;
      },
      onFieldSubmitted: (value) {
        if (onFieldSubmitted != null) {
          onFieldSubmitted(value);
        }
      },
    );
  }

  Widget _buildReadOnlyTextFormField({
    required TextEditingController controller,
    String? hintText,
    bool readOnly = true,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: _inputDecoration(hintText: hintText ?? controller.text)
          .copyWith(
            fillColor: readOnly ? Colors.grey.shade100 : null,
            filled: readOnly,
          ),
    );
  }

  Widget _buildMapPreview() {
    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_latitude, _longitude),
                initialZoom: _currentZoom,
                onTap: (tapPosition, point) {
                  setState(() {
                    _latitude = point.latitude;
                    _longitude = point.longitude;
                  });
                  _getAddressFromCoordinates(point.latitude, point.longitude);
                  _mapController.move(
                    LatLng(_latitude, _longitude),
                    _currentZoom,
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.mycompany.myapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_latitude, _longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(217),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 4),
                  ],
                ),
                child: Column(
                  children: [
                    _buildZoomButton(Icons.add, _zoomIn, 'zoomIn'),
                    const Divider(height: 1, thickness: 1, color: Colors.grey),
                    _buildZoomButton(Icons.remove, _zoomOut, 'zoomOut'),
                    const Divider(height: 1, thickness: 1, color: Colors.grey),
                    _buildZoomButton(
                      Icons.fullscreen,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenMapPage(
                              latitude: _latitude,
                              longitude: _longitude,
                              zoom: _currentZoom,
                            ),
                          ),
                        ).then((result) {
                          if (result != null && result is LatLng) {
                            setState(() {
                              _latitude = result.latitude;
                              _longitude = result.longitude;
                            });
                            _mapController.move(result, _currentZoom);
                            // Update alamat berdasarkan koordinat yang dipilih
                            _getAddressFromCoordinates(
                              result.latitude,
                              result.longitude,
                            );
                          }
                        });
                      },
                      'fullscreenMap',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            // ✅ Tombol "Gunakan Lokasi Saat Ini"
            Positioned(
              bottom: 10,
              left: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isGettingCurrentLocation ? null : _getCurrentLocation,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009688),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isGettingCurrentLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 16,
                              ),
                        const SizedBox(width: 6),
                        Text(
                          _isGettingCurrentLocation
                              ? 'Mencari...'
                              : 'Lokasi Saya',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  Widget _buildZoomButton(
    IconData icon,
    VoidCallback onPressed,
    String tag, {
    bool isLast = false,
  }) {
    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 0),
      child: FloatingActionButton.small(
        heroTag: tag,
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: onPressed,
        child: Icon(icon, color: Colors.black),
      ),
    );
  }
}

class FullscreenMapPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double zoom;

  const FullscreenMapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  @override
  State<FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<FullscreenMapPage> {
  late MapController _mapController;
  late double _latitude;
  late double _longitude;
  late double _currentZoom;
  bool _isGettingLocation = false;

  final double _minZoom = 3.0;
  final double _maxZoom = 19.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _latitude = widget.latitude;
    _longitude = widget.longitude;
    _currentZoom = widget.zoom;
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layanan lokasi tidak aktif. Mohon aktifkan GPS.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Izin lokasi ditolak'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin lokasi ditolak permanen. Ubah di pengaturan.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _currentZoom = 17.0;
      });

      _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendapatkan lokasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peta Lengkap"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // 💡 Mengembalikan koordinat yang dipilih ke halaman sebelumnya
              Navigator.pop(context, LatLng(_latitude, _longitude));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_latitude, _longitude),
              initialZoom: _currentZoom,
              onTap: (tapPosition, point) {
                setState(() {
                  _latitude = point.latitude;
                  _longitude = point.longitude;
                });
                _mapController.move(
                  LatLng(_latitude, _longitude),
                  _currentZoom,
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.mycompany.myapp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_latitude, _longitude),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "fullscreenZoomIn",
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "fullscreenZoomOut",
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
          // Tombol Lokasi Saya
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isGettingLocation ? null : _getCurrentLocation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isGettingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 18,
                              ),
                        const SizedBox(width: 6),
                        const Text(
                          'Lokasi Saya',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
