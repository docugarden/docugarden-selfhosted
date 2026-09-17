<center>
<pre>
*********************+=:.
###**********************=:
###************************=
#####************************:
######************************:
#######************************.       .:=++++=-:
########**********************-      :+***********=.
##########*******************-     .+***************=
###########*****************=     -******************+.
############***************+     -*********************:
#############**************:    -***********************.
###############***********+    :*************************
################*********#:    **************************=
#################*********    -***************************.
##################******#+    ************=---+***********=
###################*****#=   -#*********=.     :+**********.
#####################***#-   +*********=         +*********-
######################**#-   *********+          .*********=
#######################*#-  .*********-           +********+
#######################*#=  :#********.           -*********
*######################*#+  :#********            :*********
+########################*  :#********.           -*********
-#########################: .#*******#:           =********+
.#########################+  *#*******+          .*********+
 +%########################. +#*******#-         +*********-
 :%########################+ -#********#-       +**********.
  *#########################: ##********#+-..:=***********+
  .########################## =#*#********#***************:
   =%########################*.*###**********************=
    +%########################+-#####********************.
     *%########################*+#####******************:
      +%###############################****************:
       =################################**************:
        .+%%#############################*********#*=
          :+###############################***###*=.
            .-+*############################**+=-.
</pre>
</center>

# DocuGarden Self-Hosted

