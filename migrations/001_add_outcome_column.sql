-- Migration: 001_add_outcome_column.sql
-- Description: Adds categorical match outcome support (e.g., 'walkover', 'forfeit', 'bye') to the match table.
-- Compatibility: MySQL 8.0+ / MariaDB 10.3+

-- Apply column addition
ALTER TABLE `match`
ADD COLUMN `outcome` VARCHAR(30) NULL DEFAULT NULL
AFTER `winner_team_id`;

-- Verification query:
-- SELECT id, match_name, winner_team_id, outcome, status, is_final FROM `match` LIMIT 5;
