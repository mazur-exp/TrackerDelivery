# TrackerDelivery UI Quick Reference Guide

## 🚀 Ready-to-Use Components

### Dashboard Header with Logo and Live Status
```erb
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
    <button class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium hover:bg-gray-50 transition-colors">
      <i data-lucide="refresh-cw" class="w-4 h-4 mr-2"></i>
      Refresh
    </button>
  </div>
</div>
```

### Metric Cards Grid (Revenue, Orders, Stores, Rating)
```erb
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  <!-- Revenue Card -->
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

  <!-- Orders Card -->
  <div class="bg-white rounded-xl border border-blue-200 bg-blue-50/50 p-6 shadow-sm">
    <div class="flex flex-row items-center justify-between space-y-0 pb-2">
      <h3 class="text-sm font-medium">Total Orders</h3>
      <i data-lucide="shopping-bag" class="h-4 w-4 text-blue-600"></i>
    </div>
    <div class="text-2xl font-bold text-blue-700">135</div>
    <p class="text-xs text-blue-600 flex items-center gap-1">
      <i data-lucide="trending-up" class="w-3 h-3"></i>
      +8% from yesterday
    </p>
  </div>

  <!-- Online Stores Card -->
  <div class="bg-white rounded-xl border border-purple-200 bg-purple-50/50 p-6 shadow-sm">
    <div class="flex flex-row items-center justify-between space-y-0 pb-2">
      <h3 class="text-sm font-medium">Online Stores</h3>
      <i data-lucide="store" class="h-4 w-4 text-purple-600"></i>
    </div>
    <div class="text-2xl font-bold text-purple-700">2/3</div>
    <p class="text-xs text-purple-600">67% operational</p>
  </div>

  <!-- Rating Card -->
  <div class="bg-white rounded-xl border border-orange-200 bg-orange-50/50 p-6 shadow-sm">
    <div class="flex flex-row items-center justify-between space-y-0 pb-2">
      <h3 class="text-sm font-medium">Avg Rating</h3>
      <i data-lucide="star" class="h-4 w-4 text-orange-600"></i>
    </div>
    <div class="text-2xl font-bold text-orange-700">4.7</div>
    <p class="text-xs text-orange-600 flex items-center gap-1">
      <i data-lucide="star" class="w-3 h-3 fill-current"></i>
      Across all platforms
    </p>
  </div>
</div>
```

### Restaurant Status Card (Online)
```erb
<div class="bg-white rounded-xl border shadow-sm hover:shadow-md transition-shadow p-6">
  <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
    <div class="flex items-center gap-4">
      <div class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white text-xs font-bold">
        GO
      </div>
      <div>
        <h3 class="font-semibold text-lg">Nasi Padang Express</h3>
        <p class="text-sm text-gray-500">Gojek</p>
      </div>
    </div>

    <div class="flex flex-col lg:flex-row items-start lg:items-center gap-4 lg:gap-8">
      <div class="flex items-center gap-2">
        <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
        <span class="text-sm font-medium text-green-700">Online</span>
      </div>
      
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
        <div>
          <p class="text-gray-500">Orders</p>
          <p class="font-semibold">45</p>
        </div>
        <div>
          <p class="text-gray-500">Revenue</p>
          <p class="font-semibold">Rp 1,250,000</p>
        </div>
        <div>
          <p class="text-gray-500">Rating</p>
          <p class="font-semibold flex items-center gap-1">
            <i data-lucide="star" class="w-3 h-3 fill-yellow-400 text-yellow-400"></i>
            <span>4.8</span>
          </p>
        </div>
        <div>
          <p class="text-gray-500">Reviews</p>
          <p class="font-semibold">234</p>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button class="inline-flex items-center px-3 py-2 border border-red-200 text-red-600 hover:bg-red-50 rounded-md text-sm font-medium transition-colors">
          <i data-lucide="wifi-off" class="w-4 h-4 mr-2"></i>
          Go Offline
        </button>
        <button class="inline-flex items-center px-3 py-2 text-gray-400 hover:text-gray-600 rounded-md transition-colors">
          <i data-lucide="eye" class="w-4 h-4"></i>
        </button>
      </div>
    </div>
  </div>
</div>
```

