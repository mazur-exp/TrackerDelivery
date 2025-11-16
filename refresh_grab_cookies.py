#!/usr/bin/env python3
"""
Grab Cookie & JWT Auto-Refresh Service

Periodically refreshes Grab cookies and extracts x-hydra-jwt token
by visiting food.grab.com with undetected-chromedriver.

The JWT token is required for API calls to portal.grab.com/foodweb/guest/v2/merchants/
"""

import undetected_chromedriver as uc
import time
import json
import sys
from datetime import datetime
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def setup_chrome_options():
    """Configure Chrome options for headless operation with Bali geolocation"""
    options = uc.ChromeOptions()

    # Headless mode
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')

    # Browser fingerprinting
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36')

    # Performance
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-notifications')

    return options

def extract_hydra_jwt(driver):
    """
    Extract x-hydra-jwt from network requests using CDP

    Strategy: Enable Network tracking via CDP, visit restaurant page, intercept API request
    """
    print("🔍 Extracting x-hydra-jwt from network requests...")

    # Enable Network domain in Chrome DevTools Protocol
    driver.execute_cdp_cmd('Network.enable', {})

    # Storage for captured JWT
    captured_jwt = {'token': None}

    def request_interceptor(params):
        """Callback to intercept network requests"""
        request = params.get('request', {})
        headers = request.get('headers', {})

        # Check if this is the merchants API call
        if '/merchants/' in request.get('url', ''):
            jwt = headers.get('x-hydra-jwt') or headers.get('X-Hydra-Jwt')
            if jwt:
                captured_jwt['token'] = jwt
                print(f"✅ Captured x-hydra-jwt from {request['url'][:60]}...")

    # Add listener for requests
    # Note: undetected-chromedriver doesn't support add_listener, so we'll use a different approach

    # Navigate to a test restaurant page
    test_url = "https://food.grab.com/id/en/restaurant/healthy-fit-bowl-pasta-salad-wrap-bali-canggu-delivery/6-C65ZV62KVNEDPE"
    print(f"🌐 Navigating to test restaurant page...")
    driver.get(test_url)

    # Wait for page to load and make API calls
    print("⏳ Waiting for page to load and API calls to complete...")
    time.sleep(10)

    # Try to extract JWT from browser's fetch monitoring
    jwt_extraction_script = """
    // Check if JWT is in sessionStorage or localStorage
    const jwtFromStorage = sessionStorage.getItem('x-hydra-jwt') ||
                          localStorage.getItem('x-hydra-jwt') ||
                          sessionStorage.getItem('jwt') ||
                          localStorage.getItem('jwt');

    if (jwtFromStorage) {
        return {source: 'storage', jwt: jwtFromStorage};
    }

    // Try to re-trigger API call and capture from performance
    // This doesn't give us headers, but confirms the call was made
    const entries = performance.getEntriesByType('resource');
    const merchantCall = entries.find(e => e.name.includes('/merchants/'));

    return {
        source: 'performance',
        jwt: null,
        apiCalled: !!merchantCall,
        apiUrl: merchantCall?.name
    };
    """

    result = driver.execute_script(jwt_extraction_script)
    print(f"📊 Extraction attempt: {result}")

    if result.get('jwt'):
        print(f"✅ Found JWT in {result['source']}")
        return result['jwt']

    # If JWT not in storage, we need to capture it from actual network request
    # For now, return None - JWT will need to be extracted manually first time
    print("⚠️  JWT not found in automatic extraction")
    print("💡 Tip: Run with Chrome DevTools open to manually extract JWT for first time")

    return None

def refresh_grab_cookies():
    """
    Main function to refresh Grab cookies and JWT

    Returns: dict with cookies and jwt token
    """
    print("\n" + "="*50)
    print("🔄 Refreshing Grab cookies and JWT...")
    print("="*50)

    driver = None
    try:
        # Setup Chrome
        options = setup_chrome_options()
        driver = uc.Chrome(options=options, version_main=142)

        # Set Bali geolocation (optional - for local results)
        driver.execute_cdp_cmd("Emulation.setGeolocationOverride", {
            "latitude": -8.66257,
            "longitude": 115.15109,
            "accuracy": 100
        })

        print("🌐 Opening Grab homepage...")
        driver.get('https://food.grab.com/')

        # Wait for page to fully load and WAF to complete
        print("⏳ Waiting for page load and WAF verification...")
        time.sleep(12)

        # Extract cookies
        print("🍪 Extracting cookies...")
        selenium_cookies = driver.get_cookies()

        cookies_dict = {}
        for cookie in selenium_cookies:
            cookies_dict[cookie['name']] = cookie['value']

        print(f"✅ Extracted {len(cookies_dict)} cookies")

        # Extract JWT token
        jwt_token = extract_hydra_jwt(driver)

        # Prepare data structure
        cookies_data = {
            "cookies": cookies_dict,
            "jwt_token": jwt_token,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "url": "https://food.grab.com",
            "note": "Cookies and JWT for Grab API access"
        }

        # Save to file
        output_file = 'grab_cookies.json'
        with open(output_file, 'w') as f:
            json.dump(cookies_data, f, indent=2)

        print(f"\n✅ Cookies and JWT saved to {output_file}")
        print(f"📊 Total cookies: {len(cookies_dict)}")
        print(f"🔑 JWT token: {'Present' if jwt_token else 'Not captured'}")

        # Important cookies
        important = ['aws-waf-token', 'passenger_authn_token', 'passenger_authn_token_jti', 'location']
        print(f"\n🔑 Important cookies:")
        for key in important:
            status = '✅' if key in cookies_dict else '❌'
            print(f"  {status} {key}")

        return cookies_data

    except Exception as e:
        print(f"\n❌ Error during cookie refresh: {e}")
        import traceback
        traceback.print_exc()
        return None

    finally:
        if driver:
            driver.quit()
            print("🔒 Browser closed")

def main():
    """Main loop - refresh cookies every 4 hours"""
    print("\n🚀 Grab Cookie & JWT Auto-Refresh Service")
    print("📍 Target: food.grab.com")
    print("🔄 Refresh interval: 4 hours")
    print("-" * 50)

    while True:
        try:
            result = refresh_grab_cookies()

            if result:
                print("\n✅ Refresh cycle completed successfully")
                print(f"⏰ Next refresh at: {datetime.fromtimestamp(time.time() + 4*3600).strftime('%H:%M:%S')}")
            else:
                print("\n⚠️  Refresh cycle completed with errors")

            # Wait 4 hours before next refresh
            print(f"\n😴 Sleeping for 4 hours...")
            print("   (Press Ctrl+C to stop)")
            time.sleep(4 * 3600)

        except KeyboardInterrupt:
            print("\n\n🛑 Service stopped by user")
            sys.exit(0)
        except Exception as e:
            print(f"\n❌ Unexpected error in main loop: {e}")
            print("⏳ Waiting 5 minutes before retry...")
            time.sleep(5 * 60)

if __name__ == "__main__":
    main()
