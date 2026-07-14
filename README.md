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

# Docugarden Self-Hosted

Self-host [Docugarden](https://www.Docugarden.com/) with Docker Compose.

Docugarden is currently in closed beta.
To request any information, email [info@Docugarden.com](mailto:info@Docugarden.com) or visit [https://www.Docugarden.com/](https://www.Docugarden.com/).

## Requirements

- Docker Engine 24+
- Docker Compose v2+
- Bash
- curl
- OpenSSL (optional, used by the wizard for secure random values)

## Install Docker

Install Docker Engine and Docker Compose by following the [official Ubuntu guide](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).

## Quick start

```bash
# 1. Create the installation directory
mkdir -p Docugarden
cd Docugarden

# 2. Download the required files
curl -O https://raw.githubusercontent.com/Docugarden/Docugarden-selfhosted/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/Docugarden/Docugarden-selfhosted/main/setup-wizard.sh

# 3. Make the wizard executable
chmod +x setup-wizard.sh

# 4. Run the interactive setup wizard
./setup-wizard.sh

# 5. Start Docugarden
docker compose up -d
```

Open Docugarden at the URL you configured during setup (default: `http://localhost`) and follow the first-run setup to create the initial admin user.

## First login

On first access, the application prompts you to create the admin account. Use that screen to set up the initial user and password.

## What the wizard creates

- `secrets/` — sensitive credentials (MongoDB, RustFS, JWT, license)
- `.env` — non-secret environment variables

Keep `secrets/` backed up; losing these files can make your data unrecoverable.

## Services included

- **Frontend** — served on the port configured in `.env` (default 80)
- **Backend** — API on port 4000 internally
- **MongoDB** — document database
- **RustFS** — S3-compatible object storage
- **Gotenberg** — document conversion service

## Configuration

The main options are set during the wizard. To change them later:

1. Edit `.env` or the files in `secrets/`.
2. Restart the stack:

```bash
docker compose down
docker compose up -d
```

## Upgrading

```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

- **Port 80 is already in use:** set a different `FRONTEND_PORT` in `.env`.
- **Containers stay unhealthy:** check logs with `docker compose logs -f`.
- **License errors:** verify `secrets/license-key.txt` and `secrets/license-server-url.txt`.

## License

MIT — see [LICENSE](./LICENSE).
