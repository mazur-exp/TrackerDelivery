# DeliveryTracker - Product Requirements Document (PRD)

## Executive Summary

**Product Name:** DeliveryTracker (DeliveryCoPilot)  
**Version:** 1.0  
**Date:** January 2025  
**Document Status:** Final  

**Mission Statement:** Protect F&B businesses in Southeast Asia from hidden revenue losses by providing real-time monitoring and automated management of their delivery platform presence.

**Target Launch:** Q1 2025 (MVP in 8-12 weeks)

---

## 1. Product Overview

### 1.1 Problem Statement

F&B businesses operating on Grab and Gojek delivery platforms in Southeast Asia face critical operational blind spots:

- **Invisible Closures:** Restaurants appear "closed" on platforms without owner's knowledge, losing $70-200 per incident
- **Platform Auto-Closures:** Single order cancellation can trigger day-long closure without notification
- **Reputation Damage:** Unanswered negative reviews drop ratings below the critical 4.5★ threshold
- **Inventory Mismanagement:** Popular items remain out-of-stock for days, losing 10-15% of potential orders
- **Trust Issues:** Foreign owners can't effectively monitor local operations across time zones

### 1.2 Solution Overview

DeliveryTracker is a SaaS monitoring platform that:
- Checks restaurant status every 5 minutes across Grab/Gojek
- Instantly alerts owners via WhatsApp/Telegram when issues detected
- Provides actionable dashboard with downtime analytics
- Automates recovery actions (premium tiers)
- Protects revenue and reputation through proactive monitoring

### 1.3 Success Metrics

- **Prevent 95% of unnoticed closures** (currently averaging 15-30 hours/month)
- **Reduce response time to issues from hours/days to <5 minutes**
- **Improve average restaurant rating by 0.3-0.5 stars**
- **Save owners 10+ hours/month of manual checking**
- **ROI: 10-50x monthly subscription cost through prevented losses**

---

## 2. Target Audience

### 2.1 Primary ICP (Ideal Customer Profile)

**Foreign F&B Owners in Bali**
- Demographics: Expat entrepreneurs, remote investors
- Business Profile: 1-3 outlets, 10-20 staff per location
- Order Volume: 20-150 delivery orders/day
- Pain Points:
  - Language barriers with local staff
  - Time zone differences for monitoring
  - Limited trust in operational management
  - Direct income impact from platform issues

### 2.2 User Personas

**Persona 1: Remote Restaurant Owner "Alex"**
- Owns 2 restaurants in Canggu, lives in Australia
- Relies on local manager but needs oversight
- Loses $2000+/month to unnoticed platform issues
- Wants automated monitoring and instant alerts
- Tech-savvy, willing to pay for peace of mind

**Persona 2: On-Site Owner-Operator "Maria"**
- Russian entrepreneur with café in Seminyak
- Manages operations personally but overwhelmed
- Needs efficiency tools to focus on growth
- Values Telegram integration and Russian support
- Price-conscious but understands ROI

### 2.3 Market Sizing

- **TAM:** 35,000 restaurants on delivery platforms in SEA
- **SAM:** 5,000 foreign-owned establishments in Bali/Bangkok/Singapore
- **SOM:** 750 customers in Year 1 (15% of SAM)

---

## 3. Product Requirements

### 3.1 Functional Requirements

#### Core Monitoring Engine
| Feature | Priority | Description | Acceptance Criteria |
|---------|----------|-------------|-------------------|
| Platform Parsing | P0 | Parse Grab/Gojek public pages | Successfully extract status, menu, reviews every 5 min |
| Status Detection | P0 | Identify open/closed state | 99% accuracy, handle edge cases (maintenance, holidays) |
| Change Detection | P0 | Compare states between checks | Detect any status change within 5-minute window |
| Data Storage | P0 | Store historical monitoring data | 90-day retention minimum, structured for analytics |
| Multi-outlet Support | P0 | Monitor multiple locations per account | Handle 1-10 outlets per customer efficiently |

