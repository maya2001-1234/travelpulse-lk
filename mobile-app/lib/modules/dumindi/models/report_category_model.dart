import 'package:flutter/material.dart';

/// TravelPulse LK — Report Category Model (Dumindi)
/// Represents the master report taxonomy defined in Table 9: `report_categories`.
class ReportCategoryModel {
  final int id;
  final String code;
  final String name;
  final String description;
  final String defaultSeverity;
  final IconData icon;

  const ReportCategoryModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.defaultSeverity = 'medium',
    required this.icon,
  });

  /// The exact 6 categories mandated for TravelPulse LK Community Reporting
  static const List<ReportCategoryModel> allCategories = [
    ReportCategoryModel(
      id: 1,
      code: 'CROWD',
      name: 'Crowd Report',
      description: 'Report overcrowding, seat availability, and transit terminal queues.',
      defaultSeverity: 'low',
      icon: Icons.groups_rounded,
    ),
    ReportCategoryModel(
      id: 2,
      code: 'ROAD_CONDITION',
      name: 'Road Condition',
      description: 'Potholes, flash floods, landslides, fallen trees, and road closures.',
      defaultSeverity: 'medium',
      icon: Icons.add_road_rounded,
    ),
    ReportCategoryModel(
      id: 3,
      code: 'TRANSPORT_TRACKING',
      name: 'Transport/Route Tracking',
      description: 'Live bus and train tracking updates, unexpected diversions.',
      defaultSeverity: 'low',
      icon: Icons.directions_bus_rounded,
    ),
    ReportCategoryModel(
      id: 4,
      code: 'SERVICE_DISRUPTION',
      name: 'Service Disruption',
      description: 'Vehicle breakdowns, signal failures, trips cancelled, and severe delays.',
      defaultSeverity: 'high',
      icon: Icons.bus_alert_rounded,
    ),
    ReportCategoryModel(
      id: 5,
      code: 'ACCIDENT_INCIDENT',
      name: 'Accident/Incident',
      description: 'Traffic collisions, vehicle crashes, and urgent commuter safety issues.',
      defaultSeverity: 'critical',
      icon: Icons.car_crash_rounded,
    ),
    ReportCategoryModel(
      id: 6,
      code: 'OTHER',
      name: 'Other',
      description: 'General commuter feedback, route inquiries, and miscellaneous notices.',
      defaultSeverity: 'low',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  static ReportCategoryModel getById(int id) {
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => allCategories.last,
    );
  }

  static ReportCategoryModel getByName(String name) {
    return allCategories.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => allCategories.last,
    );
  }

  factory ReportCategoryModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int? ?? 6;
    final fallback = getById(id);
    return ReportCategoryModel(
      id: id,
      code: json['code'] as String? ?? fallback.code,
      name: json['name'] as String? ?? fallback.name,
      description: json['description'] as String? ?? fallback.description,
      defaultSeverity: json['defaultSeverity'] as String? ?? fallback.defaultSeverity,
      icon: fallback.icon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'defaultSeverity': defaultSeverity,
    };
  }
}

