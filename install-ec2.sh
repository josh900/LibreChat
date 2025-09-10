#!/usr/bin/env bash
set -euo pipefail

# ============
# Editable Vars
# ============
DOMAIN="chat4.skoop.digital"
ADMIN_EMAIL="admin1@skoopsignage.com"   # change if desired
REPO_URL="https://github.com/danny-avila/LibreChat.git"
APP_DIR="$HOME/LibreChat"

# ============
# Helpers
# ============
log() { echo -e "\n[+] $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }
upsert_env() {
  # upsert_env KEY VALUE
  local key="$1" val="$2"
  if grep -qE "^${key}=" ".env"; then
    sed -i "s|^${key}=.*|${key}=${val}|" ".env"
  else
    echo "${key}=${val}" >> ".env"
  fi
}

# ============
# Safety: non-root user recommended
# ============
if [ "$EUID" -eq 0 ]; then
  log "Warning: running as root is not recommended. Use a sudo-capable non-root user (e.g., created via 'adduser' + 'usermod -aG sudo'). Proceeding anyway."
fi

# ============
# Preflight
# ============
log "Updating apt and installing prerequisites"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git nano ufw

log "Configuring UFW (22,80,443)"
sudo ufw allow 22 || true
sudo ufw allow 80 || true
sudo ufw allow 443 || true
echo "y" | sudo ufw enable || true

# ============
# Docker (official)
# ============
if ! test -f /usr/share/keyrings/docker-archive-keyring.gpg; then
  log "Adding Docker GPG key"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
fi

if ! test -f /etc/apt/sources.list.d/docker.list; then
  log "Adding Docker apt repo"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

log "Installing Docker Engine and Compose plugin"
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Ensuring Docker is enabled and started"
sudo systemctl enable docker
sudo systemctl start docker

# Ensure docker group exists and ensure best-practice membership before proceeding
if ! getent group docker >/dev/null 2>&1; then
  log "Creating 'docker' group"
  sudo groupadd docker
fi

# If user is not in docker group yet, add and exit to require a re-login/newgrp
if ! id -nG "$USER" | grep -qw docker; then
  log "Adding user '$USER' to 'docker' group (requires re-login/new shell to take effect)"
  sudo usermod -aG docker "$USER"
  echo "\nPlease re-login (log out/in) or run: newgrp docker\nThen re-run: bash install.sh\nExiting now to avoid using sudo fallback."
  exit 0
fi

# Add current user to docker group for convenience
if id -nG "$USER" | grep -qw docker; then
  log "User '$USER' already in docker group"
else
  log "Adding '$USER' to docker group (you may need to re-login later)"
  sudo usermod -aG docker "$USER" || true
fi

# Pick compose command
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif need_cmd docker-compose; then
  COMPOSE_CMD="docker-compose"
else
  # Fallback symlink if needed
  if ! need_cmd docker-compose; then
    sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose || true
  fi
  COMPOSE_CMD="docker-compose"
fi

# Determine if current session can access Docker without sudo; fallback to sudo if not
DOCKER_SUDO=""
if ! docker info >/dev/null 2>&1; then
  DOCKER_SUDO="sudo "
fi

# ============
# Clone LibreChat
# ============
if [ ! -d "$APP_DIR" ]; then
  log "Cloning LibreChat into $APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
else
  log "LibreChat directory already exists at $APP_DIR; pulling latest"
  (cd "$APP_DIR" && git pull)
fi

cd "$APP_DIR"

# ============
# .env setup
# ============
if [ ! -f ".env" ]; then
  log "Creating .env from example"
  cp .env.example .env
fi

log "Generating secure keys for credentials and JWT"
CREDS_KEY="$(openssl rand -hex 32)"          # 32 bytes (64 hex)
CREDS_IV="$(openssl rand -hex 16)"           # 16 bytes (32 hex)
JWT_SECRET="$(openssl rand -hex 32)"
JWT_REFRESH_SECRET="$(openssl rand -hex 32)"
MEILI_MASTER_KEY="$(openssl rand -hex 32)"   # at least 16 bytes, hex-safe

log "Applying required env values"
upsert_env HOST "0.0.0.0"
upsert_env PORT "3080"
upsert_env TRUST_PROXY "1"
upsert_env DOMAIN_CLIENT "https://${DOMAIN}"
upsert_env DOMAIN_SERVER "https://${DOMAIN}"
upsert_env CREDS_KEY "${CREDS_KEY}"
upsert_env CREDS_IV "${CREDS_IV}"
upsert_env JWT_SECRET "${JWT_SECRET}"
upsert_env JWT_REFRESH_SECRET "${JWT_REFRESH_SECRET}"

# Mongo (internal service name 'mongo' below)
upsert_env MONGO_URI "mongodb://mongo:27017/LibreChat"

# Redis (recommended new variables)
upsert_env USE_REDIS "true"
upsert_env REDIS_URI "redis://redis:6379"

# Search (MeiliSearch)
upsert_env SEARCH "true"
upsert_env MEILI_NO_ANALYTICS "true"
upsert_env MEILI_HOST "http://meilisearch:7700"
upsert_env MEILI_MASTER_KEY "${MEILI_MASTER_KEY}"

# Optional: keep site indexable? Default is true (no index). Set to false to allow indexing:
# upsert_env NO_INDEX "false"

# ============
# librechat.yaml (LiteLLM endpoint; auto-fetch models)
# Using directEndpoint: true to fix model fetching with user_provided API keys
# This resolves the issue where models weren't fetched when users provided their own API keys
# ============
log "Writing librechat.yaml (LiteLLM custom endpoint)"
cat > librechat.yaml <<EOF
version: 0.8.0-rc3
cache: true

endpoints:
  custom:
    - name: "LiteLLM"
      apiKey: "user_provided"
      baseURL: "https://litellm.skoop.digital/v1"
      models:
        default: ["gemini/gemini-2.0-flash-lite","openai/gpt-4o"]
        fetch: true
      titleConvo: true
      titleModel: "gemini/gemini-2.0-flash-lite"
      summarize: false
      summaryModel: "gemini/gemini-2.0-flash-lite"
      forcePrompt: false
      modelDisplayLabel: "LiteLLM"
EOF

# ============
# docker-compose.override.yml
# - Ensures proper service wiring for mongo/redis/meilisearch
# - Mounts librechat.yaml into the api container
# - Publishes port 3080 for Nginx on the host
# ============
log "Creating docker-compose.override.yml"
cat > docker-compose.override.yml <<EOF
version: '3.8'

services:
  api:
    environment:
      - HOST=0.0.0.0
      - PORT=3080
      - TRUST_PROXY=1
      - DOMAIN_CLIENT=https://${DOMAIN}
      - DOMAIN_SERVER=https://${DOMAIN}
      - MONGO_URI=mongodb://mongo:27017/LibreChat
      - USE_REDIS=true
      - REDIS_URI=redis://redis:6379
      - SEARCH=true
      - MEILI_HOST=http://meilisearch:7700
      - MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
      - MEILI_NO_ANALYTICS=true
      - CREDS_KEY=${CREDS_KEY}
      - CREDS_IV=${CREDS_IV}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
    ports:
      - "3080:3080"
    depends_on:
      - mongo
      - redis
      - meilisearch
    volumes:
      - type: bind
        source: ./librechat.yaml
        target: /app/librechat.yaml

  mongo:
    image: mongo:7
    restart: unless-stopped
    volumes:
      - mongo_data:/data/db

  redis:
    image: redis:7
    restart: unless-stopped
    volumes:
      - redis_data:/data

  meilisearch:
    image: getmeili/meilisearch:latest
    restart: unless-stopped
    environment:
      - MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
      - MEILI_NO_ANALYTICS=true
    volumes:
      - meili_data:/meili_data
    ports:
      - "7700:7700"

volumes:
  mongo_data:
  redis_data:
  meili_data:
EOF

# ============
# Start LibreChat + dependencies
# ============
log "Starting LibreChat stack (MongoDB, Redis, MeiliSearch, API)"
${DOCKER_SUDO}${COMPOSE_CMD} up -d

# ============
# Nginx + Certbot (HTTPS with auto-renew)
# ============
log "Installing Nginx and Certbot"
sudo apt-get install -y nginx certbot python3-certbot-nginx

NGINX_SITE="/etc/nginx/sites-available/librechat"
NGINX_ENABLED="/etc/nginx/sites-enabled/librechat"

log "Creating Nginx site for ${DOMAIN}"
sudo bash -c "cat > '${NGINX_SITE}'" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    # Optionally redirect http->https once SSL is installed by certbot
    # return 301 https://\$host\$request_uri;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:3080;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

if [ ! -L "$NGINX_ENABLED" ]; then
  sudo ln -s "$NGINX_SITE" "$NGINX_ENABLED"
fi

log "Testing and reloading Nginx"
sudo nginx -t
sudo systemctl reload nginx

log "Requesting Let's Encrypt certificate for ${DOMAIN}"
sudo certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${ADMIN_EMAIL}" --redirect

log "Verifying certbot timers"
sudo systemctl status certbot.timer --no-pager || true

# Optional: post-renew hook to reload nginx (certbot Nginx plugin usually handles reload)
RENEW_HOOK="/etc/letsencrypt/renewal-hooks/post/reload-nginx.sh"
if [ ! -f "$RENEW_HOOK" ]; then
  log "Adding Nginx reload post-renew hook"
  sudo bash -c "cat > '${RENEW_HOOK}'" <<'EOF'
#!/usr/bin/env bash
systemctl reload nginx || true
EOF
  sudo chmod +x "$RENEW_HOOK"
fi

# ============
# Final checks
# ============
log "Containers status:"
${DOCKER_SUDO}${COMPOSE_CMD} ps

log "Done!
- App URL: https://${DOMAIN}
- MeiliSearch (admin): http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP'):7700 (keep private in security groups)
- To manage stack:
    cd ${APP_DIR}
    ${COMPOSE_CMD} ps
    ${COMPOSE_CMD} logs -f api
    ${COMPOSE_CMD} restart api

If you added your user to the docker group, you may need to re-login for 'docker' without sudo."