#### Notification System
| Feature | Priority | Description | Acceptance Criteria |
|---------|----------|-------------|-------------------|
| WhatsApp Alerts | P0 | Send immediate notifications | <1 minute from detection, support multiple numbers |
| Telegram Alerts | P0 | Telegram bot/channel integration | Support both individual and channel notifications |
| Email Alerts | P1 | Supplementary email notifications | HTML formatted with action links |
| Web Push | P1 | Browser/TWA notifications | Real-time push for dashboard users |
| Alert Customization | P1 | Configure alert types/frequency | Granular control per outlet and issue type |

#### Dashboard & Analytics
| Feature | Priority | Description | Acceptance Criteria |
|---------|----------|-------------|-------------------|
| Status Overview | P0 | Current state all outlets | Real-time view, color-coded status indicators |
| Incident History | P0 | Log of all detected issues | Filterable by date, outlet, type |
| Downtime Analytics | P0 | Calculate lost revenue | Show hours closed, estimated losses in USD |
| Review Management | P0 | Display recent reviews | Show rating trends, highlight negative reviews |
| Out-of-Stock Tracking | P0 | List unavailable items | Show duration out-of-stock, popularity metrics |

#### Restaurant Onboarding
| Feature | Priority | Description | Acceptance Criteria |
|---------|----------|-------------|-------------------|
| URL-based Addition | P0 | Add restaurant via Grab/Gojek URL | Auto-parse name, address, hours, menu |
| Data Verification | P0 | Confirm parsed information | Allow manual corrections before activation |
| Notification Setup | P0 | Configure alert channels | Support WhatsApp, Telegram, email preferences |
| Platform Detection | P0 | Identify Grab vs Gojek | Handle both platforms, detect multi-platform presence |

#### Automation Features (Premium Tiers)
| Feature | Priority | Description | Acceptance Criteria |
|---------|----------|-------------|-------------------|
| Auto-Reopen | P1 | Automatically reopen when false closure detected | Requires merchant credentials, audit log |
| Auto-Restock | P1 | Return items to available status | Configurable rules, top-items priority |
| Review Auto-Reply | P2 | Template responses to reviews | AI-powered personalization, approval workflow |
| Menu Optimization | P2 | SEO and content improvements | Keyword optimization, KBZHU calculations |

### 3.2 Non-Functional Requirements

#### Performance Requirements
- **Monitoring Frequency:** Check each restaurant every 5 minutes
- **Alert Latency:** <60 seconds from detection to notification
- **Dashboard Load Time:** <2 seconds for initial load
- **Concurrent Users:** Support 1000+ simultaneous dashboard users
- **API Response Time:** <200ms for 95th percentile

#### Scalability Requirements
- **Restaurant Capacity:** 10,000 monitored restaurants by Month 12
- **Check Volume:** 2.88M checks/day at scale (10K restaurants × 288 checks/day)
- **Data Retention:** 90 days operational data, 2 years aggregate analytics
- **Multi-tenancy:** Complete data isolation between accounts

#### Security Requirements
- **Authentication:** Email/password with 2FA option
- **Credential Storage:** AES-256 encryption for merchant credentials
- **API Security:** Rate limiting, API key authentication
- **Data Privacy:** GDPR compliance, data residency options
- **Audit Logging:** Complete trail of all automated actions

#### Reliability Requirements
- **Uptime SLA:** 99.9% for monitoring service
- **Data Durability:** No data loss for stored metrics
- **Failover:** Automatic failover for critical services
- **Error Recovery:** Graceful handling of platform changes

### 3.3 Technical Requirements

#### Infrastructure
- **Hosting:** Hetzner cloud servers (EU/Singapore regions)
- **Database:** SQLite for MVP, PostgreSQL migration path ready
- **Queue System:** Sidekiq for background jobs
- **File Storage:** Local storage initially, S3-compatible for scale

#### Monitoring & Automation
- **Web Scraping:** Bright Data for anti-bot bypass
- **Workflow Automation:** N8N for orchestration
- **Scheduling:** Cron-based triggers via N8N
- **Webhook Processing:** Incoming webhooks for real-time updates

