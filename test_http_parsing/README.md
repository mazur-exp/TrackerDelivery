# GoJek HTTP Parser - Quick Start Guide

**Обновлено**: 2025-11-11 (20:00 Bali time)

✅ **РАБОТАЕТ!** Cookie-based HTTP parsing с auto-refresh механизмом.

## Структура файлов

- `test_grab_http.rb` - HTTP парсер для Grab URLs
- `test_gojek_http.rb` - HTTP парсер для GoJek URLs  
- `performance_comparison.rb` - сравнение производительности
- `load_test_urls.rb` - загрузчик URL из файла
- `test_urls.txt` - список URL для тестирования
- `README.md` - эта инструкция

## Установка зависимостей

```bash
gem install httparty nokogiri
```

## 🚀 Быстрый старт

### 1. Запуск development сервера с auto-refresh:

```bash
# Из корня TrackerDelivery:
bin/dev
```

Автоматически запустятся:
- Rails server (port 3000)
- SolidQueue jobs
- Ngrok tunnel
- **GoJek Cookie Refresh Service** (каждые 4 часа)

### 2. Тестирование GoJek парсера:

```bash
cd test_http_parsing
ruby test_gojek_http.rb "https://gofood.link/a/MrswDDW"
```

**Вывод**:
```
✅ Loaded 6 cookies from file
Status: {is_open: true, status_text: "open", core_status: 1}
Rating: 4.7
```

### 2. Массовое тестирование

1. Добавьте реальные URL в `test_urls.txt`:
```
grab,https://food.grab.com/id/en/restaurant/warung-nasi/IDGFTI123
gojek,https://gofood.gojek.com/jakarta/restaurant/rumah-makan-456
```

2. Запустите тестирование:
```bash
ruby load_test_urls.rb
```

### 3. Сравнение производительности

```bash
ruby performance_comparison.rb
```

## Что тестируется

### Извлекаемые данные
- ✅ Название ресторана
- ✅ Адрес
- ✅ Рейтинг
- ✅ Список кухонь (cuisines)
- ✅ URL изображения
- ✅ Статус (открыт/закрыт)
- ✅ Координаты (только Grab)

### Метрики производительности
- ⏱️ Время выполнения (ожидается 2-15 сек vs 30-60 сек Chrome)
- ✅ Процент успешных парсингов
- 📊 Качество данных (0-100%)
- 🎯 Достаточность для онбординга

## Ожидаемые результаты

### HTTP парсинг
- **Скорость**: 2-15 секунд
- **Успешность**: 70-90% (зависит от структуры страниц)
- **Качество данных**: 60-85%

### Chrome парсинг (для сравнения)
- **Скорость**: 30-60 секунд
- **Успешность**: 95-99%
- **Качество данных**: 85-95%

## Принцип работы

### Grab парсер
1. HTTP запрос к странице ресторана
2. Поиск JSON данных в `<script>` тегах
3. Извлечение данных по паттернам: `"props".*"ssrRestaurantData"`
4. Fallback на DOM парсинг если JSON не найден

### GoJek парсер  
1. HTTP запрос к странице ресторана
2. DOM парсинг с CSS селекторами
3. Поиск в meta тегах и JSON-LD
4. Обработка индонезийских локализаций

## 📊 GoJek core.status Values

| Value | Meaning | Когда |
|-------|---------|-------|
| **1** | OPEN | Ресторан работает, принимает заказы |
| **2** | CLOSED | Закрыт (вне рабочих часов или временно) |
| **7** | CLOSING_SOON | Скоро закрывается (< 21-30 минут) |

**Важно**: `core.status` ≠ `delivery.deliverable`
- `core.status` = работает ли ресторан
- `delivery.deliverable` = можно ли доставить на ваш адрес (зависит от расстояния)

## ✅ Что работает (GoJek с cookies)

- ✅ Точный статус OPEN/CLOSED через `core.status`
- ✅ Rating и review count
- ✅ Полный адрес
- ✅ Cuisines (правильные, из tags)
- ✅ **Working hours (openPeriods)** - режим работы на всю неделю
- ✅ Быстро (~0.5-0.8 сек на ресторан)
- ✅ Масштабируемо (100+ ресторанов)

## Рекомендации

1. **Используйте HTTP для быстрого онбординга**
2. **Fallback на Chrome при неудаче HTTP**
3. **Обновляйте селекторы при изменениях сайтов**
4. **Мониторьте процент успешности**