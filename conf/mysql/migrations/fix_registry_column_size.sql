-- ================================================================
-- WSO2 IS 7.1.0 Registry Column Size Fix
-- ================================================================
-- Fix REG_VALUE column size for large email templates
-- ================================================================

USE WSO2AM_SHARED_DB;

-- Increase REG_VALUE column size
ALTER TABLE REG_PROPERTY MODIFY REG_VALUE TEXT;

-- Verify the change
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'WSO2AM_SHARED_DB' 
AND TABLE_NAME = 'REG_PROPERTY' 
AND COLUMN_NAME = 'REG_VALUE';

SELECT 'Registry column size fix completed successfully.' AS Status;
