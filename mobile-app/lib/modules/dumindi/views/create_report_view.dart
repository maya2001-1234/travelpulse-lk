import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../nisal/providers/auth_provider.dart';
import '../../nisal/providers/route_provider.dart';
import '../models/report_category_model.dart';
import '../providers/report_provider.dart';
import 'report_submitted_view.dart';

/// TravelPulse LK — Create Community Report Screen (Dumindi)
/// Allows commuters to report incidents across 6 categories, capture GPS/manual
/// locations, submit anonymously with ownership retention, and review before submit.
class CreateReportView extends StatefulWidget {
  final AuthProvider authProvider;
  final ReportProvider reportProvider;
  final RouteProvider? routeProvider;

  const CreateReportView({
    super.key,
    required this.authProvider,
    required this.reportProvider,
    this.routeProvider,
  });

  @override
  State<CreateReportView> createState() => _CreateReportViewState();
}

class _CreateReportViewState extends State<CreateReportView> {
  final _formKey = GlobalKey<FormState>();

  // Selected Category (default: Service Disruption, id: 4)
  late ReportCategoryModel _selectedCategory;

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // Transport-specific controllers (Category 1: Crowd Report)
  String _selectedTransportType = 'bus'; // 'bus' or 'train'
  final TextEditingController _busRouteNumberController = TextEditingController();
  final TextEditingController _busDestinationController = TextEditingController();
  final TextEditingController _busRegNumberController = TextEditingController();
  final TextEditingController _trainNameOrNumberController = TextEditingController();
  final TextEditingController _trainStartingStationController = TextEditingController();
  final TextEditingController _trainDestinationController = TextEditingController();

  // Route & Stop Association (optional)
  int? _selectedRouteId;
  String? _selectedRouteNumber;

  // Category-specific parameters
  String _selectedCrowdLevel = 'heavy'; // 'light', 'moderate', 'heavy', 'packed'
  String _selectedRoadHazard = 'Pothole';

  // Common disruption reasons for Sri Lankan transit
  final List<String> _disruptionReasons = [
    'Vehicle Breakdown',
    'Track Signal Failure',
    'Power Outage',
    'Severe Traffic Gridlock',
    'Driver Shortage',
    'Trip Cancelled by Operator',
    'Weather Obstruction',
    'Other Disruption Reason',
  ];

  final List<String> _roadHazards = [
    'Pothole',
    'Road Inundation / Flooding',
    'Road Closed for Construction',
    'Landslide Obstruction',
    'Fallen Tree / Road Debris',
    'Traffic Light Malfunction',
  ];

  // Coordinates (Colombo Fort defaults)
  double _latitude = 6.9344;
  double _longitude = 79.8540;

  // Anonymous reporting toggle
  bool _isAnonymous = false;

  // Media attachment placeholder
  bool _hasAttachedMedia = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = ReportCategoryModel.getById(4); // Service Disruption by default
    _locationController.text = 'Colombo Fort / Pettah Junction';
    _reasonController.text = _disruptionReasons.first;

    if (widget.routeProvider != null && widget.routeProvider!.routes.isNotEmpty) {
      _selectedRouteId = widget.routeProvider!.routes.first.id;
      _selectedRouteNumber = widget.routeProvider!.routes.first.routeNumber;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _reasonController.dispose();
    _busRouteNumberController.dispose();
    _busDestinationController.dispose();
    _busRegNumberController.dispose();
    _trainNameOrNumberController.dispose();
    _trainStartingStationController.dispose();
    _trainDestinationController.dispose();
    super.dispose();
  }

