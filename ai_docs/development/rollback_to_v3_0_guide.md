# TrackerDelivery Rollback Guide: Version 3.1 → 3.0

**Purpose**: Complete rollback instructions to revert TrackerDelivery from version 3.1 (with authentication) to version 3.0 (clean UI prototype without authentication).

**Warning**: This process will permanently remove all user accounts, authentication data, and email integration. Ensure you have database backups before proceeding.

## 📋 Pre-Rollback Checklist

- [ ] **Database Backup**: Create full database backup
- [ ] **User Notification**: Inform users of planned maintenance
- [ ] **Downtime Planning**: Schedule maintenance window
- [ ] **Team Coordination**: Ensure all team members are aware
- [ ] **Backup Verification**: Test backup restoration process

## 🗂️ Files to Remove (Created in v3.1)

### Controllers
```bash
rm app/controllers/users_controller.rb
rm app/controllers/sessions_controller.rb  
rm app/controllers/email_confirmations_controller.rb
rm app/controllers/passwords_controller.rb
rm app/controllers/concerns/authentication.rb
```

### Models
```bash
rm app/models/session.rb
rm app/models/current.rb
# Note: app/models/user.rb will be restored to v3.0 state (see below)
```

### Services
```bash
rm app/services/email_service.rb
rm app/services/loops_service.rb
```

### Views
```bash
rm -rf app/views/users/
rm -rf app/views/sessions/
rm -rf app/views/email_confirmations/
rm -rf app/views/passwords/
rm -rf app/views/authentication_mailer/
```

### Mailers
```bash
rm app/mailers/authentication_mailer.rb
```

## 🗃️ Database Rollback

### 1. Create Rollback Migration
```bash
rails generate migration RollbackAuthenticationToV30
```

### 2. Migration Content
```ruby
# db/migrate/[timestamp]_rollback_authentication_to_v30.rb
class RollbackAuthenticationToV30 < ActiveRecord::Migration[8.0]
  def up
    # Remove authentication-related columns
    remove_column :users, :email_confirmed_at, :datetime
    remove_column :users, :email_confirmation_token, :string
    remove_column :users, :email_confirmation_sent_at, :datetime
    remove_column :users, :password_digest, :string
    
    # Remove authentication indexes
    remove_index :users, :email_confirmation_token if index_exists?(:users, :email_confirmation_token)
    remove_index :users, :email_address if index_exists?(:users, :email_address)
    
    # Drop sessions table
    drop_table :sessions if table_exists?(:sessions)
  end
  
  def down
    # This would recreate the authentication system - not recommended for rollback
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse rollback migration"
  end
end
```

### 3. Run Migration
```bash
rails db:migrate
```

## 📝 Routes Cleanup

### Remove Authentication Routes from config/routes.rb
```ruby
# REMOVE these lines from config/routes.rb:

# Authentication routes
resource :session
get "login" => "sessions#new"
post "login" => "sessions#create"  
delete "logout" => "sessions#destroy"

# User registration
get "signup" => "users#new"
post "signup" => "users#create"
resources :users, only: [:new, :create]

# Password reset
get "forgot-password" => "passwords#new"
post "forgot-password" => "passwords#create"
get "reset-password" => "passwords#edit"
patch "reset-password" => "passwords#update"
resources :passwords, param: :token

# Email confirmation  
get "email_confirmation" => "email_confirmations#show"
get "resend-confirmation" => "email_confirmations#new"
post "email_confirmations" => "email_confirmations#create"
```

### Restore Original Routes
```ruby
# Keep only these routes (v3.0 state):
Rails.application.routes.draw do
  get "landing/index"
  get "index" => "landing#index"
  get "test" => "landing#test"

  # Dev routes для v0.dev
  get "dev/test" => "dev#test"
  get "dev/dashboard" => "dev#dashboard"
  get "dev/onboarding" => "dev#onboarding"

  # Dash routes для UI прототипа DeliveryTracker
  get "dash/test" => "dash#test"
  get "dash/onboarding" => "dash#onboarding"
  get "dash/dashboard" => "dash#dashboard"
  get "dash/alerts" => "dash#alerts"
  get "dash/settings" => "dash#settings"

  get "up" => "rails/health#show", as: :rails_health_check
  root "landing#index"
end
```

## 🛠️ Configuration Rollback

### 1. Environment Configuration Cleanup

#### config/environments/development.rb
```ruby
# REMOVE these lines:
config.action_mailer.default_url_options = { host: "localhost", port: 3001 }
config.action_mailer.perform_deliveries = false

# RESTORE original state (or remove if not needed):
# config.action_mailer.raise_delivery_errors = false
```

