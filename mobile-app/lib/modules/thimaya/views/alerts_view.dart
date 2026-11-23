import 'package:flutter/material.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../models/travel_alert_model.dart';
import '../providers/alert_provider.dart';

/// TravelPulse LK — Travel Alerts Screen (Thimaya)
/// Visualizes active emergency broadcasts, severe weather warnings, and route advisories.
class AlertsView extends StatefulWidget {
  final AlertProvider alertProvider;

  const AlertsView({
    super.key,
    required this.alertProvider,
  });

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  final List<String> _severityTabs = ['All', 'Critical', 'Warning', 'Info'];
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.alertProvider.loadAlerts();
  }

  List<TravelAlertModel> _getFilteredAlerts() {
    final list = widget.alertProvider.alerts;
    if (_selectedTabIndex == 0) return list;
    final target = _severityTabs[_selectedTabIndex].toLowerCase();
    return list.where((a) => a.severity.toLowerCase() == target).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Travel Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Settings',
            onPressed: () {
              Navigator.of(context).pushNamed(RouteConstants.alertSettings);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Alerts',
            onPressed: () => widget.alertProvider.loadAlerts(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.alertProvider,
          builder: (context, _) {
            if (widget.alertProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = _getFilteredAlerts();

            return RefreshIndicator(
              onRefresh: () => widget.alertProvider.loadAlerts(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Broadcast Advisory Banner
                    _buildAdvisoryHeader(),
                    const SizedBox(height: AppSpacing.md),

                    // Severity Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_severityTabs.length, (index) {
                          final isSelected = _selectedTabIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_severityTabs[index]),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedTabIndex = index),
                              selectedColor: AppColors.primaryLight,
                              backgroundColor: AppColors.surface,
                              labelStyle: AppTypography.labelMedium.copyWith(
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
