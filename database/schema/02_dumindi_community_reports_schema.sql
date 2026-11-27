-- =============================================================================
-- TravelPulse LK — Module 2: Community Reporting & Transport Disruption Management
-- Owning Member: Dumindi
-- Database Engine: MySQL 8.0+ (InnoDB)
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- Table 9: report_categories
-- Master taxonomy of disruption and incident categories.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `report_categories` (
  `id` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `description` VARCHAR(255) NULL,
  `default_severity` ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_report_cat_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table 10: community_reports
-- Primary crowdsourced reports from commuters about transit and road issues.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `community_reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `is_anonymous` BOOLEAN NOT NULL DEFAULT FALSE,
  `category_id` SMALLINT UNSIGNED NOT NULL,
  `route_id` BIGINT UNSIGNED NULL,
  `stop_id` BIGINT UNSIGNED NULL,
  `latitude` DECIMAL(10, 8) NOT NULL,
  `longitude` DECIMAL(11, 8) NOT NULL,
  `location_description` VARCHAR(255) NULL,
  `title` VARCHAR(150) NOT NULL,
  `description` TEXT NOT NULL,
  `disruption_reason` VARCHAR(100) NULL,
  `transport_type` ENUM('bus', 'train') NULL,
  `bus_route_number` VARCHAR(50) NULL,
  `destination` VARCHAR(150) NULL,
  `bus_registration_number` VARCHAR(50) NULL,
  `train_name_or_number` VARCHAR(100) NULL,
  `starting_station` VARCHAR(150) NULL,
  `crowd_level` ENUM('light', 'moderate', 'heavy', 'packed') NULL,
  `media_url` VARCHAR(255) NULL,
  `status` ENUM('submitted', 'verified', 'disputed', 'resolved', 'rejected', 'expired') NOT NULL DEFAULT 'submitted',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_reports_coords` (`latitude`, `longitude`),
  INDEX `idx_reports_route_status` (`route_id`, `status`),
  INDEX `idx_reports_user` (`user_id`),
  INDEX `idx_reports_created` (`created_at`),
  CONSTRAINT `fk_reports_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reports_category` FOREIGN KEY (`category_id`) REFERENCES `report_categories` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_reports_route` FOREIGN KEY (`route_id`) REFERENCES `transport_routes` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_reports_stop` FOREIGN KEY (`stop_id`) REFERENCES `route_stops` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Table 11: transport_disruptions
-- Operational public transit disruptions affecting specific transit routes.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `transport_disruptions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `originating_report_id` BIGINT UNSIGNED NULL,
  `route_id` BIGINT UNSIGNED NOT NULL,
  `affected_stop_id` BIGINT UNSIGNED NULL,
  `disruption_type` VARCHAR(50) NOT NULL,
  `severity` ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
  `headline` VARCHAR(200) NOT NULL,
  `details` TEXT NOT NULL,
  `status` ENUM('active', 'cleared', 'archived') NOT NULL DEFAULT 'active',
  `started_at` DATETIME NOT NULL,
  `estimated_cleared_at` DATETIME NULL,
  `cleared_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_disruptions_route_status` (`route_id`, `status`),
  CONSTRAINT `fk_disruptions_report` FOREIGN KEY (`originating_report_id`) REFERENCES `community_reports` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_disruptions_route` FOREIGN KEY (`route_id`) REFERENCES `transport_routes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_disruptions_stop` FOREIGN KEY (`affected_stop_id`) REFERENCES `route_stops` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

