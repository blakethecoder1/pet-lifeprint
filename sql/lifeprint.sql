-- Lifeprint Database Schema
-- The City Remembers
-- 
-- Harden SQL and Error Handling Requirements:
-- - All tables use CREATE TABLE IF NOT EXISTS
-- - Safe migration procedures for missing columns
-- - Indexes on identifier, target_identifier, created_at for performance
-- - All migrations check for column existence before ALTER

-- ============================================================================
-- Memories Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_memories` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player identifier (citizenid/license)',
    `target_identifier` VARCHAR(100) NULL COMMENT 'Related player identifier',
    `target_name` VARCHAR(100) NULL COMMENT 'Related player name for display',
    `memory_type` VARCHAR(50) NOT NULL DEFAULT 'other' COMMENT 'Type: encounter, conflict, friendship, etc.',
    `title` VARCHAR(255) NULL COMMENT 'Memory title for display',
    `description` TEXT NOT NULL COMMENT 'Memory description',
    `location` VARCHAR(255) NULL COMMENT 'Where the memory occurred',
    `x` DOUBLE NULL COMMENT 'World X coordinate for location triggers',
    `y` DOUBLE NULL COMMENT 'World Y coordinate for location triggers',
    `z` DOUBLE NULL COMMENT 'World Z coordinate for location triggers',
    `timestamp` BIGINT NOT NULL COMMENT 'Unix timestamp',
    `visibility` VARCHAR(20) DEFAULT 'private' COMMENT 'Visibility: private, public, admin',
    `metadata` JSON NULL COMMENT 'Additional metadata (JSON)',
    `decay_score` DOUBLE NOT NULL DEFAULT 1.0 COMMENT 'Current memory strength after decay (0.0 to 1.0)',
    `reinforcement_count` INT NOT NULL DEFAULT 1 COMMENT 'Times this memory has been reinforced',
    `event_chain_id` VARCHAR(64) NULL COMMENT 'Optional event chain identifier to group related memories',
    `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_target` (`target_identifier`),
    INDEX `idx_type` (`memory_type`),
    INDEX `idx_timestamp` (`timestamp`),
    INDEX `idx_visibility` (`visibility`),
    INDEX `idx_demo` (`is_demo`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_coords` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add missing columns to lifeprint_memories
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_memories`()
BEGIN
    DECLARE title_exists INT DEFAULT 0;
    DECLARE target_name_exists INT DEFAULT 0;
    DECLARE visibility_exists INT DEFAULT 0;
    DECLARE is_demo_exists INT DEFAULT 0;
    DECLARE x_exists INT DEFAULT 0;
    DECLARE y_exists INT DEFAULT 0;
    DECLARE z_exists INT DEFAULT 0;
    DECLARE created_at_index_exists INT DEFAULT 0;
    DECLARE coords_index_exists INT DEFAULT 0;
    DECLARE legacy_type_exists INT DEFAULT 0;
    DECLARE memory_type_exists INT DEFAULT 0;
    DECLARE decay_score_exists INT DEFAULT 0;
    DECLARE reinforcement_count_exists INT DEFAULT 0;
    DECLARE event_chain_id_exists INT DEFAULT 0;
    DECLARE event_chain_index_exists INT DEFAULT 0;
    
    -- Check for legacy 'type' column and rename to 'memory_type'
    SELECT COUNT(*) INTO legacy_type_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'type';
    
    SELECT COUNT(*) INTO memory_type_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'memory_type';
    
    -- If 'type' exists but 'memory_type' doesn't, rename it
    IF legacy_type_exists > 0 AND memory_type_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` CHANGE COLUMN `type` `memory_type` VARCHAR(50) NOT NULL DEFAULT 'other' COMMENT 'Type: encounter, conflict, friendship, etc.';
    -- If 'type' exists and 'memory_type' also exists, drop 'type'
    ELSEIF legacy_type_exists > 0 AND memory_type_exists > 0 THEN
        ALTER TABLE `lifeprint_memories` DROP COLUMN `type`;
    END IF;
    
    -- Check for title column
    SELECT COUNT(*) INTO title_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'title';
    
    IF title_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `title` VARCHAR(255) NULL COMMENT 'Memory title for display' 
        AFTER `memory_type`;
    END IF;
    
    -- Check for target_name column
    SELECT COUNT(*) INTO target_name_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'target_name';
    
    IF target_name_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `target_name` VARCHAR(100) NULL COMMENT 'Related player name for display' 
        AFTER `target_identifier`;
    END IF;
    
    -- Check for visibility column
    SELECT COUNT(*) INTO visibility_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'visibility';
    
    IF visibility_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `visibility` VARCHAR(20) DEFAULT 'private' COMMENT 'Visibility: private, public, admin' 
        AFTER `timestamp`;
    END IF;
    
    -- Check for is_demo column
    SELECT COUNT(*) INTO is_demo_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'is_demo';
    
    IF is_demo_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?' 
        AFTER `metadata`;
    END IF;
    
    -- Check for x column (location coordinates)
    SELECT COUNT(*) INTO x_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'x';
    
    IF x_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `x` DOUBLE NULL COMMENT 'World X coordinate for location triggers' 
        AFTER `location`;
    END IF;
    
    -- Check for y column (location coordinates)
    SELECT COUNT(*) INTO y_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'y';
    
    IF y_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `y` DOUBLE NULL COMMENT 'World Y coordinate for location triggers' 
        AFTER `x`;
    END IF;
    
    -- Check for z column (location coordinates)
    SELECT COUNT(*) INTO z_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND column_name = 'z';
    
    IF z_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` 
        ADD COLUMN `z` DOUBLE NULL COMMENT 'World Z coordinate for location triggers' 
        AFTER `y`;
    END IF;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND index_name = 'idx_created_at';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` ADD INDEX `idx_created_at` (`created_at`);
    END IF;
    
    -- Check for coords index (for location queries)
    SELECT COUNT(*) INTO coords_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_memories' 
    AND index_name = 'idx_coords';
    
    IF coords_index_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` ADD INDEX `idx_coords` (`x`, `y`);
    END IF;

    -- Check for decay_score column
    SELECT COUNT(*) INTO decay_score_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_memories'
    AND column_name = 'decay_score';

    IF decay_score_exists = 0 THEN
        ALTER TABLE `lifeprint_memories`
        ADD COLUMN `decay_score` DOUBLE NOT NULL DEFAULT 1.0 COMMENT 'Current memory strength after decay (0.0 to 1.0)'
        AFTER `metadata`;
    END IF;

    -- Check for reinforcement_count column
    SELECT COUNT(*) INTO reinforcement_count_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_memories'
    AND column_name = 'reinforcement_count';

    IF reinforcement_count_exists = 0 THEN
        ALTER TABLE `lifeprint_memories`
        ADD COLUMN `reinforcement_count` INT NOT NULL DEFAULT 1 COMMENT 'Times this memory has been reinforced'
        AFTER `decay_score`;
    END IF;

    -- Check for event_chain_id column
    SELECT COUNT(*) INTO event_chain_id_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_memories'
    AND column_name = 'event_chain_id';

    IF event_chain_id_exists = 0 THEN
        ALTER TABLE `lifeprint_memories`
        ADD COLUMN `event_chain_id` VARCHAR(64) NULL COMMENT 'Optional event chain identifier to group related memories'
        AFTER `reinforcement_count`;
    END IF;

    -- Check for event chain index
    SELECT COUNT(*) INTO event_chain_index_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_memories'
    AND index_name = 'idx_event_chain';

    IF event_chain_index_exists = 0 THEN
        ALTER TABLE `lifeprint_memories` ADD INDEX `idx_event_chain` (`event_chain_id`);
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_memories`();

