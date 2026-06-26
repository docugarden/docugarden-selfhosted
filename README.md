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

## Requirements

- Docker Engine 24+
- Docker Compose v2+
- Bash
- OpenSSL (optional, used by the wizard for secure random values)

## Quick start

```bash
# 1. Clone this repository
git clone https://github.com/docugarden/docugarden-selfhosted.git
cd docugarden-selfhosted

# 2. Run the interactive setup wizard
./setup-wizard.sh

# 3. Start DocuGarden
docker compose up -d
```

Open DocuGarden at the URL you configured during setup (default: `http://localhost`) and follow the first-run setup to create the initial admin user.

## First login

On first access, the application prompts you to create the admin account. Use that screen to set up the initial user and password.

## What the wizard creates

- `secrets/` — sensitive credentials (MongoDB, RustFS, JWT, license)
- `.env` — non-secret environment variables

Both are ignored by Git. Keep `secrets/` backed up; losing these files can make your data unrecoverable.

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
