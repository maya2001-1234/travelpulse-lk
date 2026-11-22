import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/map_provider.dart';

/// TravelPulse LK — Manual Location Selection Screen (Thimaya)
/// Fallback when GPS location is denied or when commuters want to inspect/report
/// conditions at a specific Sri Lankan transit node.
class SelectLocationView extends StatefulWidget {
  final MapProvider mapProvider;
  final Function(double lat, double lon, String label)? onLocationSelected;

  const SelectLocationView({
    super.key,
    required this.mapProvider,
    this.onLocationSelected,
  });

  @override
  State<SelectLocationView> createState() => _SelectLocationViewState();
}

class _SelectLocationViewState extends State<SelectLocationView> {
  late double _selectedLat;
  late double _selectedLon;
  late String _selectedLabel;

  final List<Map<String, dynamic>> _sriLankanHubs = [
    {
      'name': 'Colombo Fort Railway Station & Bus Terminal',
      'lat': 6.9355,
      'lon': 79.8530,
      'area': 'Colombo 01',
      'type': 'rail_bus',
    },
    {
      'name': 'Pettah Central Bus Stand',
      'lat': 6.9360,
      'lon': 79.8550,
      'area': 'Colombo 11',
      'type': 'bus',
    },
    {
      'name': 'Town Hall & Viharamahadevi Park',
      'lat': 6.9147,
      'lon': 79.8653,
      'area': 'Colombo 07',
      'type': 'junction',
    },
    {
      'name': 'Thunmulla Roundabout',
      'lat': 6.8920,
      'lon': 79.8580,
      'area': 'Colombo 04',
      'type': 'junction',
    },
    {
      'name': 'Bambalapitiya Junction',
      'lat': 6.8910,
      'lon': 79.8550,
      'area': 'Colombo 04',
      'type': 'bus',
    },
    {
      'name': 'Nugegoda Flyover & Supermarket',
      'lat': 6.8724,
      'lon': 79.8898,
      'area': 'Nugegoda',
      'type': 'junction',
    },
    {
      'name': 'Kaduwela Express Interchange',
      'lat': 6.9340,
      'lon': 79.9830,
      'area': 'Kaduwela',
      'type': 'bus',
    },
    {
      'name': 'Maharagama Bus Stand',
      'lat': 6.8480,
      'lon': 79.9260,
      'area': 'Maharagama',
      'type': 'bus',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.mapProvider.currentLocation.latitude;
    _selectedLon = widget.mapProvider.currentLocation.longitude;
    _selectedLabel = widget.mapProvider.currentLocation.label;
  }

  void _confirmSelection() {
    widget.mapProvider.setManualLocation(
      latitude: _selectedLat,
      longitude: _selectedLon,
      label: _selectedLabel,
    );

    widget.onLocationSelected?.call(_selectedLat, _selectedLon, _selectedLabel);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Map centered at $_selectedLabel'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          TextButton(
            onPressed: () {
              widget.mapProvider.resetToGpsLocation();
              Navigator.of(context).pop();
            },
            child: const Text('Reset GPS'),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: AppButton(
            text: 'Confirm Location',
            leadingIcon: Icons.check_circle_rounded,
            onPressed: _confirmSelection,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_searching_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Location Fallback',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select a key transit node to center map hazards and localized road advisories.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Current Selection Display
              Text('Selected Coordinates', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pin_drop_rounded,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedLabel, style: AppTypography.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedLat.toStringAsFixed(4)}° N, ${_selectedLon.toStringAsFixed(4)}° E',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Hubs List
              Text(
                'Major Colombo Transit Hubs',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sriLankanHubs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final hub = _sriLankanHubs[index];
                  final isSelected = _selectedLabel == hub['name'];

                  return AppCard(
                    onTap: () {
                      setState(() {
                        _selectedLat = hub['lat'] as double;
                        _selectedLon = hub['lon'] as double;
                        _selectedLabel = hub['name'] as String;
                      });
                    },
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.surface,
                    borderColor: isSelected
                        ? AppColors.primary
                        : AppColors.border,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hub['name'] as String,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${hub['area']} • ${hub['lat']}, ${hub['lon']}',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
