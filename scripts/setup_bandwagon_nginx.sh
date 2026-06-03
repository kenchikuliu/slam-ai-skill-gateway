#!/usr/bin/env bash
set -euo pipefail

DOMAIN=""
EMAIL=""
SERVER_NAME="_"
REMOTE_PORT="18766"
ENABLE_LETSENCRYPT="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --email)
      EMAIL="${2:-}"
      shift 2
      ;;
    --remote-port)
      REMOTE_PORT="${2:-18766}"
      shift 2
      ;;
    --letsencrypt)
      ENABLE_LETSENCRYPT="1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "$DOMAIN" ]]; then
  SERVER_NAME="$DOMAIN"
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y nginx curl
  if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
    apt-get install -y certbot python3-certbot-nginx
  fi
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y nginx curl
  if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
    dnf install -y certbot python3-certbot-nginx || true
  fi
elif command -v yum >/dev/null 2>&1; then
  yum install -y nginx curl
  if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
    yum install -y certbot python3-certbot-nginx || true
  fi
else
  echo "Unsupported Linux distribution: missing apt-get/dnf/yum." >&2
  exit 1
fi

mkdir -p /etc/nginx/conf.d
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

cat >/etc/nginx/conf.d/slam-ai-gateway.conf <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${SERVER_NAME};

    client_max_body_size 8m;

    location / {
        proxy_pass http://127.0.0.1:${REMOTE_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}
NGINX

nginx -t

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable nginx
  systemctl restart nginx
else
  service nginx restart
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp || true
  if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
    ufw allow 443/tcp || true
  fi
fi

if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=http || true
  if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
    firewall-cmd --permanent --add-service=https || true
  fi
  firewall-cmd --reload || true
fi

if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
  if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    echo "--letsencrypt requires --domain and --email." >&2
    exit 2
  fi
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
fi

echo "slam-ai nginx proxy ready"
echo "public_http=http://${DOMAIN:-<VPS_IP>}"
if [[ "$ENABLE_LETSENCRYPT" == "1" ]]; then
  echo "public_https=https://${DOMAIN}"
fi
echo "upstream=http://127.0.0.1:${REMOTE_PORT}"