### Restaurant Status Card (Offline)
```erb
<div class="bg-white rounded-xl border shadow-sm hover:shadow-md transition-shadow p-6">
  <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
    <div class="flex items-center gap-4">
      <div class="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center text-white text-xs font-bold">
        GR
      </div>
      <div>
        <h3 class="font-semibold text-lg">Burger Corner</h3>
        <p class="text-sm text-gray-500">Grab</p>
      </div>
    </div>

    <div class="flex flex-col lg:flex-row items-start lg:items-center gap-4 lg:gap-8">
      <div class="flex items-center gap-2">
        <div class="w-3 h-3 rounded-full bg-red-500 animate-pulse"></div>
        <span class="text-sm font-medium text-red-700">Offline</span>
      </div>
      
      <!-- Stats grid same as online -->
      
      <div class="flex items-center gap-2">
        <button class="inline-flex items-center px-3 py-2 border border-green-200 text-green-600 hover:bg-green-50 rounded-md text-sm font-medium transition-colors">
          <i data-lucide="wifi" class="w-4 h-4 mr-2"></i>
          Go Online
        </button>
        <button class="inline-flex items-center px-3 py-2 text-gray-400 hover:text-gray-600 rounded-md transition-colors">
          <i data-lucide="eye" class="w-4 h-4"></i>
        </button>
      </div>
    </div>
  </div>
</div>
```

### Tab Navigation Component
```erb
<div class="bg-gray-100 rounded-lg p-1 inline-flex">
  <button class="px-4 py-2 text-sm font-medium rounded-md transition-colors bg-white text-gray-900 shadow-sm">
    Restaurants
  </button>
  <button class="px-4 py-2 text-sm font-medium rounded-md transition-colors text-gray-500 hover:text-gray-700">
    Alerts
  </button>
  <button class="px-4 py-2 text-sm font-medium rounded-md transition-colors text-gray-500 hover:text-gray-700">
    Stock
  </button>
  <button class="px-4 py-2 text-sm font-medium rounded-md transition-colors text-gray-500 hover:text-gray-700">
    Settings
  </button>
</div>
```

### Alert Card (High Priority)
```erb
<div class="flex items-center justify-between p-4 border rounded-lg alert-item">
  <div class="flex items-center gap-3">
    <div class="inline-flex items-center px-2 py-1 rounded-md border-transparent bg-red-500 text-white text-xs font-medium gap-1">
      <i data-lucide="alert-triangle" class="w-3 h-3"></i>
      HIGH
    </div>
    <div>
      <p class="font-medium">Chicken stock running low (5 portions left)</p>
      <p class="text-sm text-gray-500">5 mins ago</p>
    </div>
  </div>
  <div class="flex items-center gap-2">
    <button class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium hover:bg-gray-50">
      Restock
    </button>
    <button class="dismiss-alert inline-flex items-center px-3 py-2 text-gray-400 hover:text-gray-600 rounded-md transition-colors">
      Dismiss
    </button>
  </div>
</div>
```

### Onboarding Form Section
```erb
<div class="bg-white border shadow-md rounded-3xl overflow-hidden">
  <!-- Section Header with Gradient -->
  <div class="bg-gradient-to-r from-green-50 to-emerald-50 border-b p-6">
    <h2 class="text-xl font-semibold text-green-800">Add Your Delivery Platform URLs</h2>
    <p class="text-green-600 mt-2">Enter your restaurant URLs from Grab and GoFood to get started</p>
  </div>
  
  <!-- Form Content -->
  <div class="p-6 space-y-6">
    <div class="space-y-2">
      <label class="flex items-center gap-2 text-sm font-medium">
        <div class="w-6 h-6 bg-green-600 rounded flex items-center justify-center">
          <span class="text-white text-xs font-bold">G</span>
        </div>
        Grab Food URL
      </label>
      <div class="relative">
        <input
          type="url"
          placeholder="https://food.grab.com/sg/en/restaurant/..."
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-600/20 focus:border-green-600 transition-all duration-300"
        />
        <div class="absolute right-3 top-1/2 -translate-y-1/2 hidden">
          <i data-lucide="check-circle" class="w-4 h-4 text-green-600"></i>
        </div>
      </div>
    </div>
    
    <!-- Info Box -->
    <div class="bg-green-50 p-4 rounded-lg">
      <p class="text-sm text-green-700">
        <strong>Tip:</strong> You can add at least one platform URL. We'll extract your restaurant information automatically.
      </p>
    </div>
  </div>
</div>
```

