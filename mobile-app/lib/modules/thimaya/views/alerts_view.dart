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

  const AlertsView({super.key, required this.alertProvider});

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
                              onSelected: (_) =>
                                  setState(() => _selectedTabIndex = index),
                              selectedColor: AppColors.primaryLight,
                              backgroundColor: AppColors.surface,
                              labelStyle: AppTypography.labelMedium.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Alerts List
                    if (alerts.isEmpty)
                      EmptyStateView(
                        title: 'No Active Travel Alerts',
                        message: 'Transit corridors are operating normally with no severe weather or hazard advisories.',
                        icon: Icons.check_circle_outline_rounded,
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return _buildAlertCard(alert);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdvisoryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.6),
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.broadcast_on_personal_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Transit Broadcasts',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Official Colombo metropolitan transit authority alerts and weather warnings.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(TravelAlertModel alert) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(alert.alertIcon, size: 16, color: alert.severityColor),
                  const SizedBox(width: 6),
                  Text(
                    alert.displayAlertTypeName,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: alert.severityColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: alert.severityColor.withOpacity(0.12),
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  alert.severity.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: alert.severityColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Title
          Text(
            alert.title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),

          // Message
          Text(alert.message, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.md),

          // Corridors & Timestamps footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (alert.targetRouteNumber != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.alt_route_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Route ${alert.targetRouteNumber}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(),
              ],
              Text(
                'Issued ${_formatDate(alert.createdAt)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
