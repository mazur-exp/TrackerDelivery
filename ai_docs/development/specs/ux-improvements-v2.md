# TrackerDelivery — UX Improvements Spec v2

**Priority:** P0-P1
**Scope:** Dashboard + Analytics refactoring based on UX audit (2026-03-24)
**Project path:** /root/TrackerDelivery

---

## CHANGE 1 (P0): Inline Analytics — Remove Separate Page, Load Inside Dashboard

### Problem
Analytics opens as a completely separate full page (/restaurants/:id/analytics) with its own HTML, HEAD, TailwindCSS CDN, and no footer/header from the dashboard. It feels disconnected. It also loads slowly because it is a full page navigation.

### Solution
Move analytics to load inline within the dashboard, inside the Restaurants tab. When user clicks "Analytics" on a restaurant card, the restaurant list is replaced with that restaurant analytics view, with a "Back to all restaurants" button to return.

### Implementation

#### 1. Routes — keep existing routes
No route changes needed. Keep GET /restaurants/:id/analytics and GET /restaurants/:id/analytics_data as they are. The analytics action will now render a partial instead of a full HTML page.

#### 2. RestaurantsController#analytics — render partial or full page
In app/controllers/restaurants_controller.rb, update the analytics method:

```ruby
def analytics
  @restaurant = current_user.restaurants.find(params[:id])
  @period = params[:period] || "7d"

  if request.headers["X-Inline"] == "true" || params[:inline] == "true"
    render partial: "restaurants/analytics_inline", layout: false
  else
    render "restaurants/analytics"
  end
rescue ActiveRecord::RecordNotFound
  redirect_to dashboard_path, alert: "Restaurant not found"
end
```

#### 3. New partial: app/views/restaurants/_analytics_inline.html.erb
Extract the body content from analytics.html.erb into a partial _analytics_inline.html.erb. This partial should NOT include html, head, body, or the TailwindCSS CDN script tag — it will be injected into the existing dashboard page.

The partial should contain:
- The analytics container div (everything inside div.max-w-2xl.mx-auto)
- The script block with all the JS (loadData, buildDayRows, etc.)

Change the "Back to Dashboard" link to a JS-powered back button:
```html
<a href="#" onclick="showRestaurantsList(); return false;" class="text-gray-400 hover:text-gray-600 text-xs flex items-center gap-1 mb-2">
  <i data-lucide="arrow-left" class="w-3.5 h-3.5"></i> Back to all restaurants
</a>
```

#### 4. Dashboard view changes (show.html.erb)
In the Restaurants tab content area, wrap the restaurant list in a container div:
```html
<div id="restaurants-list">
  <!-- existing restaurant cards here -->
</div>
<div id="restaurant-analytics" class="hidden">
  <!-- analytics will be loaded here via AJAX -->
</div>
```

Update the "Analytics" button on each restaurant card to call a JS function instead of navigating:
```html
<a href="#" onclick="loadInlineAnalytics(<%= r.id %>); return false;" class="...">
  <i data-lucide="bar-chart-3" class="w-3.5 h-3.5"></i> Analytics
</a>
```

Add JS functions to dashboard:
```javascript
async function loadInlineAnalytics(restaurantId) {
  const listEl = document.getElementById('restaurants-list');
  const analyticsEl = document.getElementById('restaurant-analytics');
  analyticsEl.innerHTML = '<div class="p-8 text-center text-gray-400">Loading analytics...</div>';
  listEl.classList.add('hidden');
  analyticsEl.classList.remove('hidden');
  const resp = await fetch('/restaurants/' + restaurantId + '/analytics?inline=true', {
    headers: { 'X-Inline': 'true' }
  });
  const html = await resp.text();
  analyticsEl.innerHTML = html;
  if (window.lucide) lucide.createIcons();
  analyticsEl.querySelectorAll('script').forEach(oldScript => {
    const newScript = document.createElement('script');
    newScript.textContent = oldScript.textContent;
    oldScript.replaceWith(newScript);
  });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function showRestaurantsList() {
  const listEl = document.getElementById('restaurants-list');
  const analyticsEl = document.getElementById('restaurant-analytics');
  analyticsEl.classList.add('hidden');
  analyticsEl.innerHTML = '';
  listEl.classList.remove('hidden');
}
```

#### 5. Keep the standalone analytics page working
Keep analytics.html.erb as a fallback for direct URL access. The primary UX path is now through the dashboard.

---

## CHANGE 2 (P0): Fix "Last Updated" Timestamp

### Problem
Dashboard shows "Last updated: -" — always empty. The last_checked_at data is available in status_data but not being used in the template.

### Implementation
In build_status_data method, last_checked_at is already returned per restaurant. Fix the template to use the most recent last_checked_at across all restaurants.

