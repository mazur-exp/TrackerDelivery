#!/usr/bin/env node
/**
 * GoFood Parser - Local Playwright + BrightData Datacenter Proxy
 *
 * Loads gofood.co.id homepage via local Chrome + datacenter proxy (WAF passes),
 * then uses Next.js router.push() for client-side navigation to restaurant pages.
 * Response interception on context level captures _next/data JSON.
 *
 * Usage:
 *   node gofood_scraper.js '{"url":"https://gofood.co.id/area/restaurant/slug"}'
 *   node gofood_scraper.js '{"urls":["url1","url2",...]}'
 *
 * Output: JSON to stdout
 *
 * Environment:
 *   PROXY_SERVER   - proxy address (default: brd.superproxy.io:33335)
 *   PROXY_USERNAME - proxy user (default: BrightData datacenter)
 *   PROXY_PASSWORD - proxy password
 */

const PROXY_SERVER = process.env.PROXY_SERVER || 'http://brd.superproxy.io:33335';
const PROXY_USERNAME = process.env.PROXY_USERNAME || 'brd-customer-hl_4f9d9889-zone-datacenter_proxy1-country-id';
const PROXY_PASSWORD = process.env.PROXY_PASSWORD || '7ow124bbuyid';

const HOMEPAGE_URL = 'https://gofood.co.id/';
const HOMEPAGE_TIMEOUT = 60000;
const ROUTER_WAIT = 4000;
const MAX_RETRIES = 3;

async function main() {
  const input = JSON.parse(process.argv[2] || '{}');

  let urls = [];
  if (input.url) urls = [input.url];
  else if (input.urls) urls = input.urls;
  else { output({ results: {}, errors: ['No url or urls provided'] }); return; }

  const restaurants = urls.map(url => {
    const match = url.match(/\/([^/]+)\/restaurant\/(.+?)(?:\?|$)/);
    if (match) return { url, area: match[1], slug: match[2] };
    return { url, area: null, slug: null, error: 'Cannot parse URL' };
  });

  const errors = [];
  const validRestaurants = restaurants.filter(r => r.slug);
  restaurants.filter(r => !r.slug).forEach(r => errors.push(`Invalid URL: ${r.url}`));

  if (validRestaurants.length === 0) { output({ results: {}, errors }); return; }

  let browser;
  try {
    let pw;
    try { pw = require('playwright'); } catch { pw = require('playwright-core'); }
    const { chromium } = pw;

    // Use system Chromium if available (Docker), otherwise Playwright's bundled
    const execPath = process.env.CHROME_BIN ||
      ['/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome-stable', '/usr/bin/google-chrome']
        .find(p => { try { require('fs').accessSync(p); return true; } catch { return false; } });

    log('Launching Chrome' + (execPath ? ` (${execPath})` : '') + ' with datacenter proxy...');
    browser = await chromium.launch({
      headless: true,
      executablePath: execPath || undefined,
      args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
      proxy: { server: PROXY_SERVER, username: PROXY_USERNAME, password: PROXY_PASSWORD }
    });

    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    let page = await context.newPage();

    // Intercept on CONTEXT level - survives page reloads
    const results = {};
    context.on('response', async (resp) => {
      const url = resp.url();
      if (url.includes('_next/data') && url.includes('restaurant')) {
        try {
          const body = await resp.json();
          const outlet = body.pageProps?.outlet;
          if (outlet) {
            results[outlet.uid] = extractOutletData(outlet, body.pageProps);
          }
        } catch {}
      }
    });

    // Load homepage
    log('Loading homepage...');
    let homepageLoaded = false;
    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        await page.goto(HOMEPAGE_URL, { waitUntil: 'domcontentloaded', timeout: HOMEPAGE_TIMEOUT });
      } catch {}

      for (let check = 0; check < 8; check++) {
        await page.waitForTimeout(5000);
        const ready = await page.evaluate(() =>
          document.documentElement?.outerHTML?.length > 50000 && !!window.next?.router?.push
        ).catch(() => false);
        if (ready) {
          log(`Homepage loaded (attempt ${attempt + 1})`);
          homepageLoaded = true;
          break;
        }
      }
      if (homepageLoaded) break;
      log(`Homepage attempt ${attempt + 1} failed, retrying...`);
    }

    if (!homepageLoaded) {
      output({ results: {}, errors: [...errors, 'Failed to load GoFood homepage'] });
      await browser.close();
      return;
    }

    // Navigate to each restaurant
    for (let i = 0; i < validRestaurants.length; i++) {
      const r = validRestaurants[i];
      const path = `/${r.area}/restaurant/${r.slug}`;

      // Ensure router is available
      const hasRouter = await page.evaluate(() => !!window.next?.router?.push).catch(() => false);
      if (!hasRouter) {
        log('Router lost, reloading homepage...');
        await page.goto(HOMEPAGE_URL, { waitUntil: 'domcontentloaded', timeout: HOMEPAGE_TIMEOUT }).catch(() => {});
        for (let c = 0; c < 8; c++) {
          await page.waitForTimeout(5000);
          if (await page.evaluate(() => !!window.next?.router?.push).catch(() => false)) break;
        }
      }

      try {
        await page.evaluate((p) => window.next.router.push(p), path);
        await page.waitForTimeout(ROUTER_WAIT);
        log(`${i + 1}/${validRestaurants.length} fetched`);
      } catch (e) {
        log(`Retry ${i + 1}/${validRestaurants.length}...`);
        // Reload and retry once
        await page.goto(HOMEPAGE_URL, { waitUntil: 'domcontentloaded', timeout: HOMEPAGE_TIMEOUT }).catch(() => {});
        await page.waitForTimeout(10000);
        try {
          await page.evaluate((p) => window.next.router.push(p), path);
          await page.waitForTimeout(ROUTER_WAIT);
          log(`${i + 1}/${validRestaurants.length} fetched (retry)`);
        } catch {
          errors.push(`Failed: ${r.slug}`);
        }
      }
    }

    // Match results to input URLs
    const finalResults = {};
    for (const r of validRestaurants) {
      const uidMatch = r.slug.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/);
      const uid = uidMatch ? uidMatch[1] : null;
      if (uid && results[uid]) {
        finalResults[r.url] = results[uid];
      } else {
        errors.push(`No data for: ${r.url}`);
      }
    }

    output({ results: finalResults, errors: errors.length > 0 ? errors : undefined });
    await browser.close();

  } catch (e) {
    errors.push(`Fatal: ${e.message}`);
    output({ results: {}, errors });
    if (browser) await browser.close().catch(() => {});
  }
}

