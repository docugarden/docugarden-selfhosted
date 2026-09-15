#!/usr/bin/env bash
set -euo pipefail

# DocuGarden Self-Hosted Setup Wizard
# Generates secrets and environment files for a self-hosted deployment.

# ---------- colors & formatting ----------
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# ---------- resolve output directory (current working directory) ----------
OUTPUT_DIR="$(pwd)"
SECRETS_DIR="$OUTPUT_DIR/secrets"
ENV_FILE="$OUTPUT_DIR/.env"
CADDYFILE="$OUTPUT_DIR/Caddyfile"

# ---------- helpers ----------
die() { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

trim() {
  local s="$*"
  echo "$s" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

print_step() {
  echo -e "\n${BOLD}${CYAN}[$1]${RESET} ${BOLD}$2${RESET}"
}

prompt_required() {
  local label="$1" hint="${2:-}" var
  while true; do
    if [[ -n "$hint" ]]; then
      read -r -p "    $label ($hint): " var || exit 1
    else
      read -r -p "    $label: " var || exit 1
    fi
    var="$(trim "$var")"
    [[ -n "$var" ]] && { echo "$var"; return 0; }
    echo -e "    ${YELLOW}↳ Required field. Please enter a value.${RESET}"
  done
}

prompt_with_default() {
  local label="$1" default="$2" var
  read -r -p "    $label [${default}]: " var || exit 1
  var="$(trim "$var")"
  [[ -z "$var" ]] && var="$default"
  echo "$var"
}

prompt_yes_no() {
  local label="$1" default="$2" v
  local hint="y/n"
  [[ "$default" == "yes" ]] && hint="Y/n" || hint="y/N"
  while true; do
    read -r -p "    $label [$hint]: " v || exit 1
    v="$(trim "$v")"
    [[ -z "$v" ]] && v="$default"
    v="$(echo "$v" | tr '[:upper:]' '[:lower:]')"
    case "$v" in
      y|yes) echo "yes"; return 0 ;;
      n|no)  echo "no"; return 0 ;;
      *) echo -e "    ${YELLOW}↳ Please enter 'yes' or 'no'.${RESET}" ;;
    esac
  done
}

prompt_secret_hidden() {
  local label="$1" var
  while true; do
    read -r -s -p "    $label: " var || exit 1
    echo
    var="${var//$'\n'/}"
    var="${var//$'\r'/}"
    var="$(trim "$var")"
    [[ -n "$var" ]] && { echo "$var"; return 0; }
    echo -e "    ${YELLOW}↳ Required field. Please enter a value.${RESET}"
  done
}

