# Payment Service Platform – Identity Server as Key Manager

This repository assembles a WSO2 Identity Server–as–Key Manager deployment together with API Manager and MySQL using Docker Compose. The pieces that matter for the Identity Server node live in two places:

## `conf/is-as-km`

This directory is bind-mounted into `/home/wso2carbon/wso2-config-volume` so that the base image copies the content into the server home at startup. It currently contains:

- `repository/conf/deployment.toml` – the primary configuration file that switches the server to MySQL, defines the super admin account, wires the API Manager integration listener and access-control rules, and declares the full set of default event listeners that the product templates expect when rendering `identity.xml`.【F:conf/is-as-km/repository/conf/deployment.toml†L1-L321】
- `repository/resources/security/` – custom keystore and truststore material that the startup script imports, allowing all containers to trust the mkcert CA that is generated at runtime.【F:dockerfiles/is-as-km/setup-and-start.sh†L1-L59】

## `dockerfiles/is-as-km`

The custom image extends the stock `wso2/wso2is:7.1.0-alpine` image and performs the following steps:

- Copies the Key Manager specific drop-in bundles so the Identity Server exposes API-M specific capabilities.【F:dockerfiles/is-as-km/Dockerfile†L1-L8】
- Downloads the MySQL JDBC driver into the product `repository/components/lib` directory so the server can reach the external MySQL database.【F:dockerfiles/is-as-km/Dockerfile†L10-L12】
- Installs `setup-and-start.sh`, a wrapper that pulls mkcert-generated certificates into the keystore/truststore before handing control over to `wso2server.sh`.【F:dockerfiles/is-as-km/Dockerfile†L4-L9】【F:dockerfiles/is-as-km/setup-and-start.sh†L1-L62】

The shell wrapper is responsible for importing the mkcert root CA and the optional leaf certificate into both the truststore and keystore so that TLS between the containers works out of the box.【F:dockerfiles/is-as-km/setup-and-start.sh†L5-L62】

## Why the Identity Server fails with `NumberFormatException`

The stack trace shows the server aborting while `IdentityConfigParser` builds the `<EventListeners>` section of `identity.xml`. The template that renders that file expects every `event.default_listener.*` stanza to provide a numeric priority; when the TOML variable is missing it collapses to an empty string and `Integer.parseInt("")` throws the exact `NumberFormatException` reported in the logs. Because the listeners bootstrap identity management, OAuth, and authentication services, the resulting cascade stops Tomcat and the rest of the Carbon stack from finishing startup.【F:conf/is-as-km/repository/conf/deployment.toml†L90-L211】

Restoring the default listener definitions with non-empty priorities resolves the issue. The repository now carries the full set under `conf/is-as-km/repository/conf/deployment.toml`, so pulling the latest configuration and rebuilding the `is-as-km` image ensures the generated runtime (`/home/wso2carbon/wso2is-7.1.0/repository/conf/identity/identity.xml`) contains valid values.【F:conf/is-as-km/repository/conf/deployment.toml†L90-L211】

While updating the listener priorities, the deployment file also reinstates the identity-management onboarding defaults, SAML response settings, and outbound provisioning flags that the upstream product expects during initialization. Those sections prevent follow-on `NullPointerException` and missing-OSGi-service warnings that appear when the configuration blocks are absent.【F:conf/is-as-km/repository/conf/deployment.toml†L271-L321】 Rebuild the image (`docker compose build is-as-km`) and restart the stack so the packaged Carbon home picks up the updated configuration.
