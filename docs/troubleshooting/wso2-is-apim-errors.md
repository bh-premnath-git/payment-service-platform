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

## Missing Baseline Internal Roles

**Log snippets**
```
org.wso2.carbon.identity.scim2.common... Error while resolving Internal/everyone role id.
org.wso2.carbon.identity.scim2.common... Error while resolving Internal/system role id.
```

**Cause**

The default internal roles (e.g., `Internal/everyone`, `Internal/system`) are absent because the primary user store database was not initialized or IS is pointing to the wrong schema.

**Fix**

1. Confirm that the primary user store datasource is reachable and credentials are correct.
2. Apply the initial DDL to the databases referenced by the Identity and User Management datasources:
   - Execute the scripts under `<IS_HOME>/dbscripts/identity/` and `<IS_HOME>/dbscripts/um/` against the corresponding schemas (e.g., `WSO2IS_IDENTITY_DB`, `WSO2IS_UM_DB`).
3. If you previously encountered `Access denied for user 'wso2carbon'`, grant the correct privileges, for example:
   ```sql
   CREATE USER 'wso2carbon'@'%' IDENTIFIED BY 'yourpass';
   GRANT ALL PRIVILEGES ON WSO2IS_IDENTITY_DB.* TO 'wso2carbon'@'%';
   GRANT ALL PRIVILEGES ON WSO2IS_UM_DB.*       TO 'wso2carbon'@'%';
   FLUSH PRIVILEGES;
   ```
4. Verify that tables such as `UM_ROLE` (schema dependent) now include the seeded roles. Re-run the DDL scripts if the roles are still missing.

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
