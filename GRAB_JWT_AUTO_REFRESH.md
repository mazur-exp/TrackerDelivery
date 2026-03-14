# Grab JWT Auto-Refresh

**Автоматическое обновление JWT токена для Grab Food API**

---

## Как работает

JWT токен для Grab Guest API v2 имеет TTL = **10 минут**. Обновляется каждые **4 минуты** через `GrabJwtRefreshJob`.

### Архитектура

```
GrabJwtRefreshJob (Solid Queue, every 4 min)
└─> GrabJwtRefreshService
    └─> Selenium Chrome + Xvfb (visible mode)
        └─> BrightData datacenter proxy (country: ID)
            └─> food.grab.com restaurant page
                └─> CDP Performance Logging
                    └─> Extract JWT from network headers
                        └─> Save to grab_cookies.json
```

### Почему Xvfb?
AWS WAF на food.grab.com детектит headless Chrome. Xvfb создает виртуальный дисплей, Chrome работает как обычный браузер, WAF не блокирует.

---

## Файлы

| Файл | Назначение |
|------|-----------|
| `app/jobs/grab_jwt_refresh_job.rb` | Solid Queue job, запускает refresh |
| `app/services/grab_jwt_refresh_service.rb` | Selenium + BrightData proxy + JWT extraction |
| `grab_cookies.json` | Хранит JWT, cookies, API version |
| `config/recurring.yml` | Расписание: `*/4 * * * *` |

---

## grab_cookies.json

```json
{
  "cookies": { "gfc_country": "ID", "grab_locale": "en", "..." },
  "jwt_token": "eyJhbGciOiJSUzI1NiIs...",
  "api_version": "uaf6yDMWlVv0CaTK5fHdB",
  "timestamp": "2025-11-16T02:54:30.000Z"
}
```

JWT decode:
```ruby
require 'base64'
payload = JSON.parse(Base64.decode64(jwt.split('.')[1]))
puts "Expires: #{Time.at(payload['exp'])}"
puts "TTL: #{payload['exp'] - payload['iat']} seconds"  # 600 = 10 min
```

---

## Troubleshooting

### JWT = null или отсутствует
1. Проверить логи `GrabJwtRefreshJob` в /jobs
2. Xvfb запущен? `pgrep -f Xvfb`
3. Chrome/Chromium установлен? `which chromium || which google-chrome`
4. BrightData proxy работает? Проверить зону `datacenter_proxy1`

### WAF блокирует (page title = "undefined undefined")
- Headless mode включен по ошибке -> убрать `--headless`
- Xvfb не запущен -> `Xvfb :99 -screen 0 1920x1080x24 -ac &`

### Headers case-sensitivity
CDP Performance Logging возвращает headers с заглавными буквами:
- `X-Hydra-JWT` (не `x-hydra-jwt`)
- `X-Grab-Web-App-Version` (не `x-grab-web-app-version`)

---

## Timing

```
JWT TTL:              10 минут
Refresh interval:     4 минуты
Safety margin:        6 минут
Monitoring interval:  5 минут
Refresh duration:     15-30 секунд
```

JWT всегда свежий для monitoring jobs.

---

**Дата обновления**: 2026-03-15
