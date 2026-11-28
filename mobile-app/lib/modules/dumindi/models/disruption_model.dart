/// TravelPulse LK — Public Transport Disruption Model (Dumindi)
class DisruptionModel {
  final int id;
  final int? originatingReportId;
  final int routeId;
  final String routeNumber;
  final String routeName;
  final int? affectedStopId;
  final String? affectedStopName;
  final String disruptionType;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String headline;
  final String details;
  final String status; // 'active', 'cleared', 'archived'
  final DateTime startedAt;
  final DateTime? estimatedClearedAt;
  final DateTime? clearedAt;

  DisruptionModel({
    required this.id,
    this.originatingReportId,
    required this.routeId,
    required this.routeNumber,
    required this.routeName,
    this.affectedStopId,
    this.affectedStopName,
    required this.disruptionType,
    this.severity = 'medium',
    required this.headline,
    required this.details,
    this.status = 'active',
    required this.startedAt,
    this.estimatedClearedAt,
    this.clearedAt,
  });

  bool get isActive => status == 'active';
  bool get isCritical => severity == 'critical' || severity == 'high';

  factory DisruptionModel.fromJson(Map<String, dynamic> json) {
    return DisruptionModel(
      id: json['id'] as int? ?? 0,
      originatingReportId: json['originatingReportId'] as int?,
      routeId: json['routeId'] as int? ?? 0,
      routeNumber: json['routeNumber'] as String? ?? '',
      routeName: json['routeName'] as String? ?? '',
      affectedStopId: json['affectedStopId'] as int?,
      affectedStopName: json['affectedStopName'] as String?,
      disruptionType: json['disruptionType'] as String? ?? 'Disruption',
      severity: json['severity'] as String? ?? 'medium',
      headline: json['headline'] as String? ?? '',
      details: json['details'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedClearedAt: json['estimatedClearedAt'] != null
          ? DateTime.tryParse(json['estimatedClearedAt'].toString())
          : null,
      clearedAt: json['clearedAt'] != null
          ? DateTime.tryParse(json['clearedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originatingReportId': originatingReportId,
      'routeId': routeId,
      'routeNumber': routeNumber,
      'routeName': routeName,
      'affectedStopId': affectedStopId,
      'affectedStopName': affectedStopName,
      'disruptionType': disruptionType,
      'severity': severity,
      'headline': headline,
      'details': details,
      'status': status,
      'startedAt': startedAt.toIso8601String(),
      'estimatedClearedAt': estimatedClearedAt?.toIso8601String(),
      'clearedAt': clearedAt?.toIso8601String(),
    };
  }
}

