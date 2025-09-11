# DeliveryTracker Product Requirements Document (PRD)

## Executive Summary

**Product Name:** DeliveryTracker  
**Version:** 1.0 (Phase 1 - Monitoring Only)  
**Target Launch:** TBD  
**Product Manager:** [Your Name]  
**Last Updated:** September 2025

### TL;DR
DeliveryTracker protects foreign F&B business owners in Bali from hidden revenue losses by automatically monitoring their Grab/GoFood restaurant status, reviews, and menu availability - delivering instant alerts when issues occur that could cost $70-200+ per day in missed orders.

---

## Product Overview and Objectives

### Problem Statement
Foreign-owned F&B businesses in Bali (cafés, restaurants, dark kitchens) face critical blind spots in their delivery platform operations:

- **Silent Revenue Loss**: Restaurants get auto-closed by Grab/GoFood due to order cancellations, system issues, or courier problems - often without immediate notification
- **Delayed Issue Detection**: Bad reviews, out-of-stock items, and closure incidents are discovered hours or days later
- **Management Overhead**: Owners cannot manually monitor platforms every few hours but don't fully trust staff to catch all issues
- **Direct Financial Impact**: Each "closed" day results in $70-200+ in lost revenue; ratings below 4.5★ reduce visibility and orders

### Solution Vision
An automated monitoring system that acts as a "co-pilot" for delivery platform management, providing instant alerts and historical insights to prevent revenue loss and maintain online reputation.

### Success Metrics
- **Primary**: Reduction in undetected closure hours (target: <30 minutes detection time)
- **Revenue Protection**: Prevention of $200+ daily revenue losses per client
- **User Engagement**: >80% of critical alerts acknowledged within 1 hour
- **Customer Retention**: >90% subscription renewal rate after trial period

---

## Target Audience

### Primary ICP (Ideal Customer Profile)
- **Demographics**: Foreign owners and co-owners of small F&B businesses in Bali
- **Business Profile**: 1-3 outlets, 10-20 staff per location, 20-150 delivery orders/day
- **Structure**: Local operations manager hired, owner tracks profit and KPIs remotely
- **Revenue Dependency**: 70%+ revenue from GoFood/GrabFood platforms
- **Pain Points**: Time-poor, cannot monitor platforms constantly, don't fully trust staff oversight
- **Technology Comfort**: Basic web/mobile app usage, active on WhatsApp/Telegram

### User Personas
1. **Remote Owner** - Lives abroad, checks business metrics daily, needs instant alerts
2. **Local Owner-Operator** - On-site but busy with operations, wants automated monitoring
3. **Operations Manager** - Hired local staff, responsible for daily platform management

---

## Core Features and Functionality

### Phase 1: Monitoring and Alerting (MVP)

#### 1. Restaurant Onboarding
**User Story**: As a restaurant owner, I want to quickly connect my delivery platforms so the system can start monitoring immediately.

**Acceptance Criteria**:
- User provides Grab and/or GoFood restaurant URLs
- System scrapes public data to extract: restaurant name, location, operating hours
- User confirms extracted information for accuracy
- Monitoring begins within 5 minutes of confirmation

**Technical Implementation**:
- URL validation for Grab/GoFood domains
- Public page scraping using BrightData
- Data extraction: restaurant_name (string), location (string), operating_hours (JSON object)
- Confirmation interface with edit capability

#### 2. Status Monitoring
**User Story**: As a restaurant owner, I want to know immediately when my restaurant appears closed on delivery platforms during business hours.

**Acceptance Criteria**:
- System checks restaurant status every 15 minutes
- Detects both manual closures and system-triggered auto-pauses
- Alerts sent within 1 minute of detection via user's preferred channels
- Distinguishes between "expected closed" (outside hours) and "unexpected closed" (during hours)

