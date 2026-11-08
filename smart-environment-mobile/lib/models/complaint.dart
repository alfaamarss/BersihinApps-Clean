import 'package:beresin_app/utils/app_log.dart';
/// Model untuk foto complaint
class ComplaintPhoto {
  final int id;
  final String url;
  final int order;

  ComplaintPhoto({required this.id, required this.url, required this.order});

  factory ComplaintPhoto.fromJson(Map<String, dynamic> json) {
    appLog('📷 [ComplaintPhoto] Parsing photo: $json');
    
    // Parse URL - coba berbagai kemungkinan field
    String photoUrl = json['url']?.toString() ?? 
                      json['photo_url']?.toString() ?? 
                      json['path']?.toString() ?? 
                      json['file_path']?.toString() ?? 
                      json['image']?.toString() ?? '';
    
    appLog('📷 [ComplaintPhoto] Parsed URL: $photoUrl');
    
    return ComplaintPhoto(
      id: json['id'] as int? ?? 0,
      url: photoUrl,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'url': url, 'order': order};
  }
}

class Complaint {
  final String id;
  final String userId;
  final String? serviceAccountId;
  final String? assigneeId;
  final String type; // Jenis keluhan
  final String description;
  final String? location; // Lokasi kejadian (address)
  final double? latitude; // ✅ NEW: Latitude lokasi
  final double? longitude; // ✅ NEW: Longitude lokasi
  final String status; // 'open', 'in_progress', 'pending_confirmation', 'resolved', 'rejected'
  final List<ComplaintPhoto> photos; // Evidence photos
  final String? resolutionPhoto; // ✅ Foto penyelesaian dari collector
  final String? rejectionReason; // ✅ NEW: Alasan penolakan
  final Map<String, dynamic>? reporter; // Reporter information for collector view
  final Map<String, dynamic>? serviceAccount; // ✅ NEW: Service account info
  final Map<String, dynamic>? assignee; // ✅ NEW: Assignee (collector) info
  final DateTime createdAt;
  final DateTime updatedAt;

