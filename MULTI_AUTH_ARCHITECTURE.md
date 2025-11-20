# Multi-Provider Authentication Architecture

## Overview

DeliveryTracker supports multiple authentication methods for maximum user flexibility. Users can register and sign in using:

- 📱 **Telegram** (current MVP implementation)
- 📧 **Email/Password** (commented out for MVP, ready to restore)
- 🔵 **Google OAuth** (prepared, not implemented yet)
- 🍎 **Apple Sign In** (prepared, not implemented yet)
- 📘 **Facebook** (prepared, not implemented yet)

## Architecture Strategy

### Core Principle: **One User, Multiple Auth Methods**

A single user account can have multiple authentication methods linked:

```ruby
user = User.find(123)
user.connected_auth_methods
# => [:telegram, :google, :email]

user.has_multiple_auth_methods?
# => true

user.primary_auth_method
# => :telegram (first one registered)
```

### Auto-Merging Strategy

**Scenario:** User registers via Telegram (without email), later signs in with Google

**Behavior:**
1. Telegram registration: Creates User with `telegram_id = 123`, `email_address = nil`
2. User adds email later: Updates `email_address = "user@gmail.com"`
3. User signs in with Google (same email): **Automatically links** `google_id` to existing account
4. **Result:** One user account with both Telegram and Google auth

**Implementation:** Use `AccountMergerService.find_or_merge()`

## Database Schema

### User Table Fields

```ruby
# Telegram (✅ Implemented)
telegram_id               :bigint   (indexed, unique)
telegram_username         :string
telegram_first_name       :string
telegram_last_name        :string
telegram_photo_url        :string
telegram_auth_date        :datetime

# Email/Password (✅ Implemented, currently disabled in UI)
email_address             :string   (indexed, unique, nullable)
password_digest           :string   (nullable)
email_confirmed_at        :datetime
email_confirmation_token  :string   (indexed, unique)

# Google OAuth (✅ DB Ready, ❌ Not implemented)
google_id                 :string   (indexed, unique)
google_email              :string
google_picture            :string

# Apple OAuth (✅ DB Ready, ❌ Not implemented)
apple_id                  :string   (indexed, unique)

# Facebook OAuth (✅ DB Ready, ❌ Not implemented)
facebook_id               :string   (indexed, unique)

# Common fields
name                      :string
locale                    :string   (for i18n)
admin                     :boolean
created_at                :datetime
updated_at                :datetime
```

## Validation Rules

```ruby
# User model validates:
validate :authentication_method_present

# At least ONE of these must be present:
- telegram_id
- google_id
- apple_id
- facebook_id
- (email_address + password_digest)
```

## User Model Helper Methods

### Provider Checks

```ruby
user.telegram_user?      # => true if telegram_id present
user.google_user?        # => true if google_id present
user.apple_user?         # => true if apple_id present
user.facebook_user?      # => true if facebook_id present
user.email_user?         # => true if email + password present
```

### Multi-Provider Methods

```ruby
user.has_multiple_auth_methods?
# => true if user has 2+ providers linked

user.auth_methods_count
# => 3 (telegram + google + email)

user.primary_auth_method
# => :telegram (first method used for registration)

user.connected_auth_methods
# => [:telegram, :google, :email]
```

## AccountMergerService API

### Find or Merge Account

```ruby
# When user signs in with Google
user = AccountMergerService.find_or_merge(
  provider: :google,
  provider_id: "google_user_123",
  email: "user@gmail.com",
  attributes: {
    google_email: "user@gmail.com",
    google_picture: "https://...",
    locale: :en
  }
)

# Logic:
# 1. Find by google_id → return if found
# 2. Find by email → link google_id → return
# 3. Create new user with google_id
```

### Link Additional Provider

```ruby
# User already logged in via Telegram, wants to add Google
success = AccountMergerService.link_provider(
  user: current_user,
  provider: :google,
  provider_id: "google_user_123",
  attributes: { google_email: "user@gmail.com" }
)

# Returns false if:
# - Provider already linked to this user
# - Provider ID already used by another user
```

### Unlink Provider

