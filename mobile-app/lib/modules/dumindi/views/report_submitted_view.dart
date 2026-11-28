import 'package:flutter/material.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../nisal/providers/auth_provider.dart';
import '../models/community_report_model.dart';
import '../providers/report_provider.dart';
import 'my_reports_view.dart';
import 'recent_reports_view.dart';

/// TravelPulse LK — Report Submission Success Screen (Dumindi)
/// Displays confirmation of submitted report, anonymous status confirmation,
/// and navigation to My Reports or the Community Feed.
class ReportSubmittedView extends StatelessWidget {
  final CommunityReportModel report;
  final AuthProvider authProvider;
  final ReportProvider reportProvider;

  const ReportSubmittedView({
    super.key,
    required this.report,
    required this.authProvider,
    required this.reportProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Icon Circle
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 50,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title & Message
              Text(
                'Report Submitted!',
                style: AppTypography.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Thank you for contributing real-time transit intelligence to the TravelPulse LK commuter community.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Report Summary Card
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Report Reference', style: AppTypography.caption),
                        Text(
                          '#${report.id}',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 20),
                    _buildDetailRow('Category', report.categoryName),
                    _buildDetailRow('Title', report.title),
                    if (report.disruptionReason != null)
                      _buildDetailRow('Disruption Reason', report.disruptionReason!),
                    _buildDetailRow(
                      'Public Display',
                      report.isAnonymous ? 'Anonymous Commuter 🔒' : report.userName,
                    ),
                    _buildDetailRow('Status', 'Submitted (Pending Verification)'),
                    _buildDetailRow('Location', report.locationDescription),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons
              AppButton(
                text: 'View in Community Feed',
                leadingIcon: Icons.dynamic_feed_rounded,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => RecentReportsView(
                        authProvider: authProvider,
                        reportProvider: reportProvider,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => MyReportsView(
                        authProvider: authProvider,
                        reportProvider: reportProvider,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_pin_rounded, size: 18),
                label: const Text('View My Reports'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

