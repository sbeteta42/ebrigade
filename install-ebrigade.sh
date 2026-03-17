#!/usr/bin/env bash
set -euo pipefail

# eBrigade auto-install (Debian 11) - default domain: formation.lan
# + Self-signed SSL auto + HTTP -> HTTPS redirect
# par ShadowHacker (sbeteta@beteta.org)
# Usage:
#   sudo ./install-ebrigade.sh --zip /root/ebrigade-5.3.2.zip
#   sudo ./install-ebrigade.sh --zip ./ebrigade-5.3.2.zip --domain autre.formation.lan

log()  { echo -e "\e[32m[+]\e[0m $*"; }
warn() { echo -e "\e[33m[!]\e[0m $*"; }
err()  { echo -e "\e[31m[x]\e[0m $*" >&2; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Lance ce script en root : sudo $0 ..."
    exit 1
  fi
}

check_debian11() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "debian" ]]; then
      warn "OS détecté: ${ID:-unknown}. Ce script fonctionne avec Debian 11."
    fi
    if [[ "${VERSION_ID:-}" != "11" ]]; then
      warn "VERSION_ID détecté: ${VERSION_ID:-unknown}. Idéalement Debian 11 (Bullseye)."
    fi
  fi
}

rand_pass() {
  openssl rand -base64 24 | tr -d '\n'
}

usage() {
  cat <<EOF
Usage: sudo $0 --zip /chemin/ebrigade-5.3.2.zip [options]

Options:
  --zip PATH            Chemin vers ebrigade-5.3.2.zip (obligatoire)
  --domain NAME         Nom DNS / ServerName Apache (défaut: formation.lan)
  --install-dir PATH    Dossier web (défaut: /var/www/ebrigade)
  --db-name NAME        Nom base MariaDB (défaut: ebrigade)
  --db-user NAME        User MariaDB (défaut: ebrigade)
  --db-pass PASS        Mot de passe MariaDB (défaut: operations)
  --no-disable-default  Ne désactive pas le site Apache 000-default
  --help                Affiche l'aide

Exemple:
  sudo $0 --zip /root/ebrigade-5.3.2.zip
EOF
}

ZIP_PATH=""
DOMAIN="formation.lan"
INSTALL_DIR="/var/www/ebrigade"
DB_NAME="ebrigade"
DB_USER="ebrigade"
DB_PASS="operations"
DISABLE_DEFAULT=1

CERT_DIR="/etc/ssl/localcerts"
CERT_CRT=""
CERT_KEY=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --zip) ZIP_PATH="${2:-}"; shift 2;;
      --domain) DOMAIN="${2:-}"; shift 2;;
      --install-dir) INSTALL_DIR="${2:-}"; shift 2;;
      --db-name) DB_NAME="${2:-}"; shift 2;;
      --db-user) DB_USER="${2:-}"; shift 2;;
      --db-pass) DB_PASS="${2:-}"; shift 2;;
      --no-disable-default) DISABLE_DEFAULT=0; shift 1;;
      --help|-h) usage; exit 0;;
      *) err "Option inconnue: $1"; usage; exit 1;;
    esac
  done

  if [[ -z "$ZIP_PATH" ]]; then
    err "--zip est obligatoire."
    usage
    exit 1
  fi

  if [[ ! -f "$ZIP_PATH" ]]; then
    err "ZIP introuvable: $ZIP_PATH"
    exit 1
  fi

  if [[ -z "$DB_PASS" ]]; then
    DB_PASS="$(rand_pass)"
    warn "DB_PASS non fourni -> génération automatique."
  fi

  CERT_CRT="${CERT_DIR}/${DOMAIN}.crt"
  CERT_KEY="/etc/ssl/private/${DOMAIN}.key"
}

apt_install_stack() {
  log "[1] - Mise à jour APT + installation Apache/MariaDB/PHP7.4..."
  apt update -y
  apt upgrade -y

  apt install -y \
    unzip rsync curl ca-certificates openssl lsb-release apt-transport-https

  apt install -y \
    apache2 mariadb-server mariadb-client

  apt install -y \
    php7.4 libapache2-mod-php7.4 \
    php7.4-mysql php7.4-xml php7.4-gd php7.4-curl php7.4-zip php7.4-mbstring \
    php7.4-intl php7.4-soap php7.4-bcmath php7.4-cli php7.4-common

  systemctl enable --now apache2 mariadb

  log "[2] - Activation modules Apache (rewrite/headers/ssl)..."
  a2enmod rewrite headers ssl >/dev/null
  systemctl restart apache2
}

db_setup() {
  log "[3] - Création DB + user MariaDB..."
  mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
}