gen_rand_hex() {
  local nbytes="$1"
  if have openssl; then
    openssl rand -hex "$nbytes"
  else
    head -c "$nbytes" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

gen_rand_base64() {
  local nbytes="$1"
  if have openssl; then
    openssl rand -base64 "$nbytes" | tr -d '\n'
  else
    head -c "$nbytes" /dev/urandom | base64 | tr -d '\n'
  fi
}

write_secret_file() {
  local filepath="$1" content="$2"
  printf '%s' "$content" > "$filepath"
  chmod 644 "$filepath"
}

# ---------- intro ----------
clear 2>/dev/null || true
cat <<'BANNER'

  ╔╦╗┌─┐┌─┐┬ ┬╔═╗┌─┐┬─┐┌┬┐┌─┐┌┐┌
   ║║│ ││  │ │║ ╦├─┤├┬┘ ││├┤ │││
  ═╩╝└─┘└─┘└─┘╚═╝┴ ┴┴└──┴┘└─┘┘└┘
  Self-Hosted Setup Wizard

BANNER

echo -e "${DIM}This wizard will generate secrets and environment files${RESET}"
echo -e "${DIM}for your self-hosted DocuGarden deployment.${RESET}"

# ---------- check for existing files ----------
if [[ -d "$SECRETS_DIR" ]] && ls "$SECRETS_DIR"/*.txt >/dev/null 2>&1; then
  echo
  c="$(prompt_yes_no "Secret files already exist in secrets/. Overwrite?" "no")"
  [[ "$c" == "yes" ]] || die "Cancelled. Existing secrets preserved."
fi

if [[ -e "$ENV_FILE" ]]; then
  echo
  c="$(prompt_yes_no ".env already exists. Overwrite?" "no")"
  [[ "$c" == "yes" ]] || die "Cancelled. Existing .env preserved."
fi

# ================================================================
# Step 1: Public Domain
# ================================================================
print_step "1/5" "Public Domain"
echo -e "    ${DIM}Configure the domain where DocuGarden will be reachable.${RESET}"
echo -e "    ${DIM}Enter the domain or IP only — HTTPS is configured automatically.${RESET}"
echo

DOMAIN="$(prompt_with_default "Public domain or IP" "localhost")"
DOMAIN="$(echo "$DOMAIN" | sed -E 's|https?://||' | sed -E 's|/.*||')"
PUBLIC_URL="https://${DOMAIN}"

TZ="$(prompt_with_default "Timezone" "Etc/UTC")"

# Optional internal IP for LAN access. If provided, Caddy will serve a
# self-signed certificate for the IP while the public domain uses Let's Encrypt.
INTERNAL_IP="$(prompt_with_default "Internal LAN IP (optional, e.g. 192.168.1.10)" "")"
INTERNAL_IP="$(echo "$INTERNAL_IP" | sed -E 's|https?://||' | sed -E 's|/.*||')"

# For bare IP addresses, Caddy must use its internal CA (self-signed cert).
# Let's Encrypt does not issue certificates for IP addresses.
if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  DOMAIN_IS_IP="yes"
else
  DOMAIN_IS_IP="no"
fi

# When HTTPS is accessed by bare IP, browsers may not send SNI.
# default_sni tells Caddy which certificate to serve in that case.
if [[ "$DOMAIN_IS_IP" == "yes" ]]; then
  DEFAULT_SNI="$DOMAIN"
elif [[ -n "$INTERNAL_IP" ]]; then
  DEFAULT_SNI="$INTERNAL_IP"
else
  DEFAULT_SNI=""
fi

echo -e "\n    ${GREEN}✓${RESET} URL: ${BOLD}${PUBLIC_URL}${RESET}"
echo -e "    ${GREEN}✓${RESET} Domain: ${BOLD}${DOMAIN}${RESET}"
[[ -n "$INTERNAL_IP" ]] && echo -e "    ${GREEN}✓${RESET} Internal IP: ${BOLD}${INTERNAL_IP}${RESET}"
echo -e "    ${GREEN}✓${RESET} Timezone: ${BOLD}${TZ}${RESET}"

# ================================================================
# Step 2: MongoDB Credentials
# ================================================================
print_step "2/5" "MongoDB Credentials"
echo -e "    ${DIM}Configure the MongoDB admin user and database.${RESET}"
echo

MONGO_USERNAME="$(prompt_with_default "Admin username" "admin")"
MONGO_DATABASE="$(prompt_with_default "Database name" "docugarden")"

echo
USE_AUTO_PASSWORD="$(prompt_yes_no "Auto-generate a secure MongoDB password?" "yes")"

if [[ "$USE_AUTO_PASSWORD" == "yes" ]]; then
  MONGO_PASSWORD="$(gen_rand_hex 16)"
  echo -e "    ${GREEN}✓${RESET} Password auto-generated (will be saved to secrets/)"
else
  MONGO_PASSWORD="$(prompt_secret_hidden "MongoDB password")"
fi

echo -e "\n    ${GREEN}✓${RESET} Username: ${BOLD}${MONGO_USERNAME}${RESET}"
echo -e "    ${GREEN}✓${RESET} Database: ${BOLD}${MONGO_DATABASE}${RESET}"

# ================================================================
# Step 3: RustFS (S3) Credentials
# ================================================================
print_step "3/5" "RustFS (S3) Credentials"
echo -e "    ${DIM}Configure the RustFS object storage credentials.${RESET}"
echo

RUSTFS_ACCESS_KEY="$(prompt_with_default "RustFS access key" "docugarden-app")"

echo
USE_AUTO_RUSTFS_SECRET="$(prompt_yes_no "Auto-generate a secure RustFS secret key?" "yes")"

if [[ "$USE_AUTO_RUSTFS_SECRET" == "yes" ]]; then
  RUSTFS_SECRET_KEY="$(gen_rand_hex 16)"
  echo -e "    ${GREEN}✓${RESET} Secret key auto-generated (will be saved to secrets/)"
else
  RUSTFS_SECRET_KEY="$(prompt_secret_hidden "RustFS secret key")"
fi

echo -e "\n    ${GREEN}✓${RESET} Access key: ${BOLD}${RUSTFS_ACCESS_KEY}${RESET}"

# ================================================================
# Step 4: Application Secrets
# ================================================================
print_step "4/5" "Application Secrets"
echo -e "    ${DIM}Generating cryptographic keys for JWT, encryption, and signing.${RESET}"
echo

JWT_SECRET="$(gen_rand_hex 64)"
echo -e "    ${GREEN}✓${RESET} JWT secret generated ${DIM}(128-char hex)${RESET}"

MONGODB_ENCRYPTION_KEY="$(gen_rand_base64 32)"
echo -e "    ${GREEN}✓${RESET} MongoDB encryption key generated ${DIM}(32-byte base64)${RESET}"

MONGODB_SIGNING_KEY="$(gen_rand_base64 64)"
echo -e "    ${GREEN}✓${RESET} MongoDB signing key generated ${DIM}(64-byte base64)${RESET}"

# ================================================================
# Step 5: License & Image Tag
# ================================================================
print_step "5/5" "License & Image Tag"
echo -e "    ${DIM}Enter your DocuGarden license and choose the image tag to run.${RESET}"
echo -e "    ${DIM}The license-server address is built into the production backend image.${RESET}"
echo -e "    ${DIM}Use this same license key when creating the initial admin user.${RESET}"
echo

LICENSE_KEY="$(prompt_secret_hidden "License key")"

echo

IMAGE_TAG="$(prompt_with_default "Image tag" "latest")"

echo -e "\n    ${GREEN}✓${RESET} Images: ${BOLD}docugarden/docugarden-*:${IMAGE_TAG}${RESET}"

# ================================================================
# Write secrets files
# ================================================================
echo -e "\n${DIM}Writing secret files...${RESET}"

mkdir -p "$SECRETS_DIR"
umask 077

write_secret_file "$SECRETS_DIR/mongodb-username.txt" "$MONGO_USERNAME"
write_secret_file "$SECRETS_DIR/mongodb-password.txt" "$MONGO_PASSWORD"
write_secret_file "$SECRETS_DIR/mongodb-database.txt" "$MONGO_DATABASE"
write_secret_file "$SECRETS_DIR/jwt-secret.txt" "$JWT_SECRET"
write_secret_file "$SECRETS_DIR/mongodb-encryption-key.txt" "$MONGODB_ENCRYPTION_KEY"
write_secret_file "$SECRETS_DIR/mongodb-signing-key.txt" "$MONGODB_SIGNING_KEY"
write_secret_file "$SECRETS_DIR/rustfs-access-key.txt" "$RUSTFS_ACCESS_KEY"
write_secret_file "$SECRETS_DIR/rustfs-secret-key.txt" "$RUSTFS_SECRET_KEY"
write_secret_file "$SECRETS_DIR/license-key.txt" "$LICENSE_KEY"

echo -e "    ${GREEN}✓${RESET} 9 secret files written to ${BOLD}secrets/${RESET}"

# ================================================================
# Write .env
# ================================================================
echo -e "${DIM}Writing .env...${RESET}"

cat > "$ENV_FILE" <<EOF
# DocuGarden Self-Hosted Environment
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# ── Public URL ────────────────────────────────────────
PUBLIC_URL=${PUBLIC_URL}
DOMAIN=${DOMAIN}
INTERNAL_IP=${INTERNAL_IP}
TZ=${TZ}

# ── Docker Images ─────────────────────────────────────
# Images are always pulled from Docker Hub (docugarden/*).
IMAGE_TAG=${IMAGE_TAG}

# ── CORS ──────────────────────────────────────────────
# Origin allowed to call the backend. Defaults to empty (same-origin).
CORS_ORIGIN=${PUBLIC_URL}
EOF

chmod 600 "$ENV_FILE"

echo -e "    ${GREEN}✓${RESET} Environment file written to ${BOLD}.env${RESET}"

# ================================================================
# Write Caddyfile
# ================================================================
echo -e "${DIM}Writing Caddyfile...${RESET}"

> "$CADDYFILE"
if [[ -n "$DEFAULT_SNI" ]]; then
  cat >> "$CADDYFILE" <<EOF
{
    default_sni $DEFAULT_SNI
    servers {
        protocols h1 h2
    }
}

EOF
else
  cat >> "$CADDYFILE" <<EOF
{
    servers {
        protocols h1 h2
    }
}

EOF
fi

cat >> "$CADDYFILE" <<'EOF'
(docugarden_routes) {
    handle /api/* {
        reverse_proxy backend:4000
    }

    handle /api-docs* {
        reverse_proxy backend:4000
    }

    handle /uploads/* {
        reverse_proxy backend:4000
    }

    handle {
        reverse_proxy frontend:80
    }
}

EOF

if [[ -n "$INTERNAL_IP" && "$INTERNAL_IP" != "$DOMAIN" ]]; then
  cat >> "$CADDYFILE" <<EOF
$INTERNAL_IP {
    tls internal
    import docugarden_routes
}

EOF
fi

if [[ "$DOMAIN_IS_IP" == "yes" ]]; then
  cat >> "$CADDYFILE" <<EOF
$DOMAIN {
    tls internal
    import docugarden_routes
}
EOF
else
  cat >> "$CADDYFILE" <<EOF
$DOMAIN {
    import docugarden_routes
}
EOF
fi

echo -e "    ${GREEN}✓${RESET} Caddyfile written to ${BOLD}Caddyfile${RESET}"

# ================================================================
# Summary
# ================================================================
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✓${RESET} ${BOLD}Done!${RESET} DocuGarden self-hosted environment has been configured."
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo -e "  ${BOLD}Generated files:${RESET}"
echo -e "    secrets/mongodb-username.txt"
echo -e "    secrets/mongodb-password.txt"
echo -e "    secrets/mongodb-database.txt"
echo -e "    secrets/jwt-secret.txt"
echo -e "    secrets/mongodb-encryption-key.txt"
echo -e "    secrets/mongodb-signing-key.txt"
echo -e "    secrets/rustfs-access-key.txt"
echo -e "    secrets/rustfs-secret-key.txt"
echo -e "    secrets/license-key.txt"
echo -e "    .env"
echo -e "    Caddyfile"
echo
echo -e "  ${BOLD}URL:${RESET}   ${PUBLIC_URL}"
[[ -n "$INTERNAL_IP" ]] && echo -e "  ${BOLD}LAN:${RESET}   https://${INTERNAL_IP} (self-signed certificate; accept the browser warning)"
echo
echo -e "  ${YELLOW}Next steps:${RESET}"
echo -e "    1. Review the generated files and adjust any values as needed"
echo -e "    2. Start DocuGarden:"
echo -e "       ${DIM}docker compose up -d${RESET}"
echo -e "    3. Verify all services are healthy:"
echo -e "       ${DIM}docker compose ps${RESET}"
echo -e "    4. Open DocuGarden in your browser and create the initial admin user"
echo -e "       ${DIM}Enter the same license key saved in secrets/license-key.txt${RESET}"
echo
echo -e "  ${YELLOW}⚠ Important:${RESET}"
echo -e "    The secrets/ directory contains sensitive credentials."
echo -e "    Ensure it is never committed to version control."
echo -e "    Back up these files securely — losing them may require"
echo -e "    recreating your database and re-encrypting data."
echo
