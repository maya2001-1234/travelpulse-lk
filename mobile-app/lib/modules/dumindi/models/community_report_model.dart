/// TravelPulse LK — Community Report Model (Dumindi)
/// Follows specific project guidelines:
/// - Anonymous reporting option
/// - Mandatory reason capture for disruptions (not invented severity)
/// - Ownership verification (users manage only their own reports)
/// - Integrated reliability score and confidence state (Suneth)
class CommunityReportModel {
  final int id;
  final int userId;
  final String userName;
  final bool isAnonymous;
  final int categoryId;
  final String categoryName;
  final int? routeId;
  final String? routeNumber;
  final int? stopId;
  final String? stopName;
  final double latitude;
  final double longitude;
  final String locationDescription;
  final String title;
  final String description;
  final String? disruptionReason; // Specific reason e.g. Vehicle Breakdown
  final String? transportType; // 'bus' or 'train'
  final String? busRouteNumber;
  final String? destination;
  final String? busRegistrationNumber;
  final String? trainNameOrNumber;
  final String? startingStation;
  final String? crowdLevel; // 'light', 'moderate', 'heavy', 'packed'
  final String? mediaUrl;
  final String status; // 'submitted', 'verified', 'disputed', 'resolved', 'rejected'
  final double reliabilityScore;
  final String confidenceStatus; // 'unverified', 'plausible', 'verified', 'disputed'
  final int upvotesCount;
  final int downvotesCount;
  final String? userVote; // Current commuter's vote: 'upvote', 'downvote', null
  final DateTime createdAt;
  final DateTime? resolvedAt;

  CommunityReportModel({
    required this.id,
    required this.userId,
    this.userName = 'Commuter',
    this.isAnonymous = false,
    required this.categoryId,
    required this.categoryName,
    this.routeId,
    this.routeNumber,
    this.stopId,
    this.stopName,
    required this.latitude,
    required this.longitude,
    required this.locationDescription,
    required this.title,
    required this.description,
    this.disruptionReason,
    this.transportType,
    this.busRouteNumber,
    this.destination,
    this.busRegistrationNumber,
    this.trainNameOrNumber,
    this.startingStation,
    this.crowdLevel,
    this.mediaUrl,
    this.status = 'submitted',
    this.reliabilityScore = 10.0,
    this.confidenceStatus = 'unverified',
    this.upvotesCount = 0,
    this.downvotesCount = 0,
    this.userVote,
    required this.createdAt,
    this.resolvedAt,
  });

  String get displayReporter => isAnonymous ? 'Anonymous Commuter' : userName;
  bool get isVerified => status == 'verified' || confidenceStatus == 'verified';
  bool get isDisputed => status == 'disputed' || confidenceStatus == 'disputed';
  bool get isResolved => status == 'resolved';

  bool isOwnedBy(int? currentUserId) {
    if (currentUserId == null) return false;
    return userId == currentUserId;
  }