#### External Integrations
- **Payment:** Stripe Singapore
- **WhatsApp:** WhatsApp Business API
- **Telegram:** Telegram Bot API
- **Email:** Loops.so for transactional emails and marketing
- **SMS (future):** Twilio for critical alerts

---

## 4. Product Features by Tier

### 4.1 Pricing Tiers

#### Monitor - $29/month ($290/year)
**Target:** Single outlet owners, price-sensitive segment

**Core Features:**
- Status monitoring (open/closed) every 5 minutes
- Instant WhatsApp/Telegram/Email alerts
- Basic dashboard with 7-day history
- Downtime analytics and loss calculations
- Manual fix instructions

**Annual Bonus Features:**
- 5 negative review removals/month
- Basic SEO optimization (20 menu items)
- Priority support
- Monthly performance reports

#### Autopilot - $59/month ($590/year)
**Target:** Multi-outlet owners, automation seekers

**Everything in Monitor, plus:**
- Auto-reopen for false closures
- Auto-restock (up to 10 items)
- Semi-automated review responses
- 30-day data retention
- Sales data access and analytics
- Weekly performance reports

**Annual Bonus Features:**
- 10 negative review removals/month
- Full menu SEO optimization
- AI-generated descriptions (50 items)
- KBZHU calculations for menu
- Competitor keyword analysis
- Custom AI review responses
- Quarterly strategy calls

#### Command Center - $100/month ($990/year)
**Target:** Premium segment, foreign investors

**Everything in Autopilot, plus:**
- Unlimited automation actions
- API access for integrations
- Custom automation rules
- 90-day data retention
- Dedicated account manager
- White-label reports
- Multi-user access (up to 5 users)

**Annual Bonus Features:**
- 20 negative review removals/month
- Complete menu optimization (SEO + descriptions + KBZHU)
- AI-enhanced food photography (100 images)
- Psychological trigger descriptions
- A/B testing for menu items
- Competitor reputation audit
- White-glove onboarding
- Dedicated WhatsApp support

### 4.2 Additional Outlet Pricing
- Monitor: +$20/outlet/month
- Autopilot: +$30/outlet/month  
- Command Center: +$40/outlet/month

### 4.3 Trial Structure
- **Duration:** 14 days free trial
- **No Credit Card Required:** Full access without payment method
- **Post-Trial:** 5-15 second data preview, then payment wall
- **Conversion Target:** 25% trial-to-paid

---

## 5. User Interface Design

### 5.1 Design Principles

1. **Mobile-First Responsive:** Optimized for smartphone monitoring
2. **Glanceable Insights:** Critical info visible immediately
3. **Action-Oriented:** Clear CTAs for issue resolution
4. **Calm Interface:** Avoid alarm fatigue with smart notifications
5. **Localization-Ready:** Support for English, Russian, Bahasa (future)

### 5.2 Key Screens

#### Dashboard (Main Screen)
```
Layout Structure:
┌─────────────────────────────────────┐
│ Header: Logo | Outlets | Notifications│
├─────────────────────────────────────┤
│ Status Cards (Grid):                │
│ ┌──────┐ ┌──────┐ ┌──────┐        │
│ │Outlet│ │Outlet│ │Outlet│        │
│ │ OPEN │ │CLOSED│ │ OPEN │        │
│ └──────┘ └──────┘ └──────┘        │
├─────────────────────────────────────┤
│ Alerts Timeline:                    │
│ • 2 min ago: Outlet 1 closed       │
│ • 1 hr ago: New 2★ review          │
│ • 3 hrs ago: 5 items out of stock  │
├─────────────────────────────────────┤
│ Quick Stats:                        │
│ Uptime: 97.3% | Lost: $340 | ★4.6 │
└─────────────────────────────────────┘
```

#### Restaurant Detail Screen
- Current status with last check timestamp
- Operating hours and platform info
- Recent incidents with resolution status
- Action buttons (Open Now, Restock Items, Reply Reviews)
- 7-30 day trend charts

