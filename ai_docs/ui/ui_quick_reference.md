# UI Design Quick Reference Guide

## ðŸš€ Quick Copy-Paste Components

### Navigation Bar
```erb
<nav class="fixed top-0 w-full bg-white/80 backdrop-blur-md z-50 border-b border-slate-200">
  <div class="max-w-7xl mx-auto px-6 py-4">
    <div class="flex items-center justify-between">
      <!-- Logo -->
      <a href="/" class="flex items-center space-x-3">
        <div class="w-10 h-10 bg-gradient-to-br from-blue-600 to-indigo-700 rounded-xl flex items-center justify-center shadow-lg">
          <span class="text-white font-bold text-xl">CV</span>
        </div>
        <span class="text-xl font-semibold text-slate-900">CVReady</span>
      </a>
      
      <!-- Nav Links -->
      <div class="flex items-center space-x-8">
        <a href="/features" class="text-slate-600 hover:text-slate-900 transition-colors">Features</a>
        <a href="/about" class="text-slate-600 hover:text-slate-900 transition-colors">About</a>
        <a href="/signup" class="px-5 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-700 text-white rounded-lg hover:shadow-lg transition-all duration-200">
          Get Started
        </a>
      </div>
    </div>
  </div>
</nav>
```

### Hero Section
```erb
<section class="pt-32 pb-20 px-6 text-center">
  <div class="max-w-4xl mx-auto">
    <!-- Badge -->
    <div class="inline-flex items-center space-x-2 px-4 py-2 bg-blue-100 rounded-full mb-8">
      <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      <span class="text-sm font-medium text-blue-800">Your Badge Text</span>
    </div>
    
    <h1 class="text-5xl md:text-6xl font-bold text-slate-900 mb-6 leading-tight">
      Your headline with
      <span class="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-700"> gradient text</span>
    </h1>
    
    <p class="text-xl text-slate-600 max-w-3xl mx-auto leading-relaxed mb-12">
      Your subheadline description goes here. Make it compelling and clear.
    </p>
    
    <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
      <a href="#" class="px-8 py-4 bg-gradient-to-r from-blue-600 to-indigo-700 text-white rounded-xl font-semibold hover:shadow-xl transition-all duration-200">
        Primary CTA
      </a>
      <a href="#" class="px-8 py-4 bg-slate-100 text-slate-700 rounded-xl font-semibold hover:bg-slate-200 transition-all duration-200">
        Secondary CTA
      </a>
    </div>
  </div>
</section>
```

### Feature Card
```erb
<div class="bg-white rounded-2xl p-8 shadow-sm border border-slate-200 hover:shadow-lg transition-all duration-200">
  <div class="w-14 h-14 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-xl flex items-center justify-center mb-6">
    <svg class="w-7 h-7 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <!-- Your icon here -->
    </svg>
  </div>
  <h3 class="text-xl font-semibold text-slate-900 mb-3">Feature Title</h3>
  <p class="text-slate-600 mb-4">
    Feature description that explains the benefit clearly and concisely.
  </p>
  <a href="#" class="text-blue-600 hover:text-blue-700 font-medium inline-flex items-center">
    Learn more
    <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
    </svg>
  </a>
</div>
```

### Dark Section
```erb
<section class="px-6 py-20 bg-slate-900 text-white">
  <div class="max-w-7xl mx-auto">
    <div class="text-center mb-16">
      <h2 class="text-3xl font-bold mb-4">Section Title</h2>
      <p class="text-xl text-slate-400 max-w-3xl mx-auto">
        Section description with muted text color
      </p>
    </div>
    
    <div class="grid md:grid-cols-3 gap-8">
      <!-- Dark cards -->
      <div class="bg-slate-800 rounded-2xl p-8 border border-slate-700">
        <h3 class="text-xl font-semibold mb-3">Card Title</h3>
        <p class="text-slate-400">Card content</p>
      </div>
    </div>
  </div>
</section>
```

### CTA Section
```erb
<section class="px-6 py-20 bg-gradient-to-r from-blue-600 to-indigo-700">
  <div class="max-w-4xl mx-auto text-center text-white">
    <h2 class="text-4xl font-bold mb-6">Ready to get started?</h2>
    <p class="text-xl mb-12 text-blue-100">
      Join thousands of users already benefiting
    </p>
    
    <a href="#" class="inline-block px-8 py-4 bg-white text-blue-600 rounded-xl font-semibold hover:shadow-xl transition-all duration-200">
      Start Free Trial
    </a>
    
    <p class="mt-8 text-sm text-blue-200">
      No credit card required â€¢ Free forever
    </p>
  </div>
</section>
```

