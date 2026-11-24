import 'package:flutter/material.dart';
import '../models/community_report_model.dart';
import '../models/disruption_model.dart';
import '../models/report_category_model.dart';
import '../services/report_service.dart';

/// TravelPulse LK — Community Reporting State Provider (Dumindi)
/// Coordinates incident reporting, disruption feeds, anonymous submissions,
/// user authored reports, and peer verification state.
class ReportProvider extends ChangeNotifier {
  final ReportService _reportService = ReportService();

  List<ReportCategoryModel> _categories = ReportCategoryModel.allCategories;
  List<CommunityReportModel> _reports = [];
  List<CommunityReportModel> _myReports = [];
  List<DisruptionModel> _disruptions = [];
  CommunityReportModel? _selectedReport;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  List<ReportCategoryModel> get categories => _categories;
  List<CommunityReportModel> get reports => _reports;
  List<CommunityReportModel> get myReports => _myReports;
  List<DisruptionModel> get disruptions => _disruptions;
  CommunityReportModel? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get selectedStatus => _selectedStatus;

  ReportProvider() {
    loadCategories();
    loadReports();
    loadDisruptions();
  }

  Future<void> loadCategories() async {
    try {
      final response = await _reportService.getCategories();
      if (response.success && response.data != null) {
        _categories = response.data!;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadReports() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _reportService.getReports(
        categoryFilter: _selectedCategory,
        statusFilter: _selectedStatus,
      );

      _isLoading = false;

      if (response.success && response.data != null) {
        _reports = response.data!;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not load community reports.';
    }

    notifyListeners();
  }

  Future<void> loadMyReports(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _reportService.getMyReports(userId);
      _isLoading = false;

      if (response.success && response.data != null) {
        _myReports = response.data!;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not load your authored reports.';
    }

    notifyListeners();
  }

  Future<void> loadDisruptions() async {
    try {
      final response = await _reportService.getDisruptions();
      if (response.success && response.data != null) {
        _disruptions = response.data!;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> selectReport(int reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _reportService.getReportById(reportId);
      _isLoading = false;

      if (response.success && response.data != null) {
        _selectedReport = response.data;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not load report details.';
    }

    notifyListeners();
  }

  Future<CommunityReportModel?> submitReport({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _reportService.submitReport(
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
      );

      _isLoading = false;

      if (response.success && response.data != null) {
        await loadReports();
        await loadMyReports(userId);
        return response.data;
      } else {
        _errorMessage = response.message;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to submit report. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteReport({
    required int reportId,
    required int userId,
    bool isModerator = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _reportService.deleteReport(
        reportId: reportId,
        userId: userId,
        isModerator: isModerator,
      );

      _isLoading = false;

      if (response.success) {
        _reports.removeWhere((r) => r.id == reportId);
        _myReports.removeWhere((r) => r.id == reportId);
        if (_selectedReport?.id == reportId) {
          _selectedReport = null;
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete report.';
      notifyListeners();
      return false;
    }
  }

  Future<void> voteOnReport({
    required int reportId,
    required int userId,
    required String voteType,
  }) async {
    try {
      final response = await _reportService.voteOnReport(
        reportId: reportId,
        userId: userId,
        voteType: voteType,
      );

      if (response.success && response.data != null) {
        final updated = response.data!;
        final index = _reports.indexWhere((r) => r.id == reportId);
        if (index != -1) {
          _reports[index] = updated;
        }
        final myIndex = _myReports.indexWhere((r) => r.id == reportId);
        if (myIndex != -1) {
          _myReports[myIndex] = updated;
        }
        if (_selectedReport?.id == reportId) {
          _selectedReport = updated;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void setCategoryFilter(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    loadReports();
  }

  void setStatusFilter(String status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    loadReports();
  }
}
