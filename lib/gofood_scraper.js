#!/usr/bin/env node
/**
 * GoFood Scraping Browser Parser
 *
 * Bypasses Tencent Cloud WAF on gofood.co.id by:
 * 1. Connecting to BrightData Scraping Browser (handles JS probe challenge)
 * 2. Loading gofood.co.id homepage (WAF passes for homepage)
 * 3. Using Next.js client-side router.push() for restaurant pages
 * 4. Intercepting _next/data XHR responses (no CAPTCHA triggered)
 *
 * Usage:
 *   Single:  node gofood_scraper.js '{"url":"https://gofood.co.id/bali/restaurant/slug-uid"}'
 *   Batch:   node gofood_scraper.js '{"urls":["url1","url2",...]}'
 *
 * Output: JSON to stdout
 *   { "results": { "uid1": {...}, "uid2": {...} }, "errors": [...] }
 *
 * Environment:
 *   SCRAPING_BROWSER_WS - BrightData Scraping Browser WebSocket URL
 */

const SBR_WS = process.env.SCRAPING_BROWSER_WS ||
  'wss://brd-customer-hl_4f9d9889-zone-scraping_browser1:vcsa70x4kkpv@brd.superproxy.io:9222';

const HOMEPAGE_URL = 'https://gofood.co.id/';
const HOMEPAGE_TIMEOUT = 120000;
const HOMEPAGE_WAIT = 15000;
const ROUTER_WAIT = 5000;
const MAX_RETRIES = 3;

