# WSO2 API Manager with Identity Server as Key Manager

This repository provides an opinionated Docker Compose deployment of **WSO2 API Manager 4.5.0** with **WSO2 Identity Server 7.1.0** acting as the Key Manager and a **MySQL 8** backing database. The configuration files under `conf/` are mounted into the containers at runtime so you can extend or override the default behavior without rebuilding the images.

## Repository layout

| Path | Description |
|------|-------------|
| `conf/apim` | Configuration overrides for the API Manager runtime, including the deployment descriptor and keystores. |
| `conf/is-as-km` | Identity Server configuration files, keystores, and templates used when it runs as the Key Manager. |
| `conf/mysql` | Custom MySQL configuration (`conf/mysql/conf/my.cnf`) and SQL initialization scripts (`conf/mysql/scripts`). |
| `dockerfiles/apim` | Docker build context for API Manager. Adds the MySQL JDBC connector specified in the `.env` file. |
| `dockerfiles/is-as-km` | Docker build context for the Identity Server (Key Manager) image. Copies additional bundles/web apps and the JDBC connector. |

## Prerequisites

Before you begin, make sure the following tools are installed locally:

- [Docker Engine](https://docs.docker.com/engine/install/) 20.10 or newer
- [Docker Compose plugin](https://docs.docker.com/compose/install/) v2 or newer (the classic `docker-compose` binary also works)

## Configure environment variables

Runtime and build-time parameters are centralized in the [`.env`](./.env) file. You can adjust host port mappings or the MySQL image tag without editing `docker-compose.yml`. The defaults are shown below:

| Variable | Purpose | Default |
|----------|---------|---------|
| `MYSQL_IMAGE` | MySQL image (tag) used for the database container. | `mysql:8.0.43-debian` |
| `MYSQL_PORT` | Host port that exposes MySQL. | `3306` |
| `MYSQL_ROOT_PASSWORD` | Root password supplied to the MySQL container. | `root` |
| `ISKM_HTTPS_PORT` | Host HTTPS port that exposes Identity Server (Key Manager). | `9444` |
| `APIM_HTTPS_PORT` | Host HTTPS port for the API Manager management UIs. | `9443` |
| `APIM_GATEWAY_HTTP_PORT` | Host HTTP port for the API Gateway. | `8280` |
| `APIM_GATEWAY_HTTPS_PORT` | Host HTTPS port for the API Gateway. | `8243` |
| `MYSQL_CONNECTOR_VERSION` | MySQL JDBC driver version downloaded into the WSO2 images during build. | `8.0.32` |
| `MKCERT_HOSTNAMES` | Space separated hostnames/IPs used when generating the shared TLS certificate. | `"localhost 127.0.0.1 ::1 mysql api-manager is-as-km"` |
| `MKCERT_EXPORT_PKCS12` | When set to `true`, also export a PKCS#12 bundle (`cert.p12`) with the generated key pair. | `false` |
| `MKCERT_PKCS12_PASSWORD` | Password used for the optional PKCS#12 bundle. | `changeit` |

> **Note:** Database credentials (`wso2carbon`) referenced by the WSO2 products are baked into the configuration under `conf/`. Update those files if you change the credentials in the SQL scripts.

## Usage

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-org>/payment-service-platform.git
   cd payment-service-platform
   ```

2. **Review or customize the environment**
   - Update the [.env](./.env) file if you need different port bindings or MySQL image tags.
   - Adjust the SQL initialization scripts in `conf/mysql/scripts/` if you require custom databases or users.

3. **Build and start the stack**
   ```bash
   docker compose up --build
   ```
   The first run downloads the base WSO2 images and injects the MySQL JDBC connector version declared in the `.env` file.

4. **Verify service health**
   - MySQL: `docker compose ps mysql`
   - Identity Server (Key Manager) health endpoint: `https://localhost:${ISKM_HTTPS_PORT}/api/health-check/v1.0/health`
   - API Manager health endpoint: `http://localhost:9763/services/Version`

5. **Access the WSO2 web applications**

   | Application | URL |
   |-------------|-----|
   | API Publisher | `https://localhost:${APIM_HTTPS_PORT}/publisher` |
   | Developer Portal | `https://localhost:${APIM_HTTPS_PORT}/devportal` |
   | Admin Portal | `https://localhost:${APIM_HTTPS_PORT}/admin` |
   | Management Console | `https://localhost:${APIM_HTTPS_PORT}/carbon` |

   Use the default credentials unless you have changed them in the configuration files:
  - **Username:** `admin`
  - **Password:** `ChangeMeNow!2024`

   The API Gateway is published on:
   - `https://localhost:${APIM_GATEWAY_HTTPS_PORT}`
   - `https://localhost:${APIM_GATEWAY_HTTP_PORT}`

6. **Shut down the environment**
   ```bash
   docker compose down
   ```
   Add the `-v` flag to remove the persisted MySQL volume if you need a clean slate.

## Shared TLS material via mkcert

The composition now includes a lightweight `mkcert` service that provisions a local Certificate Authority (CA) and a wildcard
certificate that can be reused by MySQL, API Manager, and Identity Server. Certificates are written to a named Docker volume,
`mkcert-certs`, and mounted read-only into each runtime container under `/certs`.

- `cert.pem` / `key.pem` – default leaf certificate and key that include the hostnames listed in `MKCERT_HOSTNAMES`.
- `rootCA.pem` / `rootCA-key.pem` – the locally trusted CA material generated by `mkcert`. Import `rootCA.pem` into client
  trust stores if you enable TLS on any of the services.
- `cert.p12` – optional PKCS#12 bundle produced when `MKCERT_EXPORT_PKCS12=true` (protected with
  `MKCERT_PKCS12_PASSWORD`).

The mkcert container runs once during start-up, creates the certificate assets if they do not already exist in the volume, and
then idles. You can customize the hostnames or toggle the PKCS#12 export in the `.env` file. MySQL is configured to consume the
shared certificate automatically, while the WSO2 products continue to mount the material so you can update their keystore
definitions if you want to enable TLS for their endpoints.

## Troubleshooting tips

- The MySQL server starts with TLS enabled and uses the certificates generated by the mkcert helper. Update your JDBC URLs or
  clients to trust `rootCA.pem` when connecting securely.
- If the WSO2 containers fail to start, check the logs with `docker compose logs api-manager is-as-km` to confirm that the MySQL database initialization scripts finished executing. The `mysql` health check waits for the `initialization-complete.flag` file before marking the service as healthy.
- For additional customization, update the configuration templates in `conf/is-as-km/repository/resources/conf/templates` and re-run the stack.
- If the Identity Server log reports an error similar to `Resource type with the name: CERTIFICATE_VALIDATOR does not exists`, drop the MySQL volume (or delete the schema) and restart the stack so that the [configuration management DDL](conf/mysql/scripts/mysql_apim.sql) runs. This inserts the required `CERTIFICATE_VALIDATOR` resource type for the X.509 certificate validator.
- See [MySQL volume and port troubleshooting](docs/troubleshooting/mysql-volume-and-port-errors.md) for guidance on resolving Docker volume errors and missing `33060/tcp` port mappings reported by automation scripts.



## License

This project inherits the licensing of the upstream WSO2 Docker images and supporting resources. Consult the headers inside each configuration or Dockerfile for details.