deploy_app() {
  log "[4] - Déploiement eBrigade dans ${INSTALL_DIR}..."
  mkdir -p "$INSTALL_DIR"

  local tmpdir
  tmpdir="$(mktemp -d)"
  unzip -q "$ZIP_PATH" -d "$tmpdir"

  local top_count
  top_count="$(find "$tmpdir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"

  local src="$tmpdir"
  if [[ "$top_count" -eq 1 ]]; then
    local only_item
    only_item="$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
    if [[ -n "$only_item" ]]; then
      src="$only_item"
    fi
  fi

  rsync -a --delete "${src}/" "${INSTALL_DIR}/"

  chown -R www-data:www-data "$INSTALL_DIR"
  find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
  find "$INSTALL_DIR" -type f -exec chmod 644 {} \;

  rm -rf "$tmpdir"
}

generate_self_signed_ssl() {
  log "[5] - Génération certificat self-signed pour ${DOMAIN} (si absent)..."
  mkdir -p "$CERT_DIR"
  chmod 755 "$CERT_DIR"

  if [[ -f "$CERT_CRT" && -f "$CERT_KEY" ]]; then
    log "Certificat déjà présent: ${CERT_CRT}"
    return
  fi

  # Clé privée dans /etc/ssl/private (droits stricts)
  mkdir -p /etc/ssl/private
  chmod 710 /etc/ssl/private

  # Cert self-signed avec SAN DNS:${DOMAIN}
  openssl req -x509 -nodes -newkey rsa:2048 \
    -days 825 \
    -keyout "$CERT_KEY" \
    -out "$CERT_CRT" \
    -subj "/C=FR/ST=GrandEst/L=Strasbourg/O=formation.lan/OU=IT/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN}"

  chown root:root "$CERT_KEY" "$CERT_CRT"
  chmod 600 "$CERT_KEY"
  chmod 644 "$CERT_CRT"
}

apache_vhost_ssl() {
  log "Création vhosts Apache HTTP->HTTPS + SSL pour ${DOMAIN}..."
  local vhost="/etc/apache2/sites-available/ebrigade.conf"

  cat > "$vhost" <<EOF
# eBrigade - HTTP -> HTTPS
<VirtualHost *:80>
    ServerName ${DOMAIN}
    Redirect permanent / https://${DOMAIN}/

    ErrorLog \${APACHE_LOG_DIR}/ebrigade_error.log
    CustomLog \${APACHE_LOG_DIR}/ebrigade_access.log combined
</VirtualHost>

# eBrigade - HTTPS (self-signed)
<VirtualHost *:443>
    ServerName ${DOMAIN}
    ServerAdmin webmaster@localhost

    DocumentRoot ${INSTALL_DIR}

    <Directory ${INSTALL_DIR}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile ${CERT_CRT}
    SSLCertificateKeyFile ${CERT_KEY}

    # Logs dédiés SSL
    ErrorLog \${APACHE_LOG_DIR}/ebrigade_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ebrigade_ssl_access.log combined
</VirtualHost>
EOF

  if [[ "$DISABLE_DEFAULT" -eq 1 ]]; then
    a2dissite 000-default.conf >/dev/null || true
    a2dissite default-ssl.conf >/dev/null || true
  fi

  a2ensite ebrigade.conf >/dev/null
  apache2ctl configtest
  systemctl reload apache2
}

php_tuning() {
  log "Ajustement PHP (limites upload / timezone)..."
  local ini="/etc/php/7.4/apache2/php.ini"

  sed -i 's/^memory_limit\s*=.*/memory_limit = 256M/' "$ini" || true
  sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 32M/' "$ini" || true
  sed -i 's/^post_max_size\s*=.*/post_max_size = 32M/' "$ini" || true
  sed -i 's/^max_execution_time\s*=.*/max_execution_time = 120/' "$ini" || true

  if grep -qE '^\s*;?\s*date\.timezone\s*=' "$ini"; then
    sed -i 's#^\s*;*\s*date\.timezone\s*=.*#date.timezone = Europe/Paris#' "$ini"
  else
    echo "date.timezone = Europe/Paris" >> "$ini"
  fi

  systemctl restart apache2
}

final_info() {
  echo
  log "Installation terminée."
  echo "------------------------------------------------------------"
  echo "URL (HTTPS) : https://${DOMAIN}/"
  echo "URL (HTTP)  : http://${DOMAIN}/   (redirige vers HTTPS)"
  echo "Dossier web : ${INSTALL_DIR}"
  echo "DB_NAME : ${DB_NAME}"
  echo "DB_USER : ${DB_USER}"
  echo "DB_PASS : ${DB_PASS}"
  echo "Cert CRT : ${CERT_CRT}"
  echo "Cert KEY : ${CERT_KEY}"
  echo "Logs Apache SSL : /var/log/apache2/ebrigade_ssl_error.log"
  echo "------------------------------------------------------------"
  warn "Étape restante : config eBrigade (wizard web ou fichier config)."
  warn "Avec un self-signed, le navigateur affichera un avertissement tant que le cert n'est pas 'trusté' côté client."
}

main() {
  need_root
  check_debian11
  parse_args "$@"

  apt_install_stack
  db_setup
  deploy_app
  generate_self_signed_ssl
  apache_vhost_ssl
  php_tuning
  final_info
}

main "$@"