### Footer
```erb
<footer class="bg-slate-900 text-slate-400 py-12 px-6">
  <div class="max-w-6xl mx-auto">
    <div class="grid md:grid-cols-4 gap-8 mb-8">
      <div>
        <div class="flex items-center space-x-3 mb-4">
          <div class="w-10 h-10 bg-gradient-to-br from-blue-600 to-indigo-700 rounded-xl flex items-center justify-center">
            <span class="text-white font-bold text-xl">CV</span>
          </div>
          <span class="text-xl font-semibold text-white">CVReady</span>
        </div>
        <p class="text-sm">Your tagline here</p>
      </div>
      
      <!-- Footer columns -->
    </div>
    
    <div class="border-t border-slate-800 pt-8 text-center text-sm">
      <p>&copy; 2024 CVReady. All rights reserved.</p>
    </div>
  </div>
</footer>
```

## ðŸŽ¨ Color Classes Quick Reference

### Backgrounds
```
Light: bg-slate-50, bg-blue-50, bg-green-50
Cards: bg-white with border-slate-200
Dark: bg-slate-900, bg-slate-800
Gradients: bg-gradient-to-r from-blue-600 to-indigo-700
```

### Text Colors
```
Primary: text-slate-900
Secondary: text-slate-600
Muted: text-slate-400
Accent: text-blue-600
White: text-white (on dark backgrounds)
```

### Common Gradients
```erb
<!-- Primary gradient -->
bg-gradient-to-r from-blue-600 to-indigo-700

<!-- Light gradient background -->
bg-gradient-to-br from-slate-50 via-white to-blue-50

<!-- Card accent gradient -->
bg-gradient-to-br from-blue-100 to-indigo-100

<!-- Success gradient -->
bg-gradient-to-r from-green-500 to-emerald-600

<!-- Warning gradient -->
bg-gradient-to-r from-amber-500 to-orange-600
```

## ðŸ“ Spacing Cheat Sheet

### Padding
```
Small: p-4
Medium: p-6 or p-8
Large: p-12
Section: py-20 px-6
```

### Margins
```
Between elements: mb-4
Between sections: mb-8 or mb-16
Between paragraphs: mb-6
```

### Gaps (for flex/grid)
```
Small: gap-4
Medium: gap-6 or gap-8
Large: gap-12
```

## ðŸŽ¯ Component States

### Hover Effects
```erb
<!-- Basic hover -->
hover:shadow-lg transition-all duration-200

<!-- With transform -->
hover:shadow-xl transition-all duration-200 transform hover:-translate-y-0.5

<!-- Color change -->
hover:text-slate-900 transition-colors

<!-- Background change -->
hover:bg-slate-200 transition-all duration-200
```

### Focus States
```erb
focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
```

## ðŸ“± Responsive Utilities

### Hide/Show
```erb
<!-- Hide on mobile, show on desktop -->
hidden md:block

<!-- Show on mobile, hide on desktop -->
block md:hidden
```

### Grid Columns
```erb
<!-- 1 column mobile, 2 tablet, 3 desktop -->
grid md:grid-cols-2 lg:grid-cols-3 gap-8

<!-- 1 column mobile, 2 desktop -->
grid md:grid-cols-2 gap-12
```

### Text Sizes
```erb
<!-- Responsive heading -->
text-4xl md:text-5xl lg:text-6xl

<!-- Responsive body text -->
text-lg md:text-xl
```

## ðŸš€ Rails Helpers

### Button Helper
```ruby
def gradient_button(text, path, options = {})
  link_to path, 
    class: "px-8 py-4 bg-gradient-to-r from-blue-600 to-indigo-700 text-white rounded-xl font-semibold hover:shadow-xl transition-all duration-200 #{options[:class]}" do
    text
  end
end
```

### Card Helper
```ruby
def feature_card(title:, description:, icon_path: nil, &block)
  content_tag :div, class: "bg-white rounded-2xl p-8 shadow-sm border border-slate-200 hover:shadow-lg transition-all duration-200" do
    icon_html = content_tag(:div, class: "w-14 h-14 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-xl flex items-center justify-center mb-6") do
      # Icon content
    end
    
    icon_html +
    content_tag(:h3, title, class: "text-xl font-semibold text-slate-900 mb-3") +
    content_tag(:p, description, class: "text-slate-600 mb-4") +
    (block_given? ? capture(&block) : "")
  end
end
```

## ðŸ’¡ Pro Tips

1. **Always use transitions** for interactive elements
2. **Layer gradients** for depth (background gradient + card gradient)
3. **Use consistent border radius**: rounded-lg, rounded-xl, rounded-2xl
4. **Add shadows on hover** for interactive feedback
5. **Keep text readable** with proper contrast ratios
6. **Use semantic HTML** for better accessibility
7. **Test on mobile first** - the design should work on small screens

## ðŸŽ Full Page Template

```erb
<% content_for :title, "Page Title - CVReady" %>

<div class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50">
  <%= render 'shared/navigation' %>
  
  <main>
    <%= render 'hero_section' %>
    <%= render 'features_grid' %>
    <%= render 'testimonials' %>
    <%= render 'cta_section' %>
  </main>
  
  <%= render 'shared/footer' %>
</div>
```

This quick reference guide provides everything needed to maintain consistent design across the application!