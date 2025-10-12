-- Ensure IDN_CONFIG_RESOURCE.created_time gets populated automatically
\c wso2is_db;

-- Apply default immediately if the table already exists
DO $$
BEGIN
    IF to_regclass('public.idn_config_resource') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.idn_config_resource ALTER COLUMN created_time SET DEFAULT CURRENT_TIMESTAMP';
    END IF;
END
$$;

-- Create an event trigger that sets the default as soon as the table is created
CREATE OR REPLACE FUNCTION set_idn_config_resource_created_time()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
    cmd record;
BEGIN
    FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        IF cmd.object_type = 'table'
           AND cmd.schema_name = 'public'
           AND lower(cmd.object_identity) = 'public.idn_config_resource' THEN
            EXECUTE 'ALTER TABLE public.idn_config_resource ALTER COLUMN created_time SET DEFAULT CURRENT_TIMESTAMP';
            -- Drop the trigger after applying the change so it runs only once
            EXECUTE 'DROP EVENT TRIGGER IF EXISTS trg_set_idn_config_resource_created_time';
        END IF;
    END LOOP;
END;
$$;

DROP EVENT TRIGGER IF EXISTS trg_set_idn_config_resource_created_time;
CREATE EVENT TRIGGER trg_set_idn_config_resource_created_time
    ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE')
    EXECUTE FUNCTION set_idn_config_resource_created_time();