### 2. Credentials Cleanup
```bash
# Remove Loops credentials from encrypted credentials
rails credentials:edit

# Remove this section:
# loops:
#   from: deliverybooster@aidelivery.tech
#   api_token: xxx
#   transactional_ids:
#     email_confirmation: cmfjb3x522zdky30ielc0fyw0
```

### 3. Application Configuration
#### config/application.rb
```ruby
# Ensure no authentication-related configurations remain
# Remove any authentication middleware or configurations added in v3.1
```

## 📄 Model Restoration

### Restore User Model to v3.0 State
```ruby
# app/models/user.rb (v3.0 state)
class User < ApplicationRecord
  # Remove all authentication-related code
  # Restore to original v3.0 state (likely minimal or empty)
  
  # Basic validations only (if any were in v3.0)
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

## 🎨 UI Component Restoration

### 1. Remove Authentication UI Elements
Remove any authentication-related UI components that were added to existing views:
- Login/logout buttons
- User account information
- Authentication forms
- Session-related notifications

### 2. Restore Navigation
```erb
<!-- Remove from layouts/application.html.erb or other layout files: -->
<!-- Authentication navigation, user menus, login/logout links -->

<!-- Restore original v3.0 navigation structure -->
```

## 🧪 Testing Rollback

### 1. Basic Functionality Test
```bash
# Start the application
bin/rails server -p 3001

# Verify these endpoints work:
curl http://localhost:3001/
curl http://localhost:3001/dev/test
curl http://localhost:3001/dash/test
```

### 2. Database Verification
```bash
# Check database schema
rails dbconsole
.schema users
.tables

# Verify no authentication tables exist
# Verify users table has no authentication columns
```

### 3. Route Testing
```bash
# Verify authentication routes are gone
rails routes | grep -E "(login|signup|session|password|email_confirmation)"
# Should return no results

# Verify original routes exist
rails routes | grep -E "(landing|dev|dash)"
# Should show all original v3.0 routes
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### 1. Migration Errors
```bash
# If migration fails due to missing tables/columns:
rails db:rollback STEP=1
# Then manually edit migration to handle missing elements
```

#### 2. Route Conflicts
```bash
# If route errors occur:
rails routes
# Check for duplicate or conflicting routes
# Clean up routes.rb thoroughly
```

#### 3. Missing Dependencies
```bash
# If application won't start:
bundle install
rails db:prepare
# Check for any remaining authentication-related dependencies
```

#### 4. View Errors
```bash
# If views reference removed authentication helpers:
grep -r "current_user\|authenticated\|login\|session" app/views/
# Remove or comment out any authentication-related view code
```

## 📊 Verification Checklist

After rollback completion:

- [ ] **Database**: No authentication tables or columns exist
- [ ] **Routes**: Only v3.0 routes are active
- [ ] **Files**: All v3.1 authentication files removed
- [ ] **Configuration**: No Loops.so or authentication config
- [ ] **UI**: All authentication UI elements removed
- [ ] **Testing**: All original v3.0 functionality works
- [ ] **Performance**: No authentication-related overhead
- [ ] **Logs**: No authentication-related errors

## 🔄 Re-deployment

### 1. Production Rollback (if applicable)
```bash
# If deployed via Kamal:
kamal deploy

# If manual deployment:
# Follow same steps on production server
# Ensure production database backup exists
```

### 2. DNS and Email
```bash
# If mail.aidelivery.tech was configured:
# No action needed - domain can remain configured
# Remove or disable email templates in Loops.so dashboard
```

## 📋 Post-Rollback Tasks

1. **Documentation Update**: Update any documentation referencing v3.1 features
2. **User Communication**: Notify users that authentication features are removed
3. **Monitoring**: Verify application stability post-rollback
4. **Backup Cleanup**: Archive v3.1 database backups securely
5. **Team Notification**: Inform development team of successful rollback

## 🎯 Version Verification

To confirm successful rollback to v3.0:

```bash
# Check git status
git status

# Verify application starts without errors
bin/rails server

# Test core functionality
# - Landing page loads
# - Dev routes work  
# - Dash routes work
# - No authentication required anywhere

# Check database schema matches v3.0
rails dbconsole
.schema
```

## ⚠️ Important Notes

1. **Data Loss**: All user accounts and authentication data will be permanently lost
2. **Email Integration**: Loops.so integration will be disabled but account remains active
3. **Session Storage**: All user sessions will be invalidated
4. **Third-party Services**: Loops.so domain and templates remain configured
5. **Future Upgrades**: Can re-implement authentication using this documentation as reference

---

**Emergency Contact**: If rollback issues occur, refer to database backups and this documentation. All authentication features can be re-implemented following the v3.1 release notes.