  void _useGpsLocation() {
    setState(() {
      _latitude = 6.9344;
      _longitude = 79.8540;
      _locationController.text = 'Colombo Fort (GPS detected)';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GPS coordinates captured: 6.9344° N, 79.8540° E'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onCategorySelected(ReportCategoryModel category) {
    setState(() {
      _selectedCategory = category;
      if (category.id == 4 && _reasonController.text.isEmpty) {
        _reasonController.text = _disruptionReasons.first;
      }
    });
  }

  void _showReviewDialog() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Category 1 (Crowd Report) validation check
    if (_selectedCategory.id == 1) {
      if (_selectedTransportType == 'bus') {
        if (_busRouteNumberController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a bus route number.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (_busDestinationController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a destination for the bus.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      } else if (_selectedTransportType == 'train') {
        if (_trainNameOrNumberController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter the train name or number.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (_trainStartingStationController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter the starting station.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (_trainDestinationController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a destination for the train.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }

      if (_selectedCrowdLevel.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a crowd density level.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Category 4 (Service Disruption) validation check: reason must be specified
    if (_selectedCategory.id == 4 && _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or specify a reason for the service disruption.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppSpacing.roundedSm,
                        ),
                        child: const Icon(Icons.rate_review_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Review Your Report', style: AppTypography.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Please review your report details before submitting to the TravelPulse LK community.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.sm),

                  // Category
                  _buildReviewRow('Category', _selectedCategory.name),

                  // Crowd Report Transport Details (if Category 1)
                  if (_selectedCategory.id == 1) ...[
                    _buildReviewRow('Transport Mode', _selectedTransportType == 'bus' ? 'Bus' : 'Train'),
                    if (_selectedTransportType == 'bus') ...[
                      _buildReviewRow('Bus Route', _busRouteNumberController.text.trim()),
                      _buildReviewRow('Destination', _busDestinationController.text.trim()),
                      if (_busRegNumberController.text.trim().isNotEmpty)
                        _buildReviewRow('Bus Reg No', _busRegNumberController.text.trim()),
                    ] else ...[
                      _buildReviewRow('Train Name/No', _trainNameOrNumberController.text.trim()),
                      _buildReviewRow('Starting Station', _trainStartingStationController.text.trim()),
                      _buildReviewRow('Destination', _trainDestinationController.text.trim()),
                    ],
                    _buildReviewRow('Crowd Level', _selectedCrowdLevel.toUpperCase()),
                  ],

                  // Anonymous status
                  _buildReviewRow(
                    'Identity Visibility',
                    _isAnonymous ? 'Anonymous Commuter (Identity Protected)' : (widget.authProvider.currentUser?.name ?? 'Identified Commuter'),
                  ),

                  // Title
                  _buildReviewRow('Title', _titleController.text.trim()),

                  // Disruption Reason (if category 4)
                  if (_selectedCategory.id == 4)
                    _buildReviewRow('Disruption Reason', _reasonController.text.trim()),

                  // Road Hazard (if category 2)
                  if (_selectedCategory.id == 2)
                    _buildReviewRow('Hazard Type', _selectedRoadHazard),

                  // Location
                  _buildReviewRow('Location', '${_locationController.text.trim()} (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})'),

                  // Route (if attached and not already specified by crowd report transport fields)
                  if (_selectedRouteNumber != null && _selectedCategory.id != 1)
                    _buildReviewRow('Associated Line', 'Route $_selectedRouteNumber'),

                  // Description
                  const SizedBox(height: 8),
                  Text('Description:', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Text(_descriptionController.text.trim(), style: AppTypography.bodySmall),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Confirm & Submit Button
                  AppButton(
                    text: 'Confirm & Submit Report',
                    leadingIcon: Icons.send_rounded,
                    isLoading: widget.reportProvider.isLoading,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _submitReport();
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Back to Edit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    final user = widget.authProvider.currentUser;
    final userId = user?.id ?? 1;
    final userName = user?.name ?? 'Commuter';

    String? reason;
    String? transportType;
    String? busRouteNumber;
    String? destination;
    String? busRegistrationNumber;
    String? trainNameOrNumber;
    String? startingStation;
    String? crowdLevel;

    if (_selectedCategory.id == 4) {
      reason = _reasonController.text.trim();
    } else if (_selectedCategory.id == 2) {
      reason = _selectedRoadHazard;
    } else if (_selectedCategory.id == 1) {
      reason = 'Crowd Level: ${_selectedCrowdLevel.toUpperCase()}';
      transportType = _selectedTransportType;
      crowdLevel = _selectedCrowdLevel;

      if (_selectedTransportType == 'bus') {
        busRouteNumber = _busRouteNumberController.text.trim();
        destination = _busDestinationController.text.trim();
        final reg = _busRegNumberController.text.trim();
        busRegistrationNumber = reg.isNotEmpty ? reg : null;
      } else if (_selectedTransportType == 'train') {
        trainNameOrNumber = _trainNameOrNumberController.text.trim();
        startingStation = _trainStartingStationController.text.trim();
        destination = _trainDestinationController.text.trim();
      }
    }

    final createdReport = await widget.reportProvider.submitReport(
      userId: userId,
      userName: userName,
      isAnonymous: _isAnonymous,
      categoryId: _selectedCategory.id,
      categoryName: _selectedCategory.name,
      routeId: _selectedRouteId,
      routeNumber: _selectedCategory.id == 1
          ? (_selectedTransportType == 'bus' ? busRouteNumber : trainNameOrNumber)
          : _selectedRouteNumber,
      latitude: _latitude,
      longitude: _longitude,
      locationDescription: _locationController.text.trim(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      disruptionReason: reason,
      transportType: transportType,
      busRouteNumber: busRouteNumber,
      destination: destination,
      busRegistrationNumber: busRegistrationNumber,
      trainNameOrNumber: trainNameOrNumber,
      startingStation: startingStation,
      crowdLevel: crowdLevel,
      mediaUrl: _hasAttachedMedia ? 'https://storage.travelpulse.lk/reports/sample_hazard.jpg' : null,
    );

    if (mounted) {
      if (createdReport != null) {
        // Navigate to Submission Success Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReportSubmittedView(
              report: createdReport,
              authProvider: widget.authProvider,
              reportProvider: widget.reportProvider,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.reportProvider.errorMessage ?? 'Submission failed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Community Report'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Category Selection
                Text('Select Report Category', style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Text('Choose from the 6 supported incident categories', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                _buildCategoryGrid(),
                const SizedBox(height: AppSpacing.md),

                // 2. Category-Specific Fields
                _buildCategorySpecificFields(),
                const SizedBox(height: AppSpacing.md),

                // 3. Location (GPS & Manual Description)
                _buildLocationCard(),
                const SizedBox(height: AppSpacing.md),

                // 4. Report Content (Title & Description)
                _buildReportContentCard(),
                const SizedBox(height: AppSpacing.md),

                // 5. Image Attachment Placeholder
                _buildMediaAttachmentCard(),
                const SizedBox(height: AppSpacing.md),

                // 6. Anonymous Reporting Toggle
                _buildAnonymousToggleCard(),
                const SizedBox(height: AppSpacing.lg),

                // 7. Submit Action
                AppButton(
                  text: 'Review & Submit Report',
                  leadingIcon: Icons.rate_review_rounded,
                  onPressed: _showReviewDialog,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ReportCategoryModel.allCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final cat = ReportCategoryModel.allCategories[index];
        final isSelected = _selectedCategory.id == cat.id;

        return InkWell(
          onTap: () => _onCategorySelected(cat),
          borderRadius: AppSpacing.roundedMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : AppColors.surface,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    cat.icon,
                    size: 16,
                    color: isSelected ? AppColors.textInverse : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.name,
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySpecificFields() {
    // 1. Service Disruption (Category 4) -> Requires Disruption Reason (No arbitrary severity!)
    if (_selectedCategory.id == 4) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bus_alert_rounded, size: 18, color: AppColors.warningDark),
                const SizedBox(width: 6),
                Text('Service Disruption Reason (Required)', style: AppTypography.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Specify the exact nature of the operational transit disruption.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _disruptionReasons.contains(_reasonController.text) ? _reasonController.text : _disruptionReasons.first,
                  isExpanded: true,
                  items: _disruptionReasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(reason, style: AppTypography.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _reasonController.text = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Crowd Report (Category 1) -> Transport Type & Details + Density Picker
    if (_selectedCategory.id == 1) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Crowd Report Details', style: AppTypography.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select transport mode and provide trip details to help fellow commuters.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Transport Type Selector
            Text('Transport Type', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTransportTypeOption(
                  type: 'bus',
                  label: 'Bus',
                  icon: Icons.directions_bus_rounded,
                ),
                const SizedBox(width: 8),
                _buildTransportTypeOption(
                  type: 'train',
                  label: 'Train',
                  icon: Icons.train_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Mode-specific fields
            if (_selectedTransportType == 'bus') ...[
              AppTextField(
                label: 'Bus Route Number *',
                controller: _busRouteNumberController,
                hintText: 'e.g. 138, 120, 177',
                prefixIcon: Icons.alt_route_rounded,
                validator: (val) {
                  if (_selectedCategory.id == 1 && _selectedTransportType == 'bus') {
                    if (val == null || val.trim().isEmpty) {
                      return 'Bus route number is required.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Destination *',
                controller: _busDestinationController,
                hintText: 'e.g. Maharagama, Pettah, Kandy',
                prefixIcon: Icons.flag_outlined,
                validator: (val) {
                  if (_selectedCategory.id == 1 && _selectedTransportType == 'bus') {
                    if (val == null || val.trim().isEmpty) {
                      return 'Destination is required.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Bus Registration Number (Optional)',
                controller: _busRegNumberController,
                hintText: 'e.g. NA-4512 or WP ND-9876',
                prefixIcon: Icons.badge_outlined,
              ),
            ] else ...[
              AppTextField(
                label: 'Train Name or Number *',
                controller: _trainNameOrNumberController,
                hintText: 'e.g. Samudra Devi, Express 1005',
                prefixIcon: Icons.train_outlined,
                validator: (val) {
                  if (_selectedCategory.id == 1 && _selectedTransportType == 'train') {
                    if (val == null || val.trim().isEmpty) {
                      return 'Train name or number is required.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Starting Station *',
                controller: _trainStartingStationController,
                hintText: 'e.g. Colombo Fort, Kandy, Galle',
                prefixIcon: Icons.trip_origin_rounded,
                validator: (val) {
                  if (_selectedCategory.id == 1 && _selectedTransportType == 'train') {
                    if (val == null || val.trim().isEmpty) {
                      return 'Starting station is required.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Destination *',
                controller: _trainDestinationController,
                hintText: 'e.g. Matara, Badulla, Fort',
                prefixIcon: Icons.flag_outlined,
                validator: (val) {
                  if (_selectedCategory.id == 1 && _selectedTransportType == 'train') {
                    if (val == null || val.trim().isEmpty) {
                      return 'Destination is required.';
                    }
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // Crowd Density Level
            Text('Crowd Density Level', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildCrowdOption('light', 'Light', AppColors.crowdEmpty),
                const SizedBox(width: 6),
                _buildCrowdOption('moderate', 'Moderate', AppColors.crowdModerate),
                const SizedBox(width: 6),
                _buildCrowdOption('heavy', 'Heavy', AppColors.crowdCrowded),
                const SizedBox(width: 6),
                _buildCrowdOption('packed', 'Packed', AppColors.crowdPacked),
              ],
            ),
          ],
        ),
      );
    }

    // 3. Road Condition (Category 2) -> Hazard Type Picker
    if (_selectedCategory.id == 2) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warningDark),
                const SizedBox(width: 6),
                Text('Road Hazard Classification', style: AppTypography.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRoadHazard,
                  isExpanded: true,
                  items: _roadHazards.map((hazard) {
                    return DropdownMenuItem(
                      value: hazard,
                      child: Text(hazard, style: AppTypography.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRoadHazard = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCrowdOption(String level, String label, Color color) {
    final isSelected = _selectedCrowdLevel == level;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCrowdLevel = level),
        borderRadius: AppSpacing.roundedSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.18) : AppColors.surfaceVariant,
            borderRadius: AppSpacing.roundedSm,
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? color : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportTypeOption({
    required String type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTransportType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedTransportType != type) {
            setState(() {
              _selectedTransportType = type;
            });
          }
        },
        borderRadius: AppSpacing.roundedSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surfaceVariant,
            borderRadius: AppSpacing.roundedSm,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Location Details', style: AppTypography.titleSmall),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _useGpsLocation,
                icon: const Icon(Icons.my_location_rounded, size: 14),
                label: const Text('Use GPS'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Landmark / Location Description',
            controller: _locationController,
            hintText: 'e.g. Town Hall roundabout near Public Library',
            prefixIcon: Icons.edit_location_alt_outlined,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a location description.';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'GPS: ${_latitude.toStringAsFixed(4)}° N, ${_longitude.toStringAsFixed(4)}° E',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContentCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Report Details', style: AppTypography.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Report Title',
            controller: _titleController,
            hintText: 'Brief summary (e.g. Broken bus blocking lane)',
            prefixIcon: Icons.title_rounded,
            validator: (val) {
              if (val == null || val.trim().length < 5) {
                return 'Title must be at least 5 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Detailed Description',
            controller: _descriptionController,
            hintText: 'Provide details to help fellow commuters plan their travel...',
            maxLines: 4,
            validator: (val) {
              if (val == null || val.trim().length < 10) {
                return 'Description must be at least 10 characters.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaAttachmentCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _hasAttachedMedia ? AppColors.successLight : AppColors.surfaceVariant,
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Icon(
              _hasAttachedMedia ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
              color: _hasAttachedMedia ? AppColors.success : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasAttachedMedia ? 'Photo Attached' : 'Attach Photo (Optional)',
                  style: AppTypography.titleSmall,
                ),
                Text(
                  _hasAttachedMedia ? 'sample_hazard_photo.jpg (Verified)' : 'Add photo evidence for faster verification',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _hasAttachedMedia = !_hasAttachedMedia);
            },
            child: Text(_hasAttachedMedia ? 'Remove' : 'Add Photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousToggleCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isAnonymous ? AppColors.primaryLight : AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: _isAnonymous ? AppColors.primary : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isAnonymous ? Icons.visibility_off_rounded : Icons.visibility_outlined,
            color: _isAnonymous ? AppColors.primary : AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit Anonymously',
                  style: AppTypography.titleSmall.copyWith(
                    color: _isAnonymous ? AppColors.primaryDark : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your name is hidden from public feeds as "Anonymous Commuter". You retain internal ownership and can manage this report in My Reports.',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _isAnonymous = val),
          ),
        ],
      ),
    );
  }
}

