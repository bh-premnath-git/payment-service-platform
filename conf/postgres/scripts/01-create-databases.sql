-- Create databases for WSO2
CREATE DATABASE wso2am_db;
CREATE DATABASE wso2shared_db;
CREATE DATABASE wso2is_db;

-- Create user
CREATE USER wso2user WITH ENCRYPTED PASSWORD 'wso2pass';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE wso2am_db TO wso2user;
GRANT ALL PRIVILEGES ON DATABASE wso2shared_db TO wso2user;
GRANT ALL PRIVILEGES ON DATABASE wso2is_db TO wso2user;

-- Connect to each database and grant schema privileges
\c wso2am_db;
GRANT ALL ON SCHEMA public TO wso2user;

\c wso2shared_db;
GRANT ALL ON SCHEMA public TO wso2user;

\c wso2is_db;
GRANT ALL ON SCHEMA public TO wso2user;