async function main() {
  const input = JSON.parse(process.argv[2] || '{}');

  // Normalize input: single url or batch urls
  let urls = [];
  if (input.url) urls = [input.url];
  else if (input.urls) urls = input.urls;
  else {
    output({ results: {}, errors: ['No url or urls provided'] });
    return;
  }

  // Parse slugs from URLs
  const restaurants = urls.map(url => {
    const match = url.match(/\/([^/]+)\/restaurant\/(.+?)(?:\?|$)/);
    if (match) return { url, area: match[1], slug: match[2] };
    // Try extracting just the slug (for pre-parsed input)
    const slugMatch = url.match(/restaurant\/(.+?)(?:\?|$)/);
    if (slugMatch) return { url, area: 'bali', slug: slugMatch[1] };
    return { url, area: null, slug: null, error: 'Cannot parse URL' };
  });

  const errors = [];
  const badUrls = restaurants.filter(r => !r.slug);
  badUrls.forEach(r => errors.push(`Invalid URL: ${r.url}`));
  const validRestaurants = restaurants.filter(r => r.slug);

  if (validRestaurants.length === 0) {
    output({ results: {}, errors });
    return;
  }

  let browser;
  try {
    // Try playwright first, fall back to playwright-core (global install in Docker)
    let pw;
    try { pw = require('playwright'); } catch { pw = require('playwright-core'); }
    const { chromium } = pw;

    log('Connecting to Scraping Browser...');
    browser = await chromium.connectOverCDP(SBR_WS, { timeout: 90000 });
    log('Connected');

    let page = await browser.contexts()[0].newPage();

    // Collect results from _next/data responses
    const results = {};
    const attachResponseInterceptor = (p) => {
      p.on('response', async (resp) => {
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
    };
    attachResponseInterceptor(page);

    // Load homepage to pass WAF (go directly, no warmup - SBR handles probe.js)
    log('Loading homepage...');
    let homepageLoaded = false;
    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        await page.goto(HOMEPAGE_URL, { waitUntil: 'domcontentloaded', timeout: HOMEPAGE_TIMEOUT });
      } catch {}

      // Poll for page to fully load (WAF challenge solving takes time)
      for (let check = 0; check < 12; check++) {
        await page.waitForTimeout(5000);
        const pageState = await page.evaluate(() => {
          const htmlLen = document.documentElement?.outerHTML?.length || 0;
          const hasRouter = !!window.next?.router;
          const title = document.title || '';
          return { htmlLen, hasRouter, title };
        }).catch(() => ({ htmlLen: 0, hasRouter: false, title: '' }));

        if (pageState.htmlLen > 50000 && pageState.hasRouter) {
          log(`Homepage loaded (attempt ${attempt + 1}, check ${check + 1}): ${pageState.title}`);
          homepageLoaded = true;
          break;
        }
        // Page HTML loaded but Next.js not hydrated yet - wait more
        if (pageState.htmlLen > 50000 && !pageState.hasRouter && check < 8) {
          log(`HTML loaded (${pageState.htmlLen}), waiting for Next.js hydration...`);
        }
      }
      if (homepageLoaded) break;
      log(`Homepage attempt ${attempt + 1} failed, retrying with new session...`);

      // Close page and create new one for fresh session
      await page.close().catch(() => {});
      page = await browser.contexts()[0].newPage();
      attachResponseInterceptor(page);
    }

    if (!homepageLoaded) {
      output({ results: {}, errors: [...errors, 'Failed to load GoFood homepage (WAF block)'] });
      await browser.close();
      return;
    }

    // Navigate to each restaurant via Next.js router
    for (let i = 0; i < validRestaurants.length; i++) {
      const r = validRestaurants[i];
      const path = `/${r.area}/restaurant/${r.slug}`;

      for (let attempt = 0; attempt < 2; attempt++) {
        // Check router availability, reload homepage if lost
        const hasRouter = await page.evaluate(() => !!window.next?.router?.push).catch(() => false);
        if (!hasRouter) {
          log('Router lost, reloading homepage...');
          try { await page.goto(HOMEPAGE_URL, { waitUntil: 'domcontentloaded', timeout: HOMEPAGE_TIMEOUT }); } catch {}
          // Wait for hydration
          for (let c = 0; c < 8; c++) {
            await page.waitForTimeout(5000);
            const ready = await page.evaluate(() => !!window.next?.router?.push).catch(() => false);
            if (ready) break;
          }
        }

        try {
          await page.evaluate((p) => window.next.router.push(p), path);
          await page.waitForTimeout(ROUTER_WAIT);
          log(`${i + 1}/${validRestaurants.length} fetched`);
          break; // success, exit retry loop
        } catch (e) {
          if (attempt === 0) {
            log(`Retry ${r.slug.substring(0, 30)}... (${e.message.substring(0, 50)})`);
          } else {
            errors.push(`Error navigating to ${r.slug}: ${e.message}`);
            log(`Error on ${r.slug}: ${e.message}`);
          }
        }
      }
    }

    // Match results back to input URLs by UID extracted from slug
    const finalResults = {};
    for (const r of validRestaurants) {
      // Extract UID from slug (last part after last dash-group: UUID format)
      const uidMatch = r.slug.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/);
      const uid = uidMatch ? uidMatch[1] : null;

      if (uid && results[uid]) {
        finalResults[r.url] = results[uid];
      } else {
        // Try matching by partial slug
        const found = Object.values(results).find(res =>
          r.slug.includes(res.uid?.substring(0, 8))
        );
        if (found) {
          finalResults[r.url] = found;
        } else {
          errors.push(`No data received for: ${r.url}`);
        }
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
  // Extract cuisines from tags
  const cuisines = (outlet.core?.tags || [])
    .filter(t => t.taxonomy === 2)
    .map(t => t.displayName)
    .filter(Boolean)
    .slice(0, 3);

  // Extract address
  const addressRows = outlet.core?.address?.rows || [];
  const address = addressRows.filter(Boolean).join(', ');

  // Status: 1 = open, 2 = closed
  const coreStatus = outlet.core?.status;
  const isOpen = coreStatus === 1;

  // Working hours
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
      day: p.day,
      day_name: dayNames[p.day] || '',
      start_time: startTime,
      end_time: endTime,
      formatted: `${dayNames[p.day] || ''}: ${startTime}-${endTime}`,
      day_of_week: dayOfWeek,
      opens_at: startTime,
      closes_at: endTime,
      is_closed: false,
    };
  });

  return {
    uid: outlet.uid,
    name: outlet.core?.displayName || null,
    address: address || null,
    rating: outlet.ratings?.average != null ? String(outlet.ratings.average) : 'NEW',
    review_count: outlet.ratings?.total || null,
    cuisines,
    image_url: outlet.media?.coverImgUrl || null,
    status: {
      is_open: isOpen,
      status_text: isOpen ? 'open' : 'closed',
      core_status: coreStatus,
      deliverable: outlet.delivery?.deliverable || false,
      next_open_time: outlet.core?.nextOpenTime || null,
      next_close_time: outlet.core?.nextCloseTime || null,
      blocked_reason: outlet.core?.blockedReason || null,
      error: null,
    },
    open_periods: openPeriods,
    working_hours: openPeriods,
    menu_items: extractMenuItems(outlet),
    rate_limit_remaining: pageProps?.rateLimit?.remaining || null,
  };
}

function extractMenuItems(outlet) {
  const items = [];
  const catalog = outlet.catalog;
  if (!catalog?.sections) return items;

  for (const section of catalog.sections) {
    const categoryName = section.name || section.displayName || '';
    for (const item of (section.items || [])) {
      items.push({
        id: item.uid || item.id || '',
        name: item.displayName || item.name || '',
        category: categoryName,
        status: item.status, // 1=available, other=unavailable
        price: item.price?.units || null,
        image_url: item.imgUrl || item.imageURL || null,
      });
    }
  }
  return items;
}

function output(data) {
  console.log(JSON.stringify(data));
}

function log(msg) {
  process.stderr.write(`[GoFood] ${msg}\n`);
}

main();
