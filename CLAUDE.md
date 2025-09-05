# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TrackerDelivery is a Rails 8 application that monitors delivery platform status (GrabFood/GoFood) for F&B businesses in Bali. The service tracks restaurant open/closed status, reviews, and menu availability, providing automated alerts to foreign business owners who can't manually monitor their outlets 24/7.

## Development Commands

### Setup and Running
```bash
bin/setup              # Install dependencies, prepare database, start server
bin/setup --skip-server   # Setup without starting server
bin/dev                # Start development server with CSS watching (uses Foreman)
bin/rails server       # Start Rails server only
```

### Code Quality
```bash
bin/rubocop            # Run RuboCop linter (inherits rubocop-rails-omakase)
bin/brakeman           # Run security analysis
bin/rails test         # Run test suite
bin/rails test test/controllers/landing_controller_test.rb  # Run single test file
```

### Database
```bash
bin/rails db:prepare   # Create/setup database
bin/rails db:migrate   # Run migrations
```

## Architecture

This is a Rails 8 application using:
- **TailwindCSS 4.x** with custom design system
- **Stimulus** for JavaScript interactions
- **SQLite3** database with Solid Queue/Cache/Cable
- **Kamal** for deployment

Current application structure:
- Single `LandingController` with index/test routes
- Root route points to `landing#index`
- Uses modern Rails 8 asset pipeline (Propshaft, Importmap)

## Design System Requirements

**Critical**: Always consult `ai_docs/` before implementing UI features. This contains:

1. **Business Context** (`ai_docs/business/gtm_manifest.md`): Target market is foreign F&B owners in Bali who lose $70-200/day from platform closures
2. **UI Design System** (`ai_docs/ui/ui_design_system.md`): Comprehensive design patterns with gradient-based modern aesthetic
3. **UI Quick Reference** (`ai_docs/ui/ui_quick_reference.md`): Copy-paste components and code examples

Key design principles:
- Gradient backgrounds: `bg-gradient-to-br from-slate-50 via-white to-blue-50`
- Primary colors: Blue-600 to Indigo-700 gradients
- Card-based architecture with hover states
- Professional color palette with semantic status colors

## Development Workflow

1. Check `ai_docs/` folder for business context and design requirements
2. Follow the established TailwindCSS design system
3. Use Rails 8 conventions and Omakase RuboCop styling
4. Run quality checks before commits: `bin/rubocop`, `bin/brakeman`, `bin/rails test`