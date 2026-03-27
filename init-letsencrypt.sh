#!/bin/bash

# =============================================================================
# SSL Certificate Setup for docmost.buildnweb.in
# Run this ONCE on first deployment, before docker-compose up
# =============================================================================

set -e

DOMAIN="docmost.buildnweb.in"
EMAIL="varahijourney@gmail.com"  # Your email from Hostinger
COMPOSE_FILE="docker-compose.prod.yml"

echo "=== SSL Setup for $DOMAIN ==="

# Step 1: Create dummy certificate so Nginx can start
echo "[1/4] Creating dummy certificate..."
mkdir -p ./certbot/conf/live/$DOMAIN
docker compose -f $COMPOSE_FILE run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
    -keyout /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    -out /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    -subj '/CN=localhost'" certbot
echo "  Done."

# Step 2: Start Nginx with dummy cert
echo "[2/4] Starting Nginx..."
docker compose -f $COMPOSE_FILE up -d nginx
echo "  Done. Waiting 5s for Nginx to be ready..."
sleep 5

# Step 3: Remove dummy certificate
echo "[3/4] Removing dummy certificate..."
docker compose -f $COMPOSE_FILE run --rm --entrypoint "\
  rm -rf /etc/letsencrypt/live/$DOMAIN && \
  rm -rf /etc/letsencrypt/archive/$DOMAIN && \
  rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf" certbot
echo "  Done."

# Step 4: Request real certificate from Let's Encrypt
echo "[4/4] Requesting real certificate from Let's Encrypt..."
docker compose -f $COMPOSE_FILE run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    --email $EMAIL \
    -d $DOMAIN \
    --rsa-key-size 4096 \
    --agree-tos \
    --no-eff-email \
    --force-renewal" certbot
echo "  Done."

# Step 5: Reload Nginx with real certificate
echo "=== Reloading Nginx with real SSL certificate ==="
docker compose -f $COMPOSE_FILE exec nginx nginx -s reload

echo ""
echo "=== SSL setup complete! ==="
echo "You can now run: docker compose -f $COMPOSE_FILE up -d"
echo "Your site will be live at: https://$DOMAIN"
