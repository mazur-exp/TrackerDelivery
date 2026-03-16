# GoFood WAF Bypass - Technical Documentation

## Problem

gofood.co.id is protected by **Tencent Cloud WAF (EdgeOne)**. It blocks all non-browser access to restaurant pages:

| Access Method | Homepage | Restaurant Pages |
|---------------|----------|-----------------|
| Direct curl (server IP) | 202 JS challenge | 202 JS challenge |
| curl + w_tsfp cookie | N/A | 403 (IP-bound) |
| BrightData datacenter proxy | 202 JS challenge | 202 JS challenge |
| Local Chrome + BrightData datacenter proxy | **200 OK** | CAPTCHA (Tencent) |
| Googlebot UA | 202 JS challenge | 202 JS challenge |
| CORS proxies | 403/502 | 403/502 |

WAF has two protection levels:
1. **JS probe challenge** (`/C2WF946J0/probe.js`) - solved automatically by Local Chrome + proxy
2. **Tencent CAPTCHA** (`sg.captcha.qcloud.com/Captcha.js`) - blocks automated access to restaurant pages

## Solution: Next.js Client-Side Router

GoFood uses **Next.js with SSR**. When the browser does client-side navigation (via `next.router.push()`), it fetches data from `/_next/data/BUILD_ID/path.json` via XHR instead of loading a full page. This XHR request:
- Uses the same browser session cookies
- Does NOT trigger a new WAF challenge
- Returns the full `pageProps.outlet` data as JSON

### Flow

```
1. Local Chrome + proxy -> gofood.co.id/ (homepage)
   WAF: JS probe challenge -> auto-solved -> 200 OK
   Result: Next.js app loaded, router available

2. page.evaluate -> window.next.router.push('/area/restaurant/slug')
   Browser: XHR GET /_next/data/17.20.0/area/restaurant/slug.json
   WAF: No challenge (same-origin XHR from established session)
   Result: 200 OK with full restaurant JSON data

3. Intercept response via page.on('response')
   Extract: pageProps.outlet (name, status, rating, hours, menu, etc.)
```

### Performance

- Homepage load: ~15-20s (includes WAF challenge solving)
- Each restaurant: ~4-5s (client-side navigation)
- Batch of 10 restaurants: ~60s total
- Rate limit: ~700 requests per window (from pageProps.rateLimit.remaining)

## Data Structure

Restaurant data comes from `pageProps.outlet`:

```json
{
  "core": {
    "displayName": "Restaurant Name",
    "status": 1,              // 1=OPEN, 2=CLOSED
    "nextCloseTime": "ISO",   // present when open
    "nextOpenTime": "ISO",    // present when closed
    "blockedReason": "",      // non-empty if platform-blocked
    "timeZone": "Asia/Makassar",
    "openPeriods": [
      { "day": 1, "startTime": {"hours": 7}, "endTime": {"hours": 22} }
    ],
    "address": { "rows": ["Street", "District", "Bali"] },
    "location": { "latitude": -8.64, "longitude": 115.14 },
    "tags": [{ "displayName": "Cuisine", "taxonomy": 2 }],
    "badges": [1]             // 1 = Super Partner
  },
  "ratings": { "average": 4.7, "total": 413 },
  "delivery": { "deliverable": false, "distanceKm": 26.06 },
  "media": { "coverImgUrl": "https://i.gojekapi.com/..." },
  "catalog": { "sections": [...] }
}
```

### Status Values

| core.status | Meaning | Other indicators |
|-------------|---------|-----------------|
| 1 | Open | `nextCloseTime` present |
| 2 | Closed | `nextOpenTime` present |
| 0 | Inactive/disabled | `blockedReason` may be set |

## URL Format

Full URL: `https://gofood.co.id/{service_area}/restaurant/{slug}-{uuid}`

- service_area: `bali`, `badung`, `denpasar`, `tabanan`, etc.
- slug: kebab-case restaurant name
- uuid: outlet UUID (e.g., `1b62bb76-118f-48ec-a2c0-36053d98c97f`)

Short URL: `https://gofood.link/a/{code}` - resolves via JS redirect to full URL.

## Infrastructure

### Local Chrome + BrightData datacenter proxy

- Zone: `datacenter_proxy1`
- WebSocket: `wss://brd-customer-hl_4f9d9889-zone-datacenter_proxy1:vcsa70x4kkpv@brd.superproxy.io:9222`
- Connection: Playwright `chromium.connectOverCDP()`
- Handles JS challenges automatically, but NOT Tencent CAPTCHA

### Dependencies

- Node.js (available on server at /usr/bin/node)
- Playwright (from /root/delivery-stats-parser/node_modules)
- Local Chrome + BrightData datacenter proxy zone (active subscription)

### Configuration (ENV vars)

| Variable | Default | Description |
|----------|---------|-------------|
| `SCRAPING_BROWSER_WS` | (hardcoded) | Local Chrome + BrightData datacenter proxy WebSocket URL |
| `NODE_BIN` | `node` | Path to Node.js binary |
| `PLAYWRIGHT_PATH` | `/root/delivery-stats-parser/node_modules` | Path to Playwright module |

## Alternatives Investigated (and why they don't work)

| Approach | Result | Why |
|----------|--------|-----|
| Direct HTTP + cookies | 403 | w_tsfp cookie is IP-bound |
| Selenium + Xvfb | WAF block | Headless detection |
| BrightData datacenter proxy | 202 challenge | Datacenter ASN detected |
| BrightData residential proxy | Not configured | Zone not created |
| Gojek mobile API (`api.gojekapi.com`) | 401 | Needs consumer app auth token |
| GoBiz merchant token on consumer API | 404 | Different auth realm |
| Google Cache | 404 | Not cached |
| Wayback Machine | No snapshots | Not archived |
| CORS proxies | 403/502 | WAF blocks upstream |
| Cloudflare Workers | Not tested | Alternative if SBR fails |

## Troubleshooting

### Homepage fails to load
- Local Chrome + proxy is inconsistent (~80% success rate)
- Script retries up to 2 times
- If persistent, check BrightData zone status

### Router lost after navigation
- Happens when navigating to invalid slug (404 page breaks Next.js)
- Script detects this and reloads homepage

### Rate limiting
- `pageProps.rateLimit.remaining` shows remaining requests
- Resets periodically (exact window unknown)
- 700+ remaining is normal, monitor if dropping

### BrightData WebSocket timeout
- Check zone is active at https://brightdata.com/cp/zones
- Verify credentials haven't rotated
- Try regenerating zone password
