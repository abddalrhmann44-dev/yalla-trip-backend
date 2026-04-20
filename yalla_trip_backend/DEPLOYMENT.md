# Talaa API — Production Deployment Guide

This document walks through deploying the Talaa backend to a single
Linux VM using Docker Compose. The same images work on Kubernetes /
ECS / Fly / any other orchestrator — adjust the wrapper around them.

> **Minimum host**: 2 vCPU / 4 GB RAM / 20 GB disk, Ubuntu 22.04+ with
> Docker Engine 24+ and the Compose plugin.

---

## 1 · First-time setup

```bash
# On the server, as a user with sudo + docker access:
git clone git@github.com:talaa/yalla-trip-backend.git
cd yalla-trip-backend

# Populate production secrets (never commit the result).
cp .env.prod.example .env.prod
$EDITOR .env.prod
```

Generate a strong `SECRET_KEY`:

```bash
python3 -c 'import secrets; print(secrets.token_urlsafe(64))'
```

Copy the Firebase service account JSON as a **single escaped line**
into `FIREBASE_CREDENTIALS_JSON`.

---

## 2 · TLS certificates

Nginx expects certs at `deploy/certs/fullchain.pem` +
`deploy/certs/privkey.pem`.

**Option A — Let's Encrypt with `certbot` (recommended)**

```bash
sudo apt install certbot
sudo certbot certonly --standalone -d api.talaa.com
sudo cp /etc/letsencrypt/live/api.talaa.com/fullchain.pem deploy/certs/
sudo cp /etc/letsencrypt/live/api.talaa.com/privkey.pem   deploy/certs/
sudo chmod 644 deploy/certs/*.pem
```

**Option B — self-signed for staging**

```bash
mkdir -p deploy/certs
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout deploy/certs/privkey.pem \
  -out    deploy/certs/fullchain.pem \
  -subj   "/CN=api.talaa.com"
```

---

## 3 · Launch the stack

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod build
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

# Apply database migrations on first deploy (and after every release).
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec api alembic upgrade head
```

Verify:

```bash
curl https://api.talaa.com/health
# → {"status":"healthy", ...}
```

---

## 4 · Day-2 operations

### 4.1 Deploying a new version

```bash
git pull
docker compose -f docker-compose.prod.yml --env-file .env.prod build api
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d api
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec api alembic upgrade head
```

Gunicorn gracefully rolls workers — existing in-flight requests
finish before the old worker exits.

### 4.2 Logs

```bash
# Live tail for one service
docker compose -f docker-compose.prod.yml logs -f api

# Grep across all services for an incident window
docker compose -f docker-compose.prod.yml logs --since=2h | grep ERROR
```

JSON log rotation is configured to 10 MB × 5 files per container.

### 4.3 Database backups

A nightly cron on the host keeps the last 14 days of dumps:

```cron
# /etc/cron.d/talaa-pg-backup
0 3 * * * root \
  docker compose -f /opt/talaa/docker-compose.prod.yml --env-file /opt/talaa/.env.prod \
  exec -T db pg_dump -U talaa talaa \
  | gzip > /opt/talaa/deploy/pg_backups/talaa_$(date +\%Y\%m\%d).sql.gz \
  && find /opt/talaa/deploy/pg_backups -name 'talaa_*.sql.gz' -mtime +14 -delete
```

Restore with:

```bash
gunzip -c deploy/pg_backups/talaa_20260419.sql.gz | \
  docker compose -f docker-compose.prod.yml exec -T db psql -U talaa talaa
```

### 4.4 Cert renewal

`certbot renew` on the host, then bounce Nginx:

```bash
sudo certbot renew --deploy-hook \
  "cp /etc/letsencrypt/live/api.talaa.com/*.pem /opt/talaa/deploy/certs/ \
   && docker compose -f /opt/talaa/docker-compose.prod.yml restart nginx"
```

---

## 5 · Observability

* **Sentry** – set `SENTRY_DSN` in `.env.prod` and deploy. Releases
  are tagged with `SENTRY_RELEASE` so regressions are traceable to a
  specific commit.
* **Prometheus** – scrape `/health` for dependency status; `/docs`
  exposes the full OpenAPI schema.
* **Structured logs** – every request is logged as JSON with a
  `request_id`. Pipe into Loki / Elasticsearch for search.

---

## 6 · Rollback

```bash
# Roll back to a previous image tag (assuming you pushed to a registry):
docker tag talaa-api:1.0.0 talaa-api:latest
docker compose -f docker-compose.prod.yml up -d api

# If a migration is the culprit, revert schema too:
docker compose -f docker-compose.prod.yml \
  exec api alembic downgrade -1
```

---

## 7 · Security checklist

- [ ] `.env.prod` is `chmod 600` and **not** in git.
- [ ] `SECRET_KEY` is 64 URL-safe random bytes.
- [ ] Postgres password rotated from the default.
- [ ] Firewall allows inbound **only** on 80/443 (SSH on a custom
      port ideally gated via fail2ban / ssh keys).
- [ ] Admin emails in `ADMIN_EMAILS` are minimal and monitored.
- [ ] Cloudflare / CDN fronting `api.talaa.com` to absorb L7 floods.
- [ ] Paymob webhook URL set to `https://api.talaa.com/payments/paymob/webhook`.
- [ ] Sentry project alerts wired to PagerDuty / Slack.
- [ ] Daily pg_dump backups verified monthly via a test restore.

---

## 8 · Scaling beyond one box

When traffic outgrows a single VM:

1. Move **Postgres** to a managed service (AWS RDS, GCP Cloud SQL).
2. Move **Redis** to a managed cache (ElastiCache, Upstash).
3. Keep the `api` image unchanged — it's stateless. Deploy N copies
   behind a load balancer (AWS ALB, Cloud Run, K8s Deployment).
4. S3 already handles media; no changes needed.
5. Point Nginx / the load-balancer's `X-Forwarded-For` at the API;
   the refresh-token session tracker will record real client IPs.