  Complaint({
    required this.id,
    required this.userId,
    this.serviceAccountId,
    this.assigneeId,
    required this.type,
    required this.description,
    this.location,
    this.latitude,
    this.longitude,
    required this.status,
    this.photos = const [],
    this.resolutionPhoto,
    this.rejectionReason,
    this.reporter,
    this.serviceAccount,
    this.assignee,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final photosList = json['photos'] as List<dynamic>?;
    final photos = photosList != null
        ? photosList
              .map((p) => ComplaintPhoto.fromJson(p as Map<String, dynamic>))
              .toList()
        : <ComplaintPhoto>[];

    // Parse dates with fallback and convert to local timezone
    DateTime createdAt;
    DateTime updatedAt;
    try {
      createdAt = DateTime.parse(json['created_at']).toLocal(); // ✅ Convert to local timezone
    } catch (e) {
      createdAt = DateTime.now();
    }
    try {
      updatedAt = DateTime.parse(json['updated_at'] ?? json['created_at']).toLocal(); // ✅ Convert to local timezone
    } catch (e) {
      updatedAt = createdAt;
    }

    // ✅ Parse reporter and service_account info
    Map<String, dynamic>? reporterData;
    
    // Priority 1: Check service_account field (for collector view)
    if (json.containsKey('service_account') && json['service_account'] != null) {
      final serviceAccount = json['service_account'] as Map<String, dynamic>;
      appLog('📋 [Complaint] Service Account Data: $serviceAccount');
      
      // Coba berbagai kemungkinan field untuk phone
      final phone = serviceAccount['contact_phone'] ?? 
                    serviceAccount['phone'] ?? 
                    serviceAccount['contact_number'] ?? 
                    serviceAccount['kontak'] ?? 
                    serviceAccount['phone_number'] ?? '';
      
      // Map service account sebagai reporter
      reporterData = {
        'id': serviceAccount['id'],
        'name': serviceAccount['name'] ?? 'Service Account',
        'phone': phone,
        'address': serviceAccount['address'] ?? serviceAccount['alamat'] ?? '',
        'photo': serviceAccount['photo'] ?? serviceAccount['foto'] ?? '',
        'email': serviceAccount['email'] ?? '',
      };
      
      appLog('📋 [Complaint] Mapped Service Account as Reporter:');
      appLog('   - Name: ${reporterData['name']}');
      appLog('   - Phone: ${reporterData['phone']}');
      appLog('   - Email: ${reporterData['email']}');
      appLog('   - Address: ${reporterData['address']}');
    }
    // Priority 2: Use reporter field if available (for user view)
    else if (json.containsKey('reporter') && json['reporter'] != null) {
      reporterData = json['reporter'] as Map<String, dynamic>;
      appLog('📋 [Complaint] Using reporter field: $reporterData');
      
      // If reporter doesn't have phone, it might be user data not service account
      if (!reporterData.containsKey('phone') && 
          !reporterData.containsKey('contact_phone')) {
        appLog('⚠️ [Complaint] Reporter has no phone - might be user data instead of service account');
      }
    }
    
    if (reporterData == null) {
      appLog('⚠️ [Complaint] No reporter or service_account data found');
      appLog('📋 Available keys in JSON: ${json.keys.toList()}');
    }

    return Complaint(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      serviceAccountId: json['service_account_id']?.toString(),
      assigneeId: json['assignee_id']?.toString(),
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      location: json['address']?.toString(), // ✅ API menggunakan field 'address'
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null, // ✅ NEW
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null, // ✅ NEW
      status: json['status'] ?? 'open',
      photos: photos,
      resolutionPhoto: json['resolution_photo']?.toString(), // ✅ Foto resolution
      rejectionReason: json['rejection_reason']?.toString(), // ✅ NEW
      reporter: reporterData,
      serviceAccount: json['service_account'] as Map<String, dynamic>?, // ✅ NEW
      assignee: json['assignee'] as Map<String, dynamic>?, // ✅ NEW
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'service_account_id': serviceAccountId,
      'assignee_id': assigneeId,
      'type': type,
      'description': description,
      'address': location,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'photos': photos.map((p) => p.toJson()).toList(),
      'resolution_photo': resolutionPhoto,
      'rejection_reason': rejectionReason,
      'reporter': reporter,
      'service_account': serviceAccount,
      'assignee': assignee,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get status display text in Indonesian
  String get statusText {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Menunggu';
      case 'in_progress':
        return 'Diproses';
      case 'pending_confirmation': // ✅ NEW: Status menunggu konfirmasi
        return 'Menunggu Konfirmasi';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  /// Get type display text in Indonesian
  String get typeText {
    switch (type.toLowerCase()) {
      // Tipe dari dokumentasi API
      case 'sampah_tidak_diangkut':
        return 'Sampah Tidak Diangkut';
      case 'sampah_menumpuk':
        return 'Sampah Menumpuk';
      case 'jadwal_tidak_sesuai':
        return 'Jadwal Tidak Sesuai';
      case 'pelayanan_buruk':
        return 'Pelayanan Buruk';
      case 'petugas_tidak_datang':
        return 'Petugas Tidak Datang';
      case 'lainnya':
        return 'Lainnya';
      // Legacy types (backward compatibility)
      case 'illegal_dumping':
        return 'Pembuangan Sampah Sembarangan';
      case 'uncollected_waste':
        return 'Sampah Tidak Diangkut';
      case 'damaged_facility':
        return 'Fasilitas Rusak';
      case 'other':
        return 'Lainnya';
      default:
        return type;
    }
  }

  Complaint copyWith({
    String? id,
    String? userId,
    String? serviceAccountId,
    String? assigneeId,
    String? type,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    String? status,
    List<ComplaintPhoto>? photos,
    String? resolutionPhoto,
    String? rejectionReason,
    Map<String, dynamic>? reporter,
    Map<String, dynamic>? serviceAccount,
    Map<String, dynamic>? assignee,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Complaint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serviceAccountId: serviceAccountId ?? this.serviceAccountId,
      assigneeId: assigneeId ?? this.assigneeId,
      type: type ?? this.type,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      photos: photos ?? this.photos,
      resolutionPhoto: resolutionPhoto ?? this.resolutionPhoto,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reporter: reporter ?? this.reporter,
      serviceAccount: serviceAccount ?? this.serviceAccount,
      assignee: assignee ?? this.assignee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