**Technical Implementation**:
- Scheduled jobs every 15 minutes
- Status parsing from public Grab/GoFood pages
- Cross-reference with stored operating hours
- Status states: `open`, `closed_manual`, `closed_auto`, `closed_system`

#### 3. Review Monitoring and Categorization
**User Story**: As a restaurant owner, I want immediate alerts about poor reviews so I can respond quickly to protect my reputation.

**Acceptance Criteria**:
- Real-time detection of new reviews (1-4 stars)
- AI-powered categorization: speed, packaging, taste, service
- Alert includes review text, rating, category, and timestamp
- Historical review dashboard with trend analysis

**Technical Implementation**:
- Review scraping from public pages
- AI categorization using OpenAI API or similar
- Review data model: rating (int), text (string), category (enum), timestamp (datetime)
- Sentiment analysis integration

#### 4. Out-of-Stock Tracking
**User Story**: As a restaurant owner, I want to know which menu items are marked unavailable so I can ensure they're restocked promptly.

**Acceptance Criteria**:
- Daily reports on out-of-stock items
- Track duration of unavailability
- Alert on items out-of-stock >24 hours
- Historical view of stock-out patterns

**Technical Implementation**:
- Menu scraping during status checks
- Item availability parsing
- Stock status tracking: item_name (string), status (enum), timestamp (datetime)
- Duration calculations and reporting

#### 5. Multi-Channel Notifications
**User Story**: As a restaurant owner, I want to receive alerts through my preferred communication channels and share them with my team.

**Acceptance Criteria**:
- Support for WhatsApp, Telegram, Email notifications
- Option to send to individual accounts or group chats
- User configurable notification preferences per alert type
- Checkbox interface for channel selection

**Technical Implementation**:
- WhatsApp Business API integration
- Telegram Bot API integration
- Email service (SendGrid/AWS SES)
- User notification preferences: channels (array), groups (array), alert_types (JSON)

#### 6. Smart Notification Management
**User Story**: As a restaurant owner, I want to control notification frequency to avoid alert fatigue during known issues.

**Acceptance Criteria**:
- "Acknowledge" button: "Yes, I know" - stops alerts for this specific issue
- "Postpone" options: Don't notify for 2 hours, rest of day, or tomorrow
- Item-specific suppression: Disable out-of-stock alerts for specific dishes (1-5 days)
- Visual indicators for suppressed alerts

**Technical Implementation**:
- Alert suppression database table: alert_id, suppression_type, expiry_time
- Suppression logic in notification service
- UI components for alert management
- Suppression states: `acknowledged`, `postponed_hours`, `postponed_day`, `item_specific`

#### 7. Historical Dashboard
**User Story**: As a restaurant owner, I want to see patterns in closures, reviews, and stock issues to improve my operations.

**Acceptance Criteria**:
- Current status overview (open/closed, recent reviews, stock levels)
- Historical closure incidents with duration and cause
- Review trends and rating averages over time
- Out-of-stock frequency reports
- Indefinite data retention for dispute resolution

**Technical Implementation**:
- React-based dashboard with responsive design
- Data visualization using Chart.js or D3.js
- Historical data aggregation and trend analysis
- Export functionality for reporting

#### 8. TWA Mobile Experience
**User Story**: As a restaurant owner, I want app-like access to my monitoring dashboard on mobile devices.

**Acceptance Criteria**:
- Trusted Web App (TWA) functionality for Android and iOS
- Add to home screen capability
- Push notification support
- Offline status page for basic information

**Technical Implementation**:
- Progressive Web App (PWA) setup with manifest.json
- Service worker for offline functionality
- Push notification API integration
- Mobile-optimized responsive design

#### 9. Bot Integration
**User Story**: As a restaurant owner, I want quick access to my restaurant status directly within WhatsApp and Telegram.

**Acceptance Criteria**:
- Telegram bot with /status, /reviews, /stock commands
- WhatsApp bot with button-based navigation
- Deep linking to full web dashboard
- Real-time status queries

