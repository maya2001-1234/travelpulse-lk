import 'package:flutter/material.dart';

import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../dumindi/providers/report_provider.dart';
import '../../suneth/providers/crowd_provider.dart';
import '../models/road_incident_model.dart';
import '../providers/map_provider.dart';
import '../providers/alert_provider.dart';
import '../services/location_service.dart';
import '../widgets/incident_preview_sheet.dart';
import '../widgets/map_safety_banner.dart';
import 'select_location_view.dart';

/// TravelPulse LK — Interactive Live Map Screen (Thimaya)
/// Visualizes verified road incidents, physical hazards, community disruptions,
/// and transit crowd overlays across Sri Lankan transit corridors.
class LiveMapView extends StatefulWidget {
  final MapProvider mapProvider;
  final AlertProvider? alertProvider;
  final ReportProvider? reportProvider;
  final CrowdProvider? crowdProvider;

  const LiveMapView({
    super.key,
    required this.mapProvider,
    this.alertProvider,
    this.reportProvider,
    this.crowdProvider,
  });

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterChips = [
    'All',
    'Flooding',
    'Road Closures',
    'Potholes',
    'Signal Faults',
  ];

  @override
  void initState() {
    super.initState();
    widget.mapProvider.loadMapData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMarkerTapped(RoadIncidentModel incident) {
    widget.mapProvider.selectIncident(incident);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IncidentPreviewSheet(
        incident: incident,
        onClose: () {
          widget.mapProvider.selectIncident(null);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openLocationPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectLocationView(mapProvider: widget.mapProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.mapProvider,
          builder: (context, _) {
            final provider = widget.mapProvider;
            final incidents = provider.filteredIncidents;
            final isPermissionDenied =
                provider.permissionState == LocationPermissionState.denied ||
                provider.permissionState ==
                    LocationPermissionState.permanentlyDenied;

            return Stack(
              children: [
                // 1. Visual Map Canvas Viewport
                Positioned.fill(child: _buildMapCanvas(provider, incidents)),

                // 2. Top Header Controls: Search Bar & Safety Banner
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search and Filter Bar
                      _buildTopSearchBar(provider),

                      // Filter chips
                      _buildFilterRow(provider),

                      // Safety Advisory Banner (if active critical alert exists)
                      if (provider.showSafetyBanner &&
                          widget.alertProvider != null &&
                          widget.alertProvider!.hasCriticalAlerts) ...[
                        MapSafetyBanner(
                          alert: widget.alertProvider!.criticalAlerts.first,
                          onTap: () {
                            Navigator.of(context)
                                .pushNamed(RouteConstants.alerts);
                          },
                          onDismiss: () => provider.dismissSafetyBanner(),
                        ),
                      ],

                      // Location permission warning banner (if denied)
                      if (isPermissionDenied) ...[
                        _buildPermissionWarningBanner(),
                      ],
                    ],
                  ),
                ),

                // 3. Floating Map Controls (Right Side)
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Select Location manually
                      FloatingActionButton.small(
                        heroTag: 'map_select_loc',
                        tooltip: 'Select Location Manually',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        onPressed: _openLocationPicker,
                        child: const Icon(Icons.edit_location_alt_rounded),
                      ),
                      const SizedBox(height: 8),

                      // Layers toggle (Crowd & Disruptions)
                      FloatingActionButton.small(
                        heroTag: 'map_layers',
                        tooltip: 'Toggle Overlays',
                        backgroundColor: AppColors.surface,
                        foregroundColor: provider.showCrowdOverlay
                            ? AppColors.primary
                            : AppColors.textMuted,
                        onPressed: () {
                          provider.toggleCrowdOverlay();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                provider.showCrowdOverlay
                                    ? 'Crowd density overlay enabled.'
                                    : 'Crowd density overlay hidden.',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Icon(Icons.layers_rounded),
                      ),
                      const SizedBox(height: 8),

                      // Recenter GPS
                      FloatingActionButton(
                        heroTag: 'map_recenter',
                        tooltip: 'Recenter on GPS',
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surface,
                        onPressed: () {
                          provider.resetToGpsLocation();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Centered at ${provider.currentLocation.label}',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSearchBar(MapProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedLg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search junctions, roads, or hazards...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: AppTypography.bodySmall,
              onChanged: (val) => provider.setSearchQuery(val),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              onPressed: () {
                _searchController.clear();
                provider.setSearchQuery('');
              },
            ),
          Container(
            height: 24,
            width: 1,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Travel Alerts',
            onPressed: () {
              Navigator.of(context).pushNamed(RouteConstants.alerts);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(MapProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _filterChips.map((chip) {
          final isSelected =
              (chip == 'All' && provider.typeFilter == 'All') ||
              (chip == 'Flooding' && provider.typeFilter == 'flooding') ||
              (chip == 'Road Closures' &&
                  provider.typeFilter == 'road_closure') ||
              (chip == 'Potholes' && provider.typeFilter == 'pothole') ||
              (chip == 'Signal Faults' &&
                  provider.typeFilter == 'traffic_lights_down');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(chip),
              selected: isSelected,
              onSelected: (selected) {
                if (chip == 'All') {
                  provider.setTypeFilter('All');
                } else if (chip == 'Flooding') {
                  provider.setTypeFilter(selected ? 'flooding' : 'All');
                } else if (chip == 'Road Closures') {
                  provider.setTypeFilter(selected ? 'road_closure' : 'All');
                } else if (chip == 'Potholes') {
                  provider.setTypeFilter(selected ? 'pothole' : 'All');
                } else if (chip == 'Signal Faults') {
                  provider.setTypeFilter(
                    selected ? 'traffic_lights_down' : 'All',
                  );
                }
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryLight,
              labelStyle: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.4 : 1.0,
              ),
              elevation: isSelected ? 2 : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPermissionWarningBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 18,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location access denied. Using manual location selection.',
              style: AppTypography.caption.copyWith(
                color: AppColors.warningDark,
              ),
            ),
          ),
          TextButton(
            onPressed: _openLocationPicker,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change Location',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Visual Map Canvas Viewport with Colombo schematic roads & active incident pins
  Widget _buildMapCanvas(
    MapProvider provider,
    List<RoadIncidentModel> incidents,
  ) {
    return Container(
      color: const Color(0xFFE8ECEF), // Map background tone
      child: CustomPaint(
        painter: _ColomboMapPainter(
          incidents: incidents,
          userLocation: provider.currentLocation,
          showCrowdOverlay: provider.showCrowdOverlay,
        ),
        child: Stack(
          children: [
            // Center location pin callout
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppSpacing.roundedPill,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      provider.currentLocation.label,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: provider.currentLocation.isManual
                          ? AppColors.warning
                          : AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (provider.currentLocation.isManual
                                      ? AppColors.warning
                                      : AppColors.primary)
                                  .withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Incident Marker Overlays (Tappable Pins)
            ..._buildInteractiveMarkers(incidents),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInteractiveMarkers(List<RoadIncidentModel> incidents) {
    // Relative positions on Colombo viewport for interactive tap
    final Map<int, Offset> incidentCoordinates = {
      401: const Offset(0.35, 0.60), // Thunmulla (South-West)
      402: const Offset(0.55, 0.45), // Town Hall (Center-East)
      403: const Offset(0.70, 0.75), // Nugegoda (South-East)
      404: const Offset(0.48, 0.55), // Thimbirigasyaya
    };

    return incidents.map((incident) {
      final pos = incidentCoordinates[incident.id] ?? const Offset(0.5, 0.5);

      return Align(
        alignment: FractionalOffset(pos.dx, pos.dy),
        child: GestureDetector(
          onTap: () => _onMarkerTapped(incident),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: incident.markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: incident.markerColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(incident.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.roundedSm,
                  border: Border.all(color: incident.markerColor, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  incident.incidentType.toUpperCase().replaceAll('_', ' '),
                  style: AppTypography.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: incident.markerColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Custom Canvas Painter rendering Colombo's coastal transit grid and road corridors
class _ColomboMapPainter extends CustomPainter {
  final List<RoadIncidentModel> incidents;
  final CommuterLocation userLocation;
  final bool showCrowdOverlay;

  _ColomboMapPainter({
    required this.incidents,
    required this.userLocation,
    required this.showCrowdOverlay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ocean Boundary (West Coast - Indian Ocean)
    final oceanPaint = Paint()
      ..color = const Color(0xFFCBE3EF)
      ..style = PaintingStyle.fill;
    final oceanPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.18, 0)
      ..quadraticBezierTo(
        size.width * 0.14,
        size.height * 0.5,
        size.width * 0.10,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(oceanPath, oceanPaint);

    // 2. Coastal Highway / Galle Road (A2 Corridor)
    final highwayPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    final highwayBorder = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final galleRoad = Path()
      ..moveTo(size.width * 0.22, 0)
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.4,
        size.width * 0.18,
        size.height,
      );
    canvas.drawPath(galleRoad, highwayBorder);
    canvas.drawPath(galleRoad, highwayPaint);

    // 3. High Level Road (Route 138 Corridor - East-West spine)
    final highLevelRoad = Path()
      ..moveTo(size.width * 0.22, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.50,
        size.width,
        size.height * 0.85,
      );
    canvas.drawPath(highLevelRoad, highwayBorder);
    canvas.drawPath(highLevelRoad, highwayPaint);

    // 4. Baseline Road / Kandy Road
    final baselineRoad = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width * 0.55, size.height);
    canvas.drawPath(baselineRoad, highwayBorder);
    canvas.drawPath(baselineRoad, highwayPaint);

    // 5. Connecting Arteries (Bauddhaloka Mawatha & Town Hall Circle)
    final arteryPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final bauddhaloka = Path()
      ..moveTo(size.width * 0.18, size.height * 0.60)
      ..lineTo(size.width * 0.70, size.height * 0.60);
    canvas.drawPath(bauddhaloka, arteryPaint);

    // Town hall roundabout schematic
    final circlePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.45),
      22,
      circlePaint,
    );

    // 6. Crowd Congestion Heatmap Overlay (if enabled)
    if (showCrowdOverlay) {
      final crowdPaint = Paint()
        ..color = AppColors.crowdPacked.withOpacity(0.14)
        ..style = PaintingStyle.fill;
      // High Level Road rush-hour corridor heat
      canvas.drawCircle(
        Offset(size.width * 0.55, size.height * 0.45),
        45,
        crowdPaint,
      );
      canvas.drawCircle(
        Offset(size.width * 0.35, size.height * 0.60),
        40,
        crowdPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColomboMapPainter oldDelegate) {
    return oldDelegate.incidents != incidents ||
        oldDelegate.showCrowdOverlay != showCrowdOverlay ||
        oldDelegate.userLocation != userLocation;
  }
}