#### Incident Detail Screen
- Timeline of status changes
- Estimated revenue impact
- Resolution steps (manual or automated)
- Communication log (alerts sent)
- Post-incident analysis

### 5.3 Mobile Experience

#### Trusted Web Application (TWA)
- Installable web app for Android/iOS
- Home screen icon and splash screen
- Push notifications support
- Offline capability for viewing cached data
- Native-like performance

#### Responsive Breakpoints
- Mobile: 320-768px (single column)
- Tablet: 768-1024px (two columns)
- Desktop: 1024px+ (multi-column grid)

---

## 6. Data Model

### 6.1 Core Entities

```ruby
# Users
User {
  id: UUID
  email: string (unique)
  password_hash: string
  name: string
  phone: string
  timezone: string
  notification_preferences: JSON
  subscription_tier: enum
  subscription_status: enum
  trial_ends_at: datetime
  created_at: datetime
}

# Restaurants/Outlets
Restaurant {
  id: UUID
  user_id: UUID (FK)
  platform: enum [grab, gojek]
  platform_url: string
  platform_id: string
  name: string
  address: string
  operating_hours: JSON
  current_status: enum
  last_check_at: datetime
  notification_channels: JSON
  created_at: datetime
}

# Monitoring Sessions
MonitoringSession {
  id: UUID
  restaurant_id: UUID (FK)
  checked_at: datetime
  status: enum [open, closed, error]
  rating: decimal
  review_count: integer
  menu_snapshot: JSON
  out_of_stock_items: JSON
  raw_data: JSON
}

# Incidents
Incident {
  id: UUID
  restaurant_id: UUID (FK)
  type: enum [closure, rating_drop, review, out_of_stock]
  detected_at: datetime
  resolved_at: datetime
  auto_resolved: boolean
  estimated_loss: decimal
  details: JSON
}

# Notifications
Notification {
  id: UUID
  incident_id: UUID (FK)
  channel: enum [whatsapp, telegram, email, web_push]
  recipient: string
  sent_at: datetime
  delivered: boolean
  error_message: string
}

# Reviews
Review {
  id: UUID
  restaurant_id: UUID (FK)
  platform_review_id: string
  rating: integer
  comment: text
  author: string
  posted_at: datetime
  replied: boolean
  reply_text: text
  detected_at: datetime
}
```

### 6.2 Data Flow Architecture

```
[Bright Data Scraper] → [N8N Workflow] → [Rails API]
                                              ↓
                                        [SQLite DB]
                                              ↓
                            [Notification Service] → [WhatsApp/Telegram/Email]
                                              ↓
                                      [Web Dashboard]
```

---

## 7. Technical Architecture

### 7.1 Technology Stack

#### Backend
- **Framework:** Ruby on Rails 7.x
- **Database:** SQLite (MVP) → PostgreSQL (scale)
- **Background Jobs:** Sidekiq
- **Caching:** Redis (when needed)
- **API:** RESTful JSON API

#### Frontend
- **Framework:** Rails Views + Hotwire/Stimulus
- **Styling:** Tailwind CSS
- **JavaScript:** Stimulus controllers
- **Real-time:** ActionCable for live updates

#### Automation & Monitoring
- **Orchestration:** N8N (self-hosted)
- **Web Scraping:** Bright Data
- **Scheduling:** N8N cron triggers
- **Webhook Processing:** Rails webhooks controller

#### Infrastructure
- **Hosting:** Hetzner Cloud
- **Monitoring:** Uptime monitoring via N8N
- **Logging:** Rails logs + structured logging
- **Deployment:** Capistrano or Docker

### 7.2 API Design

#### REST Endpoints

```
# Authentication
POST   /api/auth/signup
POST   /api/auth/login
POST   /api/auth/logout
POST   /api/auth/refresh

# Restaurants
GET    /api/restaurants
POST   /api/restaurants
GET    /api/restaurants/:id
PUT    /api/restaurants/:id
DELETE /api/restaurants/:id

# Monitoring
GET    /api/restaurants/:id/status
GET    /api/restaurants/:id/history
GET    /api/restaurants/:id/incidents

# Actions (Premium)
POST   /api/restaurants/:id/open
POST   /api/restaurants/:id/restock
POST   /api/reviews/:id/reply

# Analytics
GET    /api/analytics/downtime
GET    /api/analytics/losses
GET    /api/analytics/trends
```

