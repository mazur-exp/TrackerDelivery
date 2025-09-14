# TrackerDelivery UI Design System Documentation

## 🎨 Design Philosophy

TrackerDelivery's design system is built on principles of **clean monitoring**, **status-driven design**, and **restaurant-focused UX**. This comprehensive guide documents the design patterns, components, and techniques used specifically for delivery platform monitoring interfaces.

## 🎯 Core Design Principles

### 1. **Green-First Design System**
- Primary brand color: Green-600 (#16A34A) representing active/online status
- Clean white backgrounds with subtle gray-50 accents
- Status-driven color coding for instant recognition

### 2. **Card-Based Dashboard Architecture**
- Clean white cards with rounded-xl corners
- Shadow-sm with hover:shadow-md transitions
- Border-based separation instead of heavy shadows

### 3. **Status-Driven Color Palette**
- Primary: Green-600 (#16A34A) for active/online states
- Success: Green tones for positive metrics
- Warning: Yellow for busy/attention states
- Error: Red for offline/critical states
- Info: Blue/Purple for neutral information

### 4. **Functional Spacing**
- Dashboard-friendly padding: p-6 for cards, p-4 for internal elements
- Clean section separation with consistent gaps
- Responsive grid layouts with proper breathing room

## 🎨 Color System

### Primary Brand Colors
```css
/* DeliveryTracker Green System */
.primary-green {
  @apply bg-green-600; /* #16A34A */
}

.primary-green-dark {
  @apply bg-green-700; /* #15803D */
}

.primary-green-light {
  @apply bg-green-400; /* #4ADE80 */
}

.green-backgrounds {
  @apply bg-green-50; /* #F0FDF4 - Light backgrounds */
  @apply bg-green-100; /* #DCFCE7 - Slightly stronger */
}
```

### Status Color System
```css
/* Status-Based Colors */
.status-online { @apply text-green-700 bg-green-50; }
.status-offline { @apply text-red-700 bg-red-50; }
.status-busy { @apply text-yellow-700 bg-yellow-50; }
.status-warning { @apply text-orange-700 bg-orange-50; }
.status-info { @apply text-blue-700 bg-blue-50; }
```

### Platform-Specific Colors
```css
/* Platform Colors */
.platform-gojek { @apply bg-green-600; /* Gojek Green */ }
.platform-grab { @apply bg-green-600; /* Grab Green */ }
.platform-foodpanda { @apply bg-pink-500; /* Foodpanda Pink */ }
.platform-general { @apply bg-gray-600; /* Neutral platforms */ }
```

### Metric Card Colors
```css
/* Dashboard Metric Cards */
.metric-revenue { @apply border-green-200 bg-green-50/50; }
.metric-orders { @apply border-blue-200 bg-blue-50/50; }
.metric-stores { @apply border-purple-200 bg-purple-50/50; }
.metric-rating { @apply border-orange-200 bg-orange-50/50; }
```

## 🗂️ Layout Patterns

### 1. **Dashboard Header with Live Status**
```html
<div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
  <div>
    <div class="flex items-center space-x-2 mb-2">
      <div class="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center">
        <i data-lucide="monitor" class="w-5 h-5 text-white"></i>
      </div>
      <span class="text-xl font-bold text-gray-900">DeliveryTracker</span>
    </div>
    <h1 class="text-3xl font-bold text-gray-900">Restaurant Dashboard</h1>
    <p class="text-gray-600">Monitor your delivery platforms in real-time</p>
  </div>
  <div class="flex items-center gap-3">
    <div class="inline-flex items-center px-3 py-1 rounded-full border text-sm">
      <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse mr-2"></div>
      Live
    </div>
  </div>
</div>
```

### 2. **Metric Cards Grid**
```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  <div class="bg-white rounded-xl border border-green-200 bg-green-50/50 p-6 shadow-sm">
    <div class="flex flex-row items-center justify-between space-y-0 pb-2">
      <h3 class="text-sm font-medium">Total Revenue</h3>
      <i data-lucide="dollar-sign" class="h-4 w-4 text-green-600"></i>
    </div>
    <div class="text-2xl font-bold text-green-700">Rp 4,240,000</div>
    <p class="text-xs text-green-600 flex items-center gap-1">
      <i data-lucide="trending-up" class="w-3 h-3"></i>
      +12% from yesterday
    </p>
  </div>
</div>
```

### 3. **Restaurant Status Cards**
```html
<div class="bg-white rounded-xl border shadow-sm hover:shadow-md transition-shadow p-6">
  <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
    <div class="flex items-center gap-4">
      <div class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white text-xs font-bold">
        GO
      </div>
      <div>
        <h3 class="font-semibold text-lg">Restaurant Name</h3>
        <p class="text-sm text-gray-500">Platform</p>
      </div>
    </div>
    
    <div class="flex items-center gap-2">
      <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
      <span class="text-sm font-medium text-green-700">Online</span>
    </div>
  </div>
</div>
```

## 🧩 Component Library

### 1. **Status Indicators**

#### Online Status
```html
<div class="flex items-center gap-2">
  <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
  <span class="text-sm font-medium text-green-700">Online</span>
</div>
```

#### Offline Status
```html
<div class="flex items-center gap-2">
  <div class="w-3 h-3 rounded-full bg-red-500 animate-pulse"></div>
  <span class="text-sm font-medium text-red-700">Offline</span>
</div>
```

#### Busy Status
```html
<div class="flex items-center gap-2">
  <div class="w-3 h-3 rounded-full bg-yellow-500 animate-pulse"></div>
  <span class="text-sm font-medium text-yellow-700">Busy</span>
</div>
```

### 2. **Action Buttons**

#### Toggle Online/Offline Button
```html
<button class="inline-flex items-center px-3 py-2 border border-red-200 text-red-600 hover:bg-red-50 rounded-md text-sm font-medium transition-colors">
  <i data-lucide="wifi-off" class="w-4 h-4 mr-2"></i>
  Go Offline
</button>

<button class="inline-flex items-center px-3 py-2 border border-green-200 text-green-600 hover:bg-green-50 rounded-md text-sm font-medium transition-colors">
  <i data-lucide="wifi" class="w-4 h-4 mr-2"></i>
  Go Online
</button>
```

#### Primary Action Button
```html
<button class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-md text-sm font-medium transition-colors">
  Start Free Trial
</button>
```

#### Secondary Button
```html
<button class="px-4 py-2 border border-gray-300 hover:bg-gray-50 rounded-md text-sm font-medium transition-colors">
  Sign In
</button>
```

### 3. **Platform Icons**
```html
<!-- Gojek/GoFood -->
<div class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white text-xs font-bold">
  GO
</div>

<!-- Grab -->
<div class="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center text-white text-xs font-bold">
  GR
</div>

<!-- Foodpanda -->
<div class="w-8 h-8 bg-pink-500 rounded-lg flex items-center justify-center text-white text-xs font-bold">
  FP
</div>
```

### 4. **Alert Components**

#### High Priority Alert
```html
<div class="flex items-center justify-between p-4 border rounded-lg">
  <div class="flex items-center gap-3">
    <div class="inline-flex items-center px-2 py-1 rounded-md border-transparent bg-red-500 text-white text-xs font-medium gap-1">
      <i data-lucide="alert-triangle" class="w-3 h-3"></i>
      HIGH
    </div>
    <div>
      <p class="font-medium">Alert message</p>
      <p class="text-sm text-gray-500">5 mins ago</p>
    </div>
  </div>
</div>
```

#### Info Alert
```html
<div class="bg-green-50 p-4 rounded-lg">
  <p class="text-sm text-green-700">
    <strong>Tip:</strong> Helpful information message
  </p>
</div>
```

### 5. **Navigation Elements**

#### Tab Navigation
```html
<div class="bg-gray-100 rounded-lg p-1 inline-flex">
  <button class="px-4 py-2 text-sm font-medium rounded-md transition-colors bg-white text-gray-900 shadow-sm">
    Restaurants
  </button>
  <button class="px-4 py-2 text-sm font-medium rounded-md transition-colors text-gray-500 hover:text-gray-700">
    Alerts
  </button>
</div>
```

#### Breadcrumbs
```html
<nav class="flex items-center space-x-2 text-sm text-gray-500">
  <a href="/" class="hover:text-gray-700">Dashboard</a>
  <span>›</span>
  <span class="text-gray-900">Restaurant Settings</span>
</nav>
```

## 🎭 Visual Effects

### 1. **Hover Transitions**
```css
/* Standard card hover */
.card-hover {
  @apply hover:shadow-md transition-shadow duration-300;
}

/* Button hover with background change */
.button-hover {
  @apply hover:bg-green-700 transition-colors duration-200;
}

/* Icon button hover */
.icon-hover {
  @apply hover:text-gray-600 transition-colors;
}
```

### 2. **Loading States**
```html
<!-- Spinner -->
<i data-lucide="loader-2" class="w-8 h-8 animate-spin text-green-600"></i>

<!-- Pulsing dot -->
<div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>

<!-- Loading skeleton -->
<div class="animate-pulse">
  <div class="h-4 bg-gray-200 rounded w-3/4"></div>
</div>
```

### 3. **Progress Indicators**
```html
<!-- Progress bar -->
<div class="w-full bg-gray-300 h-1.5 rounded-full overflow-hidden">
  <div class="h-full bg-green-600 transition-all duration-300" style="width: 33%"></div>
</div>

<!-- Step indicators -->
<div class="w-4 h-4 bg-green-600 rounded-full ring-4 ring-green-600/20"></div>
```

## 📱 Responsive Design

### Breakpoint Strategy
```css
/* Mobile-first approach for dashboard */
/* Default: Mobile (< 768px) - Stack cards vertically */
/* md: Tablet (≥ 768px) - 2-column layout */
/* lg: Desktop (≥ 1024px) - 3-4 column layout */
/* xl: Large Desktop (≥ 1280px) - Full dashboard width */
```

### Dashboard Grid Examples
```html
<!-- Metric cards: 1 mobile, 2 tablet, 4 desktop -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  <!-- Metric cards -->
</div>

<!-- Restaurant cards: Single column on mobile, full width on desktop -->
<div class="space-y-4">
  <!-- Restaurant status cards -->
</div>
```

## 🎨 Form Design Patterns

### 1. **Onboarding Forms**
```html
<div class="bg-white border shadow-md rounded-3xl overflow-hidden">
  <div class="bg-gradient-to-r from-green-50 to-emerald-50 border-b p-6">
    <h2 class="text-xl font-semibold text-green-800">Section Title</h2>
    <p class="text-green-600 mt-2">Description</p>
  </div>
  <div class="p-6 space-y-6">
    <!-- Form content -->
  </div>
</div>
```

### 2. **Input Fields**
```html
<div class="space-y-2">
  <label class="flex items-center gap-2 text-sm font-medium">
    <div class="w-6 h-6 bg-green-600 rounded flex items-center justify-center">
      <span class="text-white text-xs font-bold">G</span>
    </div>
    Field Label
  </label>
  <input
    type="text"
    placeholder="Placeholder text"
    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-600/20 focus:border-green-600 transition-all duration-300"
  />
</div>
```

### 3. **Checkboxes with Descriptions**
```html
<div class="flex items-start space-x-3 p-4 rounded-lg border hover:bg-green-50 transition-colors">
  <input type="checkbox" class="mt-1 w-4 h-4 text-green-600 border-gray-300 rounded focus:ring-green-500">
  <div class="flex-1">
    <div class="flex items-center gap-2">
      <i data-lucide="message-square" class="w-5 h-5 text-green-600"></i>
      <label class="font-medium cursor-pointer">Notification Type</label>
    </div>
    <p class="text-sm text-gray-500 mt-1">Description of this option</p>
  </div>
</div>
```

## 🎯 Landing Page Patterns

### 1. **Hero Section**
```html
<section class="py-20 px-4">
  <div class="container mx-auto text-center max-w-4xl">
    <div class="inline-flex items-center px-3 py-1 rounded-full bg-green-50 text-green-700 border border-green-200 text-sm font-medium mb-6">
      🚀 Now monitoring 500+ restaurants
    </div>
    <h1 class="text-4xl md:text-6xl font-bold text-gray-900 mb-6 leading-tight">
      Never Miss an Order
      <span class="text-green-600 block">Again</span>
    </h1>
  </div>
</section>
```

### 2. **Feature Cards with Icons**
```html
<div class="bg-white p-6 rounded-xl border hover:shadow-lg transition-all duration-300 hover:-translate-y-1">
  <div class="w-12 h-12 bg-green-50 rounded-lg flex items-center justify-center mb-4">
    <i data-lucide="monitor" class="w-6 h-6 text-green-600"></i>
  </div>
  <h3 class="text-xl font-semibold text-gray-900 mb-2">Feature Title</h3>
  <p class="text-gray-600 leading-relaxed">Feature description</p>
</div>
```

### 3. **CTA Sections**
```html
<section class="py-20 px-4 bg-green-600">
  <div class="container mx-auto text-center">
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-4">
      Ready to boost your restaurant's performance?
    </h2>
    <div class="flex flex-col sm:flex-row gap-4 justify-center">
      <a href="/dash/onboarding" class="inline-flex items-center justify-center bg-white text-green-600 hover:bg-gray-50 px-8 py-3 rounded-md text-lg font-medium transition-colors">
        Start Free Trial
      </a>
    </div>
  </div>
</section>
```

## 🚀 Implementation in Rails 8

### 1. **TailwindCSS Configuration**
```javascript
// tailwind.config.js
tailwind.config = {
  theme: {
    extend: {
      colors: {
        primary: '#16A34A',
        'primary-dark': '#15803D',
        'primary-light': '#4ADE80',
        'green-50': '#F0FDF4',
        'green-100': '#DCFCE7',
        'green-600': '#16A34A',
        'green-700': '#15803D',
      }
    }
  }
}
```

### 2. **Component Helpers**
```ruby
# app/helpers/ui_helper.rb
def status_indicator(status)
  case status.to_s.downcase
  when 'online'
    content_tag :div, class: "flex items-center gap-2" do
      content_tag(:div, "", class: "w-3 h-3 rounded-full bg-green-500 animate-pulse") +
      content_tag(:span, "Online", class: "text-sm font-medium text-green-700")
    end
  when 'offline'
    # Similar pattern for offline
  end
end

def platform_icon(platform)
  platform_classes = {
    'gojek' => 'bg-green-500',
    'grab' => 'bg-green-600',
    'foodpanda' => 'bg-pink-500'
  }
  
  content_tag :div, class: "w-8 h-8 #{platform_classes[platform]} rounded-lg flex items-center justify-center text-white text-xs font-bold" do
    platform[0..1].upcase
  end
end
```

### 3. **Stimulus Controllers for Interactivity**
```javascript
// app/javascript/controllers/status_toggle_controller.js
export default class extends Controller {
  static targets = ["status", "button"]
  
  toggle() {
    // Toggle restaurant online/offline status
    const isOnline = this.statusTarget.textContent.includes('Online')
    this.updateStatus(!isOnline)
  }
  
  updateStatus(isOnline) {
    if (isOnline) {
      this.statusTarget.innerHTML = `
        <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
        <span class="text-sm font-medium text-green-700">Online</span>
      `
    } else {
      this.statusTarget.innerHTML = `
        <div class="w-3 h-3 rounded-full bg-red-500 animate-pulse"></div>
        <span class="text-sm font-medium text-red-700">Offline</span>
      `
    }
  }
}
```

## 💡 Best Practices

### 1. **Status-First Design**
- Always lead with status indicators (online/offline/busy)
- Use animated dots for live status feedback
- Color-code everything based on operational state

### 2. **Dashboard Hierarchy**
- Metrics at the top (revenue, orders, ratings)
- Restaurant status cards as primary content
- Secondary information (alerts, settings) in tabs

### 3. **Responsive Considerations**
- Stack restaurant cards on mobile
- Collapse navigation into mobile-friendly formats
- Ensure touch targets are minimum 44px

### 4. **Performance Indicators**
- Show loading states for real-time data
- Use skeleton screens for content loading
- Provide visual feedback for all user actions

This design system creates a focused, status-driven interface specifically designed for restaurant delivery platform monitoring, maintaining clarity and functionality across all screen sizes.