-- ============================================================================
-- Relationships Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_relationships` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player identifier',
    `target_identifier` VARCHAR(100) NOT NULL COMMENT 'Target player identifier',
    `target_name` VARCHAR(100) NULL COMMENT 'Cached target name for display',
    `display_alias` VARCHAR(100) NULL COMMENT 'Custom alias/nickname for display',
    `relationship_value` INT NOT NULL DEFAULT 0 COMMENT 'Relationship score (-100 to 100)',
    `relationship_type` VARCHAR(50) NOT NULL DEFAULT 'stranger' COMMENT 'Type: stranger, friend, enemy, etc.',
    `first_met` BIGINT NULL COMMENT 'Unix timestamp of first meeting',
    `last_interaction` BIGINT NULL COMMENT 'Unix timestamp of last interaction',
    `interaction_count` INT DEFAULT 1 COMMENT 'Number of interactions',
    `notes` VARCHAR(500) NULL COMMENT 'Private notes about this person',
    `first_location` VARCHAR(255) NULL COMMENT 'Location where first met',
    `is_face_memory` TINYINT(1) DEFAULT 0 COMMENT 'Is this a face memory?',
    `photo` TEXT NULL COMMENT 'Photo URL or reference for this relationship',
    `avatar_url` TEXT NULL COMMENT 'Alternative avatar URL',
    `headshot_txd` VARCHAR(128) NULL COMMENT 'Ped headshot TXD string from game',
    `memory_strength` INT NOT NULL DEFAULT 1 COMMENT 'Memory strength (1-10)',
    `metadata` JSON NULL COMMENT 'Additional metadata',
    `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_relationship` (`identifier`, `target_identifier`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_target` (`target_identifier`),
    INDEX `idx_value` (`relationship_value`),
    INDEX `idx_face_memory` (`is_face_memory`),
    INDEX `idx_demo` (`is_demo`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add missing columns to lifeprint_relationships
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_relationships`()
BEGIN
    DECLARE notes_exists INT DEFAULT 0;
    DECLARE first_location_exists INT DEFAULT 0;
    DECLARE is_face_memory_exists INT DEFAULT 0;
    DECLARE photo_exists INT DEFAULT 0;
    DECLARE avatar_url_exists INT DEFAULT 0;
    DECLARE headshot_txd_exists INT DEFAULT 0;
    DECLARE display_alias_exists INT DEFAULT 0;
    DECLARE memory_strength_exists INT DEFAULT 0;
    DECLARE negative_events_exists INT DEFAULT 0;
    DECLARE is_demo_exists INT DEFAULT 0;
    DECLARE created_at_index_exists INT DEFAULT 0;

    -- Check for display_alias column
    SELECT COUNT(*) INTO display_alias_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'display_alias';

    IF display_alias_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `display_alias` VARCHAR(100) NULL COMMENT 'Custom alias/nickname for display' 
        AFTER `target_name`;
    END IF;
    
    -- Check for notes column
    SELECT COUNT(*) INTO notes_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'notes';
    
    IF notes_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `notes` VARCHAR(500) NULL COMMENT 'Private notes about this person' 
        AFTER `interaction_count`;
    END IF;
    
    -- Check for first_location column
    SELECT COUNT(*) INTO first_location_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'first_location';
    
    IF first_location_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `first_location` VARCHAR(255) NULL COMMENT 'Location where first met' 
        AFTER `notes`;
    END IF;
    
    -- Check for is_face_memory column
    SELECT COUNT(*) INTO is_face_memory_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'is_face_memory';
    
    IF is_face_memory_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `is_face_memory` TINYINT(1) DEFAULT 0 COMMENT 'Is this a face memory?' 
        AFTER `first_location`;
    END IF;
    
    -- Check for photo column
    SELECT COUNT(*) INTO photo_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'photo';
    
    IF photo_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `photo` TEXT NULL COMMENT 'Photo URL or reference for this relationship' 
        AFTER `is_face_memory`;
    END IF;
    
    -- Check for avatar_url column
    SELECT COUNT(*) INTO avatar_url_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'avatar_url';
    
    IF avatar_url_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `avatar_url` TEXT NULL COMMENT 'Alternative avatar URL' 
        AFTER `photo`;
    END IF;
    
    -- Check for headshot_txd column
    SELECT COUNT(*) INTO headshot_txd_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'headshot_txd';
    
    IF headshot_txd_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `headshot_txd` VARCHAR(128) NULL COMMENT 'Ped headshot TXD string from game' 
        AFTER `avatar_url`;
    END IF;
    
    -- Check for memory_strength column
    SELECT COUNT(*) INTO memory_strength_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'memory_strength';
    
    IF memory_strength_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `memory_strength` INT NOT NULL DEFAULT 1 COMMENT 'Memory strength (1-10)' 
        AFTER `avatar_url`;
    END IF;
    
    -- Check for negative_events column
    SELECT COUNT(*) INTO negative_events_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'negative_events';
    
    IF negative_events_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `negative_events` INT NOT NULL DEFAULT 0 COMMENT 'Number of negative events in this relationship' 
        AFTER `memory_strength`;
    END IF;
    
    -- Check for is_demo column
    SELECT COUNT(*) INTO is_demo_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND column_name = 'is_demo';
    
    IF is_demo_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` 
        ADD COLUMN `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?' 
        AFTER `negative_events`;
    END IF;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_relationships' 
    AND index_name = 'idx_created_at';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_relationships` ADD INDEX `idx_created_at` (`created_at`);
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_relationships`();

-- ============================================================================
-- Relationship History Table
-- Tracks meaningful changes and moments for each relationship
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_relationship_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Owner player identifier',
    `target_identifier` VARCHAR(100) NOT NULL COMMENT 'Related target identifier',
    `event_type` VARCHAR(50) NOT NULL COMMENT 'relationship, note, alias, face_memory, photo, etc.',
    `summary` VARCHAR(255) NOT NULL COMMENT 'Short human-readable summary',
    `metadata` JSON NULL COMMENT 'Optional structured event metadata',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier_target` (`identifier`, `target_identifier`),
    INDEX `idx_event_type` (`event_type`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Reputation Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_reputation` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player identifier',
    `category` VARCHAR(50) NOT NULL COMMENT 'Category: general, criminal, business, etc.',
    `reputation_value` INT NOT NULL DEFAULT 0 COMMENT 'Reputation score (-100 to 100)',
    `notes` VARCHAR(500) NULL COMMENT 'Notes about this reputation',
    `last_updated` BIGINT NULL COMMENT 'Unix timestamp of last update',
    `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_reputation` (`identifier`, `category`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_category` (`category`),
    INDEX `idx_value` (`reputation_value`),
    INDEX `idx_demo` (`is_demo`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add missing columns to lifeprint_reputation
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_reputation`()
BEGIN
    DECLARE notes_exists INT DEFAULT 0;
    DECLARE is_demo_exists INT DEFAULT 0;
    DECLARE created_at_index_exists INT DEFAULT 0;
    
    -- Check for notes column
    SELECT COUNT(*) INTO notes_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation' 
    AND column_name = 'notes';
    
    IF notes_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation` 
        ADD COLUMN `notes` VARCHAR(500) NULL COMMENT 'Notes about this reputation' 
        AFTER `reputation_value`;
    END IF;
    
    -- Check for is_demo column
    SELECT COUNT(*) INTO is_demo_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation' 
    AND column_name = 'is_demo';
    
    IF is_demo_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation` 
        ADD COLUMN `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?' 
        AFTER `last_updated`;
    END IF;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation' 
    AND index_name = 'idx_created_at';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation` ADD INDEX `idx_created_at` (`created_at`);
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_reputation`();

-- ============================================================================
-- Reputation Log Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_reputation_log` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player identifier',
    `category` VARCHAR(50) NOT NULL COMMENT 'Reputation category',
    `change_amount` INT NOT NULL COMMENT 'Points changed (positive or negative)',
    `reason` VARCHAR(500) NULL COMMENT 'Reason for the change',
    `source` VARCHAR(100) NULL COMMENT 'Source of the change (system, player, event)',
    `created_at` BIGINT NOT NULL COMMENT 'Unix timestamp',
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_category` (`category`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Rename reserved keyword column in lifeprint_reputation_log
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_reputation_log`()
BEGIN
    DECLARE change_exists INT DEFAULT 0;
    DECLARE change_amount_exists INT DEFAULT 0;
    
    -- Check if old 'change' column exists (reserved keyword)
    SELECT COUNT(*) INTO change_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_log' 
    AND column_name = 'change';
    
    -- Check if new 'change_amount' column exists
    SELECT COUNT(*) INTO change_amount_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_log' 
    AND column_name = 'change_amount';
    
    -- If 'change' exists but 'change_amount' doesn't, rename it
    IF change_exists > 0 AND change_amount_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_log` 
        CHANGE COLUMN `change` `change_amount` INT NOT NULL COMMENT 'Points changed (positive or negative)';
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_reputation_log`();

-- ============================================================================
-- Reputation Counters Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_reputation_counters` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player identifier',
    `arrests` INT NOT NULL DEFAULT 0 COMMENT 'Number of arrests',
    `ems_visits` INT NOT NULL DEFAULT 0 COMMENT 'Number of EMS/hospital visits',
    `crashes` INT NOT NULL DEFAULT 0 COMMENT 'Number of vehicle crashes',
    `meetings` INT NOT NULL DEFAULT 0 COMMENT 'Number of meaningful meetings with other characters',
    `helpful_actions` INT NOT NULL DEFAULT 0 COMMENT 'Number of helpful/good samaritan actions',
    `suspicious_actions` INT NOT NULL DEFAULT 0 COMMENT 'Number of suspicious/questionable actions',
    `kills` INT NOT NULL DEFAULT 0 COMMENT 'Number of player kills',
    `deaths` INT NOT NULL DEFAULT 0 COMMENT 'Number of player deaths',
    `last_updated` BIGINT NULL COMMENT 'Unix timestamp of last counter update',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_counters` (`identifier`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add columns to lifeprint_reputation_counters
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_counters`()
BEGIN
    DECLARE created_at_index_exists INT DEFAULT 0;
    DECLARE kills_exists INT DEFAULT 0;
    DECLARE deaths_exists INT DEFAULT 0;
    DECLARE npc_vehicle_thefts_exists INT DEFAULT 0;
    DECLARE npc_assaults_exists INT DEFAULT 0;
    DECLARE npc_kills_exists INT DEFAULT 0;
    DECLARE gunshots_reported_exists INT DEFAULT 0;
    DECLARE drug_deals_exists INT DEFAULT 0;
    DECLARE injuries_exists INT DEFAULT 0;
    DECLARE vehicle_hits_exists INT DEFAULT 0;
    DECLARE gunshot_wounds_exists INT DEFAULT 0;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND index_name = 'idx_created_at';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` ADD INDEX `idx_created_at` (`created_at`);
    END IF;
    
    -- Check for kills column
    SELECT COUNT(*) INTO kills_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'kills';
    
    IF kills_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `kills` INT NOT NULL DEFAULT 0 COMMENT 'Number of player kills' 
        AFTER `suspicious_actions`;
    END IF;
    
    -- Check for deaths column
    SELECT COUNT(*) INTO deaths_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'deaths';
    
    IF deaths_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `deaths` INT NOT NULL DEFAULT 0 COMMENT 'Number of player deaths' 
        AFTER `kills`;
    END IF;
    
    -- Check for npc_vehicle_thefts column
    SELECT COUNT(*) INTO npc_vehicle_thefts_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'npc_vehicle_thefts';
    
    IF npc_vehicle_thefts_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `npc_vehicle_thefts` INT NOT NULL DEFAULT 0 COMMENT 'Number of NPC vehicle thefts witnessed' 
        AFTER `deaths`;
    END IF;
    
    -- Check for npc_assaults column
    SELECT COUNT(*) INTO npc_assaults_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'npc_assaults';
    
    IF npc_assaults_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `npc_assaults` INT NOT NULL DEFAULT 0 COMMENT 'Number of NPC assaults witnessed' 
        AFTER `npc_vehicle_thefts`;
    END IF;
    
    -- Check for npc_kills column
    SELECT COUNT(*) INTO npc_kills_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'npc_kills';
    
    IF npc_kills_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `npc_kills` INT NOT NULL DEFAULT 0 COMMENT 'Number of NPC kills witnessed' 
        AFTER `npc_assaults`;
    END IF;
    
    -- Check for gunshots_reported column
    SELECT COUNT(*) INTO gunshots_reported_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'gunshots_reported';
    
    IF gunshots_reported_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `gunshots_reported` INT NOT NULL DEFAULT 0 COMMENT 'Number of gunshot incidents reported by NPCs' 
        AFTER `npc_kills`;
    END IF;
    
    -- Check for drug_deals column
    SELECT COUNT(*) INTO drug_deals_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'drug_deals';
    
    IF drug_deals_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `drug_deals` INT NOT NULL DEFAULT 0 COMMENT 'Number of drug deals witnessed by NPCs' 
        AFTER `gunshots_reported`;
    END IF;
    
    -- Check for injuries column
    SELECT COUNT(*) INTO injuries_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'injuries';
    
    IF injuries_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `injuries` INT NOT NULL DEFAULT 0 COMMENT 'Number of non-fatal injuries' 
        AFTER `drug_deals`;
    END IF;
    
    -- Check for vehicle_hits column
    SELECT COUNT(*) INTO vehicle_hits_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'vehicle_hits';
    
    IF vehicle_hits_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `vehicle_hits` INT NOT NULL DEFAULT 0 COMMENT 'Number of times hit by vehicles (survived)' 
        AFTER `injuries`;
    END IF;
    
    -- Check for gunshot_wounds column
    SELECT COUNT(*) INTO gunshot_wounds_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_reputation_counters' 
    AND column_name = 'gunshot_wounds';
    
    IF gunshot_wounds_exists = 0 THEN
        ALTER TABLE `lifeprint_reputation_counters` 
        ADD COLUMN `gunshot_wounds` INT NOT NULL DEFAULT 0 COMMENT 'Number of gunshot wounds survived' 
        AFTER `vehicle_hits`;
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_counters`();

-- ============================================================================
-- Rumors Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_rumors` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player who has this rumor in their collection',
    `source_identifier` VARCHAR(100) NULL COMMENT 'Player who created/heard the rumor',
    `target_identifier` VARCHAR(100) NULL COMMENT 'Player the rumor is about',
    `target_name` VARCHAR(100) NULL COMMENT 'Cached target name for display',
    `rumor_type` VARCHAR(50) NOT NULL DEFAULT 'hearsay' COMMENT 'Type: crime, secret, scandal, etc.',
    `content` TEXT NOT NULL COMMENT 'The rumor content',
    `expires_at` BIGINT NULL COMMENT 'Unix timestamp when rumor expires (NULL = never)',
    `created_at` BIGINT NOT NULL COMMENT 'Unix timestamp',
    `is_public` BOOLEAN DEFAULT FALSE COMMENT 'Whether rumor is public knowledge',
    `verification_status` VARCHAR(20) NOT NULL DEFAULT 'unverified' COMMENT 'unverified, verified, disputed',
    `credibility_score` INT NOT NULL DEFAULT 0 COMMENT 'Credibility score (-100 to 100)',
    `verified_by_identifier` VARCHAR(100) NULL COMMENT 'Identifier that verified/disputed this rumor',
    `verified_at` BIGINT NULL COMMENT 'Unix timestamp of verification/dispute',
    `event_chain_id` VARCHAR(64) NULL COMMENT 'Optional event chain identifier to group related rumor events',
    `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?',
    `metadata` JSON NULL COMMENT 'Additional metadata',
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_source` (`source_identifier`),
    INDEX `idx_target` (`target_identifier`),
    INDEX `idx_type` (`rumor_type`),
    INDEX `idx_expires` (`expires_at`),
    INDEX `idx_demo` (`is_demo`),
    INDEX `idx_created_at_timestamp` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add missing columns to lifeprint_rumors
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_rumors`()
BEGIN
    DECLARE is_demo_exists INT DEFAULT 0;
    DECLARE created_at_index_exists INT DEFAULT 0;
    DECLARE verification_status_exists INT DEFAULT 0;
    DECLARE credibility_score_exists INT DEFAULT 0;
    DECLARE verified_by_exists INT DEFAULT 0;
    DECLARE verified_at_exists INT DEFAULT 0;
    DECLARE event_chain_id_exists INT DEFAULT 0;
    DECLARE verification_index_exists INT DEFAULT 0;
    
    -- Check for is_demo column
    SELECT COUNT(*) INTO is_demo_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_rumors' 
    AND column_name = 'is_demo';
    
    IF is_demo_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors` 
        ADD COLUMN `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?' 
        AFTER `is_public`;
    END IF;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_rumors' 
    AND index_name = 'idx_created_at_timestamp';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors` ADD INDEX `idx_created_at_timestamp` (`created_at`);
    END IF;

    -- Check for verification_status column
    SELECT COUNT(*) INTO verification_status_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_rumors'
    AND column_name = 'verification_status';

    IF verification_status_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors`
        ADD COLUMN `verification_status` VARCHAR(20) NOT NULL DEFAULT 'unverified' COMMENT 'unverified, verified, disputed'
        AFTER `is_public`;
    END IF;

    -- Check for credibility_score column
    SELECT COUNT(*) INTO credibility_score_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_rumors'
    AND column_name = 'credibility_score';

    IF credibility_score_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors`
        ADD COLUMN `credibility_score` INT NOT NULL DEFAULT 0 COMMENT 'Credibility score (-100 to 100)'
        AFTER `verification_status`;
    END IF;

    -- Check for verified_by_identifier column
    SELECT COUNT(*) INTO verified_by_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_rumors'
    AND column_name = 'verified_by_identifier';

    IF verified_by_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors`
        ADD COLUMN `verified_by_identifier` VARCHAR(100) NULL COMMENT 'Identifier that verified/disputed this rumor'
        AFTER `credibility_score`;
    END IF;

    -- Check for verified_at column
    SELECT COUNT(*) INTO verified_at_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_rumors'
    AND column_name = 'verified_at';

    IF verified_at_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors`
        ADD COLUMN `verified_at` BIGINT NULL COMMENT 'Unix timestamp of verification/dispute'
        AFTER `verified_by_identifier`;
    END IF;

    -- Check for event_chain_id column
    SELECT COUNT(*) INTO event_chain_id_exists
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_rumors'
    AND column_name = 'event_chain_id';

    IF event_chain_id_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors`
        ADD COLUMN `event_chain_id` VARCHAR(64) NULL COMMENT 'Optional event chain identifier to group related rumor events'
        AFTER `verified_at`;
    END IF;

    -- Check verification index
    SELECT COUNT(*) INTO verification_index_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
    AND table_name = 'lifeprint_rumors'
    AND index_name = 'idx_verification';

    IF verification_index_exists = 0 THEN
        ALTER TABLE `lifeprint_rumors` ADD INDEX `idx_verification` (`verification_status`, `credibility_score`);
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_rumors`();

-- ============================================================================
-- Settings Table (Privacy Controls)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_settings` (
    `identifier` VARCHAR(100) NOT NULL PRIMARY KEY COMMENT 'Player identifier',
    `face_reminders` TINYINT(1) DEFAULT 1 COMMENT 'Enable face memory reminders',
    `proximity_memories` TINYINT(1) DEFAULT 1 COMMENT 'Enable automatic proximity memories',
    `rumor_notifications` TINYINT(1) DEFAULT 1 COMMENT 'Enable rumor notifications',
    `memory_popups` TINYINT(1) DEFAULT 1 COMMENT 'Enable memory brought up popups',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add index to lifeprint_settings
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_settings`()
BEGIN
    DECLARE created_at_index_exists INT DEFAULT 0;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_settings' 
    AND index_name = 'idx_created_at';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_settings` ADD INDEX `idx_created_at` (`created_at`);
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_settings`();

-- ============================================================================
-- Social Links Table (Seen With Feature)
-- Tracks who players are frequently seen near
-- ============================================================================

CREATE TABLE IF NOT EXISTS `lifeprint_social_links` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL COMMENT 'Player identifier',
    `target_identifier` VARCHAR(100) NOT NULL COMMENT 'Target player identifier',
    `target_name` VARCHAR(128) NULL COMMENT 'Cached target name for display',
    `seen_count` INT NOT NULL DEFAULT 1 COMMENT 'Number of times seen together',
    `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last proximity timestamp',
    `first_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'First proximity timestamp',
    `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_social_link` (`identifier`, `target_identifier`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_target` (`target_identifier`),
    INDEX `idx_seen_count` (`seen_count`),
    INDEX `idx_last_seen` (`last_seen`),
    INDEX `idx_demo` (`is_demo`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Safe Migration: Add columns to lifeprint_social_links
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_migrate_social_links`()
BEGIN
    DECLARE first_seen_exists INT DEFAULT 0;
    DECLARE is_demo_exists INT DEFAULT 0;
    DECLARE created_at_index_exists INT DEFAULT 0;
    
    -- Check for first_seen column
    SELECT COUNT(*) INTO first_seen_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_social_links' 
    AND column_name = 'first_seen';
    
    IF first_seen_exists = 0 THEN
        ALTER TABLE `lifeprint_social_links` 
        ADD COLUMN `first_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'First proximity timestamp' 
        AFTER `last_seen`;
    END IF;
    
    -- Check for is_demo column
    SELECT COUNT(*) INTO is_demo_exists 
    FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_social_links' 
    AND column_name = 'is_demo';
    
    IF is_demo_exists = 0 THEN
        ALTER TABLE `lifeprint_social_links` 
        ADD COLUMN `is_demo` TINYINT(1) DEFAULT 0 COMMENT 'Is this demo data?' 
        AFTER `first_seen`;
    END IF;
    
    -- Check for created_at index
    SELECT COUNT(*) INTO created_at_index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = 'lifeprint_social_links' 
    AND index_name = 'idx_created_at';
    
    IF created_at_index_exists = 0 THEN
        ALTER TABLE `lifeprint_social_links` ADD INDEX `idx_created_at` (`created_at`);
    END IF;
END //
DELIMITER ;

CALL `lifeprint_migrate_social_links`();

-- ============================================================================
-- Cleanup Procedure (Optional - run via cron or scheduled task)
-- ============================================================================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `lifeprint_cleanup_expired_rumors`()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Silently handle errors in cleanup
    END;
    
    DELETE FROM `lifeprint_rumors` 
    WHERE `expires_at` IS NOT NULL 
    AND `expires_at` < UNIX_TIMESTAMP();
END //
DELIMITER ;

-- ============================================================================
-- Initialize Tables (ensure all tables exist on resource start)
-- ============================================================================

-- This is handled by CREATE TABLE IF NOT EXISTS above
-- All migrations are called after table definitions
