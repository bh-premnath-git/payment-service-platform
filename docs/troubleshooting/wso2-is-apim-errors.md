# WSO2 Identity Server ↔ API Manager Integration Errors

This guide summarizes the runtime errors captured in the shared log, the root cause of each, and the recommended remediation steps. It also outlines how to configure mutual TLS trust between WSO2 Identity Server (IS) 7.1.0 and API Manager (APIM) 4.5.0 when using locally issued mkcert certificates.

## Identity Governance Data Store NullPointerException

**Log snippet**
```
Error while activating identity governance component. ... NullPointerException: Cannot invoke "String.trim()" because "storeClassName" is null
```

**Cause**

The Identity Governance `Identity Data Store` configuration is missing. IS expects a data store implementation class and receives `null`, which triggers the `NullPointerException` during component activation.

**Fix**

Restore the default JDBC data store configuration. Use either option below:

- **Restore the XML block** – Copy the `<IdentityDataStore>` block from a clean IS 7.1.0 pack into `repository/conf/identity/identity.xml`.
- **TOML override** – If you manage configs via `deployment.toml`, add the override:
  ```toml
  [identity_gov.identity_data_store]
  store_class_name = "org.wso2.carbon.identity.governance.store.JDBCIdentityDataStore"
  ```

If you use a custom data store implementation, set its fully qualified class name instead.

## DefaultRealm/User Store Initialization Failure

**Log snippets**
```
DefaultRealm ... UserStoreException ... DB error occurred while persisting domain : PRIMARY & tenant id : -1234
Caused by: SQLNonTransientConnectionException: Could not create connection ...
Caused by: CJException: Access denied for user 'wso2carbon'@'%' to database 'WSO2IS_SHARED_DB'
```

**Cause**

Identity Server cannot initialize the primary user store because the datasource targets `WSO2IS_SHARED_DB`, a schema the
`wso2carbon` user cannot access (or that does not exist). The user store bundles depend on the database connection and fail
cascadingly, so resolving the datasource mapping fixes the downstream errors (e.g., "Cannot start User Manager Core bundle").

**Fix**

1. **Create the intended schemas and grant privileges** – Unless you explicitly need a shared database, use the standard IS
   schemas and grant full access to the integration user:
   ```sql
   CREATE DATABASE WSO2IS_IDENTITY_DB CHARACTER SET utf8mb4;
   CREATE DATABASE WSO2IS_UM_DB       CHARACTER SET utf8mb4;
   CREATE DATABASE WSO2IS_CONFIG_DB   CHARACTER SET utf8mb4;

   CREATE USER 'wso2carbon'@'%' IDENTIFIED BY '<DB_PASSWORD>';
   GRANT ALL PRIVILEGES ON WSO2IS_IDENTITY_DB.* TO 'wso2carbon'@'%';
   GRANT ALL PRIVILEGES ON WSO2IS_UM_DB.*       TO 'wso2carbon'@'%';
   GRANT ALL PRIVILEGES ON WSO2IS_CONFIG_DB.*   TO 'wso2carbon'@'%';
   FLUSH PRIVILEGES;
   ```
2. **Point datasources to the correct schemas** – Update `<IS_HOME>/repository/conf/deployment.toml` so each datasource
   references the matching schema:
   ```toml
   [database.identity_db]
   type = "mysql"
   url = "jdbc:mysql://<mysql-host>:3306/WSO2IS_IDENTITY_DB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
   username = "wso2carbon"
   password = "<DB_PASSWORD>"

   [database.user]
   type = "mysql"
   url = "jdbc:mysql://<mysql-host>:3306/WSO2IS_UM_DB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
   username = "wso2carbon"
   password = "<DB_PASSWORD>"

   [database.config]
   type = "mysql"
   url = "jdbc:mysql://<mysql-host>:3306/WSO2IS_CONFIG_DB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
   username = "wso2carbon"
   password = "<DB_PASSWORD>"
   ```
   Only use a `*_SHARED_DB` schema when you have a specific requirement for one.
3. **Load the IS schema DDL** – From the product pack, execute the scripts against the corresponding databases:
   ```bash
   mysql -u root -p WSO2IS_IDENTITY_DB < dbscripts/identity/mysql.sql
   mysql -u root -p WSO2IS_UM_DB       < dbscripts/um/mysql.sql       # sometimes mysql5.sql
   mysql -u root -p WSO2IS_CONFIG_DB   < dbscripts/config/mysql.sql
   ```
4. **Run a quick connectivity test** – Before restarting IS, confirm the integration user can connect:
   ```bash
   mysql -h <mysql-host> -u wso2carbon -p WSO2IS_UM_DB -e "select 1;"
   ```

