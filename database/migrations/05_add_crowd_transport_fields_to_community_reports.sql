-- =============================================================================
-- Migration: 05_add_crowd_transport_fields_to_community_reports.sql
-- Module 2: Community Reporting & Transport Disruption Management (Dumindi)
-- Description: Adds transport-specific attributes (Bus/Train details & Crowd Density)
--              to community_reports table for enhanced Crowd Reports.
-- Target Table: community_reports
-- Engine: MySQL 8.0+
-- Safety: All added columns are NULLABLE with default NULL.
--         Existing records in community_reports remain completely intact.
-- =============================================================================

ALTER TABLE `community_reports`
  ADD COLUMN `transport_type` ENUM('bus', 'train') NULL AFTER `disruption_reason`,
  ADD COLUMN `bus_route_number` VARCHAR(50) NULL AFTER `transport_type`,
  ADD COLUMN `destination` VARCHAR(150) NULL AFTER `bus_route_number`,
  ADD COLUMN `bus_registration_number` VARCHAR(50) NULL AFTER `destination`,
  ADD COLUMN `train_name_or_number` VARCHAR(100) NULL AFTER `bus_registration_number`,
  ADD COLUMN `starting_station` VARCHAR(150) NULL AFTER `train_name_or_number`,
  ADD COLUMN `crowd_level` ENUM('light', 'moderate', 'heavy', 'packed') NULL AFTER `starting_station`;

-- Optional rollback statement (for documentation):
-- ALTER TABLE `community_reports`
--   DROP COLUMN `crowd_level`,
--   DROP COLUMN `starting_station`,
--   DROP COLUMN `train_name_or_number`,
--   DROP COLUMN `bus_registration_number`,
--   DROP COLUMN `destination`,
--   DROP COLUMN `bus_route_number`,
--   DROP COLUMN `transport_type`;

