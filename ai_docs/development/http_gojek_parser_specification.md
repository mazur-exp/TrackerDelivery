# HttpGojekParserService Specification

**Version**: 2.1 (HTTP-based)
**Date**: 2025-11-12 (11:10 Bali time)
**Status**: ✅ Production Ready

---

## Overview

HttpGojekParserService - это production-ready HTTP парсер для GoFood ресторанов, использующий cookie-based authentication для получения полных данных без headless браузера. Обеспечивает быстрый мониторинг статуса open/closed для сотен ресторанов.

**Ключевое преимущество**: ~0.5 сек на ресторан (vs 30-60 сек Chrome-based парсер)

**Inheritance**: Standalone service (не наследует RetryableParser)

---

## 📖 Оглавление

1. [Configuration](#configuration)
2. [Public Methods](#public-methods)
3. [Extracted Data Structure](#extracted-data-structure)
4. [Cookie Management](#cookie-management)
5. [Testing & UI](#testing--ui)
6. [Техническая документация](#техническая-документация)

---

## Configuration

### Class Definition
```ruby
require "httparty"
require "nokogiri"
require "json"
require "http-cookie"

class HttpGojekParserService
  include HTTParty

  def initialize
    @timeout = 15
    @cookie_jar = HTTP::CookieJar.new
    load_cookies_from_file
  end
end
```

### Headers
```ruby
headers({
  'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  'Accept-Language' => 'en-US,en;q=0.9,id;q=0.8',
  'Sec-Fetch-Dest' => 'document',
  'Sec-Fetch-Mode' => 'navigate',
  'Cache-Control' => 'max-age=0'
})
```

---

## Public Methods

### parse(url)

Main entry point for parsing GoFood restaurant data via HTTP with cookies.

**Parameters:**
- `url` (String): GoFood restaurant URL (supports both `gofood.link` shortlinks and full URLs)

**Returns:**
- `Hash`: Complete restaurant data structure
- `nil`: If parsing fails

**Example Usage:**
```ruby
service = HttpGojekParserService.new
result = service.parse("https://gofood.link/a/MrswDDW")

# Expected result structure:
{
  name: "Ducat Cafe (Breakfast, Croissant, Salad, Steak), Canggu",
  address: "Jl Subak Sari 13, Tibubeneng, Kuta Utara",
  rating: "4.7",
  review_count: 305,  # ← Total number of reviews from ratings.total
  cuisines: ["Cepat saji", "Barat", "Makanan sehat"],
  image_url: "https://i.gojekapi.com/darkroom/gofood-indonesia/...",
  status: {
    is_open: true,           # ← Actual working status
    status_text: "open",     # "open" | "closed"
    core_status: 1,          # 1=OPEN, 2=CLOSED, 7=CLOSING_SOON
    deliverable: false,      # Distance-based delivery availability
    error: nil
  },
  open_periods: [            # ← Working hours (NEW in v2.1)
    {
      day: 1,                # 1=Monday, 7=Sunday
      day_name: "Senin",     # Indonesian day name
      start_time: "09:00",   # Opening time (HH:MM)
      end_time: "20:00",     # Closing time (HH:MM)
      formatted: "Senin: 09:00-20:00"  # Human-readable format
    },
    # ... 6 more days
  ]
}
```

**Key Features:**
- **Cookie-based auth**: No login required, uses cookies from `gojek_cookies.json`
- **__NEXT_DATA__ parsing**: Extracts from Next.js SSR JSON (532KB)
- **gofood.link resolution**: Automatically resolves JavaScript redirects
- **Accurate status**: Uses `outlet.core.status` (1/2/7), not `deliverable`
- **Review count**: Extracts from `outlet.ratings.total`
- **Working hours**: Extracts from `outlet.core.openPeriods` (7 days)
- **Performance**: ~0.5-1.6 seconds per restaurant
- **No headless browser**: Pure HTTP requests

---

## Проблема

### Цель:
Мониторить статус open/closed сотен GoFood ресторанов каждые 5 минут для автоматических alerts владельцам.

### Требования:
- ✅ Быстро (< 1 сек на ресторан)
- ✅ Масштабируемо (100+ ресторанов)
- ✅ Надёжно (статус должен быть точным)
- ❌ БЕЗ headless браузера для каждого запроса (слишком медленно)

---

## Исследование

### Попытка 1: Прямые HTTP запросы (curl/HTTParty)

**Результат**: ❌ FAILED

```ruby
response = HTTParty.get('https://gofood.link/a/MrswDDW')
# => 50KB урезанный HTML без статуса
```

**Проблема**:
- GoFood детектит curl/HTTParty как бота
- Отдаёт упрощённый HTML БЕЗ `__NEXT_DATA__`
- Есть только: name, cuisines, address, image
- НЕТ: rating, **status (open/closed)**

---

### Попытка 2: Chrome DevTools MCP с JavaScript перехватчиками

**Результат**: ❌ FAILED (WAF блокировка)

**Проблемы**:
1. **Tencent Cloud WAF** блокирует автоматизацию
2. Chrome DevTools Protocol оставляет характерные fingerprints
3. CAPTCHA требует ручного решения
4. Login flow блокируется с HTTP 403

**Что пробовали**:
- ✅ Установка геолокации Bali
- ✅ JavaScript injection для перехвата
- ✅ Monkey patching fetch/XHR
- ❌ Всё равно WAF block

---

### Попытка 3: Поиск Bearer/Refresh tokens

**Результат**: ❌ НЕ НУЖНЫ

**Выяснили**:
- GoFood Consumer API НЕ использует Bearer tokens
- Вся аутентификация через **cookies**
- Merchant Portal имеет refresh_token, но он НЕ работает для Consumer API
- Это две разные системы аутентификации

---

### ✅ РЕШЕНИЕ: Cookie-Based HTTP Parsing

**Ключевое открытие**:
GoFood отдаёт полный HTML (532KB) с `__NEXT_DATA__` **если есть правильные cookies**.

**Критический тест**:
```ruby
# БЕЗ cookies:
response.body.length => 50,622 bytes (урезанный)
response.body.include?('__NEXT_DATA__') => false

# С cookies:
response.body.length => 532,802 bytes (полный!)
response.body.include?('__NEXT_DATA__') => true
```

**Второе открытие**:
Cookies можно получить **БЕЗ логина** - просто визит на homepage!

```python
# Undetected ChromeDriver
driver.get('https://gofood.co.id/')
time.sleep(15)  # WAF challenge
cookies = driver.get_cookies()
# => w_tsfp, csrfSecret, XSRF-TOKEN, etc
```

Эти cookies **ПОЛНОСТЬЮ РАБОТАЮТ** для парсинга данных ресторанов!

---

## Архитектура

### Компоненты:

#### 1. Cookie Refresh Service (`refresh_gojek_cookies.py`)

```python
┌─────────────────────────────────────┐
│  Loop (каждые 4 часа):             │
│                                     │
│  1. Launch undetected-chromedriver │
│  2. Open gofood.co.id/              │
│  3. Wait 15 sec (WAF challenge)    │
│  4. Extract cookies + localStorage  │
│  5. Save to gojek_cookies.json     │
│  6. Sleep 4 hours                   │
│  7. Goto 1                          │
└─────────────────────────────────────┘
```

**Характеристики**:
- Headless mode (не открывает окно)
- Геолокация Bali (-8.66257, 115.15109)
- Использует venv от restaurant_parser
- Запускается автоматически с `bin/dev`

#### 2. HTTP Parser Service (`app/services/http_gojek_parser_service.rb`)

```ruby
┌────────────────────────────────────────┐
│  Для каждого ресторана:               │
│                                        │
│  1. Load cookies from JSON file       │
│  2. Resolve gofood.link → full URL    │
│  3. HTTParty.get with cookies         │
│  4. Extract __NEXT_DATA__ JSON        │
│  5. Parse outlet.core.status          │
│  6. Return structured data            │
└────────────────────────────────────────┘
```

**Возвращает**:
```ruby
{
  name: "Restaurant Name",
  address: "Full address",
  rating: "4.7" or "NEW",
  cuisines: ["Cuisine1", "Cuisine2", ...],
  image_url: "https://...",
  status: {
    is_open: true/false,
    status_text: "open"/"closed",
    core_status: 1/2/7,
    deliverable: true/false,
    error: nil
  }
}
```

---

## Использование

### Development (локальный сервер):

```bash
# 1. Запуск всех сервисов (Rails + Jobs + Ngrok + Cookie Refresh):
bin/dev

# Вывод:
# web           | Rails server started
# jobs          | SolidQueue workers started
# ngrok         | Tunnel established
# gojek_cookies | 🚀 GoJek Cookie Auto-Refresh Service
#               | 🔄 Обновление GoJek cookies...
#               | ✅ Cookies обновлены!
```

### Ручное тестирование парсера:

```bash
cd test_http_parsing

# Тест одного URL:
ruby test_gojek_http.rb "https://gofood.link/a/MrswDDW"

# Вывод:
# ✅ Found cookies file: gojek_cookies.json
# 🍪 Loading cookies from ../gojek_cookies.json...
# ✅ Loaded 6 cookies from file
# 🔗 Resolving gofood.link redirect...
# ✅ Resolved to: https://gofood.co.id/bali/restaurant/...
# ✅ Extracted data from Next.js JSON
# Status: {is_open: true, status_text: "open", core_status: 1}
```

### Использование в Rails:

```ruby
# В контроллере или job:
parser = HttpGojekParserService.new
data = parser.parse("https://gofood.link/a/MrswDDW")

if data && data[:status]
  if data[:status][:is_open]
    puts "✅ #{data[:name]} ОТКРЫТ"
  else
    puts "❌ #{data[:name]} ЗАКРЫТ"
    # Send alert to owner
  end
end
```

### Ручное обновление cookies:

```bash
# Если нужно обновить cookies вручную:
/Users/mzr/Developments/restaurant_parser/venv/bin/python3 refresh_gojek_cookies.py

# Ctrl+C после первого успешного refresh (не ждать 4 часа)
```

---

## Техническая документация

### gofood.link → Full URL Resolution

**Проблема**: `gofood.link` - это DeepLink shortener с JavaScript redirect

```html
<!-- gofood.link/a/MrswDDW returns: -->
<script>
  window.location.href = "https:\/\/gofood.co.id\/bali\/restaurant\/...";
</script>
```

**Решение**: Regex extraction + unescape

```ruby
def resolve_gofood_link(short_url)
  return short_url unless short_url.include?('gofood.link')

  response = HTTParty.get(short_url)
  match = response.body.match(/window\.location\.href\s*=\s*["']([^"']+)["']/)

  if match && match[1] != ' # '
    return match[1].strip.gsub('\\/', '/')  # Unescape slashes
  end

  short_url
end
```

---

### __NEXT_DATA__ Structure

GoFood использует **Next.js SSR**. Полные данные ресторана embedded в HTML:

```html
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "outlet": {
        "uuid": "8524cfd6-be35-4724-bc69-ece7e9b98621",
        "core": {
          "displayName": "Ducat Cafe (Breakfast, Croissant, Salad, Steak), Canggu",
          "status": 1,              // ← 1=OPEN, 2=CLOSED, 7=CLOSING_SOON
          "address": {
            "rows": ["Jl Subak Sari 13", "Tibubeneng", "Kuta Utara"]
          },
          "tags": [
            {"taxonomy": 2, "displayName": "Barat"},
            {"taxonomy": 2, "displayName": "Makanan sehat"}
          ],
          "openPeriods": [          // ← Working hours (7 days)
            {
              "day": 1,             // 1=Monday, 2=Tuesday, ... 7=Sunday
              "startTime": {
                "hours": 9,
                "minutes": 0,
                "seconds": 0,
                "nanos": 0
              },
              "endTime": {
                "hours": 20,
                "minutes": 0,
                "seconds": 0,
                "nanos": 0
              }
            },
            // ... 6 more days
          ],
          "nextCloseTime": "2025-11-11T12:30:00.000Z"
        },
        "ratings": {
          "average": 4.7,
          "total": 305        // ← Review count (NOT "reviewCount"!)
        },
        "delivery": {
          "deliverable": false,     // ← Distance-based (НЕ status!)
          "distanceKm": 28.8,
          "etaRange": {...}
        },
        "media": {
          "coverImgUrl": "https://i.gojekapi.com/..."
        }
      }
    }
  }
}
</script>
```

---

### openPeriods Structure (Working Hours)

**Location**: `outlet.core.openPeriods`

**Description**: Array of 7 objects (one per day of week), each containing opening and closing times.

**Day Numbering**:
- `1` = Monday (Senin)
- `2` = Tuesday (Selasa)
- `3` = Wednesday (Rabu)
- `4` = Thursday (Kamis)
- `5` = Friday (Jumat)
- `6` = Saturday (Sabtu)
- `7` = Sunday (Minggu)

**Example**:
```json
{
  "day": 1,
  "startTime": {"hours": 9, "minutes": 0, "seconds": 0, "nanos": 0},
  "endTime": {"hours": 20, "minutes": 0, "seconds": 0, "nanos": 0}
}
```

**Parsing Implementation**:
```ruby
open_periods = outlet['core']['openPeriods'].map do |period|
  start_time = format('%02d:%02d', period.dig('startTime', 'hours'), period.dig('startTime', 'minutes'))
  end_time = format('%02d:%02d', period.dig('endTime', 'hours'), period.dig('endTime', 'minutes'))

  {
    day: period['day'],
    day_name: day_names[period['day']],  # ["", "Senin", "Selasa", ...]
    start_time: start_time,               # "09:00"
    end_time: end_time,                   # "20:00"
    formatted: "#{day_names[period['day']]}: #{start_time}-#{end_time}"  # "Senin: 09:00-20:00"
  }
end
```

**Use Cases**:
- Display working hours to users
- Calculate if restaurant is open at specific time
- Show "Opens at HH:MM" / "Closes at HH:MM"
- Automated alerts for schedule changes

---

### core.status Values

| Value | Meaning | Description |
|-------|---------|-------------|
| **1** | OPEN | Ресторан работает, принимает заказы |
| **2** | CLOSED | Ресторан закрыт (вне рабочих часов или временно) |
| **7** | CLOSING_SOON | Скоро закрывается (< 30 минут до закрытия?) |

**Важно**: `core.status` - это **статус работы**, а `delivery.deliverable` - это **техническая возможность доставки** (зависит от расстояния).

**Пример**:
```json
{
  "core": {"status": 2},           // ЗАКРЫТ
  "delivery": {"deliverable": true} // Но близко к вам
}
```

---

### Cookie Management

#### Структура gojek_cookies.json:

```json
{
  "cookies": {
    "w_tsfp": "ltv...SqA=",           // WAF token (КРИТИЧНО!)
    "csrfSecret": "pUXZgF...",        // CSRF
    "XSRF-TOKEN": "qCVJ6jW1-M...",    // CSRF
    "gf_chosen_loc": "%7B%22name%22%3A...",  // Геолокация
    "_ga": "GA1.1.1362665128...",     // Google Analytics
    "TDC_itoken": "1709385127%3A..."  // Session token
  },
  "localStorage": {
    "w_tsfp": "ltv2UU8E3ewC6mwF...",  // Backup WAF token
    "TDC_itoken": "1709385127:..."    // Backup session
  },
  "url": "https://gofood.co.id/",
  "timestamp": "2025-11-11T11:18:45.416Z"
}
```

#### Как парсер использует cookies:

```ruby
# Load from file
@cookie_jar = HTTP::CookieJar.new
cookies_data = JSON.parse(File.read('gojek_cookies.json'))

cookies_data['cookies'].each do |name, value|
  cookie = HTTP::Cookie.new(
    name: name,
    value: value,
    domain: 'gofood.co.id',
    path: '/'
  )
  @cookie_jar.add(cookie)
end

# Use in requests
cookie_header = @cookie_jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join('; ')
response = HTTParty.get(url, headers: {'Cookie' => cookie_header})
```

---

### WAF Bypass Strategy

**GoFood использует Tencent Cloud WAF** который детектит:
- TLS fingerprinting (curl, HTTParty, requests)
- Browser fingerprinting (Canvas, WebGL, Audio)
- Behavioral patterns (mouse movements, timing)
- IP reputation

**Обход через Hybrid подход**:

1. **Undetected ChromeDriver** (bypass WAF):
   - Патчит Chrome для обхода automation detection
   - Проходит TLS/browser fingerprinting
   - Получает валидные cookies

2. **HTTParty с cookies** (fast parsing):
   - Cookies уже прошли WAF проверку
   - HTTP requests быстрые (~0.5 сек)
   - WAF пропускает запросы с валидными cookies

---

## Решение

### Cookie Auto-Refresh

**Файл**: `refresh_gojek_cookies.py`

```python
#!/usr/bin/env python3
import undetected_chromedriver as uc
import time
import json

# Каждые 4 часа:
while True:
    # 1. Launch undetected Chrome (headless)
    driver = uc.Chrome(options=options)

    # 2. Set Bali geolocation
    driver.execute_cdp_cmd("Emulation.setGeolocationOverride", {
        "latitude": -8.66257,
        "longitude": 115.15109
    })

    # 3. Open homepage (NO LOGIN!)
    driver.get('https://gofood.co.id/')
    time.sleep(15)  # Wait for WAF challenge

    # 4. Extract cookies
    cookies = driver.get_cookies()

    # 5. Save to JSON
    save_cookies('gojek_cookies.json', cookies)

    # 6. Sleep 4 hours
    time.sleep(4 * 3600)
```

**Запуск**: Автоматически через `Procfile.dev`

```
gojek_cookies: /path/to/venv/bin/python3 refresh_gojek_cookies.py
```

---

### HTTP Parser Implementation

**Файл**: `app/services/http_gojek_parser_service.rb`

```ruby
class HttpGojekParserService
  def initialize
    @cookie_jar = HTTP::CookieJar.new
    load_cookies_from_file  # Load from gojek_cookies.json
  end

  def parse(url)
    # 1. Resolve gofood.link if needed
    resolved_url = resolve_gofood_link(url)

    # 2. Make HTTP request with cookies
    cookie_header = @cookie_jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join('; ')
    response = HTTParty.get(resolved_url, headers: {'Cookie' => cookie_header})

    # 3. Extract __NEXT_DATA__ JSON
    json_data = extract_from_nextjs_json(response.body)

    # 4. Parse outlet data
    outlet = json_data.dig('props', 'pageProps', 'outlet')

    # Extract working hours
    day_names = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu']
    open_periods = outlet.dig('core', 'openPeriods')&.map do |period|
      start_time = format('%02d:%02d', period.dig('startTime', 'hours'), period.dig('startTime', 'minutes'))
      end_time = format('%02d:%02d', period.dig('endTime', 'hours'), period.dig('endTime', 'minutes'))

      {
        day: period['day'],
        day_name: day_names[period['day']],
        start_time: start_time,
        end_time: end_time,
        formatted: "#{day_names[period['day']]}: #{start_time}-#{end_time}"
      }
    end || []

    {
      name: outlet.dig('core', 'displayName'),
      address: address_rows.join(', '),
      rating: outlet.dig('ratings', 'average')&.to_s,
      review_count: outlet.dig('ratings', 'total'),  # ← Review count
      cuisines: cuisines,
      image_url: outlet.dig('media', 'coverImgUrl'),
      status: {
        is_open: outlet.dig('core', 'status') == 1,
        status_text: outlet.dig('core', 'status') == 1 ? 'open' : 'closed',
        core_status: outlet.dig('core', 'status'),
        deliverable: outlet.dig('delivery', 'deliverable'),
        error: nil
      },
      open_periods: open_periods  # ← Working hours (v2.1)
    }
  end
end
```

---

## Использование

### 1. Первичная настройка:

```bash
# Извлечь cookies из браузера (один раз):
# 1. Откройте GoFood в браузере
# 2. DevTools → Console → выполните:

const cookies = document.cookie.split(';').reduce((obj, c) => {
  const [name, ...value] = c.trim().split('=');
  obj[name] = value.join('=');
  return obj;
}, {});

const localStorage_data = {};
Object.keys(localStorage).forEach(key => {
  if (key.includes('token') || key === 'w_tsfp') {
    localStorage_data[key] = localStorage.getItem(key);
  }
});

console.log(JSON.stringify({
  cookies: cookies,
  localStorage: localStorage_data,
  timestamp: new Date().toISOString()
}, null, 2));

# 3. Скопировать JSON → сохранить в gojek_cookies.json
```

### 2. Запуск development сервера:

```bash
bin/dev
```

Автоматически запустятся:
- Rails server (port 3000)
- SolidQueue jobs
- Ngrok tunnel
- **Cookie refresh service** (фон)

### 3. Проверка что cookie refresh работает:

```bash
# Смотреть логи:
tail -f log/development.log | grep "GoJek Cookie"

# Или проверить timestamp в файле:
cat gojek_cookies.json | grep timestamp
```

### 4. Использование в коде:

```ruby
# В любом месте Rails app:
parser = HttpGojekParserService.new
data = parser.parse("https://gofood.link/a/MrswDDW")

# Проверка статуса:
if data[:status][:is_open]
  puts "Ресторан открыт!"
else
  puts "Ресторан закрыт!"
  # Trigger alert
end
```

---

## Техническая документация

### Зависимости:

**Ruby gems** (добавить в Gemfile):
```ruby
gem 'httparty'
gem 'nokogiri'
gem 'http-cookie'
```

**Python packages** (уже есть в restaurant_parser/venv):
```
undetected-chromedriver
selenium
```

### Файловая структура:

```
TrackerDelivery/
├── refresh_gojek_cookies.py          # Cookie refresh service
├── gojek_cookies.json                 # Актуальные cookies (auto-updated)
├── Procfile.dev                       # Foreman config (updated)
├── app/services/
│   └── http_gojek_parser_service.rb  # Production parser
├── test_http_parsing/
│   ├── test_gojek_http.rb            # Test parser
│   ├── proxy_manager.rb               # Proxy rotation (опционально)
│   ├── proxies_test.txt               # Proxy list
│   └── TEST_RESULTS.md                # Test results
├── GOJEK_TOKEN_RESEARCH.md            # Research notes (updated)
└── HTTP_PARSER_GOJEK.md               # Эта документация
```

---

## Troubleshooting

### Problem: "Could not find __NEXT_DATA__"

**Причина**: Cookies истекли или отсутствуют

**Решение**:
```bash
# 1. Проверить gojek_cookies.json существует:
ls -lh gojek_cookies.json

# 2. Проверить timestamp (должен быть свежий):
cat gojek_cookies.json | grep timestamp

# 3. Если старый - ручное обновление:
/Users/mzr/Developments/restaurant_parser/venv/bin/python3 refresh_gojek_cookies.py
# Ctrl+C после первого refresh
```

---

### Problem: "WAF block detected (209 bytes)"

**Причина**: Cookies не работают или WAF обновил защиту

**Решение**:
```bash
# 1. Обновить cookies:
python3 refresh_gojek_cookies.py

# 2. Если не помогает - извлечь из реального браузера:
# Откройте GoFood в Chrome → DevTools → Console
# Выполните скрипт извлечения (см. "Первичная настройка")
```

---

### Problem: Cookie refresh service не запускается

**Проверка**:
```bash
# 1. Проверить Python path в Procfile.dev:
which python3
ls /Users/mzr/Developments/restaurant_parser/venv/bin/python3

# 2. Проверить зависимости:
/Users/mzr/Developments/restaurant_parser/venv/bin/python3 -c "import undetected_chromedriver; print('OK')"

# 3. Запустить вручную для debug:
/Users/mzr/Developments/restaurant_parser/venv/bin/python3 refresh_gojek_cookies.py
```

---

### Problem: `core_status` unexpected value

**Известные значения**:
- `1` = OPEN
- `2` = CLOSED
- `7` = CLOSING_SOON (< 30 мин до закрытия)

Если появятся новые значения - добавить в mapping:

```ruby
STATUS_MAPPING = {
  1 => 'open',
  2 => 'closed',
  7 => 'closing_soon',
  # Add more as discovered
}
```

---

## Performance Metrics

### Cookie Refresh:
- **Frequency**: Каждые 4 часа
- **Duration**: ~15-20 секунд
- **Resource**: 1 headless Chrome instance
- **Memory**: ~200-300 MB (temporary)

### HTTP Parsing:
- **Per restaurant**: ~0.3-0.7 секунд
- **100 restaurants**: ~30-70 секунд
- **Memory**: Minimal (just HTTP::CookieJar)
- **CPU**: Низкое (JSON parsing only)

### Comparison:

| Method | Speed (1 restaurant) | Speed (100 restaurants) | Suitable for 5-min monitoring |
|--------|---------------------|------------------------|-------------------------------|
| Selenium/Ferrum | 5-10 sec | 500-1000 sec (8-16 min) | ❌ Too slow |
| **HTTP + Cookies** | **0.5 sec** | **50 sec** | ✅✅✅ Perfect! |

---

## Мониторинг и Alerts

### Интеграция с SolidQueue Job:

```ruby
# app/jobs/monitor_gojek_restaurants_job.rb
class MonitorGojekRestaurantsJob < ApplicationJob
  queue_as :default

  def perform
    parser = HttpGojekParserService.new

    Restaurant.where(platform: 'gojek').find_each do |restaurant|
      data = parser.parse(restaurant.deeplink_url)

      next unless data && data[:status]

      # Check status change
      was_open = restaurant.is_open
      now_open = data[:status][:is_open]

      if was_open && !now_open
        # Restaurant closed - ALERT!
        TelegramNotificationService.send_alert(
          restaurant: restaurant,
          message: "⚠️ #{restaurant.name} ЗАКРЫЛСЯ!"
        )
      elsif !was_open && now_open
        # Restaurant opened
        TelegramNotificationService.send_info(
          restaurant: restaurant,
          message: "✅ #{restaurant.name} открылся"
        )
      end

      # Update database
      restaurant.update(
        is_open: now_open,
        last_checked_at: Time.current
      )

      sleep(0.5)  # Rate limiting (опционально)
    end
  end
end
```

### Запуск через SolidQueue (каждые 5 минут):

```ruby
# config/recurring.yml
production:
  monitor_gojek_restaurants:
    class: MonitorGojekRestaurantsJob
    queue: default
    schedule: "*/5 * * * *"  # Every 5 minutes
```

---

## Security Notes

### Cookie Storage:

**⚠️ ВАЖНО**: `gojek_cookies.json` содержит session cookies!

```bash
# Добавить в .gitignore:
gojek_cookies.json
gojek_cookies_test.json

# На production - использовать encrypted credentials:
# config/credentials.yml.enc
```

### Production Deployment:

```yaml
# config/credentials.yml.enc
gojek:
  cookies_refresh_enabled: true
  refresh_interval_hours: 4
```

```ruby
# Production version of refresh service:
# Use encrypted credentials instead of JSON file
```

---

## Известные ограничения

### 1. Cookie TTL
- **TDC_itoken**: ~6-24 часа (точное время не определено)
- **w_tsfp**: Обновляется при каждом homepage visit
- **Решение**: Auto-refresh каждые 4 часа

### 2. Геолокация
- `deliverable` зависит от `gf_chosen_loc` cookie
- Если нужна проверка deliverability - установить правильную геолокацию
- Для статуса work (OPEN/CLOSED) - геолокация НЕ важна

### 3. Rate Limiting
- GoFood может заблокировать при слишком частых запросах
- **Рекомендация**: sleep 0.5-1 сек между запросами
- Или использовать proxy rotation (proxies_test.txt)

---

## Future Improvements

### 1. Cookie Rotation
Если один набор cookies блокируется - иметь fallback:

```python
# Генерировать 3 набора cookies с разными fingerprints
# Ротировать при 403/429 errors
```

### 2. API Discovery
Найти прямой API endpoint вместо HTML parsing:

```
POST https://gofood.co.id/api/v2/restaurant/status
Body: {"uuid": "8524cfd6-..."}
Response: {"is_open": true, "core_status": 1}
```

### 3. Webhooks (если GoFood предоставляет)
Подписаться на события изменения статуса вместо polling.

---

## Changelog

### 2025-11-11 v1.0 - Initial Implementation

**Added**:
- Cookie-based HTTP parsing
- Auto-refresh mechanism via undetected-chromedriver
- __NEXT_DATA__ JSON parsing
- core.status extraction (1=OPEN, 2=CLOSED, 7=CLOSING_SOON)
- gofood.link redirect resolution
- Integration with Procfile.dev

**Tested**:
- 7 restaurant URLs
- 100% success rate
- Performance: 0.5 sec per restaurant

**Files**:
- `refresh_gojek_cookies.py`
- `test_http_parsing/test_gojek_http.rb`
- `app/services/http_gojek_parser_service.rb`

---

## Контакты и поддержка

**Разработано**: 2025-11-11 (Claude Code session)
**Тестировано на**: 7 Bali restaurants
**Platform**: GoFood Indonesia (gofood.co.id)

**Для вопросов**: См. исходные файлы с комментариями

---

## Testing & UI

### Web Test Interface

**Location**: `test_web_parser/`

HTTP парсер интегрирован в веб-интерфейс для визуального тестирования.

**Start Server**:
```bash
# From TrackerDelivery root:
ruby test_web_parser/parser.rb 3001

# Open in browser:
http://localhost:3001/
```

**Features**:
- 🌐 Interactive web UI for testing
- ⏱️ Real-time parsing duration display
- 📊 Data quality score (0-100%)
- 🖼️ Image preview
- 🟢 **ОТКРЫТО** / 🔴 **ЗАКРЫТО** - Visual status indicators
- ⭐ **Rating with review count**: "4.7 (305 отзывов)"
- 🆕 **NEW badge** for restaurants without ratings (rating: 0)

**Example Output**:

For established restaurant (with rating):
```
✅ GoJek
⏱️ 1.63с  📊 95% качество

Название: Ducat Cafe (Breakfast, Croissant, Salad, Steak), Canggu
Рейтинг: ⭐ 4.7 (305 отзывов)
🟢 Статус: ОТКРЫТО (core_status: 1)
Адрес: Jl Subak Sari 13, Tibubeneng, Kuta Utara
Кухни: Barat, Makanan sehat, Cepat saji
[Restaurant Image Preview]

Режим работы:
  Senin: 09:00-20:00
  Selasa: 09:00-20:00
  Rabu: 09:00-20:00
  Kamis: 09:00-20:00
  Jumat: 09:00-20:00
  Sabtu: 09:00-20:00
  Minggu: 09:00-16:00
```

For NEW restaurant (no rating):
```
✅ GoJek
⏱️ 1.45с  📊 90% качество

Название: Tiramisu 2Go Bali
Рейтинг: NEW
🟢 Статус: ОТКРЫТО (core_status: 1)
Адрес: ...
Кухни: Sweets, Roti, Barat
```

### UI Implementation Details

**Rating Display Logic** (`test_web_parser/index.html`):
```javascript
// Handle NEW restaurants (rating: 0 or "NEW")
if (result.data.rating !== undefined) {
    const rating = result.data.rating;
    const isNew = rating === 0 || rating === "0" || rating === "NEW";

    if (isNew) {
        html += `<span style="color: #F59E0B; font-weight: bold;">NEW</span>`;
    } else {
        const reviewText = result.data.review_count 
            ? ` (${result.data.review_count} отзывов)` 
            : '';
        html += `⭐ ${rating}${reviewText}`;
    }
}
```

**Status Display Logic**:
```javascript
// Visual status with emoji and color
if (result.data.status) {
    const isOpen = result.data.status.is_open;
    const statusEmoji = isOpen ? '🟢' : '🔴';
    const statusText = isOpen ? 'ОТКРЫТО' : 'ЗАКРЫТО';
    const statusColor = isOpen 
        ? 'color: #16A34A; font-weight: bold;'  // Green
        : 'color: #DC2626; font-weight: bold;';  // Red
    const coreStatus = result.data.status.core_status || '';

    html += `<div style="${statusColor}">
        ${statusEmoji} Статус: ${statusText}
        <span style="color: #666;">(core_status: ${coreStatus})</span>
    </div>`;
}
```

### Test URLs (Updated Examples)

**Restaurants with ratings**:
- `https://gofood.link/a/MrswDDW` - Ducat Cafe (4.7, 305 reviews)
- `https://gofood.link/a/Nt5i77d` - Kue Tiram Ny Hok (4.9 rating)

**NEW restaurants** (rating: 0):
- `https://gofood.link/a/QK8wyTj` - Tiramisu 2Go Bali (NEW)
- `https://gofood.link/a/BHZmkmU` - Tiramisu By MilmisyuBali (NEW)

---

## Changelog

### v2.1 (2025-11-12 11:10 Bali time)

**Added**:
- ✅ **open_periods** field from `outlet.core.openPeriods`
- ✅ Working hours extraction for all 7 days of the week
- ✅ Indonesian day names (Senin, Selasa, Rabu, etc.)
- ✅ Formatted display: "Senin: 09:00-20:00"
- ✅ Working hours display in test UI
- ✅ Console output shows "Working Hours:" section

**Features**:
- Extracts opening/closing times from Next.js JSON
- Parses `startTime` and `endTime` objects (hours, minutes)
- Provides both structured data and formatted strings
- No additional HTTP requests needed - data already in __NEXT_DATA__

**Use Cases**:
- Display working hours to restaurant owners
- Calculate if restaurant should be open at specific time
- Automated alerts for schedule violations
- Business analytics (operating hours patterns)

**Files Updated**:
- `test_http_parsing/test_gojek_http.rb` - Added openPeriods extraction and display
- `test_web_parser/index.html` - Added working hours UI section
- `ai_docs/development/http_gojek_parser_specification.md` - This doc updated

**Example Output**:
```ruby
{
  open_periods: [
    {day: 1, day_name: "Senin", start_time: "09:00", end_time: "20:00", formatted: "Senin: 09:00-20:00"},
    {day: 2, day_name: "Selasa", start_time: "09:00", end_time: "20:00", formatted: "Selasa: 09:00-20:00"},
    # ... 5 more days
  ]
}
```

---

### v2.0 (2025-11-11 22:45)

**Added**:
- ✅ **review_count** field from `outlet.ratings.total`
- ✅ Visual status indicators in test UI (🟢 ОТКРЫТО / 🔴 ЗАКРЫТО)
- ✅ NEW badge for restaurants without ratings
- ✅ Review count display in UI: "4.7 (305 отзывов)"
- ✅ test_web_parser integration with cookie support

**Fixed**:
- Field name corrected: `ratings.total` (not `reviewCount`)
- Rating display handles 0/"NEW"/"4.7" values correctly
- Status color coding (green for open, red for closed)

**Files Updated**:
- `test_http_parsing/test_gojek_http.rb` - Added review_count extraction
- `test_web_parser/index.html` - Enhanced UI with status/rating improvements
- `test_web_parser/parser.rb` - Cookie file integration
- `ai_docs/development/http_gojek_parser_specification.md` - This doc

