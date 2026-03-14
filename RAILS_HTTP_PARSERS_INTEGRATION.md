# Rails Parsers Integration

**Парсеры данных ресторанов для TrackerDelivery**

---

## Overview

TrackerDelivery использует два парсера для мониторинга ресторанов на платформах доставки:

| Платформа | Парсер | Подход | Скорость |
|-----------|--------|--------|----------|
| **Grab** | `GrabApiParserService` | HTTP + JWT API | ~0.5s/ресторан |
| **GoFood** | `HttpGojekParserService` | Scraping Browser + Next.js router | ~4-5s/ресторан |

Оба парсера имеют одинаковый интерфейс: `parser.parse(url)` -> Hash с данными ресторана.

---

## 1. GrabApiParserService (JWT + API v2)

**Файл**: `app/services/grab_api_parser_service.rb`

**Подход:**
- Использует Grab Guest API v2 (`portal.grab.com/foodweb/guest/v2`)
- Требует JWT token (`x-hydra-jwt`) из `grab_cookies.json`
- JWT TTL = 10 минут, обновляется каждые 4 минуты

**Использование:**
```ruby
parser = GrabApiParserService.new
data = parser.parse("https://r.grab.com/g/6-...")

# Возвращает:
{
  name: "Restaurant Name",
  address: "Full address",
  rating: "4.7",
  review_count: 305,
  cuisines: ["Western", "Fast Food"],
  coordinates: { latitude: -8.640, longitude: 115.142 },
  image_url: "https://food-cms.grab.com/...",
  status: { is_open: true, status_text: "open" },
  working_hours: [...],  # 7 days
  distance_km: 12.198
}
```

**Зависимости:**
- `grab_cookies.json` с валидным JWT
- JWT обновляется автоматически через `GrabJwtRefreshJob` (Selenium + Xvfb + BrightData proxy)

---

## 2. HttpGojekParserService (Scraping Browser + Next.js Router)

**Файл**: `app/services/http_gojek_parser_service.rb`
**Скрипт**: `lib/gofood_scraper.js`

**Подход:**
- gofood.co.id защищен Tencent Cloud WAF (EdgeOne) с CAPTCHA
- Прямой HTTP-доступ невозможен (любой curl/HTTP библиотеки блокируются)
- Решение: BrightData Scraping Browser загружает homepage (проходит JS challenge), затем использует `window.next.router.push()` для client-side навигации к ресторанам
- Данные перехватываются из `_next/data` XHR ответов (полный `pageProps.outlet`)
- Подробности: `GOFOOD_WAF_BYPASS.md`

**Использование:**
```ruby
# Одиночный запрос
parser = HttpGojekParserService.new
data = parser.parse("https://gofood.co.id/bali/restaurant/slug-uuid")
data = parser.parse("https://gofood.link/a/CODE")  # короткие ссылки тоже работают

# Батч (эффективнее - одна сессия Scraping Browser)
results = parser.parse_batch([url1, url2, url3])

# Возвращает:
{
  name: "Restaurant Name",
  address: "Full address",
  rating: "4.8",
  review_count: 330,
  cuisines: ["Cepat saji", "Barat"],
  image_url: "https://i.gojekapi.com/...",
  status: {
    is_open: true,
    status_text: "open",
    core_status: 1,       # 1=open, 2=closed
    deliverable: false,
    next_open_time: nil,   # ISO datetime when closed
    next_close_time: "...",# ISO datetime when open
    blocked_reason: nil
  },
  working_hours: [...]  # 7 days, same format as Grab
}
```

**Зависимости:**
- Node.js (на сервере)
- Playwright (`/root/delivery-stats-parser/node_modules`)
- BrightData Scraping Browser zone (`scraping_browser1`)
- Кеш: результаты кешируются на 4 минуты в `tmp/gofood_cache/`

**ENV переменные:**
| Variable | Default | Description |
|----------|---------|-------------|
| `SCRAPING_BROWSER_WS` | hardcoded | BrightData WebSocket URL |
| `NODE_BIN` | `node` | Путь к Node.js |
| `PLAYWRIGHT_PATH` | `/root/delivery-stats-parser/node_modules` | Путь к Playwright |

---

## Production Monitoring: /jobs

**URL**: `https://aidelivery.tech/jobs`

**Access:**
```
Username: admin
Password: TrackerDelivery2025!
```

Показывает: статус джобов, performance метрики, ошибки и ретраи.

---

## Credentials Management

### Grab: grab_cookies.json

**Структура:**
```json
{
  "cookies": { "...": "..." },
  "jwt_token": "eyJhbGciOiJSUzI1NiIs...",
  "api_version": "uaf6yDMWlVv0CaTK5fHdB",
  "timestamp": "2025-11-16T02:54:30.000Z"
}
```

**Обновление**: автоматически через `GrabJwtRefreshJob` каждые 4 минуты (Selenium + Xvfb + BrightData datacenter proxy).

### GoFood: НЕ требует credentials

GoFood парсер **не использует файлы cookies**. Всё проходит через Scraping Browser, который сам получает и использует WAF tokens в рамках сессии.

Старые файлы (`gojek_cookies.json`, `GojekCookieRefreshService`, `GojekCookieRefreshJob`) больше не используются.

---

## Scheduled Jobs

```yaml
# config/recurring.yml
production:
  grab_jwt_refresh:
    class: GrabJwtRefreshJob
    schedule: "*/4 * * * *"   # Every 4 minutes

  restaurant_monitoring:
    class: RestaurantMonitoringSchedulerJob
    schedule: "*/5 * * * *"   # Every 5 minutes
```

---

## Troubleshooting

### Grab Parser не работает

1. **JWT отсутствует?** `cat grab_cookies.json | grep jwt_token`
2. **JWT истек?** Декодируй JWT и проверь `exp`
3. **Refresh не работает?** Проверь логи `GrabJwtRefreshJob` в /jobs

### GoFood Parser не работает

1. **Node.js доступен?** `which node`
2. **Playwright установлен?** `ls /root/delivery-stats-parser/node_modules/playwright`
3. **Scraping Browser подключается?** Проверь логи -- `GoFood SBR: Connecting...`
4. **Homepage не грузится?** Scraping Browser нестабилен (~80% success). Скрипт ретраит до 3 раз.
5. **BrightData зона активна?** Проверь https://brightdata.com/cp/zones

### GoFood: подробная диагностика

```bash
# Тест скрипта вручную
NODE_PATH=/root/delivery-stats-parser/node_modules \
  node /root/TrackerDelivery/lib/gofood_scraper.js \
  '{"urls":["https://gofood.co.id/bali/restaurant/SLUG"]}'
```

stderr покажет прогресс (`[GoFood] Homepage loaded...`), stdout -- JSON результат.

---

## Performance

| Parser | Одиночный | Батч 10 шт | Качество |
|--------|-----------|------------|----------|
| **Grab API** | 0.5s | 5s (parallel) | 75-100% |
| **GoFood SBR** | 20s (homepage) + 5s | 20s + 50s = 70s | 100% |

GoFood батч эффективнее: одна сессия Scraping Browser (~20s homepage) + ~5s на каждый ресторан.

---

**Дата обновления**: 2026-03-15
**Status**: Production Ready
