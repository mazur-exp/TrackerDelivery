# GoJek Token Research - Session Notes

## Цель
Найти **refresh_token** для GoJek Consumer API для автоматического обновления токенов в Python боте.

## Что выяснили

### 1. Merchant Portal (portal.gofoodmerchant.co.id)
- ✅ **Access Token**: Найден в cookies
- ✅ **Refresh Token**: Найден в response от `POST https://api.gobiz.co.id/goid/token`
- ❌ **НЕ работает для Consumer API** (HTTP 403 при попытке использовать для api.gojekapi.com)
- Используется только для управления рестораном

### 2. Python Bot на сервере (193.42.32.137)
**Локация**: `/app/src/.../gojek_headers.json`
- ❌ **Только Bearer token** (протухающий)
- ❌ **НЕТ refresh_token**
- Токены перехвачены через Charles Proxy, но был перехвачен уже готовый Bearer, а не login flow

### 3. Файл gojek.py (локальный)
**Локация**: `/Users/mzr/Downloads/gojek.py`
- ❌ **Только Bearer token**
- ❌ **НЕТ refresh_token**

## Проблема
Consumer API токены протухают и нет способа их автоматически обновлять!

## Решение
Залогиниться в **GoFood Consumer Web** и перехватить login flow:

### Шаги:
1. Открыть: https://gofood.co.id/en/login
2. Залогиниться с номером: **81390604722**
3. Открыть DevTools → Network tab
4. Найти запрос к `/token` или `/login` endpoint
5. В Response найти:
   - `access_token`
   - **`refresh_token`** ← главная цель!

### Credentials
- **Phone**: +6281390604722
- **Email**: mazur.bali+oe@gmail.com (из Merchant Portal)
- **Merchant Password**: Mazur_230791 (не факт что подходит для consumer)

## Технические проблемы
- Chrome DevTools MCP периодически отключается
- Кнопка "Continue" на gofood.co.id не работает (причина не выяснена)

## Endpoints для исследования

### Merchant Portal Login
```
POST https://api.gobiz.co.id/goid/token
Headers:
  - x-appid: go-biz-web-dashboard
  - authentication-type: go-id
Body:
  {
    "client_id": "go-biz-web-new",
    "grant_type": "password",
    "data": {
      "email": "mazur.bali+oe@gmail.com",
      "password": "Mazur_230791"
    }
  }
Response:
  {
    "access_token": "...",
    "refresh_token": "...",
    "dbl_enabled": true
  }
```

### Consumer API (предположительно)
```
POST https://api.gojekapi.com/goid/login (?)
или
POST https://gofood.co.id/api/v1/auth/token (?)
```

## ✅ ФИНАЛЬНОЕ РЕШЕНИЕ (2025-11-11)

### Критическое открытие:
**Bearer/Refresh tokens НЕ НУЖНЫ для GoFood HTTP парсинга!**

GoFood использует **cookie-based authentication**, а не OAuth flow.

### Что работает:

#### 1. Cookie-Based Parsing (РЕАЛИЗОВАНО)
- ✅ Undetected ChromeDriver открывает `gofood.co.id/` (БЕЗ логина!)
- ✅ Извлекает cookies: `w_tsfp`, `csrfSecret`, `XSRF-TOKEN`, `_ga`, etc
- ✅ HTTParty использует эти cookies для запросов к ресторанам
- ✅ Получает полный HTML с `__NEXT_DATA__` (532KB)
- ✅ Парсит `outlet.core.status` (1=OPEN, 2=CLOSED, 7=CLOSING_SOON)

#### 2. Ключевые cookies:
```
w_tsfp              - WAF fingerprint token (КРИТИЧНО!)
csrfSecret          - CSRF protection
XSRF-TOKEN          - CSRF token
gf_chosen_loc       - Геолокация (опционально)
_ga, TDC_itoken     - Analytics/tracking
```

#### 3. Автоматическое обновление:
**Файл**: `refresh_gojek_cookies.py`
- Запускается через `Procfile.dev` с `bin/dev`
- Обновляет cookies каждые 4 часа
- Использует undetected-chromedriver
- НЕ ТРЕБУЕТ логина, OTP, CAPTCHA!

### Архитектура:

```
┌─────────────────────────────────────────────────────┐
│  refresh_gojek_cookies.py (каждые 4 часа)          │
│  └─> Opens gofood.co.id/ with undetected-chrome    │
│  └─> Extracts cookies                               │
│  └─> Saves to gojek_cookies.json                    │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  HttpGojekParserService (каждые 5 минут)           │
│  └─> Loads cookies from gojek_cookies.json          │
│  └─> HTTParty.get(restaurant_url, cookies)          │
│  └─> Parses __NEXT_DATA__ → core.status             │
│  └─> Returns: name, address, rating, cuisines,      │
│               status (OPEN/CLOSED)                   │
└─────────────────────────────────────────────────────┘
```

### Performance:
- **Cookie refresh**: ~15 сек раз в 4 часа (фоновый процесс)
- **Парсинг 1 ресторана**: ~0.3-0.7 сек (HTTP request)
- **100 ресторанов**: ~30-70 сек
- **Масштабируемость**: ✅✅✅ Подходит для мониторинга каждые 5 минут

### Протестировано на 7 URLs:
- 4 ресторана OPEN (core_status: 1)
- 3 ресторана CLOSED (core_status: 2, 7)
- 100% success rate с cookies

## Следующие шаги
1. ✅ Cookies mechanism реализован
2. ✅ Auto-refresh через Procfile.dev
3. ⏳ Интегрировать в monitoring job
4. ⏳ Добавить alerts для status changes

## Файлы
- `refresh_gojek_cookies.py` - Cookie refresh service
- `gojek_cookies.json` - Актуальные cookies
- `test_http_parsing/test_gojek_http.rb` - Test parser
- `app/services/http_gojek_parser_service.rb` - Production service
- `test_http_parsing/TEST_RESULTS.md` - Детальные результаты

## Дата
2025-11-11 (20:00 Bali time)
