-- ================================================================
-- WSO2 IS 7.1.0 Schema Migration - IDP_AUTHENTICATOR
-- ================================================================
-- Run this script BEFORE starting WSO2 IS/API Manager if upgrading
-- from an older schema version
-- ================================================================

USE WSO2AM_DB;

-- Backup recommendation (uncomment if needed)
-- CREATE TABLE IDP_AUTHENTICATOR_BACKUP AS SELECT * FROM IDP_AUTHENTICATOR;

-- Add missing AUTHENTICATION_TYPE column
ALTER TABLE IDP_AUTHENTICATOR 
ADD COLUMN IF NOT EXISTS AUTHENTICATION_TYPE VARCHAR(255) DEFAULT 'FEDERATED' 
AFTER DISPLAY_NAME;

-- Verify the column was added
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'WSO2AM_DB' 
AND TABLE_NAME = 'IDP_AUTHENTICATOR' 
AND COLUMN_NAME = 'AUTHENTICATION_TYPE';

SELECT 'Migration completed successfully. The AUTHENTICATION_TYPE column has been added to IDP_AUTHENTICATOR table.' AS Status;
