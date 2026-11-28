-- =============================================================================
-- TravelPulse LK — Module 2: Community Reporting Seed Data
-- Owning Member: Dumindi
-- =============================================================================

-- Master taxonomy of report categories (Table 9: report_categories)
INSERT INTO `report_categories` (`id`, `code`, `name`, `description`, `default_severity`, `is_active`)
VALUES
  (1, 'CROWD', 'Crowd Report', 'Real-time transit crowd density and wait times', 'low', TRUE),
  (2, 'ROAD_CONDITION', 'Road Condition', 'Potholes, flooding, road closures, and hazards', 'medium', TRUE),
  (3, 'TRANSPORT_TRACKING', 'Transport/Route Tracking', 'Bus and train operational movement and tracking', 'low', TRUE),
  (4, 'SERVICE_DISRUPTION', 'Service Disruption', 'Cancellations, breakdowns, delays, and service interruptions', 'high', TRUE),
  (5, 'ACCIDENT_INCIDENT', 'Accident/Incident', 'Traffic collisions, emergencies, and safety incidents', 'critical', TRUE),
  (6, 'OTHER', 'Other', 'General commuter notices, lost & found, and feedback', 'low', TRUE)
ON DUPLICATE KEY UPDATE
  `name` = VALUES(`name`),
  `description` = VALUES(`description`),
  `default_severity` = VALUES(`default_severity`),
  `is_active` = VALUES(`is_active`);

-- Initial community reports (Table 10: community_reports)
INSERT INTO `community_reports` (
  `id`, `user_id`, `is_anonymous`, `category_id`, `route_id`, `stop_id`,
  `latitude`, `longitude`, `location_description`, `title`, `description`,
  `disruption_reason`, `status`, `created_at`
) VALUES
  (
    101, 1, FALSE, 4, 1, 104,
    6.91470000, 79.86530000, 'Town Hall roundabout near Public Library',
    'Bus Breakdown Blocking Center Lane',
    'Route 138 SLTB bus broke down right after the roundabout. Traffic backing up towards Maradana and Borella.',
    'Vehicle Breakdown', 'verified', DATE_SUB(NOW(), INTERVAL 25 MINUTE)
  ),
  (
    102, 2, TRUE, 2, 2, NULL,
    6.89200000, 79.85800000, 'Bauddhaloka Mawatha near Thunmulla',
    'Severe Waterlogging / Flash Flood',
    'Heavy rain has flooded the junction with 1.5 feet of water. Low clearance three-wheelers and cars cannot pass. Buses moving slowly.',
    'Road Inundation / Flooding', 'verified', DATE_SUB(NOW(), INTERVAL 70 MINUTE)
  ),
  (
    103, 1, FALSE, 1, 1, 101,
    6.93550000, 79.85300000, 'Pettah Main Bus Stand - Route 138 bay',
    'Heavy Evening Rush Hour Overcrowding',
    'Huge queue extending over 50 meters. Buses arriving every 10 minutes but fill immediately.',
    NULL, 'submitted', DATE_SUB(NOW(), INTERVAL 15 MINUTE)
  )
ON DUPLICATE KEY UPDATE
  `title` = VALUES(`title`),
  `description` = VALUES(`description`),
  `status` = VALUES(`status`);

