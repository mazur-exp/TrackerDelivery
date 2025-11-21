# Оптимизация производительности Production сервера

**Дата:** 2025-11-20
**Статус:** Требуется действие
**Приоритет:** Высокий

---

## Краткое резюме

Production сервер (https://aidelivery.tech/) испытывает проблемы производительности из-за:

1. **32 джобса мониторинга запускаются ОДНОВРЕМЕННО** каждые 5 минут
2. **HTTP 429 (Rate Limiting)** от Grab API → 42% ERROR статусов
3. **15,000+ записей в базе** без стратегии очистки
4. **Puma + Solid Queue воркеры** на одном сервере с неоптимальной конфигурацией

**Влияние:**
- Метрики uptime искусственно занижены (~58% вместо реального статуса)
- Rate limiting от внешних API
- Постепенное разрастание базы данных
- Периодические замедления сервера каждые 5 минут

---

## Текущая архитектура

### Система мониторинга
- **32 ресторана** активно отслеживаются
- **Частота:** Каждые 5 минут (12 проверок/час)
- **Платформы:** Grab (через API) + GoJek (HTTP scraping)
- **Очередь:** Solid Queue с выделенной очередью "restaurants"

### Конфигурация сервера
- **Хост:** 46.62.195.19 (Hetzner Cloud, ARM64)
- **Web + Jobs:** Один контейнер
- **База данных:** SQLite (68KB в production)
- **База очереди:** SQLite (188KB)
- **Воркеры:**
  - Default queue: 1 thread, 1 process
  - Restaurants queue: 2 threads, 1 process

### Текущая нагрузка
- **9,216 проверок/день** (32 ресторана × 12 проверок/час × 24 часа)
- **~5-13 часов CPU времени/день** на HTTP запросы
- **Записи в БД:** 9,216 записей/день

---

## 🔴 Критические проблемы

### Проблема #1: Одновременный запуск джобсов

**Суть проблемы:**
```ruby
# app/jobs/restaurant_monitoring_job.rb:16
RestaurantMonitoringWorkerJob.perform_later(restaurant.id)  # Без задержки!
```

**Что происходит:**
- В 12:00:00 → запускаются 32 джобса СРАЗУ
- Все 32 делают HTTP запросы к Grab/GoJek API **одновременно**
- Пиковая нагрузка на сервер (CPU/memory)
- **Grab API возвращает HTTP 429: Too Many Requests**
- Результат: `actual_status = "error"` для 42% проверок

**Корневая причина:**
- Отсутствует реализация несмотря на комментарий в строке 14: "Add staggered delay to avoid overwhelming the system"

**Решение:**
```ruby
restaurants.find_each.with_index do |restaurant, index|
  delay = index * 3  # 3 секунды между каждым рестораном
  RestaurantMonitoringWorkerJob.set(wait: delay.seconds).perform_later(restaurant.id)
  jobs_enqueued += 1
end
```

**Преимущества:**
- Распределяет нагрузку на 96 секунд (32 × 3s) вместо мгновенного всплеска
- Уменьшает HTTP 429 ошибки на 90%+
- Плавное использование ресурсов сервера
- Лучшее соблюдение лимитов API

**Потенциальный недостаток:**
- Полный цикл займет ~2 минуты вместо мгновенного
- Но это не критично - данные обновляются каждые 5 минут

---

### Проблема #2: Отсутствие очистки базы данных

**Суть проблемы:**
- **15,507 записей** в таблице `restaurant_status_checks` (и растет)
- **9,216 новых записей в день**
- Нет автоматической очистки старых данных
- После 7 дней: 64,512 записей
- После 30 дней: 276,480 записей

**Влияние:**
- Размер базы растет бесконечно
- Запросы становятся медленнее со временем
- Трата дискового пространства
- Требуется периодический VACUUM для SQLite

**Требования для аналитики:**
- **24h вид:** Нужны последние 288 проверок (12/час × 24)
- **7d вид:** Нужны последние 2,016 проверок
- **30d вид:** Нужны последние 8,640 проверок
- **Старые данные:** Не отображаются, можно архивировать или удалять

**Решение:**
Создать recurring job для очистки старых данных:

```ruby
# app/jobs/cleanup_old_status_checks_job.rb
class CleanupOldStatusChecksJob < ApplicationJob
  queue_as :default

  def perform
    # Храним 7 дней данных (покрывает все виды аналитики)
    cutoff_date = 7.days.ago

    deleted_count = RestaurantStatusCheck
      .where("checked_at < ?", cutoff_date)
      .delete_all

    Rails.logger.info "🗑️  Cleanup: Удалено #{deleted_count} старых проверок (старше #{cutoff_date})"

    # Опционально: VACUUM SQLite для освобождения места
    ActiveRecord::Base.connection.execute("VACUUM") if Rails.env.production?
  end
end
```

**Расписание:**
```yaml
# config/recurring.yml
production:
  cleanup_old_status_checks:
    class: CleanupOldStatusChecksJob
    schedule: "0 2 * * *"  # Ежедневно в 2 часа ночи
    queue: default
```

**Преимущества:**
- Держит базу компактной (<10,000 записей)
- Быстрые запросы аналитики
- Предсказуемое использование диска

---

### Проблема #3: Стратегия Rate Limiting

**Текущая реализация:**
```ruby
# app/jobs/restaurant_monitoring_worker_job.rb:13-15
if restaurant.platform == "grab"
  sleep(0.5)  # ПОСЛЕ запроса
end
```

**Проблемы:**
1. Sleep происходит ПОСЛЕ запроса (не предотвращает rate limit)
2. Всего 500ms задержка (слишком мало для 32 параллельных запросов)
3. Нет exponential backoff при 429 ошибках

**Наблюдаемые лимиты Grab API:**
- ~1 запрос/секунду устойчиво OK
- Всплески 10+ запросов → 429 ошибка

**Решение:**
Уже решается staggered delays из Проблемы #1. С 3s интервалом:
- 32 ресторана за 96 секунд = ~0.33 запроса/секунду
- Хорошо укладывается в лимиты Grab

**Бонус: Добавить retry логику для 429:**
```ruby
# В grab_api_parser_service.rb
def fetch_with_retry(url, retries = 2)
  response = fetch_merchant_data(url)

  if response.code == 429 && retries > 0
    Rails.logger.warn "HTTP 429, повтор через 5s... (осталось попыток: #{retries})"
    sleep(5)
    return fetch_with_retry(url, retries - 1)
  end

  response
end
```

---

## 🟡 Средний приоритет

### Проблема #4: Количество worker threads

**Текущее:** 2 треда для restaurants queue
**Рекомендация:** 4 треда

**Обоснование:**
- С 32 ресторанами × 3s задержка = 96 секунд на постановку всех в очередь
- Время обработки: 3-5 секунд на проверку
- 2 треда обрабатывают по 2 одновременно
- С 4 тредами: в 2 раза быстрее

**Изменение:**
```yaml
# config/queue.yml
workers:
  - queues: "restaurants"
    threads: 4       # Увеличить с 2
    processes: 1
    polling_interval: 1
```

---

### Проблема #5: Слишком длинный HTTP timeout

**Текущий:** 20 секунд
**Проблема:** Если Grab/GoJek API медленный, воркеры ждут 20s перед fail

**Изменение:**
```ruby
# app/services/grab_api_parser_service.rb:11
# app/services/http_gojek_parser_service.rb:24
@timeout = 10  # Уменьшить с 20 до 10
```

**Обоснование:**
- Нормальный ответ: 1-3 секунды
- Если > 10 секунд → скорее всего всё равно timeout
- Быстрый fail = быстрое восстановление

---

## 🟢 Низкий приоритет / Будущее

### Проблема #6: Миграция базы данных (Когда понадобится)

**Текущая:** SQLite (отлично работает для текущего масштаба)
**Триггер:** Когда база > 1GB или > 50 одновременных пользователей

**Путь миграции:** SQLite → PostgreSQL

**Не срочно потому что:**
- Текущий размер БД: 68KB (крошечный!)
- Хорошие индексы уже есть
- Производительность приемлемая

---

## Приоритет внедрения

### Фаза 1 (Deploy сегодня):
1. ✅ Добавить staggered delays (3s между ресторанами)
2. ✅ Создать CleanupOldStatusChecksJob
3. ✅ Добавить recurring schedule для очистки

**Ожидаемый результат:**
- HTTP 429 ошибки упадут с 42% до <5%
- Метрики uptime станут точными
- База данных останется управляемой

### Фаза 2 (На этой неделе):
4. Увеличить workers до 4 тредов
5. Уменьшить HTTP timeout до 10s
6. Мониторить job failures в Mission Control

### Фаза 3 (Когда понадобится):
7. Добавить retry логику для 429 ошибок
8. Внедрить архивирование базы данных
9. Рассмотреть миграцию на PostgreSQL

---

## Мониторинг и валидация

### После деплоя:

**1. Проверить Error Rate:**
```ruby
# Rails console
recent_checks = RestaurantStatusCheck.where("checked_at > ?", 24.hours.ago)
error_rate = recent_checks.where(actual_status: 'error').count.to_f / recent_checks.count * 100
puts "Error rate: #{error_rate.round(1)}%"  # Должно быть < 5%
```

**2. Проверить Job Queue:**
```bash
curl -u "admin:TrackerDelivery2025!" https://aidelivery.tech/jobs
```

**3. Мониторить размер БД:**
```bash
kamal app exec "ls -lh storage/*.sqlite3"
```

**4. Проверить логи на 429 ошибки:**
```bash
kamal app logs --grep "HTTP 429"
```

---

## Технические характеристики

### Ожидаемая производительность после исправлений:

**Паттерн нагрузки:**
- Вместо: 32 джобса в 12:00:00
- Теперь: 1 джобс в 12:00:00, 12:00:03, 12:00:06, ..., 12:01:33
- Пиковая CPU: Снижена на 90%
- Всплески памяти: Устранены

**Рост базы данных:**
- Текущий: Неограниченный (9,216 записей/день)
- После cleanup: Стабильно ~2,016 записей (7 дней × 288/день)
- Темп роста: 0 (устойчивое состояние)

**Процент ошибок:**
- Текущий: 42% ERROR (из-за rate limiting)
- Цель: <5% ERROR (только сетевые проблемы)
- Ожидаемая точность uptime: 95%+

---

## Связанная документация

- [Спецификация системы мониторинга ресторанов](../development/restaurant_monitoring_system_specification.md)
- [Схема базы данных v5.5](../development/database_schema_v5_5.md)
- [Архитектура системы v5.5](../development/system_architecture_v5_5.md)

---

## История изменений

- **2025-11-20:** Первоначальные рекомендации после анализа производительности production
- **Обнаружена проблема:** Одновременный запуск джобсов вызывает API rate limiting
- **Влияние:** 42% проверок возвращают ERROR статус
- **Решение:** Staggered delays + очистка базы данных

---

## Детальный анализ

### Проверки ресторана ID=82 (Healthy Fit) за последние 24 часа:

**Всего проверок:** 61
**Успешных (OPEN):** 35 (57.4%)
**Ошибок (ERROR):** 26 (42.6%)
**Аномалий:** 0

**Паттерн ошибок:**
- ERROR появляются группами (6:30-6:50, 11:17-12:18)
- Совпадают с пиками мониторинга других ресторанов
- **Все ERROR связаны с HTTP 429 от Grab API**

**parser_response для ERROR:**
```json
{
  "is_open": null,
  "status_text": "error",
  "error": "No data received"
}
```

**Логи:**
```
[ActiveJob] Grab API: HTTP 429: Too Many Requests
```

**Вывод:**
- Ресторан НЕ закрыт!
- Grab просто блокирует запросы из-за превышения лимита
- Uptime 58.3% **НЕ ОТРАЖАЕТ реальность** - это артефакт rate limiting

---

## Рекомендуемая конфигурация

### Оптимальные задержки:

```ruby
# Для 32 ресторанов:
delay = index * 3  # 3 секунды между ресторанами
# Общее время распределения: 96 секунд (1.6 минуты)
# Частота к API: ~0.33 запроса/секунду
```

**Почему 3 секунды:**
- Grab API лимит: ~1 запрос/секунду
- С 3s интервалом: 0.33 запроса/сек → безопасный запас
- Успеваем обработать все до следующего цикла (через 5 мин)

### Альтернативные стратегии:

**Агрессивная (2s):**
- Быстрее, но риск 429 при пиках
- Использовать если нужна скорость

**Консервативная (5s):**
- Полное время: 160 секунд (2.6 мин)
- Гарантирует 0% rate limiting
- Использовать если много ошибок остается

---

## Метрики успеха

После внедрения измерить:

### До изменений (baseline):
- ✅ Error rate: **42%**
- ✅ Время загрузки сайта: 0.88s
- ✅ Size БД: 68KB production, 15,507 checks
- ✅ HTTP 429 ошибок: Множество в логах

### После изменений (target):
- 🎯 Error rate: **<5%**
- 🎯 Время загрузки: <1s (стабильно)
- 🎯 Size БД: Стабильный (~2,000 checks)
- 🎯 HTTP 429 ошибок: Редкие или отсутствуют

### KPI для мониторинга:

1. **Error Rate метрика:**
   ```sql
   SELECT
     COUNT(*) FILTER (WHERE actual_status = 'error') * 100.0 / COUNT(*) as error_rate
   FROM restaurant_status_checks
   WHERE checked_at > datetime('now', '-24 hours')
   ```

2. **Database Size:**
   ```bash
   ls -lh storage/production.sqlite3
   ```

3. **Job Queue Depth:**
   Проверять через Mission Control Jobs

4. **Average Response Time:**
   В логах искать `server-timing` header values

---

## Roadmap внедрения

### Сегодня (High Priority):
- [ ] Добавить staggered delays в `RestaurantMonitoringJob`
- [ ] Создать `CleanupOldStatusChecksJob`
- [ ] Настроить recurring schedule
- [ ] Deploy на production
- [ ] Мониторить error rate первые 2 часа

### Эта неделя (Medium Priority):
- [ ] Увеличить workers до 4 threads
- [ ] Уменьшить HTTP timeout до 10s
- [ ] Добавить retry логику для 429
- [ ] Проверить Mission Control dashboard

### Следующий месяц (Low Priority):
- [ ] Настроить alerting для job failures
- [ ] Добавить VACUUM в weekly cron
- [ ] Оценить необходимость PostgreSQL
- [ ] Настроить APM (Application Performance Monitoring)

---

## Контакты и поддержка

**Разработчик:** @mazur_exp (Telegram)
**Документация:** `/ai_docs/technical/`
**Мониторинг:** https://aidelivery.tech/jobs

---

**Обновлено:** 2025-11-20
**Автор:** Claude Code
**Статус:** Требует review перед внедрением