### 7.3 Security Architecture

#### Authentication & Authorization
- JWT-based authentication
- Role-based access (User, Super Admin)
- API rate limiting (100 requests/minute)
- CORS configuration for web app

#### Data Protection
- HTTPS everywhere
- Encrypted credentials storage
- Secure webhook endpoints
- Input validation and sanitization

---

## 8. Integration Requirements

### 8.1 Bright Data Integration

**Purpose:** Bypass anti-bot protection on delivery platforms

**Implementation:**
```javascript
// N8N Workflow Node
{
  "method": "POST",
  "url": "https://api.brightdata.com/serp",
  "headers": {
    "Authorization": "Bearer ${BRIGHT_DATA_API_KEY}"
  },
  "body": {
    "url": "${RESTAURANT_URL}",
    "country": "id",
    "format": "json",
    "device": "desktop"
  }
}
```

**Requirements:**
- Handle rate limits gracefully
- Implement retry logic for failures
- Cache successful responses for 5 minutes
- Monitor credit usage

### 8.2 WhatsApp Business API

**Purpose:** Primary notification channel

**Implementation:**
- Use official WhatsApp Business API
- Template messages for alerts
- Support multiple recipient numbers
- Handle delivery confirmations

**Message Templates:**
```
ALERT: {{restaurant_name}} is showing CLOSED on {{platform}}!
Time closed: {{duration}}
Estimated loss: ${{amount}}
Open now: {{action_link}}
```

### 8.3 Telegram Bot API

**Purpose:** Notifications for Russian-speaking owners

**Features:**
- Individual bot messages
- Channel broadcasting
- Inline keyboard for quick actions
- Multi-language support

### 8.4 Stripe Integration

**Purpose:** Subscription billing

**Requirements:**
- Stripe Singapore account
- Support SGD and USD
- Subscription management
- Invoice generation
- Payment failure handling

---

## 9. Development Roadmap

### 9.1 Phase 1: MVP (Weeks 1-4)

**Core Monitoring & Alerts**
- [ ] Rails application setup
- [ ] Database schema implementation
- [ ] User authentication (basic)
- [ ] Restaurant CRUD operations
- [ ] N8N + Bright Data integration
- [ ] Basic monitoring workflow
- [ ] WhatsApp/Telegram notifications
- [ ] Simple dashboard

**Success Criteria:**
- Monitor 50 test restaurants
- Detect closures within 5 minutes
- Send alerts successfully

### 9.2 Phase 2: Full Features (Weeks 5-8)

**Enhanced Monitoring**
- [ ] Review tracking
- [ ] Out-of-stock detection
- [ ] Downtime analytics
- [ ] Revenue loss calculations
- [ ] Email notifications
- [ ] Improved dashboard
- [ ] Incident history

**Success Criteria:**
- 100 beta users onboarded
- All core features functional
- <5% false positive rate

### 9.3 Phase 3: Automation (Weeks 9-12)

**Premium Features**
- [ ] Auto-reopen functionality
- [ ] Auto-restock capability
- [ ] Review response templates
- [ ] Stripe payment integration
- [ ] Subscription management
- [ ] Multi-outlet support
- [ ] TWA implementation

**Success Criteria:**
- Payment processing live
- 25% trial conversion rate
- 500 paying customers

### 9.4 Phase 4: Scale (Months 4-6)

**Growth Features**
- [ ] API for integrations
- [ ] Advanced analytics
- [ ] Competitor monitoring
- [ ] Menu optimization tools
- [ ] White-label options
- [ ] Multi-language support
- [ ] Enterprise features

---

## 10. Success Metrics & KPIs