Restart Identity Server after completing the steps. The `DefaultRealm` and `User Manager Core` errors should no longer appear,
and OAuth services will activate without further waiting messages.

## User Store Datasource JNDI Lookup Failure

**Log snippet**
```
NameNotFoundException: Name [WSO2UM_DB] is not bound in this Context. Unable to find [WSO2UM_DB]
```

**Cause**

Identity Server is trying to resolve the primary user store datasource via JNDI using the name `WSO2UM_DB`, but no such resource
is bound. This typically happens when:

- `[database.user]` is missing from `deployment.toml`, so the runtime falls back to JNDI.
- A JNDI datasource exists but is registered under a different name (e.g., `jdbc/WSO2UM_DB`).
- `user-mgt.xml` references a datasource name that is not actually bound.

**Fix (pick one approach)**

1. **Configure the datasource directly in TOML (recommended)** – Add the datasource under `[database.user]`. When present, IS
   uses the TOML definition without attempting JNDI resolution:
   ```toml
   [database.user]
   type = "mysql"
   url = "jdbc:mysql://<MYSQL_HOST>:3306/WSO2IS_UM_DB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
   username = "wso2carbon"
   password = "<DB_PASSWORD>"
   ```
   Ensure the schema exists and the integration user can connect:
   ```sql
   CREATE DATABASE WSO2IS_UM_DB CHARACTER SET utf8mb4;
   GRANT ALL PRIVILEGES ON WSO2IS_UM_DB.* TO 'wso2carbon'@'%' IDENTIFIED BY '<DB_PASSWORD>';
   FLUSH PRIVILEGES;
   ```
   Keep `<Property name="dataSource">` empty or matching `WSO2UM_DB` in `repository/conf/user-mgt.xml`; the TOML entry takes
   precedence.
2. **Align the JNDI name** – If you prefer JNDI, bind the datasource under the exact name the runtime expects. In
   `deployment.toml`:
   ```toml
   [datasource.WSO2UM_DB]
   id        = "WSO2UM_DB"
   url       = "jdbc:mysql://<MYSQL_HOST>:3306/WSO2IS_UM_DB?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
   username  = "wso2carbon"
   password  = "<DB_PASSWORD>"
   driver    = "com.mysql.cj.jdbc.Driver"
   jndi_name = "WSO2UM_DB"
   ```
   If `user-mgt.xml` uses a different JNDI name (e.g., `jdbc/WSO2UM_DB`), update both the `jndi_name` here and the
   `<Property name="dataSource">` entry to match.

Before restarting, run a quick connectivity check to validate credentials and networking:
```bash
mysql -h <MYSQL_HOST> -u wso2carbon -p WSO2IS_UM_DB -e "select 1;"
```
After the fix, the `User Manager Core` bundle should start cleanly with no further `NameNotFoundException` messages.

## Missing Baseline Internal Roles

**Log snippets**
```
org.wso2.carbon.identity.scim2.common... Error while resolving Internal/everyone role id.
org.wso2.carbon.identity.scim2.common... Error while resolving Internal/system role id.
```

**Cause**

The default internal roles (e.g., `Internal/everyone`, `Internal/system`) are absent because the primary user store database was not initialized or IS is pointing to the wrong schema.

**Fix**

