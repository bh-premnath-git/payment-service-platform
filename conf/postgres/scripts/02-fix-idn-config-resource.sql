\c wso2is_db;

-- Helper function that can be reused both by the DO block below and the event trigger
CREATE OR REPLACE FUNCTION public.ensure_idn_config_resource_created_time()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ensure future inserts receive a timestamp automatically
    EXECUTE 'ALTER TABLE public.idn_config_resource ALTER COLUMN created_time SET DEFAULT CURRENT_TIMESTAMP';

    -- Update any existing rows that may have been inserted without a timestamp
    EXECUTE 'UPDATE public.idn_config_resource
             SET created_time = CURRENT_TIMESTAMP
             WHERE created_time IS NULL';
END;
$$;

-- Apply the default and backfill rows immediately if the table already exists
DO $$
BEGIN
    IF to_regclass('public.idn_config_resource') IS NOT NULL THEN
        PERFORM public.ensure_idn_config_resource_created_time();
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
    object_name text;
BEGIN
    FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        object_name := lower(replace(cmd.object_identity, '"', ''));

        IF cmd.object_type = 'table'
           AND cmd.schema_name = 'public'
           AND object_name = 'public.idn_config_resource' THEN
            PERFORM public.ensure_idn_config_resource_created_time();
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
