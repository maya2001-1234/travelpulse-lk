import 'package:flutter/material.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../nisal/providers/auth_provider.dart';
import '../../nisal/providers/route_provider.dart';
import '../models/community_report_model.dart';
import '../providers/report_provider.dart';
import 'create_report_view.dart';
import 'report_details_view.dart';

/// TravelPulse LK — My Authored Reports Screen (Dumindi)
/// Displays reports authored by the authenticated commuter, including
/// anonymous submissions, with full ownership and deletion controls.
class MyReportsView extends StatefulWidget {
  final AuthProvider authProvider;
  final ReportProvider reportProvider;
  final RouteProvider? routeProvider;

  const MyReportsView({
    super.key,
    required this.authProvider,
    required this.reportProvider,
    this.routeProvider,
  });

  @override
  State<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends State<MyReportsView> {
  @override
  void initState() {
    super.initState();
    final userId = widget.authProvider.currentUser?.id;
    if (userId != null) {
      widget.reportProvider.loadMyReports(userId);
    }
  }

  void _confirmDeleteReport(CommunityReportModel report) {
    final currentUserId = widget.authProvider.currentUser?.id ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Delete Your Report?',
        message: 'Are you sure you want to delete report #${report.id} ("${report.title}")? This will permanently remove your report.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () async {
          final success = await widget.reportProvider.deleteReport(
            reportId: report.id,
            userId: currentUserId,
          );

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report deleted successfully.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.reportProvider.errorMessage ?? 'Could not delete report.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guest guard
    if (widget.authProvider.isGuest || widget.authProvider.currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('My Reports')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle_outlined, size: 64, color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text('Sign In to View Your Reports', style: AppTypography.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sign in with your TravelPulse LK account to view and manage all reports you have submitted.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: 'Sign In',
                  onPressed: () => Navigator.of(context).pushNamed(RouteConstants.signIn),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              final userId = widget.authProvider.currentUser!.id;
              widget.reportProvider.loadMyReports(userId);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.reportProvider,
          builder: (context, _) {
            if (widget.reportProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final myReports = widget.reportProvider.myReports;

            if (myReports.isEmpty) {
              return EmptyStateView(
                title: 'No Reports Yet',
                message: 'You have not submitted any transit disruption or incident reports yet.',
                icon: Icons.assignment_outlined,
                actionText: 'Create Your First Report',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateReportView(
                        authProvider: widget.authProvider,
                        reportProvider: widget.reportProvider,
                        routeProvider: widget.routeProvider,
                      ),
                    ),
                  );
                },
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                final userId = widget.authProvider.currentUser!.id;
                await widget.reportProvider.loadMyReports(userId);
              },
              child: ListView.separated(
                padding: AppSpacing.screenPadding,
                itemCount: myReports.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSummaryHeader(myReports.length);
                  }

                  final report = myReports[index - 1];
                  return _buildMyReportCard(report);
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateReportView(
                authProvider: widget.authProvider,
                reportProvider: widget.reportProvider,
                routeProvider: widget.routeProvider,
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildSummaryHeader(int totalCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Authored Contributions', style: AppTypography.titleSmall),
              const SizedBox(height: 2),
              Text(
                'You have submitted $totalCount community ${totalCount == 1 ? "report" : "reports"}.',
                style: AppTypography.caption,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppSpacing.roundedPill,
            ),
            child: Text(
              '$totalCount Total',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyReportCard(CommunityReportModel report) {
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
          // Top Row: Category + Anonymous Indicator + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const SizedBox(width: 6),
              if (report.isAnonymous) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppSpacing.roundedSm,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_off_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Anonymous', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              StatusBadge.reportStatus(report.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Title
          Text(report.title, style: AppTypography.titleSmall),
          const SizedBox(height: 4),

          // Disruption Reason (if applicable)
          if (report.disruptionReason != null && report.disruptionReason!.isNotEmpty) ...[
            Text(
              'Reason: ${report.disruptionReason}',
              style: AppTypography.caption.copyWith(
                color: AppColors.warningDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Description Excerpt
          Text(
            report.description,
            style: AppTypography.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Bottom Bar: Date + Upvotes + Delete Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(_formatDate(report.createdAt), style: AppTypography.caption),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.thumb_up_alt_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${report.upvotesCount}', style: AppTypography.caption),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                tooltip: 'Delete report',
                onPressed: () => _confirmDeleteReport(report),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