1. Complete the remediation steps in [DefaultRealm/User Store Initialization Failure](#defaultrealmuser-store-initialization-failure) so the datasources reference valid schemas with appropriate privileges and DDL applied.
2. Verify that tables such as `UM_ROLE` (schema dependent) now include the seeded roles. Re-run the DDL scripts if the roles are still missing.

## Extension Manager NullPointerException

**Log snippet**
```
Error while activating ExtensionManagerComponent. java.lang.NullPointerException ... getExtensionTypes
```

**Cause**

The extension registry cannot read its metadata because the Configuration Management tables are missing or the default extension resources are absent.

**Fix**

- Run the Configuration Management DDL scripts (if available for 7.1.0) under `<IS_HOME>/dbscripts/config/` against the schema configured for configuration data.
- Ensure the contents of `<IS_HOME>/repository/resources/identity/`—especially `extensions/`—match a clean IS 7.1.0 distribution. Restore any missing files.

## Remote Logger Configuration Errors

**Log snippet**
```
RemoteLoggingConfigUpdater ... Error occurred while loading Remote Logger configuration. ... Resource type with the name: REMOTE_LOGGING_CONFIG does not exists.
```

**Cause**

The required Configuration Management resource types have not yet been created because the related database tables are missing or uninitialized.

**Fix**

Once the Configuration Management schema is in place (see above), restart IS and the error should clear. If you do not plan to use remote logging immediately, disable the updater:
```toml
[system.config.remote_logging]
enabled = false
```

## Default Super Admin Credentials Warning

**Log snippet**
```
[WARNING]: Internal authentication is utilizing default credentials
```

**Cause**

IS is still using the default `admin/admin` super admin account.

**Fix**

Change the credentials either through the management console or via `deployment.toml`:
```toml
[super_admin]
username = "admin"
password = "<strong-new-password>"
```

## Informational Warnings

### Supported Response Modes

```
' SupportedResponseModes' element not configured in identity.xml. Therefore instantiating default response mode providers.
```

This warning is informational. IS falls back to default response mode providers. Configure the `SupportedResponseModes` block only if you require custom response mode handlers.

### OAuth Service Activation Messages

```
Waiting for required OSGi services: ... OAuth2Service, OAuth2ScopeService, OAuthAdminServiceImpl, ...
```

These warnings persist while the earlier critical errors prevent OAuth-related bundles from activating. Resolve the Identity Data Store, user store, and extension issues first; the warnings will disappear once services start successfully.

### Apple Attestation Certificate Warning

```
Apple attestation root certificate path is not configured.
```

If you do not use Apple device attestation, you can ignore this message. Otherwise configure the root certificate path:
```toml
[authentication.client_attestation.apple]
root_certificate_path = "/path/to/apple-root.cer"
```

## mkcert Certificate Trust Between IS and APIM

Establish mutual TLS trust so that IS and APIM (and your browsers) trust the mkcert-issued certificates.

1. **Install mkcert root CA into the JRE cacerts**
   ```bash
   mkcert -install
   sudo keytool -importcert -trustcacerts -noprompt \
     -alias mkcert-root \
     -file "$(mkcert -CAROOT)/rootCA.pem" \
     -keystore "$JAVA_HOME/lib/security/cacerts" \
     -storepass changeit
   ```

2. **Import the mkcert root CA into the product truststores**
   ```bash
   # IS truststore
   keytool -importcert -trustcacerts -noprompt \
     -alias mkcert-root \
     -file "$(mkcert -CAROOT)/rootCA.pem" \
     -keystore <IS_HOME>/repository/resources/security/client-truststore.jks \
     -storepass wso2carbon

   # APIM truststore
   keytool -importcert -trustcacerts -noprompt \
     -alias mkcert-root \
     -file "$(mkcert -CAROOT)/rootCA.pem" \
     -keystore <APIM_HOME>/repository/resources/security/client-truststore.jks \
     -storepass wso2carbon
   ```

3. **Issue mkcert leaf certificates and load them into keystores**
   ```bash
   mkcert wso2is localhost 127.0.0.1 ::1

   openssl pkcs12 -export -in wso2is+2.pem -inkey wso2is+2-key.pem \
     -out /tmp/wso2is.p12 -name wso2is -passout pass:wso2carbon

   keytool -importkeystore \
     -srckeystore /tmp/wso2is.p12 -srcstoretype PKCS12 -srcstorepass wso2carbon \
     -destkeystore <IS_HOME>/repository/resources/security/wso2carbon.jks \
     -deststorepass wso2carbon -alias wso2is
   ```

4. **Configure HTTPS transports to use the mkcert artifacts**

   In `deployment.toml`:
   ```toml
   [transport.https]
   key_alias = "wso2is"
   keystore.file_name = "wso2carbon.jks"
   keystore.password = "wso2carbon"
   truststore.file_name = "client-truststore.jks"
   truststore.password = "wso2carbon"
   ```

   Apply equivalent settings for APIM (publisher/gateway/traffic manager) to use the mkcert keystores and truststores.

5. **Align hostnames**

   Ensure all URLs that APIM uses to reach IS (e.g., `KeyManager`, `AdminServices`) match a Subject Alternative Name in the mkcert leaf certificate (`https://wso2is:9443/...`). Mismatched hostnames lead to TLS handshake failures.

## Validation Checklist

- Datasources point to the intended Identity and UM databases with applied DDL scripts.
- The Identity Data Store configuration exists (JDBC or custom).
- Configuration Management tables and extension resources are present.
- Internal baseline roles (e.g., `Internal/everyone`) exist in the user store.
- mkcert root CA is trusted by the JRE, IS, and APIM truststores; HTTPS keystores serve mkcert leaf certificates.
- Default super admin password is changed.
- Identity Server restarts cleanly with OAuth services active and no blocking errors.

Once all items above are completed, the previously observed errors and warnings should disappear, and IS↔APIM communication over HTTPS will succeed.
