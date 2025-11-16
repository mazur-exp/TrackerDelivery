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
- [x] `grab_cookies.json` содержит валидный JWT ← **Закоммичен в git!**
- [x] `gojek_cookies.json` содержит валидные cookies ← **Закоммичен в git!**

### 2. Проверка credentials (ВАЖНО!)

```bash
# JWT должен быть ВАЛИДНЫМ (не null!)
cat grab_cookies.json | grep jwt_token
# Должно быть: "jwt_token": "eyJ..." (НЕ null!)

# Cookies должны быть свежими
cat gojek_cookies.json | grep w_tsfp
# Должен быть WAF token
```

**КРИТИЧНО:** Файлы `grab_cookies.json` и `gojek_cookies.json` **включены в Docker image**!
- При build Docker копирует их в `/rails/*.json`
- Refresh scripts обновляют файлы **inside container** каждые 4 минуты
- Updates НЕ сохраняются между container restarts (ephemeral)
- Для production stability: перебилдить image с fresh JWT каждые несколько часов

---

## 🚀 Deployment Steps (SIMPLE!)

### Step 1: Verify credentials committed

```bash
# Проверить что JWT валидный (НЕ null!)
git show HEAD:grab_cookies.json | grep jwt_token

# Должно быть: "jwt_token": "eyJ..."
```

### Step 2: Push и Deploy

```bash
git push
kamal deploy
```

**Вот и всё!** Credentials включены в Docker image автоматически!

---

## ✅ Как это работает (Simple Architecture)

### Docker Build:
```dockerfile
# Dockerfile автоматически копирует:
COPY . /rails
# ↑ Включает grab_cookies.json и gojek_cookies.json!
```

### Container Runtime:
```
/rails/
├── grab_cookies.json     ← Initial JWT (baked in image)
├── gojek_cookies.json    ← Initial cookies
├── refresh_grab_jwt.py   ← Updates grab_cookies.json every 4 min
└── refresh_gojek_cookies.py  ← Updates gojek_cookies.json every 4 hours
```

### JWT Lifecycle:
```
1. Docker build → grab_cookies.json с JWT копируется в image
2. Container starts → файл в /rails/grab_cookies.json
3. refresh_grab_jwt.py запускается → обновляет JWT каждые 4 минуты
4. Parser читает → СВЕЖИЙ JWT! ✅
5. Container restart → JWT возвращается к initial (from image)
   └─> refresh скрипт сразу обновит! (4 min cycle)
```

### Важно:
- ✅ Initial JWT работает первые 10 минут после deployment
- ✅ Refresh обновляет JWT каждые 4 минуты
- ⚠️ Container restart → возврат к initial JWT (но быстро обновляется)
- 💡 Для длительной стабильности: redeploy каждые несколько дней с fresh JWT

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
