import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../nisal/providers/auth_provider.dart';
import '../models/community_report_model.dart';
import '../providers/report_provider.dart';

/// TravelPulse LK — Community Report Details Screen (Dumindi)
/// Displays complete incident details, anonymous reporter masking,
/// Suneth's peer voting integration, and ownership-verified deletion.
class ReportDetailsView extends StatelessWidget {
  final int reportId;
  final AuthProvider authProvider;
  final ReportProvider reportProvider;

  const ReportDetailsView({
    super.key,
    required this.reportId,
    required this.authProvider,
    required this.reportProvider,
  });

  void _confirmDeleteReport(BuildContext context, CommunityReportModel report) {
    final currentUserId = authProvider.currentUser?.id ?? 0;
    final isModerator = authProvider.currentUser?.isModerator ?? false;

    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Delete Community Report?',
        message: 'Are you sure you want to delete report #${report.id} ("${report.title}")? This action will permanently remove it from the TravelPulse LK community feed.',
        confirmText: 'Delete Report',
        isDestructive: true,
        onConfirm: () async {
          final success = await reportProvider.deleteReport(
            reportId: report.id,
            userId: currentUserId,
            isModerator: isModerator,
          );

          if (context.mounted) {
            if (success) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report deleted successfully.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(reportProvider.errorMessage ?? 'Failed to delete report.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Incident Details'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: reportProvider,
          builder: (context, _) {
            // Find report from active list or selected report
            CommunityReportModel? report = reportProvider.reports.firstWhere(
              (r) => r.id == reportId,
              orElse: () => reportProvider.myReports.firstWhere(
                (r) => r.id == reportId,
                orElse: () => reportProvider.selectedReport ?? CommunityReportModel(
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
              ),
            );

            if (report.id == 0) {
              return Center(
                child: EmptyStateView(
                  title: 'Report Not Found',
                  message: 'The requested community report could not be found or has been removed.',
                  icon: Icons.search_off_rounded,
                  actionText: 'Go Back',
                  onAction: () => Navigator.of(context).pop(),
                ),
              );
            }

            final currentUserId = authProvider.currentUser?.id;
            final isAuthor = report.isOwnedBy(currentUserId);
            final isModerator = authProvider.currentUser?.isModerator ?? false;
            final canDelete = isAuthor || isModerator;

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Reporter Info Header Card
                  _buildReporterHeaderCard(report, isAuthor),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Incident Core Content Card
                  _buildReportContentCard(report),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Location & Coordinates Card
                  _buildLocationCard(report),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Peer Verification & Voting Section (Suneth's Engine)
                  _buildVotingSection(context, report),
                  const SizedBox(height: AppSpacing.lg),

                  // 5. Ownership-Verified Deletion Action
                  if (canDelete) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight.withOpacity(0.5),
                        borderRadius: AppSpacing.roundedLg,
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: AppColors.errorDark, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isAuthor ? 'Author Report Management' : 'Moderator Administration',
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.errorDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAuthor
                                ? 'As the author of this report, you have full ownership and can delete it at any time.'
                                : 'As an authorized transport moderator, you can delete or moderate this report.',
                            style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmDeleteReport(context, report),
                              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                              label: const Text('Delete This Report'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReporterHeaderCard(CommunityReportModel report, bool isAuthor) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: report.isAnonymous ? AppColors.primaryLight : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  report.isAnonymous ? Icons.visibility_off_rounded : Icons.person_rounded,
                  color: report.isAnonymous ? AppColors.primary : AppColors.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            report.displayReporter,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: report.isAnonymous ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (report.isAnonymous) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: Text(
                              'Anonymous',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (isAuthor) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: Text(
                              'Your Report',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.successDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reported ${_formatDate(report.createdAt)}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              StatusBadge.reportStatus(report.status),
            ],
          ),
          const SizedBox(height: 10),
          // Reliability / Confidence Pill (Suneth engine)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppSpacing.roundedSm,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Peer Reliability: ${report.reliabilityScore.toStringAsFixed(0)}% Confidence (${report.confidenceStatus.toUpperCase()})',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContentCard(CommunityReportModel report) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Text(
              report.categoryName,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Title
          Text(report.title, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.sm),

          // Service Disruption Reason (Mandatory requirement for Category 4!)
          if (report.disruptionReason != null && report.disruptionReason!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.warningDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disruption Reason (No Arbitrary Severity)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warningDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report.disruptionReason!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Full Description
          Text('Full Description', style: AppTypography.titleSmall),
          const SizedBox(height: 4),
          Text(report.description, style: AppTypography.bodyLarge),

          // Associated Route (if present)
          if (report.routeNumber != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppSpacing.roundedSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Transit Corridor: Route ${report.routeNumber}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  if (report.stopName != null) ...[
                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                    Expanded(
                      child: Text(
                        'Near ${report.stopName}',
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(CommunityReportModel report) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 6),
              Text('Location & Geolocation', style: AppTypography.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(report.locationDescription, style: AppTypography.bodyMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Coordinates: ${report.latitude.toStringAsFixed(4)}° N, ${report.longitude.toStringAsFixed(4)}° E',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVotingSection(BuildContext context, CommunityReportModel report) {
    final currentUserId = authProvider.currentUser?.id ?? 1;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Peer Verification (Crowd Intelligence)', style: AppTypography.titleSmall),
              Text('Suneth’s Engine', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm or dispute this report to help the automated reliability algorithm verify genuine transit conditions.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Upvote Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    reportProvider.voteOnReport(
                      reportId: report.id,
                      userId: currentUserId,
                      voteType: 'upvote',
                    );
                  },
                  icon: Icon(
                    Icons.thumb_up_alt_rounded,
                    color: report.userVote == 'upvote' ? AppColors.success : AppColors.textSecondary,
                    size: 16,
                  ),
                  label: Text('Confirm (${report.upvotesCount})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: report.userVote == 'upvote' ? AppColors.successDark : AppColors.textPrimary,
                    side: BorderSide(
                      color: report.userVote == 'upvote' ? AppColors.success : AppColors.border,
                      width: report.userVote == 'upvote' ? 1.5 : 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Downvote Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    reportProvider.voteOnReport(
                      reportId: report.id,
                      userId: currentUserId,
                      voteType: 'downvote',
                    );
                  },
                  icon: Icon(
                    Icons.thumb_down_alt_rounded,
                    color: report.userVote == 'downvote' ? AppColors.error : AppColors.textSecondary,
                    size: 16,
                  ),
                  label: Text('Dispute (${report.downvotesCount})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: report.userVote == 'downvote' ? AppColors.errorDark : AppColors.textPrimary,
                    side: BorderSide(
                      color: report.userVote == 'downvote' ? AppColors.error : AppColors.border,
                      width: report.userVote == 'downvote' ? 1.5 : 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

  