**Technical Implementation**:
- Telegram Bot API with webhook integration
- WhatsApp Business API for interactive messages
- Bot command parsing and response generation
- Deep link generation to web app

---

## Phase 2: Action Capabilities (Future Development)

### Advanced Features (Roadmap)
1. **Direct Platform Actions**
   - "Reopen Restaurant" button for closed venues
   - "Restock Item" functionality for out-of-stock dishes
   - Review response submission
   - Review complaint/reporting

2. **AI-Powered Review Management**
   - Automatic review response generation with 3 options
   - Manual editing capability
   - WhatsApp number insertion in responses
   - Fully automated response posting (optional)

3. **Sales Analytics**
   - Revenue data collection and reporting
   - Performance trend analysis
   - Competitive benchmarking
   - Business intelligence dashboard

**Phase 2 Requirements:**
- Merchant account access (requires separate onboarding)
- Manager-developer account creation for automation
- Enhanced security and liability considerations
- Premium pricing tier

---

## Technical Stack Recommendations

### Frontend Architecture
- **Framework**: React.js with TypeScript
- **Styling**: Tailwind CSS for responsive design
- **PWA**: Workbox for service worker and offline capability
- **State Management**: Redux Toolkit or Zustand
- **Charts**: Chart.js or Recharts for data visualization

### Backend Architecture
- **Runtime**: Node.js with Express.js or Next.js API routes
- **Database**: PostgreSQL for relational data, Redis for caching
- **Authentication**: NextAuth.js or Auth0
- **Job Scheduling**: Bull Queue with Redis
- **API Design**: RESTful APIs with OpenAPI documentation

### Scraping and Data Collection
- **Primary**: BrightData for web scraping and anti-bot protection
- **Mobile Emulation**: Appium or custom Android/iOS automation
- **Rate Limiting**: Redis-based throttling
- **Data Parsing**: Cheerio for HTML parsing, custom parsers for mobile data

### Notification Services
- **WhatsApp**: WhatsApp Business API (Cloud API)
- **Telegram**: Telegram Bot API with webhook support
- **Email**: SendGrid or AWS SES
- **Push Notifications**: Firebase Cloud Messaging (FCM)

### Infrastructure and DevOps
- **Hosting**: AWS or Vercel for web app, VPS for scraping services
- **Database Hosting**: AWS RDS or Supabase
- **Monitoring**: Sentry for error tracking, DataDog for performance
- **CI/CD**: GitHub Actions or Vercel automatic deployments

### AI and Machine Learning
- **Review Categorization**: OpenAI GPT-4 or Claude API
- **Response Generation**: OpenAI GPT-4 with custom prompts
- **Sentiment Analysis**: AWS Comprehend or custom model

---

## Data Models and Architecture

### Core Database Schema

```sql
-- Users and Restaurants
users (
  id: uuid PRIMARY KEY,
  email: string UNIQUE,
  created_at: timestamp,
  subscription_tier: enum
)

restaurants (
  id: uuid PRIMARY KEY,
  user_id: uuid REFERENCES users(id),
  name: string,
  location: string,
  grab_url: string,
  gofood_url: string,
  operating_hours: jsonb,
  created_at: timestamp
)

-- Monitoring Data
status_checks (
  id: uuid PRIMARY KEY,
  restaurant_id: uuid REFERENCES restaurants(id),
  platform: enum('grab', 'gofood'),
  status: enum('open', 'closed_manual', 'closed_auto', 'closed_system'),
  checked_at: timestamp,
  closure_reason: string
)

reviews (
  id: uuid PRIMARY KEY,
  restaurant_id: uuid REFERENCES restaurants(id),
  platform: enum('grab', 'gofood'),
  rating: integer,
  text: text,
  category: enum('speed', 'packaging', 'taste', 'service'),
  sentiment_score: float,
  created_at: timestamp
)

stock_status (
  id: uuid PRIMARY KEY,
  restaurant_id: uuid REFERENCES restaurants(id),
  item_name: string,
  status: enum('available', 'out_of_stock'),
  platform: enum('grab', 'gofood'),
  checked_at: timestamp
)

-- Notifications and Alerts
alerts (
  id: uuid PRIMARY KEY,
  restaurant_id: uuid REFERENCES restaurants(id),
  type: enum('closure', 'review', 'stock'),
  severity: enum('low', 'medium', 'high'),
  message: text,
  data: jsonb,
  sent_at: timestamp
)

alert_suppressions (
  id: uuid PRIMARY KEY,
  alert_id: uuid REFERENCES alerts(id),
  suppression_type: enum('acknowledged', 'postponed_hours', 'postponed_day', 'item_specific'),
  expires_at: timestamp,
  created_at: timestamp
)

notification_preferences (
  id: uuid PRIMARY KEY,
  user_id: uuid REFERENCES users(id),
  whatsapp_number: string,
  telegram_username: string,
  email_address: string,
  channels: jsonb,
  alert_types: jsonb
)
```