Server-side initial render (in show.html.erb):
```erb
<%
  latest_check = @status_data.values.map { |d| d[:last_checked_at] }.compact.max
  if latest_check
    mins_ago = ((Time.current - Time.parse(latest_check)) / 60).round
    last_updated_text = mins_ago < 1 ? "just now" : "#{mins_ago} min ago"
  end
%>
<span id="last-updated">Last updated: <%= last_updated_text || "-" %></span>
```

Client-side polling update (add to status polling JS):
```javascript
function updateLastUpdated(statusData) {
  let latestTime = null;
  Object.values(statusData).forEach(rd => {
    if (rd.last_checked_at) {
      const t = new Date(rd.last_checked_at);
      if (!latestTime || t > latestTime) latestTime = t;
    }
  });
  const el = document.getElementById('last-updated');
  if (el && latestTime) {
    const ago = Math.round((Date.now() - latestTime.getTime()) / 60000);
    if (ago < 1) el.textContent = 'Last updated: just now';
    else if (ago < 60) el.textContent = 'Last updated: ' + ago + ' min ago';
    else el.textContent = 'Last updated: ' + latestTime.toLocaleTimeString();
  }
}
```

Call updateLastUpdated(data) in the AJAX polling callback that fetches /dashboard/status_data.

---

## CHANGE 3 (P0): Clarify Uptime Calculation — Show Against Working Hours

### Problem
Uptime 46.4% looks catastrophic but restaurant may only work 8h/day. The denominator is total checks (24h), not working hours.

### Solution
Calculate uptime percentage only against checks that fall within scheduled working hours. Show clearly.

### Implementation

In analytics_helper.rb, add method:
```ruby
def calculate_working_hours_uptime(checks, restaurant)
  working_checks = checks.select do |check|
    bali_time = check.checked_at.in_time_zone("Asia/Makassar")
    day_of_week = bali_time.wday == 0 ? 6 : bali_time.wday - 1
    wh = restaurant.working_hours.find { |w| w.day_of_week == day_of_week }
    next false unless wh && !wh.is_closed
    current_time = bali_time.strftime("%H:%M")
    opens = wh.opens_at.to_s
    closes = wh.closes_at.to_s
    if closes > opens
      current_time >= opens && current_time <= closes
    else
      current_time >= opens || current_time <= closes
    end
  end
  return nil if working_checks.empty?
  open_count = working_checks.count { |c| c.actual_status == "open" }
  (open_count.to_f / working_checks.size * 100).round(1)
end
```

In restaurants_controller.rb#analytics_data, add to metrics:
```ruby
working_hours_uptime: calculate_working_hours_uptime(checks, @restaurant),
```

In analytics JS, use working_hours_uptime as primary:
```javascript
const uptimePct = (m.working_hours_uptime ?? m.uptime_percentage).toFixed(1);
```

In dashboards_controller.rb#build_status_data, similarly filter today uptime to working hours only. Add working_hours_uptime_pct to the status data hash. Show this on the dashboard card instead of 24h uptime.

---

## CHANGE 4 (P0): Align Terminology — "Issues" Not "Anomalies"

### Problem
Summary says "706 anomalies" but day rows say "1 issue". Confusing.

### Implementation
Use "issues" everywhere user-facing. Keep "anomalies" in the database/backend only.

In analytics JS, change subtitle:
```javascript
const openHours = Math.round(m.open_checks * 5 / 60 * 10) / 10;
const closedHours = Math.round(m.closed_checks * 5 / 60 * 10) / 10;
const issueText = m.anomalies_count === 1 ? '1 issue' : m.anomalies_count + ' issues';
document.getElementById('period-subtitle').textContent =
  openHours + 'h open / ' + closedHours + 'h closed · ' + issueText;
```

Replace "checks" with hours everywhere in user-facing strings.

---

## CHANGE 5 (P1): Add Revenue Loss Estimation

### Problem
analytics_helper.rb already has REVENUE_PER_HOUR = 50_000 (Rp) but it is not shown anywhere.

### Implementation
In analytics_data JSON response, add estimated_revenue_loss to metrics.

In analytics view, show in period summary:
```javascript
if (m.estimated_revenue_loss > 0) {
  const lossFormatted = new Intl.NumberFormat('id-ID').format(m.estimated_revenue_loss);
  subtitle += ' · ~Rp ' + lossFormatted + ' est. lost';
}
```

In day rows, add small revenue loss for days with downtime:
```javascript
const dayLoss = closedCount * 5 / 60 * 50000;
if (dayLoss > 0) {
  const lossStr = 'Rp ' + new Intl.NumberFormat('id-ID').format(Math.round(dayLoss));
  html += '<span class="text-xs text-red-400 ml-1">~' + lossStr + '</span>';
}
```

---

## CHANGE 6 (P1): Differentiate Scheduled Closures from No-Data

