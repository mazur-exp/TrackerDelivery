#!/usr/bin/env python3
"""
Grab JWT Auto-Refresh Service
Автоматически обновляет JWT токен для Grab Food API каждые 20 часов
Использует selenium-wire для перехвата HTTP headers
"""

import undetected_chromedriver as uc
# from seleniumwire import webdriver as wire_webdriver  # NOT USED - commented out
import time
import json
import sys
import os
from datetime import datetime
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def log(message):
    """Print timestamped log message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")
    sys.stdout.flush()

def refresh_grab_jwt():
    """
    Refresh Grab JWT token by:
    1. Opening Grab Food page with undetected Chrome
    2. Intercepting network requests to capture JWT from headers
    3. Saving JWT + cookies to grab_cookies.json
    """
    log("🔄 Обновление Grab JWT token...")

    jwt_token = None
    api_version = None

    try:
        # Setup Chrome options with MAXIMUM stealth for headless
        options = uc.ChromeOptions()

        # Use new headless mode (Chrome 109+) - harder to detect than old headless
        # options.add_argument('--headless=new')  # DISABLED for testing - visible mode!

        # Make window visible and maximized for debugging
        options.add_argument('--start-maximized')

        # Critical anti-detection flags
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-blink-features=AutomationControlled')
        options.add_argument('--disable-features=IsolateOrigins,site-per-process')

        # Window and display settings
        options.add_argument('--window-size=1920,1080')
        options.add_argument('--start-maximized')

        # Hide headless indicators
        options.add_argument('--disable-gpu')
        options.add_argument('--disable-software-rasterizer')
        options.add_argument('--disable-extensions')

        # Realistic user agent
        options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36')

        # Additional stealth
        options.add_argument('--disable-infobars')
        options.add_argument('--lang=en-US,en;q=0.9')

        # Auto-allow geolocation popup
        prefs = {
            "profile.default_content_setting_values.geolocation": 1,
            "credentials_enable_service": False,
            "profile.password_manager_enabled": False
        }
        options.add_experimental_option("prefs", prefs)

        # Enable performance logging to capture network requests
        options.set_capability('goog:loggingPrefs', {'performance': 'ALL'})

        log("🚀 Запуск Undetected ChromeDriver (headless=new с maximum stealth)...")
        driver = uc.Chrome(options=options, use_subprocess=True, version_main=None)

        # CRITICAL: Override navigator.webdriver after browser starts
        driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
            'source': '''
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined
                });

                // Override chrome object to hide automation
                window.chrome = {
                    runtime: {}
                };

                // Override permissions
                const originalQuery = window.navigator.permissions.query;
                window.navigator.permissions.query = (parameters) => (
                    parameters.name === 'notifications' ?
                        Promise.resolve({ state: Notification.permission }) :
                        originalQuery(parameters)
                );

                // Mock plugins
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [1, 2, 3, 4, 5]
                });

                // Mock languages
                Object.defineProperty(navigator, 'languages', {
                    get: () => ['en-US', 'en']
                });
            '''
        })

        # Set geolocation to Bali BEFORE enabling network
        driver.execute_cdp_cmd("Emulation.setGeolocationOverride", {
            "latitude": -8.6705,
            "longitude": 115.2126,
            "accuracy": 100
        })

        # Load existing cookies to establish session BEFORE opening page
        cookies_file = 'grab_cookies.json'
        if os.path.exists(cookies_file):
            log("🍪 Загрузка существующих cookies из grab_cookies.json...")
            try:
                with open(cookies_file, 'r') as f:
                    data = json.load(f)
                    # First navigate to domain to set cookies
                    log("🔄 Открываем Grab homepage для установки cookies...")
                    driver.get('https://food.grab.com/')
                    time.sleep(3)
                    # Add cookies
                    for name, value in data.get('cookies', {}).items():
                        try:
                            driver.add_cookie({'name': name, 'value': value, 'domain': '.grab.com'})
                        except Exception as cookie_err:
                            pass  # Some cookies may fail, it's OK
                    log(f"✅ Загружено {len(data.get('cookies', {}))} cookies")
            except Exception as e:
                log(f"⚠️  Ошибка загрузки cookies: {e}")

        # Enable Network domain and set up request interception BEFORE page load
        log("🔍 Включаем перехват network requests через CDP...")
        driver.execute_cdp_cmd('Network.enable', {})

        # Store captured JWT in a list that we can access later
        captured_requests = []

        def capture_request(request):
            """Callback to capture network requests with headers"""
            if 'portal.grab.com/foodweb/guest/v2' in request.get('request', {}).get('url', ''):
                captured_requests.append(request)

        # This won't work in Selenium directly, we need different approach
        # Use execute_cdp_cmd to enable request interception
        driver.execute_cdp_cmd('Network.setRequestInterception', {'patterns': [{'urlPattern': '*portal.grab.com*'}]})

        log("🌐 Открываем страницу Grab Food...")
        # Use a known restaurant URL
        test_url = "https://food.grab.com/id/en/restaurant/online-delivery/6-C65ZV62KVNEDPE"
        driver.get(test_url)

        # Debug: Check page loaded
        log(f"📄 Page title: {driver.title}")
        log(f"📄 Page HTML length: {len(driver.page_source)} bytes")

        # Save HTML for debugging
        with open('debug_grab_page.html', 'w', encoding='utf-8') as f:
            f.write(driver.page_source)
        log(f"💾 HTML сохранен в debug_grab_page.html для анализа")

        # Check for JavaScript errors
        try:
            js_errors = driver.execute_script("return window.__jsErrors || [];")
            if js_errors:
                log(f"⚠️  JavaScript errors: {js_errors}")
        except:
            pass

        # Check if React is waiting for login
        is_logged_in = driver.execute_script("return window.dataLayer && window.dataLayer.find(d => d.userLogin !== undefined)?.userLogin;")
        log(f"🔑 User logged in: {is_logged_in}")

        log("⏳ Ожидание полной загрузки React приложения...")
        # Wait for restaurant name to appear (means React loaded and made API calls)
        try:
            wait = WebDriverWait(driver, 20)
            wait.until(EC.presence_of_element_located(("xpath", "//h1[contains(text(), 'Healthy Fit')]")))
            log("✅ Страница загрузилась, React сделал API запросы")
        except Exception as e:
            log(f"⚠️  Элемент 'Healthy Fit' не найден за 20 сек")
            # Debug: Check what's on the page
            try:
                h1_elements = driver.find_elements("tag name", "h1")
                log(f"📄 Найдено h1 элементов: {len(h1_elements)}")
                if h1_elements:
                    for i, h1 in enumerate(h1_elements[:3]):
                        log(f"   h1[{i}]: {h1.text[:50]}")
            except:
                pass

        # Additional wait for API calls to complete
        time.sleep(2)

        log("🔍 Извлечение JWT из CDP Network requests...")

        try:
            # Get ALL network logs from CDP performance
            logs = driver.get_log('performance')
            log(f"📊 Получено {len(logs)} CDP events")

            for entry in logs:
                try:
                    log_entry = json.loads(entry['message'])['message']
                    method = log_entry.get('method', '')

                    # Look for Network.requestWillBeSent events (contains headers!)
                    if method == 'Network.requestWillBeSent':
                        request = log_entry['params']['request']
                        url = request.get('url', '')

                        # Check if this is a request to Grab Guest API
                        if 'portal.grab.com/foodweb/guest/v2/merchants' in url:
                            headers = request.get('headers', {})

                            # Found the API request! Extract JWT
                            # Headers are case-sensitive! Use exact case from CDP
                            if 'X-Hydra-JWT' in headers:
                                jwt_token = headers['X-Hydra-JWT']
                                api_version = headers.get('X-Grab-Web-App-Version', 'uaf6yDMWlVv0CaTK5fHdB')
                                log(f"✅ JWT извлечен из request к {url}")
                                log(f"   JWT: {jwt_token[:80]}...")
                                log(f"   API version: {api_version}")
                                break
                            else:
                                # Debug: print all headers to see what we have
                                log(f"⚠️  Найден запрос к API но без x-hydra-jwt header")
                                log(f"   URL: {url}")
                                log(f"   Headers: {list(headers.keys())}")

                except (KeyError, json.JSONDecodeError, TypeError) as e:
                    continue

            if not jwt_token:
                log("⚠️  JWT не найден ни в одном Network.requestWillBeSent event")
                log("   Попробуем другие CDP события...")

                # Try responseReceived events
                for entry in logs:
                    try:
                        log_entry = json.loads(entry['message'])['message']
                        if log_entry.get('method') == 'Network.responseReceived':
                            response = log_entry['params']['response']
                            if 'portal.grab.com/foodweb/guest/v2' in response.get('url', ''):
                                log(f"📍 Нашли response от API: {response.get('url')}")
                                # Response doesn't have request headers, only response headers
                    except:
                        continue

        except Exception as e:
            log(f"❌ Ошибка при извлечении JWT из CDP: {e}")
            import traceback
            log(f"   {traceback.format_exc()}")

        # Extract cookies
        log("🍪 Извлечение cookies...")
        cookies_list = driver.get_cookies()
        cookies = {cookie['name']: cookie['value'] for cookie in cookies_list}
        log(f"✅ Извлечено {len(cookies)} cookies")

        driver.quit()
        log("🔒 Browser закрыт")

        # Save to file
        if jwt_token:
            data = {
                'cookies': cookies,
                'jwt_token': jwt_token,
                'api_version': api_version or 'uaf6yDMWlVv0CaTK5fHdB',
                'timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z')
            }

            with open('grab_cookies.json', 'w') as f:
                json.dump(data, f, indent=2)

            log(f"✅ JWT token сохранен в grab_cookies.json")
            log(f"   JWT: {jwt_token[:50]}...")
            log(f"   API version: {api_version}")
            log(f"   Cookies: {len(cookies)} шт")
            log(f"   Timestamp: {data['timestamp']}")

            return True
        else:
            log("⚠️  ВНИМАНИЕ: JWT token не найден в network requests!")
            log("   Возможные причины:")
            log("   - Страница не загрузилась полностью")
            log("   - API запрос не был выполнен")
            log("   - Изменился формат headers")
            log("   Попробуйте увеличить время ожидания или проверить URL")

            # Save cookies anyway (may still be useful)
            data = {
                'cookies': cookies,
                'jwt_token': None,
                'api_version': None,
                'timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z'),
                'error': 'JWT not found in network requests'
            }

            with open('grab_cookies.json', 'w') as f:
                json.dump(data, f, indent=2)

            return False

    except Exception as e:
        log(f"❌ Ошибка при обновлении JWT: {e}")
        log(f"   Тип ошибки: {type(e).__name__}")
        import traceback
        log(f"   Traceback: {traceback.format_exc()}")
        return False

def main():
    """
    Main loop: refresh JWT every 20 hours
    """
    log("🚀 Grab JWT Auto-Refresh Service запущен!")
    log("📍 Режим работы: обновление каждые 20 часов")
    log("⏹️  Для остановки нажмите Ctrl+C")
    log("-" * 60)

    # First run immediately
    success = refresh_grab_jwt()

    if success:
        log("✅ Первичное обновление JWT успешно завершено")
    else:
        log("⚠️  Первичное обновление завершено с предупреждениями")

    log("-" * 60)

    # Then loop every 20 hours
    while True:
        sleep_hours = 20
        sleep_seconds = sleep_hours * 3600

        log(f"💤 Следующее обновление через {sleep_hours} часов...")
        log(f"   (в {datetime.fromtimestamp(time.time() + sleep_seconds).strftime('%Y-%m-%d %H:%M:%S')})")

        try:
            time.sleep(sleep_seconds)
        except KeyboardInterrupt:
            log("\n⏹️  Получен сигнал остановки (Ctrl+C)")
            log("👋 Сервис остановлен")
            sys.exit(0)

        log("-" * 60)
        log("⏰ Время обновления!")

        success = refresh_grab_jwt()

        if success:
            log("✅ Обновление JWT успешно завершено")
        else:
            log("⚠️  Обновление завершено с предупреждениями")

        log("-" * 60)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        log("\n⏹️  Получен сигнал остановки (Ctrl+C)")
        log("👋 Сервис остановлен")
        sys.exit(0)
    except Exception as e:
        log(f"❌ Критическая ошибка: {e}")
        import traceback
        log(traceback.format_exc())
        sys.exit(1)