```ruby
# Remove Google from user's account
success = AccountMergerService.unlink_provider(
  user: current_user,
  provider: :google
)

# Returns false if this is the LAST auth method
# (User must have at least one way to sign in)
```

## Adding a New Auth Provider (Future)

### Example: Adding Google OAuth

#### 1. Database fields already exist ✅

#### 2. Add gem to Gemfile

```ruby
gem 'omniauth-google-oauth2'
```

#### 3. Configure OmniAuth

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    {
      scope: 'email,profile',
      prompt: 'select_account'
    }
end
```

#### 4. Create callback controller

```ruby
# app/controllers/oauth_callbacks_controller.rb
class OauthCallbacksController < ApplicationController
  skip_before_action :require_authentication

  def google
    auth = request.env['omniauth.auth']

    user = AccountMergerService.find_or_merge(
      provider: :google,
      provider_id: auth['uid'],
      email: auth['info']['email'],
      attributes: {
        name: auth['info']['name'],
        google_email: auth['info']['email'],
        google_picture: auth['info']['image'],
        locale: I18n.locale
      }
    )

    start_new_session_for(user)
    redirect_to after_authentication_url(user)
  end
end
```

#### 5. Add routes

```ruby
# config/routes.rb
get '/auth/:provider/callback', to: 'oauth_callbacks#:provider'
```

#### 6. Add button to login page

```erb
<%= button_to "Sign in with Google", "/auth/google_oauth2",
    method: :post,
    data: { turbo: false },
    class: "google-button-styles" %>
```

That's it! The infrastructure is ready.

## Benefits of This Architecture

### ✅ Flexibility
- User can add/remove auth methods in settings
- Not locked into one provider

### ✅ Account Merging
- Automatic linking by email
- No duplicate accounts

### ✅ Backwards Compatible
- Existing Telegram users keep working
- Can add email later
- Can restore email auth anytime

### ✅ Easy to Extend
- Adding new provider = just OAuth controller + button
- Database already prepared
- AccountMergerService handles all logic

## Current Status

### ✅ Fully Implemented
- Telegram authentication
- Email/Password (commented out, ready to restore)
- i18n (EN/RU)
- Account merging logic
- User model helpers

### ✅ Database Ready
- All OAuth provider fields added
- Indexes created
- Validations updated

### ❌ Not Yet Implemented (Easy to add later)
- Google OAuth controller
- Apple Sign In controller
- Facebook OAuth controller
- Settings UI for managing connected accounts

## Migration Path

### Today (MVP)
- Users sign in via Telegram only
- Database prepared for multi-provider

### Future (Phase 2)
- Uncomment email auth forms
- Show both Telegram + Email options on login page
- Users can choose preferred method

### Future (Phase 3)
- Add "Sign in with Google" button
- Add "Sign in with Apple" button
- Users can link multiple methods in settings

### Future (Phase 4)
- Settings page: "Connected Accounts"
- Users can add/remove auth methods
- Show which providers are linked

## Security Considerations

### Email Matching
- ⚠️ **Risk:** Attacker could register Google account with victim's email
- ✅ **Mitigation:** Only merge if email is VERIFIED by OAuth provider
- ✅ **Google/Apple verify emails** - safe to auto-merge

### Provider ID Uniqueness
- All `*_id` columns have UNIQUE indexes
- Prevents duplicate registrations
- Database enforces integrity

### Last Auth Method
- User cannot remove last authentication method
- `AccountMergerService.unlink_provider` enforces this
- Always have at least one way to sign in

## Testing

```ruby
# Test multi-provider user
user = User.create!(
  telegram_id: 123,
  google_id: "google_456",
  email_address: "user@example.com"
)

user.connected_auth_methods  # => [:telegram, :google, :email]
user.has_multiple_auth_methods?  # => true
user.primary_auth_method  # => :telegram
```

## Summary

The database and business logic are **ready for multi-provider authentication**.

When you want to add Google/Email/Apple auth:
1. Uncomment or create OAuth controller
2. Add button to UI
3. Use `AccountMergerService.find_or_merge()`
4. Everything else already works! ✅
