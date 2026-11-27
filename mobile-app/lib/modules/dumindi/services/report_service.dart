import 'dart:async';
import '../../../core/models/api_response.dart';
import '../../../core/services/api_service.dart';
import '../models/community_report_model.dart';
import '../models/disruption_model.dart';
import '../models/report_category_model.dart';

/// TravelPulse LK — Community Reporting Service (Dumindi)
/// ---------------------------------------------------------------------------
/// Connects to Express backend (/api/v1/reports) with graceful offline fallback.
/// Implements community incident reporting, disruption management,
/// anonymous submission handling, ownership verification for deletion,
/// and Suneth's peer voting & reliability recalculation hooks.
/// ---------------------------------------------------------------------------
class ReportService {
  final ApiService _api;

  ReportService({ApiService? api}) : _api = api ?? ApiService();

  // Seeded authentic reports across Sri Lankan transit corridors
  static final List<CommunityReportModel> _reports = [
    CommunityReportModel(
      id: 101,
      userId: 1, // Kamal Perera
      userName: 'Kamal Perera',
      isAnonymous: false,
      categoryId: 4,
      categoryName: 'Service Disruption',
      routeId: 1,
      routeNumber: '138',
      stopId: 104,
      stopName: 'Town Hall / Viharamahadevi Park',
      latitude: 6.9147,
      longitude: 79.8653,
      locationDescription: 'Town Hall roundabout near Public Library',
      title: 'Bus Breakdown Blocking Center Lane',
      description: 'Route 138 SLTB bus broke down right after the roundabout. Traffic backing up towards Maradana and Borella.',
      disruptionReason: 'Vehicle Breakdown',
      status: 'verified',
      reliabilityScore: 84.0,
      confidenceStatus: 'verified',
      upvotesCount: 8,
      downvotesCount: 1,
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    CommunityReportModel(
      id: 102,
      userId: 2, // Dilshan Silva
      userName: 'Dilshan Silva',
      isAnonymous: true, // Anonymous report demo
      categoryId: 2,
      categoryName: 'Road Condition',
      routeId: 2,
      routeNumber: '100',
      latitude: 6.8920,
      longitude: 79.8580,
      locationDescription: 'Bauddhaloka Mawatha near Thunmulla',
      title: 'Severe Waterlogging / Flash Flood',
      description: 'Heavy rain has flooded the junction with 1.5 feet of water. Low clearance vehicles cannot pass. Buses moving slowly.',
      disruptionReason: 'Road Inundation / Flooding',
      status: 'verified',
      reliabilityScore: 92.0,
      confidenceStatus: 'verified',
      upvotesCount: 14,
      downvotesCount: 0,
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
    ),
    CommunityReportModel(
      id: 103,
      userId: 1, // Kamal Perera
      userName: 'Kamal Perera',
      isAnonymous: false,
      categoryId: 1,
      categoryName: 'Crowd Report',
      routeId: 1,
      routeNumber: '138',
      stopId: 101,
      stopName: 'Pettah Main Bus Stand',
      latitude: 6.9355,
      longitude: 79.8530,
      locationDescription: 'Route 138 bus bay',
      title: 'Heavy Evening Rush Hour Overcrowding',
      description: 'Huge queue extending over 50 meters. Buses arriving every 10 minutes but fill immediately.',
      disruptionReason: null,
      transportType: 'bus',
      busRouteNumber: '138',
      destination: 'Maharagama',
      busRegistrationNumber: 'NA-4512',
      crowdLevel: 'heavy',
      status: 'submitted',
      reliabilityScore: 60.0,
      confidenceStatus: 'plausible',
      upvotesCount: 3,
      downvotesCount: 0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    CommunityReportModel(
      id: 104,
      userId: 3,
      userName: 'Nadeesha Fernando',
      isAnonymous: false,
      categoryId: 5,
      categoryName: 'Accident/Incident',
      latitude: 6.8724,
      longitude: 79.8898,
      locationDescription: 'Nugegoda Flyover Junction',
      title: 'Motorcycle & Van Collision under Flyover',
      description: 'Accident under the Nugegoda flyover blocking one lane towards High Level Road. Traffic police on scene directing vehicles.',
      disruptionReason: 'Traffic Collision',
      status: 'submitted',
      reliabilityScore: 45.0,
      confidenceStatus: 'plausible',
      upvotesCount: 5,
      downvotesCount: 1,
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    CommunityReportModel(
      id: 105,
      userId: 2,
      userName: 'Dilshan Silva',
      isAnonymous: true,
      categoryId: 3,
      categoryName: 'Transport/Route Tracking',
      routeId: 3,
      routeNumber: 'MAIN-RLY',
      stopId: 115,
      stopName: 'Ragama Junction Railway Station',
      latitude: 7.0270,
      longitude: 79.9230,
      locationDescription: 'Ragama Platform 3',
      title: 'Commuter Train Stationary on Platform',
      description: 'Upcountry slow train has been held at Ragama for 20 minutes awaiting clearance signal.',
      status: 'submitted',
      reliabilityScore: 35.0,
      confidenceStatus: 'unverified',
      upvotesCount: 2,
      downvotesCount: 0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
  ];

  static final List<DisruptionModel> _disruptions = [
    DisruptionModel(
      id: 201,
      originatingReportId: 101,
      routeId: 1,
      routeNumber: '138',
      routeName: 'Colombo Fort - Maharagama',
      affectedStopId: 104,
      affectedStopName: 'Town Hall',
      disruptionType: 'Vehicle Breakdown',
      severity: 'medium',
      headline: 'Route 138 Delays Near Town Hall',
      details: 'SLTB bus mechanical failure has restricted traffic flow to a single lane. Estimated travel delay of 15-20 minutes.',
      status: 'active',
      startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      estimatedClearedAt: DateTime.now().add(const Duration(minutes: 45)),
    ),
    DisruptionModel(
      id: 202,
      routeId: 3,
      routeNumber: 'MAIN-RLY',
      routeName: 'Main Line Train (Colombo - Kandy)',
      disruptionType: 'Track Maintenance / Signal Failure',
      severity: 'high',
      headline: 'Main Line Railway Signal Failure',
      details: 'Automatic block signalling system down between Ragama and Gampaha. All trains running at restricted speed with 25-30 min delays.',
      status: 'active',
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      estimatedClearedAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  ];

  static int _nextReportId = 106;

  /// Retrieve the 6 master report categories
  Future<ApiResponse<List<ReportCategoryModel>>> getCategories() async {
    // 1. Attempt live HTTP call to /api/v1/reports/categories
    final apiRes = await _api.get<List<ReportCategoryModel>>(
      '/reports/categories',
      includeAuth: false,
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((item) => ReportCategoryModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        return <ReportCategoryModel>[];
      },
    );

    if (apiRes.isSuccess && apiRes.data != null && apiRes.data!.isNotEmpty) {
      return apiRes;
    }

    // 2. Offline fallback
    return ApiResponse.success(
      message: 'Categories loaded (offline mode)',
      data: ReportCategoryModel.allCategories,
    );
  }

  /// Get active community reports with optional filtering
  Future<ApiResponse<List<CommunityReportModel>>> getReports({
    String? categoryFilter,
    String? statusFilter,
    int? routeId,
  }) async {
    // 1. Prepare query parameters
    final Map<String, String> queryParams = {};
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter.toLowerCase() != 'all') {
      final matchingCat = ReportCategoryModel.allCategories.firstWhere(
        (c) => c.name.toLowerCase() == categoryFilter.toLowerCase(),
        orElse: () => ReportCategoryModel.allCategories.last,
      );
      if (matchingCat.name.toLowerCase() == categoryFilter.toLowerCase()) {
        queryParams['categoryId'] = matchingCat.id.toString();
      }
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'all') {
      queryParams['status'] = statusFilter.toLowerCase();
    }
    if (routeId != null) {
      queryParams['routeId'] = routeId.toString();
    }

    // 2. Attempt live HTTP call to /api/v1/reports
    final apiRes = await _api.get<List<CommunityReportModel>>(
      '/reports',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      includeAuth: true,
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((item) => CommunityReportModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        return <CommunityReportModel>[];
      },
    );

    if (apiRes.isSuccess && apiRes.data != null) {
      return apiRes;
    }

    // 3. Offline fallback
    var list = List<CommunityReportModel>.from(_reports);

    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter.toLowerCase() != 'all') {
      list = list.where((r) => r.categoryName.toLowerCase() == categoryFilter.toLowerCase()).toList();
    }

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'all') {
      list = list.where((r) => r.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    }

    if (routeId != null) {
      list = list.where((r) => r.routeId == routeId).toList();
    }

    // Sort by newest first
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ApiResponse.success(
      message: 'Reports retrieved successfully (offline mode)',
      data: list,
    );
  }

  /// Get reports authored by a specific commuter (shows both identified & anonymous)
  Future<ApiResponse<List<CommunityReportModel>>> getMyReports(int userId) async {
    // 1. Attempt live HTTP call to /api/v1/reports/my-reports
    final apiRes = await _api.get<List<CommunityReportModel>>(
      '/reports/my-reports',
      includeAuth: true,
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((item) => CommunityReportModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        return <CommunityReportModel>[];
      },
    );

    if (apiRes.isSuccess && apiRes.data != null) {
      return apiRes;
    }

    // 2. Offline fallback
    final myReports = _reports.where((r) => r.userId == userId).toList();
    myReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ApiResponse.success(
      message: 'My reports retrieved (offline mode)',
      data: myReports,
    );
  }

  /// Get report details by ID
  Future<ApiResponse<CommunityReportModel>> getReportById(int id) async {
    // 1. Attempt live HTTP call to /api/v1/reports/:id
    final apiRes = await _api.get<CommunityReportModel>(
      '/reports/$id',
      includeAuth: true,
      fromJsonT: (json) => CommunityReportModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );

    if (apiRes.isSuccess && apiRes.data != null) {
      return apiRes;
    }

    if (apiRes.statusCode == 404 || apiRes.error?.code == 'RESOURCE_NOT_FOUND') {
      return ApiResponse.failure(
        message: 'Report not found.',
        code: 'REPORT_NOT_FOUND',
        statusCode: 404,
      );
    }

    // 2. Offline fallback
    final report = _reports.firstWhere(
      (r) => r.id == id,
      orElse: () => CommunityReportModel(
        id: 0,
        userId: 0,
        categoryId: 0,
        categoryName: '',
        latitude: 0,
        longitude: 0,
        locationDescription: '',
        title: '',
        description: '',
        createdAt: DateTime.now(),
      ),
    );

    if (report.id == 0) {
      return ApiResponse.failure(
        message: 'Report not found.',
        code: 'REPORT_NOT_FOUND',
        statusCode: 404,
      );
    }

    return ApiResponse.success(
      message: 'Report loaded (offline mode)',
      data: report,
    );
  }

  /// Submit a new community report
  Future<ApiResponse<CommunityReportModel>> submitReport({
    required int userId,
    required String userName,
    required bool isAnonymous,
    required int categoryId,
    required String categoryName,
    int? routeId,
    String? routeNumber,
    int? stopId,
    String? stopName,
    required double latitude,
    required double longitude,
    required String locationDescription,
    required String title,
    required String description,
    String? disruptionReason,
    String? transportType,
    String? busRouteNumber,
    String? destination,
    String? busRegistrationNumber,
    String? trainNameOrNumber,
    String? startingStation,
    String? crowdLevel,
    String? mediaUrl,
  }) async {
    // 1. Attempt live HTTP submission to /api/v1/reports
    final body = <String, dynamic>{
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
      'isAnonymous': isAnonymous,
      'mediaUrl': mediaUrl,
    };

    final apiRes = await _api.post<CommunityReportModel>(
      '/reports',
      body: body,
      includeAuth: true,
      fromJsonT: (json) => CommunityReportModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );

    if (apiRes.isSuccess && apiRes.data != null) {
      _reports.insert(0, apiRes.data!);
      return apiRes;
    }

    // 2. Offline fallback simulation
    final newReport = CommunityReportModel(
      id: _nextReportId++,
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
      transportType: transportType,
      busRouteNumber: busRouteNumber,
      destination: destination,
      busRegistrationNumber: busRegistrationNumber,
      trainNameOrNumber: trainNameOrNumber,
      startingStation: startingStation,
      crowdLevel: crowdLevel,
      mediaUrl: mediaUrl,
      status: 'submitted',
      reliabilityScore: 20.0,
      confidenceStatus: 'unverified',
      upvotesCount: 1, // Author's implicit upvote
      downvotesCount: 0,
      createdAt: DateTime.now(),
    );

    _reports.insert(0, newReport);

    return ApiResponse.success(
      message: 'Report submitted successfully (offline mode)!',
      data: newReport,
      statusCode: 201,
    );
  }

  /// Delete report (Strictly checks ownership!)
  Future<ApiResponse<bool>> deleteReport({
    required int reportId,
    required int userId,
    bool isModerator = false,
  }) async {
    // 1. Attempt live HTTP DELETE to /api/v1/reports/:id
    final apiRes = await _api.delete<bool>(
      '/reports/$reportId',
      includeAuth: true,
      fromJsonT: (_) => true,
    );

    if (apiRes.isSuccess) {
      _reports.removeWhere((r) => r.id == reportId);
      return apiRes;
    }

    // If server returned specific 403 or 404, return it
    if (apiRes.statusCode == 403 || apiRes.statusCode == 404) {
      return apiRes;
    }

    // 2. Offline fallback
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index == -1) {
      return ApiResponse.failure(
        message: 'Report not found.',
        code: 'REPORT_NOT_FOUND',
        statusCode: 404,
      );
    }

    final report = _reports[index];
    if (!report.isOwnedBy(userId) && !isModerator) {
      return ApiResponse.failure(
        message: 'Unauthorized. You can only delete reports that you have authored.',
        code: 'FORBIDDEN_DELETE',
        statusCode: 403,
      );
    }

    _reports.removeAt(index);

    return ApiResponse.success(
      message: 'Report deleted successfully (offline mode).',
      data: true,
    );
  }

  /// Cast vote on report (Suneth's Peer Reliability Engine)
  Future<ApiResponse<CommunityReportModel>> voteOnReport({
    required int reportId,
    required int userId,
    required String voteType, // 'upvote', 'downvote', 'confirm_resolved'
  }) async {
    // 1. Attempt live HTTP POST to /api/v1/reports/:id/vote
    final apiRes = await _api.post<CommunityReportModel>(
      '/reports/$reportId/vote',
      body: {'voteType': voteType},
      includeAuth: true,
      fromJsonT: (json) => CommunityReportModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );

    if (apiRes.isSuccess && apiRes.data != null) {
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _reports[index] = apiRes.data!;
      }
      return apiRes;
    }

    // 2. Offline fallback
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index == -1) {
      return ApiResponse.failure(
        message: 'Report not found.',
        code: 'REPORT_NOT_FOUND',
        statusCode: 404,
      );
    }

    final current = _reports[index];
    int upvotes = current.upvotesCount;
    int downvotes = current.downvotesCount;
    String status = current.status;
    String confidence = current.confidenceStatus;
    DateTime? resolvedAt = current.resolvedAt;

    if (voteType == 'upvote') {
      if (current.userVote == 'upvote') {
        upvotes = (upvotes > 0) ? upvotes - 1 : 0;
      } else {
        upvotes += 1;
        if (current.userVote == 'downvote') {
          downvotes = (downvotes > 0) ? downvotes - 1 : 0;
        }
      }
    } else if (voteType == 'downvote') {
      if (current.userVote == 'downvote') {
        downvotes = (downvotes > 0) ? downvotes - 1 : 0;
      } else {
        downvotes += 1;
        if (current.userVote == 'upvote') {
          upvotes = (upvotes > 0) ? upvotes - 1 : 0;
        }
      }
    } else if (voteType == 'confirm_resolved') {
      status = 'resolved';
      resolvedAt = DateTime.now();
    }

    // Reliability algorithm recalculation
    final totalVotes = upvotes + downvotes;
    double score = 50.0;
    if (totalVotes > 0) {
      score = ((upvotes / totalVotes) * 100.0).clamp(0.0, 100.0);
    }

    if (score >= 70.0 && upvotes >= 3) {
      confidence = 'verified';
      if (status != 'resolved') status = 'verified';
    } else if (score < 40.0 && downvotes >= 3) {
      confidence = 'disputed';
      if (status != 'resolved') status = 'disputed';
    } else {
      confidence = 'plausible';
    }

    final updated = current.copyWith(
      upvotesCount: upvotes,
      downvotesCount: downvotes,
      userVote: (current.userVote == voteType) ? null : voteType,
      reliabilityScore: score,
      confidenceStatus: confidence,
      status: status,
      resolvedAt: resolvedAt,
    );

    _reports[index] = updated;

    return ApiResponse.success(
      message: 'Vote recorded and reliability recalculated (offline mode).',
      data: updated,
    );
  }

  /// Get official transit disruptions
  Future<ApiResponse<List<DisruptionModel>>> getDisruptions() async {
    // 1. Attempt live HTTP call to /api/v1/reports/disruptions
    final apiRes = await _api.get<List<DisruptionModel>>(
      '/reports/disruptions',
      includeAuth: false,
      fromJsonT: (json) {
        if (json is List) {
          return json
              .map((item) => DisruptionModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        return <DisruptionModel>[];
      },
    );

    if (apiRes.isSuccess && apiRes.data != null && apiRes.data!.isNotEmpty) {
      return apiRes;
    }

    // 2. Offline fallback
    return ApiResponse.success(
      message: 'Disruptions loaded (offline mode)',
      data: List<DisruptionModel>.from(_disruptions),
    );
  }
}