### API Endpoints

```typescript
// Authentication
POST /api/auth/register
POST /api/auth/login
POST /api/auth/logout

// Restaurant Management
POST /api/restaurants - Add new restaurant
GET /api/restaurants - List user's restaurants
PUT /api/restaurants/:id - Update restaurant details
DELETE /api/restaurants/:id - Remove restaurant

// Monitoring Data
GET /api/restaurants/:id/status - Current status
GET /api/restaurants/:id/reviews - Recent reviews
GET /api/restaurants/:id/stock - Stock status
GET /api/restaurants/:id/history - Historical data

// Alerts and Notifications
GET /api/alerts - List recent alerts
POST /api/alerts/:id/suppress - Suppress alert
PUT /api/notifications/preferences - Update notification settings

// Bot Endpoints
POST /api/webhook/telegram - Telegram bot webhook
POST /api/webhook/whatsapp - WhatsApp bot webhook
```

---

## Security and Privacy Considerations

### Data Protection
- **User Data**: GDPR-compliant data handling for EU users
- **Restaurant Data**: Secure storage of business information
- **Scraping Ethics**: Respect robots.txt and rate limiting
- **Data Retention**: Indefinite storage with user consent for business purposes

### Authentication and Authorization
- **User Authentication**: JWT tokens with refresh mechanism
- **API Security**: Rate limiting, input validation, SQL injection prevention
- **Bot Security**: Webhook verification and command validation
- **Phase 2 Security**: Enhanced security for merchant account access

### Compliance Requirements
- **GDPR**: Right to data portability and deletion
- **Indonesian Data Protection**: Local compliance for Bali market
- **Platform Terms**: Compliance with Grab/GoFood terms of service
- **Business Registration**: Proper business licensing in Indonesia

---

## Development Phases and Milestones

### Phase 1: MVP (Months 1-3)
**Goal**: Launch core monitoring functionality with basic alerting

**Sprint 1 (Month 1)**:
- User authentication and restaurant onboarding
- Basic web scraping infrastructure
- Simple status monitoring (open/closed detection)

**Sprint 2 (Month 2)**:
- Review monitoring and categorization
- Multi-channel notification system
- Alert suppression functionality

**Sprint 3 (Month 3)**:
- Historical dashboard and reporting
- TWA mobile experience
- Bot integration (basic commands)
- User acceptance testing and bug fixes

### Phase 1.5: Enhancement (Months 4-5)
**Goal**: Improve user experience and add advanced monitoring

**Sprint 4 (Month 4)**:
- Out-of-stock tracking
- Advanced notification preferences
- Performance optimization and scaling

**Sprint 5 (Month 5)**:
- Mobile app emulation for Grab Merchant data
- Enhanced dashboard analytics
- Customer onboarding improvements

### Phase 2: Action Capabilities (Months 6-9)
**Goal**: Add direct platform interaction features