### Landing Page Hero Section
```erb
<section class="py-20 px-4">
  <div class="container mx-auto text-center max-w-4xl">
    <div class="inline-flex items-center px-3 py-1 rounded-full bg-green-50 text-green-700 border border-green-200 text-sm font-medium mb-6">
      🚀 Now monitoring 500+ restaurants
    </div>
    <h1 class="text-4xl md:text-6xl font-bold text-gray-900 mb-6 leading-tight">
      Never Miss an Order
      <span class="text-green-600 block">Again</span>
    </h1>
    <p class="text-xl text-gray-600 mb-8 leading-relaxed max-w-2xl mx-auto">
      Monitor your restaurant's status across all delivery platforms in real-time. 
      Get instant alerts for outages, reviews, and stock issues.
    </p>
    <div class="flex flex-col sm:flex-row gap-4 justify-center mb-12">
      <a href="/dash/onboarding" class="inline-flex items-center justify-center bg-green-600 hover:bg-green-700 text-white px-8 py-3 rounded-md text-lg font-medium transition-colors">
        Start Free Trial
        <i data-lucide="arrow-right" class="ml-2 w-4 h-4"></i>
      </a>
      <button class="inline-flex items-center justify-center border border-gray-300 hover:bg-gray-50 px-8 py-3 rounded-md text-lg font-medium transition-colors">
        Watch Demo
      </button>
    </div>
  </div>
</section>
```

### Feature Card
```erb
<div class="bg-white p-6 rounded-xl border hover:shadow-lg transition-all duration-300 hover:-translate-y-1">
  <div class="w-12 h-12 bg-green-50 rounded-lg flex items-center justify-center mb-4">
    <i data-lucide="monitor" class="w-6 h-6 text-green-600"></i>
  </div>
  <h3 class="text-xl font-semibold text-gray-900 mb-2">Real-time Status Monitoring</h3>
  <p class="text-gray-600 leading-relaxed">Track your restaurant's availability across Grab, GoFood, and other delivery platforms in real-time with instant updates.</p>
</div>
```

### CTA Section
```erb
<section class="py-20 px-4 bg-green-600">
  <div class="container mx-auto text-center">
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-4">
      Ready to boost your restaurant's performance?
    </h2>
    <p class="text-xl text-green-100 mb-8 max-w-2xl mx-auto">
      Join hundreds of restaurant owners who never miss an order or review again
    </p>
    <div class="flex flex-col sm:flex-row gap-4 justify-center">
      <a href="/dash/onboarding" class="inline-flex items-center justify-center bg-white text-green-600 hover:bg-gray-50 px-8 py-3 rounded-md text-lg font-medium transition-colors">
        Start Free Trial
        <i data-lucide="arrow-right" class="ml-2 w-4 h-4"></i>
      </a>
      <button class="inline-flex items-center justify-center border border-white text-white hover:bg-white hover:text-green-600 px-8 py-3 rounded-md text-lg font-medium transition-colors">
        Contact Sales
      </button>
    </div>
  </div>
</section>
```

## 🎨 Color Classes Quick Reference

### Status Colors
```css
/* Online/Active Status */
text-green-700 bg-green-50
border-green-200 bg-green-50/50

/* Offline/Inactive Status */
text-red-700 bg-red-50
border-red-200 bg-red-50/50

/* Busy/Warning Status */
text-yellow-700 bg-yellow-50
border-yellow-200 bg-yellow-50/50

/* Info/Neutral Status */
text-blue-700 bg-blue-50
border-blue-200 bg-blue-50/50
```

### Platform Colors
```css
/* Gojek/GoFood */
bg-green-500

/* Grab */
bg-green-600

/* Foodpanda */
bg-pink-500

/* General */
bg-gray-600
```

### Button States
```css
/* Primary Button */
bg-green-600 hover:bg-green-700 text-white

/* Secondary Button */
border border-gray-300 hover:bg-gray-50

/* Danger Button */
border-red-200 text-red-600 hover:bg-red-50

/* Success Button */
border-green-200 text-green-600 hover:bg-green-50
```

## 📏 Spacing Quick Reference

### Card Padding
```css
p-6        /* Main cards */
p-4        /* Internal elements */
px-3 py-2  /* Form inputs */
px-8 py-3  /* Large buttons */
px-3 py-2  /* Small buttons */
```

### Gaps and Margins
```css
gap-4      /* Grid/flex gaps */
space-y-4  /* Vertical spacing between cards */
space-y-6  /* Vertical spacing in forms */
mb-6       /* Margins between sections */
```

### Responsive Grid
```css
/* Metric Cards */
grid-cols-1 md:grid-cols-2 lg:grid-cols-4

/* Two Column Layout */
grid-cols-1 md:grid-cols-2

/* Single Column (Restaurant Cards) */
space-y-4
```

## 🔧 Interactive Elements

### Status Indicators
```erb
<!-- Online -->
<div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>

<!-- Offline -->
<div class="w-3 h-3 rounded-full bg-red-500 animate-pulse"></div>

<!-- Busy -->
<div class="w-3 h-3 rounded-full bg-yellow-500 animate-pulse"></div>
```

