import 'package:beresin_app/utils/app_log.dart';
class OffSchedulePickup {
  final int id;
  final ServiceAccount? serviceAccount;
  final int? _serviceAccountIdDirect; // Fallback if service_account is null
  final String pickupType;
  final String requestStatus;
  final String status;
  final int bagCount;
  final int baseAmount;
  final int extraFee;
  final int totalAmount;
  final DateTime? createdAt;
  final String requestedPickupDate;
  final String? requestedPickupTime;
  final AssignedCollector? assignedCollector;
  final String? rejectionReason;
  final String? photoUrl;
  final Invoice? invoice;
  final String? residentNote;
  final String? note;
  final String? collectorNotes;
  final DateTime? collectedAt;
  // Timestamps for status tracking
  final DateTime? processedAt;
  final DateTime? completedAt;
  final DateTime? assignedAt;
  // Waste items details
  final List<Map<String, dynamic>>? wasteItems;

  OffSchedulePickup({
    required this.id,
    this.serviceAccount,
    int? serviceAccountIdDirect,
    required this.pickupType,
    required this.requestStatus,
    required this.status,
    required this.bagCount,
    required this.baseAmount,
    required this.extraFee,
    required this.totalAmount,
    this.createdAt,
    required this.requestedPickupDate,
    this.requestedPickupTime,
    this.assignedCollector,
    this.rejectionReason,
    this.photoUrl,
    this.invoice,
    this.residentNote,
    this.note,
    this.collectorNotes,
    this.collectedAt,
    this.processedAt,
    this.completedAt,
    this.assignedAt,
    this.wasteItems,
  }) : _serviceAccountIdDirect = serviceAccountIdDirect;

  // Convenience getters for backward compatibility
  int get serviceAccountId {
    if (serviceAccount != null) {
      return serviceAccount!.id;
    }
    return _serviceAccountIdDirect ?? 0;
  }
  String get serviceAccountName => serviceAccount?.name ?? '';
  String get address => serviceAccount?.address ?? '';

  factory OffSchedulePickup.fromJson(Map<String, dynamic> json) {
    // Parse service_account_id directly as fallback
    int? directServiceAccountId;
    if (json['service_account_id'] != null) {
      final saId = json['service_account_id'];
      directServiceAccountId = saId is int ? saId : int.tryParse(saId.toString());
    }
    
    return OffSchedulePickup(
      id: json['id'] ?? 0,
      serviceAccount: json['service_account'] != null
          ? ServiceAccount.fromJson(json['service_account'])
          : null,
      serviceAccountIdDirect: directServiceAccountId,
      pickupType: json['pickup_type'] ?? 'request',
      requestStatus: json['request_status'] ?? 'sent',
      status: json['status'] ?? 'pending',
      bagCount: json['bag_count'] ?? 0,
      baseAmount: (json['base_amount'] ?? 0).toInt(),
      extraFee: (json['extra_fee'] ?? 0).toInt(),
      totalAmount: (json['total_amount'] ?? 0).toInt(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() // ✅ Convert to local timezone
          : null,
      requestedPickupDate: json['requested_pickup_date'] ?? '',
      requestedPickupTime: json['requested_pickup_time'],
      assignedCollector: json['assigned_collector'] != null
          ? AssignedCollector.fromJson(json['assigned_collector'])
          : null,
      rejectionReason: json['rejection_reason'],
      photoUrl: json['photo_url'],
      invoice: json['invoice'] != null ? Invoice.fromJson(json['invoice']) : null,
      residentNote: json['resident_note'],
      note: json['note'],
      collectorNotes: json['collector_notes'],
      collectedAt: json['collected_at'] != null
          ? DateTime.parse(json['collected_at']).toLocal() // ✅ Convert to local timezone
          : null,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at']).toLocal() // ✅ Convert to local timezone
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at']).toLocal() // ✅ Convert to local timezone
          : null,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at']).toLocal() // ✅ Convert to local timezone
          : null,
      wasteItems: json['waste_items'] != null
          ? List<Map<String, dynamic>>.from(json['waste_items'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_account': serviceAccount?.toJson(),
      'service_account_id': serviceAccountId,
      'pickup_type': pickupType,
      'request_status': requestStatus,
      'status': status,
      'bag_count': bagCount,
      'base_amount': baseAmount,
      'extra_fee': extraFee,
      'total_amount': totalAmount,
      'created_at': createdAt?.toIso8601String(),
      'requested_pickup_date': requestedPickupDate,
      'requested_pickup_time': requestedPickupTime,
      'assigned_collector': assignedCollector?.toJson(),
      'rejection_reason': rejectionReason,
      'photo_url': photoUrl,
      'invoice': invoice?.toJson(),
      'resident_note': residentNote,
      'note': note,
      'collector_notes': collectorNotes,
      'collected_at': collectedAt?.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'waste_items': wasteItems,
    };
  }

  String getStatusLabel() {
    switch (requestStatus) {
      case 'sent':
        return 'Menunggu Penugasan';
      case 'processing':
        return 'Sedang Diproses';
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'completed':
        return 'Selesai';
      case 'paid':
        return 'Lunas';
      case 'rejected':
        return 'Ditolak';
      default:
        return requestStatus;
    }
  }

  String getStatusColor() {
    switch (requestStatus) {
      case 'sent':
        return 'blue';
      case 'processing':
        return 'orange';
      case 'pending':
        return 'purple';
      case 'completed':
        return 'green';
      case 'paid':
        return 'teal';
      case 'rejected':
        return 'red';
      default:
        return 'grey';
    }
  }
}

class ServiceAccount {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;

  ServiceAccount({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.contactPhone,
  });

  factory ServiceAccount.fromJson(Map<String, dynamic> json) {
    // Debug: Print all available keys
    appLog('🔍 [ServiceAccount] Parsing from JSON with keys: ${json.keys.toList()}');
    appLog('   Raw JSON: $json');
    
    // Parse id as int, handling both int and string
    int parsedId = 0;
    if (json['id'] != null) {
      if (json['id'] is int) {
        parsedId = json['id'];
      } else {
        parsedId = int.tryParse(json['id'].toString()) ?? 0;
      }
    }
    
    return ServiceAccount(
      id: parsedId,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      // ✅ PERBAIKAN: Coba beberapa kemungkinan field name untuk contact phone
      contactPhone: json['contact_phone'] ?? json['phone'] ?? json['contact_number'] ?? json['phone_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contact_phone': contactPhone,
    };
  }
}

class AssignedCollector {
  final int id;
  final String name;

  AssignedCollector({
    required this.id,
    required this.name,
  });

  factory AssignedCollector.fromJson(Map<String, dynamic> json) {
    return AssignedCollector(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class Invoice {
  final int id;
  final String invoiceNumber;
  final String status;
  final int totalAmount;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.totalAmount,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      invoiceNumber: json['invoice_number'],
      status: json['status'],
      totalAmount: json['total_amount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'status': status,
      'total_amount': totalAmount,
    };
  }
}
