import 'package:flutter/material.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../nisal/providers/auth_provider.dart';
import '../../nisal/providers/route_provider.dart';
import '../models/community_report_model.dart';
import '../models/report_category_model.dart';
import '../providers/report_provider.dart';
import 'create_report_view.dart';
import 'report_details_view.dart';

/// TravelPulse LK — Recent Community Reports Feed (Dumindi)
/// Displays public community feed with category filters, anonymous reporter
/// masking, upvoting interactions, and incident details.
class RecentReportsView extends StatefulWidget {
  final AuthProvider authProvider;
  final ReportProvider reportProvider;
  final RouteProvider? routeProvider;

  const RecentReportsView({
    super.key,
    required this.authProvider,
    required this.reportProvider,
    this.routeProvider,
  });

  @override
  State<RecentReportsView> createState() => _RecentReportsViewState();
}

class _RecentReportsViewState extends State<RecentReportsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  final List<String> _categoryFilterLabels = [
    'All',
    'Service Disruption',
    'Road Condition',
    'Crowd Report',
    'Accident/Incident',
    'Transport/Route Tracking',
    'Other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCreateReport() {
    if (widget.authProvider.isGuest) {
      _showGuestPrompt();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateReportView(
          authProvider: widget.authProvider,
          reportProvider: widget.reportProvider,
          routeProvider: widget.routeProvider,
        ),
      ),
    );
  }

  void _showGuestPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
        title: Row(
          children: [
            const Icon(Icons.account_circle_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Sign In Required'),
          ],
        ),
        content: Text(
          'To maintain trust and accountability in the commuter community, please sign in or register before submitting reports.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed(RouteConstants.signIn);
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Community Reports Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Feed',
            onPressed: () => widget.reportProvider.loadReports(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search reports (e.g. Route 138, Town Hall)...',
                  hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.roundedMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.roundedMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
              ),
            ),

            // 2. Category Filter Pills (Horizontal Scroll)
            Container(
              height: 42,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categoryFilterLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final label = _categoryFilterLabels[index];
                  final isSelected = widget.reportProvider.selectedCategory == label;

                  return InkWell(
                    onTap: () => widget.reportProvider.setCategoryFilter(label),
                    borderRadius: AppSpacing.roundedPill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: AppSpacing.roundedPill,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected ? AppColors.textInverse : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: AppColors.border, height: 16),

            // 3. Feed List
            Expanded(
              child: ListenableBuilder(
                listenable: widget.reportProvider,
                builder: (context, _) {
                  if (widget.reportProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var list = widget.reportProvider.reports;

                  // Apply search query filter
                  if (_searchFilter.isNotEmpty) {
                    list = list.where((r) {
                      return r.title.toLowerCase().contains(_searchFilter) ||
                          r.description.toLowerCase().contains(_searchFilter) ||
                          r.locationDescription.toLowerCase().contains(_searchFilter) ||
                          (r.routeNumber != null && r.routeNumber!.toLowerCase().contains(_searchFilter)) ||
                          (r.disruptionReason != null && r.disruptionReason!.toLowerCase().contains(_searchFilter));
                    }).toList();
                  }

                  if (list.isEmpty) {
                    return EmptyStateView(
                      title: 'No Reports Found',
                      message: 'There are currently no active community reports matching your filter.',
                      icon: Icons.campaign_outlined,
                      actionText: 'Create First Report',
                      onAction: _onCreateReport,
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    onRefresh: () => widget.reportProvider.loadReports(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final report = list[index];
                        return _buildReportFeedCard(report);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreateReport,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report Issue'),
      ),
    );
  }

  Widget _buildReportFeedCard(CommunityReportModel report) {
    return AppCard(
      onTap: () {
        widget.reportProvider.selectReport(report.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportDetailsView(
              reportId: report.id,
              authProvider: widget.authProvider,
              reportProvider: widget.reportProvider,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Category Tag + Route Tag + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Text(
                  report.categoryName,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (report.routeNumber != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppSpacing.roundedSm,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Route ${report.routeNumber}',
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const Spacer(),
              StatusBadge.reportStatus(report.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Row 2: Title
          Text(report.title, style: AppTypography.titleSmall),
          const SizedBox(height: 4),

          // Row 3: Disruption Reason Badge (Crucial requirement for Service Disruptions!)
          if (report.disruptionReason != null && report.disruptionReason!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.warningDark),
                  const SizedBox(width: 5),
                  Text(
                    'Reason: ${report.disruptionReason}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warningDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Row 4: Description
          Text(
            report.description,
            style: AppTypography.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Row 5: Location description
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  report.locationDescription,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.border, height: 12),

          // Row 6: Reporter Display ("Anonymous Commuter" masking) + Peer Voting
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    report.isAnonymous ? Icons.visibility_off_rounded : Icons.person_outline_rounded,
                    size: 14,
                    color: report.isAnonymous ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    report.displayReporter,
                    style: AppTypography.caption.copyWith(
                      color: report.isAnonymous ? AppColors.primaryDark : AppColors.textSecondary,
                      fontWeight: report.isAnonymous ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                  Text(_formatTimeAgo(report.createdAt), style: AppTypography.caption),
                ],
              ),

              // Upvote counter & interactive pill
              InkWell(
                onTap: () {
                  final userId = widget.authProvider.currentUser?.id ?? 1;
                  widget.reportProvider.voteOnReport(
                    reportId: report.id,
                    userId: userId,
                    voteType: 'upvote',
                  );
                },
                borderRadius: AppSpacing.roundedPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.userVote == 'upvote' ? AppColors.primaryLight : AppColors.surfaceVariant,
                    borderRadius: AppSpacing.roundedPill,
                    border: Border.all(
                      color: report.userVote == 'upvote' ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thumb_up_alt_rounded,
                        size: 13,
                        color: report.userVote == 'upvote' ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${report.upvotesCount}',
                        style: AppTypography.caption.copyWith(
                          color: report.userVote == 'upvote' ? AppColors.primaryDark : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 60)}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