### Problem
Days with 0% / 0m open could mean: (a) scheduled day off, (b) monitoring failed, (c) open 0% of working hours. All look the same.

### Implementation
In analytics_data response, add working hours:
```ruby
working_hours: @restaurant.working_hours.map { |wh|
  { day_of_week: wh.day_of_week, opens_at: wh.opens_at, closes_at: wh.closes_at, is_closed: wh.is_closed }
}
```

In buildDayRows JS, check each day against working hours:
- Scheduled closed day: gray icon + "Day off" label
- No monitoring data (0 checks): yellow warning icon + "No data" label
- Open 0% of scheduled hours: red icon + "0%" as now

Also generate placeholder rows for days in the period that have NO checks at all.

---

## CHANGE 7 (P1): Settings — Hide Non-Functional Toggles + Add Telegram

### Problem
Settings shows toggles for "Review Alerts" and "Order Alerts" which do not exist yet. No Telegram settings despite it being the primary alert channel.

### Implementation
In dashboards/show.html.erb Settings tab:

1. Gray out Review Alerts and Order Alerts toggles with opacity-50 pointer-events-none and add "Coming Soon" badge.
2. Add Telegram Notifications as a delivery method option, ON by default.
3. Show connected Telegram account info (username from user model).

---

## CHANGE 8 (P1): Out of Stock — Add Sorting + Duration Color Coding

### Problem
No sorting, no filtering, no actions.

### Implementation
In show.html.erb Out of Stock tab:

1. Add sort dropdown: Duration (longest first) | Restaurant | Category
2. Color-code items by duration:
   - > 72h: border-l-4 border-red-400
   - > 24h: border-l-4 border-yellow-400
   - < 24h: default
3. Add "Open in Platform" link per item using restaurant platform_url.

---

## CHANGE 9 (P1): Dashboard — Improve Mobile Restaurant Cards

### Problem
On mobile (390px), restaurant name truncated, status elements cramped in one row.

### Implementation
1. Add short_name method to Restaurant model:
```ruby
def short_name
  name.gsub(/\s*\([^)]*\)\s*/, ' ').strip.gsub(/\s+/, ' ')
end
```

2. In show.html.erb, show short name on mobile:
```html
<h3 class="font-semibold text-gray-900">
  <span class="hidden md:inline"><%= r.name %></span>
  <span class="md:hidden"><%= r.short_name %></span>
</h3>
```

3. Use flex-wrap on status elements so they wrap to 2 rows on narrow screens.

---

## CHANGE 10 (P2): Timeline Bar Improvements

Increase height to h-2.5 (from ~h-1). Add title tooltip on each segment showing time range and status.

---

## CHANGE 11 (P2): Remove CDN Tailwind from Analytics Page

analytics.html.erb loads TailwindCSS from CDN and Lucide from unpkg. Use the app own stylesheet instead. Remove cdn.tailwindcss.com script tag. Use stylesheet_link_tag "application". Make sure all Tailwind classes used in analytics are in the project content paths.

---

## Summary of Files to Modify

| File | Changes |
|------|---------|
| app/controllers/restaurants_controller.rb | analytics action: support inline rendering |
| app/views/restaurants/analytics.html.erb | Keep as standalone fallback, remove CDN Tailwind |
| app/views/restaurants/_analytics_inline.html.erb | NEW — extracted partial for inline loading |
| app/views/dashboards/show.html.erb | Inline analytics container, fix last_updated, mobile cards, settings toggles, OOS sorting, timeline height |
| app/controllers/dashboards_controller.rb | Fix last_updated in build_status_data, add working_hours_uptime_pct |
| app/helpers/analytics_helper.rb | Add calculate_working_hours_uptime method |
| app/models/restaurant.rb | Add short_name method |

---

## Testing Checklist

- [ ] Dashboard loads with correct "Last updated: X min ago"
- [ ] Clicking "Analytics" on restaurant card loads analytics inline (no page navigation)
- [ ] "Back to all restaurants" returns to restaurant list without full page reload
- [ ] Direct URL /restaurants/:id/analytics still works as standalone page
- [ ] Uptime % shows working-hours-only calculation
- [ ] Period subtitle shows "Xh open / Yh closed · N issues" (not "checks" or "anomalies")
- [ ] Days with no working hours show "Day off" indicator
- [ ] Revenue loss estimation shows on analytics page
- [ ] Settings tab: Review/Order alerts grayed out with "Coming Soon"
- [ ] Settings tab: Telegram notification option visible
- [ ] Out of Stock: items sorted by duration by default, color-coded
- [ ] Mobile (390px): restaurant name shortened, status elements wrap to 2 rows
- [ ] Timeline bars are taller and have hover tooltips
- [ ] No TailwindCSS CDN — uses project own build
