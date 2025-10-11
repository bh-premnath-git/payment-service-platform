# MySQL volume and port troubleshooting

When running the MySQL service defined in this repository with Docker Compose you may see errors similar to the following:

```
Error response from daemon: get 29538f5159542cae369389b059394a72c11a27ab225cc0703a5a1b2e200c30ba: no such volume
Error response from daemon: remove 8145a4d016a96686a0c86f610358cf867317dbb8b56b58f8366250fc93829c69: volume is in use - [99439025d3006b9d44e8e9bead4dbc044af90fa203a3ac82b254a6cee53ef674]
Invalid input: expected array, received null (path: NetworkSettings -> Ports -> 33060/tcp)
```

These log entries generally mean that Docker could not find or manipulate the named volumes that persist MySQL data, or that the container inspection output does not include a published port mapping for the MySQL X Plugin (33060/tcp).

## Root causes

1. **`no such volume` during `docker volume inspect`**  
   A Compose project name change or manual volume removal can leave stale references in automation scripts. Docker reports the error when the requested volume ID is no longer present on the host.

2. **`volume is in use` when removing a volume**  
   Attempting to delete the `mysql_data` volume while the MySQL container is still running (or a dependent container has the volume mounted) prevents Docker from performing the removal.

3. **`expected array, received null` on `Ports["33060/tcp"]`**  
   The MySQL container only publishes port `33060` when the X Plugin is enabled and a host mapping is declared. If Compose is configured to expose only the classic MySQL port (`3306`), the Docker inspect response will contain `"Ports": {"33060/tcp": null}`, which explains the schema validation error.

## Resolution steps

1. **Confirm the Compose project name**
   ```bash
   docker compose ls
   docker volume ls | grep mysql
   ```
   Ensure the volume prefix (defaults to the project name) matches the one referenced by the failing command.

2. **Recreate missing volumes**
   ```bash
   docker volume create payment-service-platform_mysql_data
   docker compose up -d mysql
   ```
   Adjust the volume name if you changed the `COMPOSE_PROJECT_NAME` environment variable.

3. **Safely remove a volume**
   ```bash
   docker compose down -v
   ```
   The `-v` flag removes the named volumes only after all services are stopped, preventing the "volume is in use" error.

4. **Publish the X Plugin port when needed**

   If automation expects the 33060/tcp mapping, expose it explicitly in `docker-compose.yml`:
   ```yaml
   services:
     mysql:
       ports:
         - "${MYSQL_PORT:-3306}:3306"
         - "33060:33060"  # add this line
   ```
   After updating the compose file, restart the stack:
   ```bash
   docker compose up -d mysql
   ```

5. **Verify MySQL container health and logs**
   ```bash
   docker compose ps mysql
   docker compose logs -f mysql
   ```
   Healthy status and successful startup logs (InnoDB initialization, TLS configuration, and readiness message) confirm that the container is operating correctly.

## Additional tips

- The repository bundles SQL initialization scripts under `conf/mysql/scripts/`. When you remove the MySQL volume, these scripts re-run on the next start to repopulate the schema.
- If you need to inspect a stopped container's mount references, run `docker container inspect <container-id> --format '{{ json .Mounts }}'` to locate the corresponding volumes.
- The MySQL entrypoint logs warnings about the self-signed CA and PID file permissions. These are expected with the default configuration and do not block startup.