Self-host [DocuGarden](https://www.docugarden.com/) with Docker Compose.

DocuGarden is currently in closed beta.
To request any information, email [info@docugarden.com](mailto:info@docugarden.com) or visit [https://www.docugarden.com/](https://www.docugarden.com/).

## Requirements

- Docker Engine 24+
- Docker Compose v2+
- Bash
- curl
- OpenSSL (optional, used by the wizard for secure random values)

## Install Docker

Install Docker Engine and Docker Compose by following the [official Ubuntu guide](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).

After installation, follow the [Docker Linux post-install steps](https://docs.docker.com/engine/install/linux-postinstall/) so you can run `docker` without `sudo`.

## Quick start

```bash
# 1. Create the installation directory
mkdir -p docugarden
cd docugarden

# 2. Download the required files
curl -fsSLO https://raw.githubusercontent.com/docugarden/docugarden-selfhosted/main/docker-compose.yml
curl -fsSLO https://raw.githubusercontent.com/docugarden/docugarden-selfhosted/main/setup-wizard.sh
curl -fsSLO https://raw.githubusercontent.com/docugarden/docugarden-selfhosted/main/Caddyfile
curl -fsSLO https://raw.githubusercontent.com/docugarden/docugarden-selfhosted/main/import-archive.sh
curl -fsSLO https://raw.githubusercontent.com/docugarden/docugarden-selfhosted/main/Makefile

# 3. Make the wizard executable
chmod +x setup-wizard.sh import-archive.sh

# 4. Run the interactive setup wizard
./setup-wizard.sh

# 5. Start DocuGarden
docker compose up -d
```

Open DocuGarden at the URL you configured during setup. Caddy automatically serves it over HTTPS: a real Let's Encrypt certificate for public domains, or a self-signed local certificate for `localhost`/IP addresses (browsers will show a warning you must accept).

## First login

On first access, the application prompts you to create the admin account. Use that screen to set up the initial user and password, and enter the same license key saved by the wizard in `secrets/license-key.txt`.

## License verification

The production backend image has a built-in license-server address and verifier public key. Successful responses must be signed by the DocuGarden license server and bound to the current request. The server's signing private key is never needed on a self-hosted installation.

Only `secrets/license-key.txt` is configurable. There is no license-server URL secret or runtime license-check bypass in the production image. Existing `secrets/license-server-url.txt` files from older installations are unused by the updated image.

The current backend release configuration uses `http://licenseserver.docugarden.cloud:40965`. Allow outbound TCP port 40965 from the backend to that host; do not publish port 40965 on the self-hosted installation. This temporary HTTP connection is unencrypted, even when the self-hosted application's own Caddy serves HTTPS. Signed responses protect response integrity, not request confidentiality.

The application's Caddy ports 80/443 are unrelated to the remote license-server port. A future license-server HTTPS migration requires an updated backend image with the new compiled endpoint, not a local URL setting.

License checks run at backend startup and normally every 4–6 hours. Site usage on the license-server dashboard reflects the last report, not immediate site changes. To trigger a check after changing the license key or testing site usage:

```bash
docker compose up -d --force-recreate backend
docker compose logs --tail=100 backend
```

The key must be valid and authorize this installation. A healthy backend container alone does not confirm a successful license check; inspect the license-check logs for the result. Never share logs containing a license key.

## Database seeding

Instead of creating the first user manually, you can initialize the database from a MongoDB archive. The archive is not included in this repository; obtain it from your DocuGarden representative and save it as `db/docugarden.archive`:

```bash
mkdir -p db
cp /path/to/docugarden.archive db/docugarden.archive
```

Make sure the stack is running, then run:

```bash
# Safe restore: refuses to run if the database contains any collections
make seed

# Force restore, dropping existing collections first (destructive)
make seed-drop

# Or use the helper script directly
./import-archive.sh
./import-archive.sh --drop
```

To use an archive in another location, pass its absolute path:

```bash
ARCHIVE_FILE=/path/to/docugarden.archive make seed
```

## What the wizard creates

- `secrets/` — sensitive credentials (MongoDB, RustFS, JWT, license)
- `.env` — non-secret environment variables (including `DOMAIN` for HTTPS)
- `Caddyfile` — reverse proxy configuration; generated per-server by the wizard. API, API documentation, and upload requests are sent directly to the backend, while all other requests are sent to the frontend. Uses a real Let's Encrypt certificate for public domains and a self-signed local certificate (`tls internal`) for LAN IP addresses when provided.

## Services included

- **Caddy** — reverse proxy with automatic HTTPS on ports 80 and 443
- **Frontend** — internal nginx service
- **Backend** — API on port 4000 internally
- **MongoDB** — document database
- **RustFS** — S3-compatible object storage
- **Gotenberg** — document conversion service

## Configuration

The main options are set during the wizard. To change non-domain settings later:

1. Edit `.env` or the files in `secrets/`.
2. Restart the stack:

```bash
docker compose down
docker compose up -d
```

The generated `.env` values have these roles:

| Variable | Purpose |
| --- | --- |
| `PUBLIC_URL` | Canonical external URL. Compose passes it to the backend as `FRONTEND_URL` for share links, request-origin checks, CORS, and API documentation. |
| `CORS_ORIGIN` | Comma-separated browser origins allowed to call the backend. |
| `TZ` | Backend timezone, including the timezone used by scheduled jobs. |
| `IMAGE_TAG` | Tag used by both DocuGarden application images. |
| `DOMAIN`, `INTERNAL_IP` | Inputs recorded by the wizard when it generates `Caddyfile`; Caddy does not read them dynamically. |

Other backend variables—such as upload limits, bucket name, job concurrency, retention, and password-policy settings—already have production defaults in the DocuGarden source. They do not need to be passed to the container unless you intentionally want to override those defaults. `PUBLIC_API_URL` is also unnecessary when the API and frontend share one public origin.

The production frontend is compiled into its image. Adding `VITE_*` variables to the running frontend container will not change it; those values must be supplied when building the frontend image. The published frontend and this Compose file both use the default 10 MB media-upload limit.

For a public domain, point its DNS A record to this server and make sure ports 80 and 443 are open. Caddy will request a Let's Encrypt certificate automatically.

Changing `DOMAIN`, `PUBLIC_URL`, or `INTERNAL_IP` in `.env` does not rewrite `Caddyfile`. When changing an address, update both `.env` and the corresponding site blocks in `Caddyfile`. Set `CORS_ORIGIN` to every allowed browser origin as a comma-separated list, then recreate the backend and Caddy containers.

For dual access (public domain + LAN IP), run `./setup-wizard.sh` and provide both your public domain and your server's local IP address. The wizard generates a `Caddyfile` with `default_sni` set to the IP (so browsers that omit SNI when connecting to a bare IP still get the right certificate), a real certificate for the domain, and a self-signed certificate for the IP. You can also edit `Caddyfile` manually to add an IP block:

```caddy
192.168.10.22 {
    tls internal
    import docugarden_routes
}
```

## Upgrading

If the existing installation is already running RustFS 1.0.0, a normal upgrade is:

```bash
docker compose pull
docker compose up -d
```

If it is still running RustFS beta.8, do not run the generic upgrade first. Use the migration procedure below. You can check the running image with:

```bash
docker inspect docugarden-rustfs --format '{{.Config.Image}}'
```

### Upgrading RustFS from beta.8 to 1.0.0

RustFS stores uploaded files in the `docugarden_rustfs_data` Docker volume. The 1.0.0 release is a substantial jump from beta.8, so make an offline volume copy before starting the new image.

1. Stop services that read or write object storage:

   ```bash
   docker compose stop backend frontend rustfs
   ```

2. Create a backup volume and copy all RustFS data into it:

   ```bash
   docker volume create docugarden_rustfs_data_beta8_backup
   docker run --rm \
     -v docugarden_rustfs_data:/source:ro \
     -v docugarden_rustfs_data_beta8_backup:/backup \
     alpine:3.22 sh -c 'cd /source && cp -a . /backup/'
   ```

3. Pull and start RustFS 1.0.0, then inspect its health and logs before starting the application:

   ```bash
   docker compose pull rustfs
   docker compose up -d rustfs
   docker compose ps rustfs
   docker compose logs --tail=100 rustfs
   docker compose up -d
   ```

4. Verify uploads, downloads, and document conversion. Keep the backup volume until verification is complete.

To roll back, stop the stack, temporarily change the RustFS image in `docker-compose.yml` from `rustfs/rustfs:1.0.0` to `rustfs/rustfs:1.0.0-beta.8`, replace the changed data volume with the backup copy, and restart:

```bash
docker compose down
docker volume rm docugarden_rustfs_data
docker volume create docugarden_rustfs_data
docker run --rm \
  -v docugarden_rustfs_data_beta8_backup:/source:ro \
  -v docugarden_rustfs_data:/restore \
  alpine:3.22 sh -c 'cd /source && cp -a . /restore/'
docker compose up -d
```

## Troubleshooting

- **Containers stay unhealthy:** check logs with `docker compose logs -f`.
- **License errors:** verify `secrets/license-key.txt`. The production backend uses the built-in DocuGarden license-server endpoint and always enforces license checks.
- **HTTPS does not work on an IP address:** Caddy serves IP addresses with a local self-signed certificate (`tls internal`). Browsers will show a warning you must accept; `curl -vk https://<ip>` can be used to test the TLS handshake. If you changed the Caddyfile or switched from a domain to an IP, run `docker compose down`, remove the `docugarden_caddy_data` volume (`docker volume rm docugarden_caddy_data`), then `docker compose up -d` so Caddy regenerates the certificate.
- **HTTPS does not work on a domain:** ensure ports 80 and 443 are open and the DNS A record for your `DOMAIN` points to this server.

## License

MIT — see [LICENSE](./LICENSE).
