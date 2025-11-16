# GoJek HTTP Parser - Test Results

## Date: 2025-11-11

## Summary

✅ **HTTP парсер GoJek работает с cookies!**

### Ключевые находки:

1. **`gofood.link`** делает JavaScript redirect на `gofood.co.id/bali/restaurant/...`
2. **GoFood требует cookies** для полного HTML (без cookies = 50KB урезанный, с cookies = 532KB полный)
3. **`__NEXT_DATA__` JSON** содержит все данные включая статус
4. **`core.status`** = статус работы (1 = OPEN, 2 = CLOSED)
5. **`delivery.deliverable`** = возможность доставки (зависит от расстояния)

### Тестирование 7 URLs:

| URL | Ресторан | Status | core_status | Rating | deliverable |
|-----|----------|--------|-------------|--------|-------------|
| gofood.link/a/MrswDDW | Ducat Cafe, Canggu | ✅ OPEN | 1 | 4.7 | false (28.8 km) |
| gofood.link/a/NsrdBg7 | Alex Villas Kitchen 5 | ✅ OPEN | 1 | 4.5 | false |
| gofood.link/a/Q8i9MZw | Nangka Dan Pisang Goreng | ❌ CLOSED | 2 | NEW | true |
| gofood.link/a/BHZmkmU | Tiramisu By MilmisyuBali | ❌ CLOSED | 2 | NEW | false |
| gofood.link/a/PTGZGz7 | SOMARI Tiramisu Bar | ❌ CLOSED | 2 | NEW | false |
| gofood.link/a/QK8wyTj | Tiramisu 2Go Bali | ✅ OPEN | 1 | NEW | false |
| gofood.link/a/Nt5i77d | Kue Tiram Ny Hok | ✅ OPEN | 1 | 4.9 | false |

**Итого**: 4 открыто, 3 закрыто

### Важное наблюдение:

Последний ресторан показывает что `deliverable=true` НЕ означает "открыто":
- **Nangka Dan Pisang Goreng**: CLOSED (core_status=2), но deliverable=true

Это подтверждает что:
- **`core.status`** → статус работы ресторана (открыт/закрыт по времени)
- **`delivery.deliverable`** → техническая возможность доставки (расстояние < limit)

## Технические детали:

### Cookies (требуются):
```
w_tsfp              - WAF fingerprint token (КРИТИЧНО!)
gf_chosen_loc       - Геолокация пользователя
_ga, _TDID_CK       - Analytics
TDC_itoken          - Session identifier
```

### __NEXT_DATA__ Structure:
```json
{
  "props": {
    "pageProps": {
      "outlet": {
        "core": {
          "status": 1,              // 1 = OPEN, 2 = CLOSED
          "displayName": "...",
          "address": {"rows": [...]},
          "tags": [...],            // taxonomy=2 для cuisines
          "openPeriods": [          // Working hours (7 days)
            {
              "day": 1,
              "startTime": {"hours": 9, "minutes": 0},
              "endTime": {"hours": 20, "minutes": 0}
            }
          ]
        },
        "ratings": {
          "average": 4.7,
          "total": 305              // Review count
        },
        "delivery": {
          "deliverable": false       // Distance-based availability
        }
      }
    }
  }
}
```

## Performance:

- **С cookies**: ~0.3-0.7 секунды на запрос
- **Без браузера**: Только HTTP requests
- **Масштабируемость**: ✅ Подходит для сотен ресторанов каждые 5 минут

## Next Steps:

1. ✅ Cookie management реализован
2. ✅ __NEXT_DATA__ парсинг с core.status
3. ✅ gofood.link redirect handling
4. ⏳ Интегрировать в Rails monitoring job
5. ⏳ Добавить cookie refresh mechanism

## Files Modified:

- `test_http_parsing/test_gojek_http.rb` - Test version with full features
- `app/services/http_gojek_parser_service.rb` - Production service
- `test_http_parsing/proxies_test.txt` - Proxy list (for WAF bypass)
- `gojek_cookies.json` - Extracted cookies from browser

---

## 🕒 Working Hours Feature (v2.1 - 2025-11-12)

### Implementation:

**Добавлено извлечение режима работы** из `outlet.core.openPeriods`.

**Example Output**:
```
Working Hours:
  Senin: 09:00-20:00
  Selasa: 09:00-20:00
  Rabu: 09:00-20:00
  Kamis: 09:00-20:00
  Jumat: 09:00-20:00
  Sabtu: 09:00-20:00
  Minggu: 09:00-16:00
```

### Test Result (Kue Tiram Ny Hok):
- ✅ Successfully extracted 7 days of working hours
- ✅ Correctly formatted with Indonesian day names
- ✅ Parsing time: 0.80-4.44 seconds (including all data)
- ✅ Data matches GoFood website modal popup

### Features:
- Array of 7 objects (Monday=1 to Sunday=7)
- Each day has: day, day_name, start_time, end_time, formatted
- No additional HTTP requests needed (data already in __NEXT_DATA__)
- UI displays working hours in test_web_parser

### Benefits:
- Restaurant owners can see operating hours
- Can calculate if restaurant should be open
- Automated schedule violation alerts
- Business analytics on operating patterns
