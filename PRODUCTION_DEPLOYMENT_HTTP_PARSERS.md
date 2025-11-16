# Production Deployment: HTTP Parsers

**Quick Guide для deployment HTTP парсеров на Hetzner ARM64 сервер**

---

## 📋 Pre-Deployment Checklist

### 1. Локальная подготовка

- [x] `http-cookie` gem добавлен в Gemfile
- [x] `GrabApiParserService` создан (app/services/)
- [x] `HttpGojekParserService` существует
- [x] `/test-parsers` route настроен
- [x] `refresh_grab_jwt.py` исправлен (case-sensitive headers)
- [x] `grab_cookies.json` содержит валидный JWT
- [x] `gojek_cookies.json` содержит валидные cookies

### 2. Проверка credentials

```bash
# JWT должен быть свежим (< 10 минут!)
cat grab_cookies.json | grep -E '(jwt_token|timestamp)'

# Cookies должны быть свежими (< 6 часов)
cat gojek_cookies.json | grep timestamp
```

---

## 🚀 Deployment Steps

### Step 1: Bundle install

```bash
bundle install
# Должно установить http-cookie gem
```

### Step 2: Update Procfile.dev для production

```ruby
# Procfile.dev
web: bin/rails server
jobs: bin/jobs
gojek_cookies: python3 refresh_gojek_cookies.py
grab_jwt: xvfb-run -a python3 refresh_grab_jwt.py  # ← Добавлен xvfb-run!
```

**Важно**: `xvfb-run` bypasses AWS WAF на headless сервере!

### Step 3: Copy credentials на сервер

```bash
# SCP credentials на production
scp grab_cookies.json root@your-server:/root/TrackerDelivery/
scp gojek_cookies.json root@your-server:/root/TrackerDelivery/

# В Docker они будут в /rails/
```

### Step 4: Deploy via Kamal

```bash
kamal deploy
```

### Step 5: Verify deployment

```bash
# SSH на сервер
ssh root@your-server

# Проверить credentials скопированы
ls -lh /root/TrackerDelivery/*.json

# Проверить процессы
ps aux | grep -E "(refresh_grab|refresh_gojek)"
```

---

## 🧪 Production Testing

### Via Web UI:

```
1. Открыть: https://your-domain.com/test-parsers
2. Ввести Grab URL
3. Кликнуть "Test Grab Parser"
4. Проверить result: success=true, duration < 1s
5. Repeat для GoJek
```

### Via API:

```bash
# Test Grab
curl -X POST https://your-domain.com/test-parsers/grab \
  -H "Content-Type: application/json" \
  -d '{"url": "https://r.grab.com/g/6-C65ZV62KVNEDPE"}'

# Expected:
# {"success":true,"duration":0.45,"quality":75,...}

# Test GoJek
curl -X POST https://your-domain.com/test-parsers/gojek \
  -H "Content-Type: application/json" \
  -d '{"url": "https://gofood.link/a/MrswDDW"}'

# Expected:
# {"success":true,"duration":2.0,"quality":100,...}
```

---

## 🔧 Troubleshooting Production

### Problem: Grab parser returns "No JWT token"

**Причина**: grab_cookies.json не найден или JWT = null

**Solution**:
```bash
# На сервере check file
cat /root/TrackerDelivery/grab_cookies.json | grep jwt_token

# Если null - copy fresh file from local
scp grab_cookies.json root@server:/root/TrackerDelivery/
kamal app exec -i -- cat /rails/grab_cookies.json
```

### Problem: GoJek parser fails with WAF

**Причина**: Cookies истекли

**Solution**:
```bash
# Copy fresh cookies
scp gojek_cookies.json root@server:/root/TrackerDelivery/
```

### Problem: refresh_grab_jwt.py не запускается

**Причина**: Xvfb не установлен или Python venv отсутствует

**Solution**:
```bash
# На сервере
which xvfb-run  # Должен быть /usr/bin/xvfb-run

# Check Python venv
ls /app/venv/bin/python3  # Или где установлен venv
```

---

## 📊 Expected Performance

### After Deployment:

| Metric | Expected | Acceptable Range |
|--------|----------|------------------|
| Grab parser duration | 0.5s | 0.3-1.0s |
| GoJek parser duration | 1.5s | 0.5-3.0s |
| Grab quality | 75-100% | > 70% |
| GoJek quality | 100% | > 90% |
| JWT refresh success | 100% | > 95% |
| Cookie refresh success | 100% | > 95% |

### Monitoring:

```ruby
# Check logs через Kamal
kamal app logs -f | grep -E "(Grab API|HTTP GoJek)"

# Expected output:
# Grab API: Parsing completed in 0.45s
# HTTP GoJek: Parsing completed in 2.08s
```

---

## 🎯 Post-Deployment Actions

### 1. Verify auto-refresh works

```bash
# Wait 4-5 minutes
# Check JWT timestamp updated
kamal app exec -- cat /rails/grab_cookies.json | grep timestamp
```

### 2. Test monitoring jobs

```bash
# Trigger manual job run
kamal app exec -- bin/rails runner "MonitorGrabRestaurantsJob.perform_now"

# Check logs
kamal app logs | grep "Grab API"
```

### 3. Setup alerts

```ruby
# If parser fails > 5% → send alert
# If JWT refresh fails → send critical alert
```

---

## ✅ Success Criteria

Deployment successful если:

- [x] /test-parsers route accessible
- [x] Grab parser returns data in < 1s
- [x] GoJek parser returns data in < 3s
- [x] JWT refresh works (check timestamp updates)
- [x] Cookie refresh works
- [x] No errors in logs

---

**Version**: 1.0
**Date**: 2025-11-16
**Target Server**: Hetzner CAX11 (ARM64)
**Tested**: MacOS ARM64 M4 ✅
