#!/usr/bin/env bash
set -euo pipefail

CONF="/www/server/panel/vhost/nginx/0.default.conf"
PATH_PREFIX="/slam-ai"
REMOTE_PORT="18766"
NGINX_BIN="/www/server/nginx/sbin/nginx"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --conf)
      CONF="${2:-}"
      shift 2
      ;;
    --path-prefix)
      PATH_PREFIX="${2:-/slam-ai}"
      shift 2
      ;;
    --remote-port)
      REMOTE_PORT="${2:-18766}"
      shift 2
      ;;
    --nginx-bin)
      NGINX_BIN="${2:-/www/server/nginx/sbin/nginx}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if [[ -z "$CONF" || ! -f "$CONF" ]]; then
  echo "Nginx site config not found: $CONF" >&2
  exit 1
fi

if [[ ! -x "$NGINX_BIN" ]]; then
  NGINX_BIN="$(command -v nginx || true)"
fi
if [[ -z "$NGINX_BIN" || ! -x "$NGINX_BIN" ]]; then
  echo "nginx binary not found." >&2
  exit 1
fi

python3 - "$CONF" "$PATH_PREFIX" "$REMOTE_PORT" <<'PY'
import shutil
import sys
from datetime import datetime
from pathlib import Path

conf = Path(sys.argv[1])
prefix = sys.argv[2].strip() or "/slam-ai"
remote_port = sys.argv[3].strip() or "18766"

if not prefix.startswith("/"):
    prefix = "/" + prefix
prefix = prefix.rstrip("/")

text = conf.read_text(encoding="utf-8", errors="replace")
if f"location {prefix}/" in text:
    print(f"path proxy already present: {prefix}/")
    raise SystemExit(0)

marker = "    location / {\n"
if marker not in text:
    raise SystemExit(f"marker not found in {conf}: {marker!r}")

backup = conf.with_name(f"{conf.name}.bak-slam-ai-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}")
shutil.copy2(conf, backup)

block = f"""    location = {prefix} {{
        return 301 {prefix}/;
    }}

    location {prefix}/ {{
        proxy_pass http://127.0.0.1:{remote_port}/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }}

"""

conf.write_text(text.replace(marker, block + marker, 1), encoding="utf-8")
print(f"backup={backup}")
print(f"path_proxy={prefix}/")
PY

"$NGINX_BIN" -t
"$NGINX_BIN" -s reload
echo "slam-ai path proxy ready"