### 10.1 Product Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Uptime Detection Accuracy | >99% | True positives / Total checks |
| Alert Delivery Rate | >95% | Delivered / Sent |
| False Positive Rate | <5% | False alerts / Total alerts |
| Average Detection Time | <5 min | Time to detect closure |
| Platform Coverage | 100% | Both Grab and Gojek |

### 10.2 Business Metrics

| Metric | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|----------|
| Total Customers | 100 | 500 | 2,500 |
| MRR | $3K | $25K | $125K |
| Trial Conversion | 20% | 25% | 30% |
| Monthly Churn | <10% | <7% | <5% |
| CAC | <$50 | <$30 | <$20 |
| LTV/CAC | >3 | >5 | >10 |

### 10.3 Customer Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Revenue Saved/Customer | >$500/mo | Via incident tracking |
| Time Saved/Customer | >10 hrs/mo | Via automation metrics |
| Rating Improvement | +0.3 stars | 3-month average |
| NPS Score | >50 | Quarterly survey |
| Support Tickets | <0.5/customer | Monthly average |

---

## 11. Risk Management

### 11.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Platform blocks scraping | High | Medium | Multiple scraping methods, official API negotiations |
| Platform UI changes | Medium | High | Automated change detection, rapid fix capability |
| Scaling issues | Medium | Medium | Performance testing, gradual rollout |
| Data accuracy problems | High | Low | Validation layers, manual review options |

### 11.2 Business Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Low trial conversion | High | Medium | Onboarding optimization, value demonstration |
| High churn rate | High | Medium | Engagement features, success tracking |
| Competition from platforms | High | Low | Fast execution, superior UX |
| Market size overestimation | Medium | Low | Gradual expansion, validate each segment |

### 11.3 Contingency Plans

**If Scraping Blocked:**
1. Negotiate official partnership
2. Pivot to browser extension model
3. Focus on API-available features

**If Growth Slower:**
1. Expand to other SEA markets faster
2. Add adjacent features (POS integration)
3. White-label to POS providers

---

## 12. Launch Strategy

### 12.1 Beta Launch (Month 1-2)

**Target:** 100 beta users
- Free access for feedback
- Bali F&B Facebook groups
- Direct outreach to prospects
- Focus on product refinement

### 12.2 Soft Launch (Month 3)

**Target:** 500 paying customers
- 14-day free trial
- $29 promotional pricing
- Content marketing activation
- Referral program launch

### 12.3 Full Launch (Month 4-6)

**Target:** 2,500 customers
- Full pricing tiers
- Partnership channel activation
- Paid acquisition if CAC positive
- Geographic expansion

---

## 13. Support & Documentation

### 13.1 Customer Support

**Channels:**
- Email support (all tiers)
- WhatsApp support (Command Center)
- Knowledge base (self-service)
- Video tutorials

**SLA:**
- Monitor: 24-hour response
- Autopilot: 12-hour response
- Command Center: 2-hour response

### 13.2 Documentation Requirements

- API documentation (when released)
- User onboarding guide
- Troubleshooting guides
- Video walkthroughs
- Best practices guide

---

## Appendices

### A. Glossary

- **CAC:** Customer Acquisition Cost
- **LTV:** Lifetime Value
- **MRR:** Monthly Recurring Revenue
- **ICP:** Ideal Customer Profile
- **TWA:** Trusted Web Application
- **SLA:** Service Level Agreement

### B. Competitive Analysis

| Competitor | Strengths | Weaknesses | Our Advantage |
|------------|-----------|------------|---------------|
| Manual Monitoring | Free | Time-consuming, error-prone | Automation |
| TabSquare | Established | Hardware-dependent, expensive | Software-only |
| StoreHub | Regional presence | Generic, not delivery-focused | Specialized |

### C. Technical Debt Considerations

**Future Refactoring Needs:**
- SQLite to PostgreSQL migration
- Monolith to microservices (if needed)
- Horizontal scaling architecture
- Real-time WebSocket implementation

---

**Document Version Control:**
- v1.0 - Initial PRD creation
- Last Updated: January 2025
- Next Review: Post-MVP launch

**Document prepared for:** Development team handoff and implementation