**Sprint 6-8 (Months 6-8)**:
- Merchant account integration framework
- AI-powered review response system
- Direct action buttons (reopen, restock, reply)

**Sprint 9 (Month 9)**:
- Sales data collection and analytics
- Premium tier launch
- Advanced business intelligence features

---

## Technical Challenges and Mitigation Strategies

### High-Priority Challenges

#### 1. Mobile App Data Extraction
**Challenge**: Some Grab Merchant data only available in mobile app, not web interface
**Technical Risk**: High - Core functionality depends on this data
**Mitigation Strategy**:
- Research Appium-based Android/iOS automation
- Create dedicated mobile scraping infrastructure
- Develop fallback mechanisms for web-only data
- Consider reverse engineering mobile API calls

#### 2. iOS Authentication and Account Management
**Challenge**: Grab Merchant account authentication in iOS environment
**Technical Risk**: High - Affects ability to access merchant data
**Mitigation Strategy**:
- Test authentication flows in controlled environment
- Develop manager-developer account system
- Create robust session management
- Plan for manual fallback procedures

#### 3. Platform Structure Changes
**Challenge**: Grab/GoFood may change page structures, breaking scrapers
**Technical Risk**: Medium - Regular maintenance required
**Mitigation Strategy**:
- Implement robust CSS selector strategies
- Create automated tests for scraping logic
- Build monitoring for scraping failures
- Develop rapid response process for fixes

#### 4. Scaling and Cost Management
**Challenge**: BrightData costs increasing with restaurant count and frequency
**Technical Risk**: Medium - Affects business model sustainability
**Mitigation Strategy**:
- Optimize scraping frequency based on business hours
- Implement intelligent caching strategies
- Research alternative scraping solutions
- Plan tiered monitoring frequencies

### Lower-Priority Challenges

#### 5. WhatsApp API Limitations
**Challenge**: Potential rate limiting or policy restrictions
**Technical Risk**: Low - Alternative channels available
**Mitigation Strategy**:
- Use official WhatsApp Business API
- Implement message queuing and rate limiting
- Provide Telegram as primary alternative
- Monitor API usage and compliance

#### 6. User Onboarding Complexity (Phase 2)
**Challenge**: Educating non-technical users about account access requirements
**Business Risk**: Medium - Affects Phase 2 adoption
**Mitigation Strategy**:
- Create comprehensive onboarding documentation
- Develop video tutorials and guides
- Implement step-by-step account setup wizard
- Provide dedicated customer support

---

## Performance and Scalability Requirements

### System Performance Targets
- **Response Time**: Web dashboard loads in <2 seconds
- **Alert Latency**: Notifications sent within 60 seconds of detection
- **Uptime**: 99.5% availability (excluding planned maintenance)
- **Scraping Frequency**: Consistent 15-minute intervals per restaurant

### Scalability Planning
- **Initial Capacity**: Support 100 restaurants with 15-minute monitoring
- **Growth Target**: Scale to 1,000 restaurants within 12 months
- **Database Performance**: Sub-second query response for dashboard data
- **Notification Throughput**: Handle 1,000 concurrent notifications

### Infrastructure Scaling
- **Horizontal Scaling**: Microservices architecture for scraping workers
- **Database Scaling**: Read replicas for dashboard queries
- **Caching Strategy**: Redis for frequently accessed data
- **CDN**: Static asset distribution for global performance

---

## Business Model and Pricing Integration

### Technical Requirements for Billing
- **Subscription Management**: Integration with Stripe or local payment processors
- **Usage Tracking**: Monitor scraping frequency and notification volume
- **Billing Cycles**: Monthly recurring billing with prorated changes
- **Trial Management**: 14-day free trial with automatic conversion

### Feature Gating
- **Tier Differences**: Basic monitoring vs. advanced analytics
- **Restaurant Limits**: 1 restaurant for basic, unlimited for premium
- **API Access**: Rate limiting based on subscription tier
- **Data Retention**: Different retention periods by tier

