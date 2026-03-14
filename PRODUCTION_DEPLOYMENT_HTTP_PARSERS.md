# Production Deployment Guide

**Deployment TrackerDelivery на Hetzner ARM64 сервер**

---

## Pre-Deployment Checklist

### Grab Parser
- [x] `GrabApiParserService` создан (`app/services/`)
- [x] `grab_cookies.json` с валидным JWT
- [x] `GrabJwtRefreshJob` настроен (каждые 4 мин)
- [x] Xvfb + Selenium в Dockerfile

### GoFood Parser
- [x] `HttpGojekParserService` переписан (Scraping Browser)
- [x] `lib/gofood_scraper.js` создан
- [x] Node.js доступен на сервере
- [x] Playwright доступен (`/root/delivery-stats-parser/node_modules`)
- [x] BrightData Scraping Browser zone активна

### Infrastructure
- [x] Docker image с Chromium ARM64
- [x] Kamal deployment настроен
- [x] Mission Control Jobs (/jobs)

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│  TrackerDelivery (Rails 8 + Solid Queue)         │
│                                                  │
│  RestaurantMonitoringSchedulerJob (every 5min)   │
│  └─> RestaurantMonitoringWorkerJob (per restaurant)
│      ├─> GrabApiParserService (Grab restaurants) │
│      │   └─> HTTP + JWT → portal.grab.com API    │
│      └─> HttpGojekParserService (GoFood restaurants)
│          └─> Node.js subprocess                  │
│              └─> gofood_scraper.js               │
│                  └─> BrightData Scraping Browser │
│                      └─> gofood.co.id (Next.js)  │
│                                                  │
│  GrabJwtRefreshJob (every 4min)                  │
│  └─> Selenium + Xvfb + BrightData proxy         │
│      └─> grab_cookies.json (JWT token)           │
└──────────────────────────────────────────────────┘
```

---

## Deployment Steps

### 1. Verify Grab JWT

```bash
cat grab_cookies.json | grep jwt_token
# Должно быть: "jwt_token": "eyJ..." (не null!)
```

### 2. Deploy

```bash
git push
kamal deploy
```

### 3. Verify

```bash
# Check Grab parser
kamal app logs -f | grep "Grab API"

# Check GoFood parser
kamal app logs -f | grep "GoFood SBR"

# Check jobs
# https://aidelivery.tech/jobs (admin/TrackerDelivery2025!)
```

---

## Container Runtime

```
/rails/
├── grab_cookies.json          ← Grab JWT (initial, refreshed every 4 min)
├── lib/gofood_scraper.js      ← GoFood Node.js scraper
├── app/services/
│   ├── grab_api_parser_service.rb
│   └── http_gojek_parser_service.rb
└── tmp/gofood_cache/          ← GoFood results cache (4 min TTL)
```

**Grab JWT lifecycle:**
1. Docker build -> `grab_cookies.json` baked into image
2. Container starts -> `GrabJwtRefreshJob` обновляет JWT каждые 4 мин
3. Container restart -> initial JWT (valid ~10 min), refresh job обновит

**GoFood credentials:**
- Не требуются! Scraping Browser получает WAF tokens автоматически.
- Старые файлы `gojek_cookies.json` и `refresh_gojek_cookies.py` не нужны.

---

## Expected Performance

| Metric | Expected | Acceptable |
|--------|----------|------------|
| Grab parser duration | 0.5s | 0.3-1.0s |
| GoFood parser (single) | 25s | 15-60s |
| GoFood parser (batch 10) | 70s | 40-120s |
| Grab JWT refresh | 15-30s | < 60s |
| Monitoring cycle (5min) | < 3min | < 5min |

### Monitoring logs

```bash
kamal app logs -f | grep -E "(Grab API|GoFood SBR)"

# Expected:
# Grab API: Parsing completed in 0.45s
# GoFood SBR: Completed in 25.3s - Restaurant Name
# GoFood SBR: Cache hit in 0.01s
```

---

## Troubleshooting

### Grab: "No JWT token"
```bash
# Check file exists and has JWT
kamal app exec -- cat /rails/grab_cookies.json | grep jwt_token

# If null - check GrabJwtRefreshJob in /jobs
# Manual refresh: copy fresh grab_cookies.json to server
scp -P 2222 grab_cookies.json root@46.62.195.19:/root/TrackerDelivery/
```

### GoFood: Scraper timeout
```bash
# Test manually on server
NODE_PATH=/root/delivery-stats-parser/node_modules \
  node /root/TrackerDelivery/lib/gofood_scraper.js \
  '{"urls":["https://gofood.co.id/bali/restaurant/SLUG-UUID"]}'

# Common issues:
# 1. Scraping Browser zone expired -> check BrightData dashboard
# 2. Homepage WAF not passing -> retry (80% success rate)
# 3. Node.js not found -> verify `which node`
# 4. Playwright not found -> verify NODE_PATH
```

### GoFood: Node.js not available in Docker
```bash
# If Docker container doesn't have Node.js:
# Option 1: Install in Dockerfile
# Option 2: Use host Node.js via volume mount
# Option 3: Run scraper as external service
```

---

## Mission Control Jobs

**URL**: `https://aidelivery.tech/jobs`
**Auth**: `admin / TrackerDelivery2025!`

Shows: job status, errors, retries, queue health.

---

**Version**: 3.0
**Date**: 2026-03-15
**Target Server**: Hetzner CAX11 (ARM64, Finland)
