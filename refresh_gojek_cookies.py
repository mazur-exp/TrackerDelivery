#!/usr/bin/env python3
"""
GoJek Cookie Auto-Refresh Service
Автоматически обновляет cookies для HTTP парсера каждые 4 часа
Запускается через Procfile.dev вместе с Rails server
"""

import time
import json
from pathlib import Path
import undetected_chromedriver as uc
from datetime import datetime


class GoJekCookieRefresher:
    """Автоматическое обновление GoJek cookies без логина"""

    REFRESH_INTERVAL = 4 * 3600  # 4 часа в секундах
    HOMEPAGE_URL = "https://gofood.co.id/"
    OUTPUT_FILE = "gojek_cookies.json"

    def __init__(self):
        self.driver = None
        self.cookies_file = Path(__file__).parent / self.OUTPUT_FILE

    def init_browser(self):
        """Инициализирует undetected ChromeDriver"""
        print("🌐 Запуск Undetected ChromeDriver...")

        options = uc.ChromeOptions()
        # Headless mode для production
        options.add_argument('--headless=new')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--window-size=1920,1080')

        # Геолокация Bali (опционально, но помогает)
        prefs = {
            "profile.default_content_setting_values.geolocation": 1,
        }
        options.add_experimental_option("prefs", prefs)

        self.driver = uc.Chrome(options=options, use_subprocess=True)

        # Устанавливаем геолокацию через CDP
        try:
            self.driver.execute_cdp_cmd(
                "Emulation.setGeolocationOverride",
                {
                    "latitude": -8.66257,  # Sitara Loft, Bali (из ваших cookies)
                    "longitude": 115.15109,
                    "accuracy": 100
                }
            )
        except:
            pass  # Не критично если не сработает

        print("✅ Браузер запущен")

    def refresh_cookies(self):
        """Обновляет cookies через homepage visit"""
        print(f"\n{'='*70}")
        print(f"🔄 Обновление GoJek cookies...")
        print(f"⏰ Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*70}")

        try:
            if not self.driver:
                self.init_browser()

            # Открываем homepage
            print(f"🔗 Открываю: {self.HOMEPAGE_URL}")
            self.driver.get(self.HOMEPAGE_URL)

            # Ждём полной загрузки + WAF challenge
            print("⏳ Ожидание загрузки страницы и WAF challenge (15 сек)...")
            time.sleep(15)

            # Проверяем что страница загрузилась
            page_source = self.driver.page_source
            if len(page_source) < 5000:
                print(f"⚠️  Страница слишком маленькая ({len(page_source)} bytes), жду ещё 10 сек...")
                time.sleep(10)

            # Извлекаем cookies из браузера
            browser_cookies = self.driver.get_cookies()

            # Извлекаем localStorage
            local_storage = self.driver.execute_script(
                "return Object.entries(localStorage).reduce((obj, [key, value]) => "
                "{obj[key] = value; return obj;}, {});"
            )

            # Фильтруем только важные ключи из localStorage
            filtered_storage = {
                k: v for k, v in local_storage.items()
                if any(keyword in k.lower() for keyword in ['token', 'auth', 'w_tsfp', 'wafts'])
            }

            # Формируем cookie dict для HTTParty
            cookie_dict = {}
            for cookie in browser_cookies:
                cookie_dict[cookie['name']] = cookie['value']

            # Сохраняем
            output_data = {
                'cookies': cookie_dict,
                'localStorage': filtered_storage,
                'url': self.HOMEPAGE_URL,
                'timestamp': datetime.now().isoformat()
            }

            self.cookies_file.write_text(json.dumps(output_data, indent=2))

            print(f"\n✅ Cookies обновлены!")
            print(f"   💾 Файл: {self.cookies_file}")
            print(f"   🍪 Cookies: {len(cookie_dict)}")
            print(f"   📋 Список: {', '.join(cookie_dict.keys())}")
            print(f"   💿 localStorage: {len(filtered_storage)} items")

            return True

        except Exception as e:
            print(f"\n❌ Ошибка обновления cookies: {e}")
            # Пробуем перезапустить браузер
            if self.driver:
                try:
                    self.driver.quit()
                except:
                    pass
                self.driver = None
            return False

    def run_forever(self):
        """Основной loop - обновление каждые 4 часа"""
        print("\n" + "="*70)
        print("🚀 GoJek Cookie Auto-Refresh Service")
        print("="*70)
        print(f"📁 Output: {self.cookies_file}")
        print(f"⏱️  Interval: {self.REFRESH_INTERVAL // 3600} hours")
        print(f"🔄 Режим: Непрерывный loop")
        print("="*70 + "\n")

        try:
            while True:
                success = self.refresh_cookies()

                if success:
                    next_refresh = datetime.now().timestamp() + self.REFRESH_INTERVAL
                    next_refresh_dt = datetime.fromtimestamp(next_refresh)

                    print(f"\n⏰ Следующее обновление: {next_refresh_dt.strftime('%Y-%m-%d %H:%M:%S')}")
                    print(f"😴 Sleep {self.REFRESH_INTERVAL // 3600} hours...\n")

                    time.sleep(self.REFRESH_INTERVAL)
                else:
                    print("\n⚠️  Обновление не удалось, retry через 5 минут...")
                    time.sleep(300)

        except KeyboardInterrupt:
            print("\n\n⏹️  Остановка сервиса...")
            self.cleanup()
        except Exception as e:
            print(f"\n❌ Критическая ошибка: {e}")
            self.cleanup()
            raise

    def cleanup(self):
        """Закрывает браузер"""
        if self.driver:
            print("🔒 Закрытие браузера...")
            try:
                self.driver.quit()
            except:
                pass
            self.driver = None


def main():
    refresher = GoJekCookieRefresher()
    refresher.run_forever()


if __name__ == "__main__":
    main()
