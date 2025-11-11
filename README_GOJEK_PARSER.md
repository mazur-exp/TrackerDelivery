# GoJek HTTP Parser - Documentation

**Дата**: 2025-11-11
**Статус**: ✅ Production Ready

---

## 📚 Документация

Вся документация находится в **`ai_docs/development/`**:

### 🚀 Quick Start:
```bash
# 1. Запуск с auto-refresh cookies:
bin/dev

# 2. Тестирование:
cd test_http_parsing
ruby test_gojek_http.rb "https://gofood.link/a/MrswDDW"
```

### 📖 Читать документацию:

1. **HTTP Parser Specification**
   ```
   ai_docs/development/http_gojek_parser_specification.md
   ```
   Полная техническая документация HTTP парсера

2. **Cookie Refresh Service**
   ```
   ai_docs/development/gojek_cookie_refresh_service.md
   ```
   Auto-refresh mechanism, Procfile.dev integration

3. **Research & History**
   ```
   GOJEK_TOKEN_RESEARCH.md
   ```
   История исследования, что пробовали, финальное решение

4. **Test Results**
   ```
   test_http_parsing/TEST_RESULTS.md
   ```
   Результаты тестирования 7 URLs

---

## ✅ Key Facts

- ✅ HTTP парсинг с cookies - **0.5 сек на ресторан**
- ✅ Auto-refresh каждые 4 часа - **БЕЗ логина!**
- ✅ `core.status`: 1=OPEN, 2=CLOSED, 7=CLOSING_SOON
- ✅ Production ready

---

## 📁 Файлы

- `refresh_gojek_cookies.py` - Cookie refresh service
- `gojek_cookies.json` - Актуальные cookies (auto-updated)
- `app/services/http_gojek_parser_service.rb` - Production parser
- `test_http_parsing/test_gojek_http.rb` - Test parser
- `Procfile.dev` - Updated with gojek_cookies process

---

**См. ai_docs/development/ для полной документации**
