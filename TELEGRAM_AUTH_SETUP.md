# Telegram Authentication Setup Guide

## Overview
This guide explains how to configure Telegram Login Widget authentication for DeliveryTracker.

## Prerequisites
- You need a Telegram Bot (use your existing bot or create a new one)
- The bot token from @BotFather
- Your deployment domain (e.g., aidelivery.tech)

## Step 1: Configure Your Telegram Bot

### Option A: Using Your Existing Bot
If you already have a bot for notifications (`TELEGRAM_BOT_TOKEN`), you can use the same bot for authentication.

1. Open Telegram and message [@BotFather](https://t.me/botfather)
2. Send `/mybots`
3. Select your existing bot
4. Click **"Bot Settings"** → **"Domain"**
5. Set your domain (without https://):
   ```
   aidelivery.tech
   ```
   Or for development:
   ```
   localhost
   ```

### Option B: Create a New Bot for Authentication
If you want a separate bot for authentication:

1. Open Telegram and message [@BotFather](https://t.me/botfather)
2. Send `/newbot`
3. Follow the prompts:
   - **Bot name**: `DeliveryTracker Auth` (visible to users)
   - **Bot username**: `deliverytracker_auth_bot` (must end with "bot")
4. Save the **bot token** (e.g., `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
5. Send `/mybots` → select your new bot
6. Click **"Bot Settings"** → **"Domain"**
7. Set your domain

## Step 2: Configure Environment Variables

### Development (.env.development)
Create or update `.env.development`:

```bash
# Telegram Bot for Authentication
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_BOT_USERNAME=your_bot_username_here

# Example:
# TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
# TELEGRAM_BOT_USERNAME=deliverytracker_bot
```

### Production (Rails Credentials)
For production, add Telegram credentials to Rails credentials:

```bash
bin/rails credentials:edit --environment production
```

Add:
```yaml
telegram:
  bot_token: your_production_bot_token
  bot_username: your_production_bot_username
```

Or use environment variables in production:
```bash
TELEGRAM_BOT_TOKEN=your_token
TELEGRAM_BOT_USERNAME=your_username
```

## Step 3: Test the Integration

### 1. Start your Rails server
```bash
bin/dev
```

### 2. Visit the login page
```
http://localhost:3000/login
```

### 3. Click the Telegram Login button
- If configured correctly, you'll see the Telegram Login Widget
- Click it to authorize with your Telegram account
- You should be redirected back and logged in

### 4. Verify in logs
Check your Rails logs for:
```
✅ New Telegram user created: @your_username (ID: 123456789)
```

## Troubleshooting

### "Bot domain invalid" error
- Make sure you've set the domain in @BotFather settings
- For development, set domain to `localhost`
- For production, use your actual domain without `https://`

### Widget doesn't appear
- Check `TELEGRAM_BOT_USERNAME` is set correctly
- Verify the bot username ends with "bot"
- Check browser console for JavaScript errors

### "Invalid Telegram authentication" error
- Verify `TELEGRAM_BOT_TOKEN` matches the bot you're using
- Check that the token is not expired
- Ensure the auth data is less than 24 hours old

### Hash validation fails
- The bot token must match exactly
- Check for extra spaces in environment variables
- Verify you're using the same bot for widget and validation

## Security Notes

1. **Never commit bot tokens to git**
   - Use `.env` for development (add to `.gitignore`)
   - Use Rails credentials for production

2. **Hash validation is critical**
   - The controller validates the Telegram signature
   - Don't skip or disable this validation

3. **HTTPS in production**
   - Telegram Login Widget requires HTTPS in production
   - Use your existing SSL certificate

## How It Works

1. User clicks Telegram Login Widget on `/login` or `/signup`
2. Telegram redirects to your callback URL with signed data
3. `TelegramAuthController#create` validates the signature
4. If valid, finds or creates user by `telegram_id`
5. Starts a new session for the user
6. Redirects to dashboard or onboarding

## Rolling Back to Email Authentication

To restore email/password authentication:

1. Rename disabled controllers:
   ```bash
   mv app/controllers/passwords_controller.rb.disabled app/controllers/passwords_controller.rb
   mv app/controllers/email_confirmations_controller.rb.disabled app/controllers/email_confirmations_controller.rb
   ```

2. Uncomment routes in `config/routes.rb`

3. Uncomment email forms in views:
   - `app/views/sessions/new.html.erb`
   - `app/views/users/new.html.erb`

4. Update User model validations to require email/password

## Support

For issues:
1. Check Rails logs: `tail -f log/development.log`
2. Check browser console for JavaScript errors
3. Verify Telegram Bot settings in @BotFather
4. Test with a different Telegram account