### Loading States
```erb
<!-- Spinner -->
<i data-lucide="loader-2" class="w-8 h-8 animate-spin text-green-600"></i>

<!-- Progress Bar -->
<div class="w-full bg-gray-300 h-1.5 rounded-full overflow-hidden">
  <div class="h-full bg-green-600 transition-all duration-300" style="width: 33%"></div>
</div>

<!-- Step Indicator -->
<div class="w-4 h-4 bg-green-600 rounded-full ring-4 ring-green-600/20"></div>
```

### Icon Buttons
```erb
<!-- Refresh Button -->
<button class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium hover:bg-gray-50 transition-colors">
  <i data-lucide="refresh-cw" class="w-4 h-4 mr-2"></i>
  Refresh
</button>

<!-- View Button -->
<button class="inline-flex items-center px-3 py-2 text-gray-400 hover:text-gray-600 rounded-md transition-colors">
  <i data-lucide="eye" class="w-4 h-4"></i>
</button>
```

## 🚀 Rails Helpers

### Status Indicator Helper
```ruby
def status_indicator(status)
  case status.to_s.downcase
  when 'online'
    content_tag :div, class: "flex items-center gap-2" do
      content_tag(:div, "", class: "w-3 h-3 rounded-full bg-green-500 animate-pulse") +
      content_tag(:span, "Online", class: "text-sm font-medium text-green-700")
    end
  when 'offline'
    content_tag :div, class: "flex items-center gap-2" do
      content_tag(:div, "", class: "w-3 h-3 rounded-full bg-red-500 animate-pulse") +
      content_tag(:span, "Offline", class: "text-sm font-medium text-red-700")
    end
  when 'busy'
    content_tag :div, class: "flex items-center gap-2" do
      content_tag(:div, "", class: "w-3 h-3 rounded-full bg-yellow-500 animate-pulse") +
      content_tag(:span, "Busy", class: "text-sm font-medium text-yellow-700")
    end
  end
end
```

### Platform Icon Helper
```ruby
def platform_icon(platform, restaurant_name)
  platform_colors = {
    'gojek' => 'bg-green-500',
    'grab' => 'bg-green-600',
    'foodpanda' => 'bg-pink-500'
  }
  
  platform_abbreviations = {
    'gojek' => 'GO',
    'grab' => 'GR',
    'foodpanda' => 'FP'
  }
  
  color = platform_colors[platform.downcase] || 'bg-gray-600'
  abbr = platform_abbreviations[platform.downcase] || platform[0..1].upcase
  
  content_tag :div, class: "w-8 h-8 #{color} rounded-lg flex items-center justify-center text-white text-xs font-bold" do
    abbr
  end
end
```

### Metric Card Helper
```ruby
def metric_card(title:, value:, change: nil, icon:, color: 'green')
  color_classes = {
    'green' => 'border-green-200 bg-green-50/50 text-green-700',
    'blue' => 'border-blue-200 bg-blue-50/50 text-blue-700',
    'purple' => 'border-purple-200 bg-purple-50/50 text-purple-700',
    'orange' => 'border-orange-200 bg-orange-50/50 text-orange-700'
  }
  
  content_tag :div, class: "bg-white rounded-xl border #{color_classes[color].split.first(2).join(' ')} p-6 shadow-sm" do
    content_tag(:div, class: "flex flex-row items-center justify-between space-y-0 pb-2") do
      content_tag(:h3, title, class: "text-sm font-medium") +
      content_tag(:i, "", 'data-lucide': icon, class: "h-4 w-4 #{color_classes[color].split.last}")
    end +
    content_tag(:div, value, class: "text-2xl font-bold #{color_classes[color].split.last}") +
    (change ? content_tag(:p, change, class: "text-xs #{color_classes[color].split.last} flex items-center gap-1") : "")
  end
end
```

## 💡 Pro Tips

1. **Always use animated dots** for status indicators
2. **Consistent border-radius**: rounded-md for buttons, rounded-xl for cards
3. **Use hover:shadow-md** for card interactions
4. **Green-first color scheme** - green means active/good
5. **Mobile-first responsive** - stack cards on mobile
6. **Include Lucide icons** in all interactive elements
7. **Use transition-colors** for smooth hover effects

## 📱 Mobile Considerations

### Responsive Breakpoints
```css
/* Mobile: < 768px */
grid-cols-1
flex-col

/* Tablet: 768px+ */
md:grid-cols-2
md:flex-row

/* Desktop: 1024px+ */
lg:grid-cols-4
lg:items-center
```

### Touch Targets
- Minimum 44px height for buttons
- Adequate spacing between clickable elements
- Clear visual feedback on tap

This quick reference provides everything needed to build consistent TrackerDelivery interfaces!