function extractOutletData(outlet, pageProps) {
  const cuisines = (outlet.core?.tags || [])
    .filter(t => t.taxonomy === 2)
    .map(t => t.displayName)
    .filter(Boolean)
    .slice(0, 3);

  const addressRows = outlet.core?.address?.rows || [];
  const address = addressRows.filter(Boolean).join(', ');

  const coreStatus = outlet.core?.status;
  const isOpen = coreStatus === 1;

  const dayNames = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const openPeriods = (outlet.core?.openPeriods || []).map(p => {
    const startH = p.startTime?.hours || 0;
    const startM = p.startTime?.minutes || 0;
    const endH = p.endTime?.hours || 0;
    const endM = p.endTime?.minutes || 0;
    const startTime = `${String(startH).padStart(2, '0')}:${String(startM).padStart(2, '0')}`;
    const endTime = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;
    const dayOfWeek = p.day === 7 ? 0 : p.day;
    return {
      day: p.day, day_name: dayNames[p.day] || '',
      start_time: startTime, end_time: endTime,
      formatted: `${dayNames[p.day] || ''}: ${startTime}-${endTime}`,
      day_of_week: dayOfWeek, opens_at: startTime, closes_at: endTime, is_closed: false,
    };
  });

  const menuItems = [];
  const catalog = outlet.catalog;
  if (catalog?.sections) {
    for (const section of catalog.sections) {
      const categoryName = section.name || section.displayName || '';
      for (const item of (section.items || [])) {
        menuItems.push({
          id: item.uid || item.id || '',
          name: item.displayName || item.name || '',
          category: categoryName,
          status: item.status,
          price: item.price?.units || null,
          image_url: item.imgUrl || item.imageURL || null,
        });
      }
    }
  }

  return {
    uid: outlet.uid,
    name: outlet.core?.displayName || null,
    address: address || null,
    rating: outlet.ratings?.average != null ? String(outlet.ratings.average) : 'NEW',
    review_count: outlet.ratings?.total || null,
    cuisines,
    image_url: outlet.media?.coverImgUrl || null,
    status: {
      is_open: isOpen, status_text: isOpen ? 'open' : 'closed',
      core_status: coreStatus, deliverable: outlet.delivery?.deliverable || false,
      next_open_time: outlet.core?.nextOpenTime || null,
      next_close_time: outlet.core?.nextCloseTime || null,
      blocked_reason: outlet.core?.blockedReason || null, error: null,
    },
    open_periods: openPeriods,
    working_hours: openPeriods,
    menu_items: menuItems,
    rate_limit_remaining: pageProps?.rateLimit?.remaining || null,
  };
}

function output(data) { console.log(JSON.stringify(data)); }
function log(msg) { process.stderr.write(`[GoFood] ${msg}\n`); }

main();