---

## Go-to-Market Technical Considerations

### Analytics and Tracking
- **User Behavior**: Google Analytics 4 and Mixpanel integration
- **Funnel Analysis**: Track onboarding completion rates
- **Feature Usage**: Monitor dashboard engagement and alert response rates
- **Performance Metrics**: Core Web Vitals and user experience monitoring

### Integration with Marketing Efforts
- **Landing Page Optimization**: A/B testing framework
- **Lead Capture**: Integration with CRM and email marketing
- **Referral System**: Built-in referral tracking and rewards
- **Content Marketing**: SEO-optimized blog with technical insights

---

## Testing and Quality Assurance

### Testing Strategy
- **Unit Testing**: Jest for JavaScript/TypeScript components
- **Integration Testing**: Supertest for API endpoint testing
- **End-to-End Testing**: Playwright for full user journey testing
- **Scraping Tests**: Automated validation of data extraction accuracy

### Quality Metrics
- **Code Coverage**: Minimum 80% test coverage
- **Bug Tracking**: Sentry for production error monitoring
- **Performance Testing**: Load testing with Artillery or k6
- **Security Testing**: OWASP compliance and vulnerability scanning

### User Acceptance Testing
- **Beta Program**: 10-20 friendly restaurants for pre-launch testing
- **Feedback Integration**: Built-in feedback collection and bug reporting
- **Performance Monitoring**: Real-user monitoring and analytics
- **Support Integration**: Helpdesk and documentation system

---

## Deployment and DevOps

### Deployment Strategy
- **Environment Management**: Development, staging, and production environments
- **CI/CD Pipeline**: Automated testing and deployment via GitHub Actions
- **Database Migrations**: Automated schema updates with rollback capability
- **Zero-Downtime Deployment**: Blue-green deployment for production updates

### Monitoring and Observability
- **Application Monitoring**: DataDog or New Relic for performance tracking
- **Error Tracking**: Sentry for real-time error detection and alerting
- **Uptime Monitoring**: External monitoring with PagerDuty integration
- **Log Management**: Centralized logging with search and alerting

### Backup and Disaster Recovery
- **Database Backups**: Daily automated backups with point-in-time recovery
- **Code Repository**: Git-based version control with multiple remotes
- **Configuration Management**: Infrastructure as Code with Terraform
- **Recovery Testing**: Quarterly disaster recovery drills

---

## Future Expansion Possibilities

### Technical Expansion Areas
- **Multi-Country Support**: Expand beyond Indonesia to Thailand, Philippines
- **Additional Platforms**: Include Foodpanda, local delivery services
- **Advanced AI**: Predictive analytics for optimal operating hours
- **Integration APIs**: Allow third-party POS and management system integration

### Business Model Evolution
- **White-Label Solution**: Offer platform to restaurant management companies
- **Franchise Support**: Multi-location management for restaurant chains
- **Consultant Dashboard**: Tools for restaurant consultants and managers
- **Marketplace Integration**: Direct integration with ingredient suppliers

---

## Appendices

### A. Technical Research References
- BrightData Documentation and Pricing
- WhatsApp Business API Guidelines
- Telegram Bot API Reference
- Grab/GoFood Terms of Service Analysis

### B. Competitive Analysis
- Current manual monitoring solutions
- Existing restaurant management platforms
- Social media monitoring tools
- Customer review management systems

### C. User Research Findings
- Interview insights from target restaurant owners
- Pain point analysis and prioritization
- Willingness to pay research
- Feature preference rankings

---

**Document Control**
- **Version**: 1.0
- **Created**: September 2025
- **Owner**: [Your Name]
- **Reviewers**: Development Team, Business Stakeholders
- **Next Review**: [Date]

This PRD serves as the foundation for DeliveryTracker development and should be updated as requirements evolve through user feedback and technical discoveries.