  CommunityReportModel copyWith({
    String? status,
    double? reliabilityScore,
    String? confidenceStatus,
    int? upvotesCount,
    int? downvotesCount,
    String? userVote,
    DateTime? resolvedAt,
    String? transportType,
    String? busRouteNumber,
    String? destination,
    String? busRegistrationNumber,
    String? trainNameOrNumber,
    String? startingStation,
    String? crowdLevel,
  }) {
    return CommunityReportModel(
      id: id,
      userId: userId,
      userName: userName,
      isAnonymous: isAnonymous,
      categoryId: categoryId,
      categoryName: categoryName,
      routeId: routeId,
      routeNumber: routeNumber,
      stopId: stopId,
      stopName: stopName,
      latitude: latitude,
      longitude: longitude,
      locationDescription: locationDescription,
      title: title,
      description: description,
      disruptionReason: disruptionReason,
      transportType: transportType ?? this.transportType,
      busRouteNumber: busRouteNumber ?? this.busRouteNumber,
      destination: destination ?? this.destination,
      busRegistrationNumber: busRegistrationNumber ?? this.busRegistrationNumber,
      trainNameOrNumber: trainNameOrNumber ?? this.trainNameOrNumber,
      startingStation: startingStation ?? this.startingStation,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      mediaUrl: mediaUrl,
      status: status ?? this.status,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      confidenceStatus: confidenceStatus ?? this.confidenceStatus,
      upvotesCount: upvotesCount ?? this.upvotesCount,
      downvotesCount: downvotesCount ?? this.downvotesCount,
      userVote: userVote ?? this.userVote,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  factory CommunityReportModel.fromJson(Map<String, dynamic> json) {
    return CommunityReportModel(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] as int? ?? json['user_id'] as int? ?? 0,
      userName: json['userName'] as String? ?? json['user_name'] as String? ?? 'Commuter',
      isAnonymous: json['isAnonymous'] as bool? ?? json['is_anonymous'] as bool? ?? false,
      categoryId: json['categoryId'] as int? ?? json['category_id'] as int? ?? 1,
      categoryName: json['categoryName'] as String? ?? json['category_name'] as String? ?? 'General Report',
      routeId: json['routeId'] as int? ?? json['route_id'] as int?,
      routeNumber: json['routeNumber'] as String? ?? json['route_number'] as String?,
      stopId: json['stopId'] as int? ?? json['stop_id'] as int?,
      stopName: json['stopName'] as String? ?? json['stop_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationDescription: json['locationDescription'] as String? ?? json['location_description'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      disruptionReason: json['disruptionReason'] as String? ?? json['disruption_reason'] as String?,
      transportType: json['transportType'] as String? ?? json['transport_type'] as String?,
      busRouteNumber: json['busRouteNumber'] as String? ?? json['bus_route_number'] as String?,
      destination: json['destination'] as String?,
      busRegistrationNumber: json['busRegistrationNumber'] as String? ?? json['bus_registration_number'] as String?,
      trainNameOrNumber: json['trainNameOrNumber'] as String? ?? json['train_name_or_number'] as String?,
      startingStation: json['startingStation'] as String? ?? json['starting_station'] as String?,
      crowdLevel: json['crowdLevel'] as String? ?? json['crowd_level'] as String?,
      mediaUrl: json['mediaUrl'] as String? ?? json['media_url'] as String?,
      status: json['status'] as String? ?? 'submitted',
      reliabilityScore: (json['reliabilityScore'] as num?)?.toDouble() ?? (json['reliability_score'] as num?)?.toDouble() ?? 10.0,
      confidenceStatus: json['confidenceStatus'] as String? ?? json['confidence_status'] as String? ?? 'unverified',
      upvotesCount: json['upvotesCount'] as int? ?? json['upvotes_count'] as int? ?? json['upvotes'] as int? ?? 0,
      downvotesCount: json['downvotesCount'] as int? ?? json['downvotes_count'] as int? ?? json['downvotes'] as int? ?? 0,
      userVote: json['userVote'] as String? ?? json['user_vote'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : (json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'isAnonymous': isAnonymous,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'routeId': routeId,
      'routeNumber': routeNumber,
      'stopId': stopId,
      'stopName': stopName,
      'latitude': latitude,
      'longitude': longitude,
      'locationDescription': locationDescription,
      'title': title,
      'description': description,
      'disruptionReason': disruptionReason,
      'transportType': transportType,
      'busRouteNumber': busRouteNumber,
      'destination': destination,
      'busRegistrationNumber': busRegistrationNumber,
      'trainNameOrNumber': trainNameOrNumber,
      'startingStation': startingStation,
      'crowdLevel': crowdLevel,
      'mediaUrl': mediaUrl,
      'status': status,
      'reliabilityScore': reliabilityScore,
      'confidenceStatus': confidenceStatus,
      'upvotesCount': upvotesCount,
      'downvotesCount': downvotesCount,
      'userVote': userVote,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }
}

