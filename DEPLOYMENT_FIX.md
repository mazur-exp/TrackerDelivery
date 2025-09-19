# Fixing Production Parsing Issues

## Problem Identified
The parsing functionality was failing on production because the Docker container was missing Chrome browser and ChromeDriver dependencies.

## Solution Applied
Updated the Dockerfile to include all necessary Chrome dependencies and optimized parser services for production environment.

## Changes Made

### 1. Updated Dockerfile
- Added Chrome browser installation
- Added ChromeDriver installation using Chrome for Testing API
- Added all required system dependencies for headless Chrome
- Added environment variables for Chrome/ChromeDriver paths
- Optimized for container environment

### 2. Enhanced Parser Services
- Updated `GrabParserService` with production-optimized Chrome flags
- Updated `GojekParserService` with production-optimized Chrome flags
- Added binary path detection for container environments
- Improved memory management and timeouts

### 3. Created Testing Scripts
- `diagnose_production_chrome.rb` - Diagnose Chrome/Selenium issues
- `debug_production_parsing.rb` - Test production parsing endpoints
- `test_deployment.rb` - Comprehensive deployment verification

## Deployment Steps

1. **Rebuild and Deploy**
   ```bash
   # Build new image with Chrome dependencies
   kamal build

   # Deploy to production
   kamal deploy
   ```

2. **Verify Deployment**
   ```bash
   # Test the deployment
   ruby test_deployment.rb https://aidelivery.tech
   ```

3. **Monitor Logs**
   ```bash
   # Check application logs
   kamal app logs -f
   ```

## Expected Results
After deployment, both Grab and GoJek parsers should:
- ✅ Successfully extract restaurant data
- ✅ Handle headless Chrome in container environment
- ✅ Return proper JSON responses with parsed information
- ✅ Complete parsing within reasonable timeouts (30-90 seconds)

## Troubleshooting

If issues persist after deployment:

1. **Check Container Resources**
   - Ensure server has sufficient memory (Chrome needs ~100MB+)
   - Verify /tmp directory is writable
   - Check disk space for Chrome cache

2. **Verify Chrome Installation**
   ```bash
   kamal app exec "which google-chrome-stable"
   kamal app exec "which chromedriver"
   ```

3. **Test Chrome Manually**
   ```bash
   kamal app exec "google-chrome-stable --version"
   kamal app exec "chromedriver --version"
   ```

4. **Check Specific Errors**
   ```bash
   kamal app logs | grep -i "chrome\|selenium\|webdriver"
   ```

## Files Modified
- `Dockerfile` - Added Chrome and dependencies
- `app/services/grab_parser_service.rb` - Production optimizations
- `app/services/gojek_parser_service.rb` - Production optimizations

## Testing URLs Used
- **Grab**: `https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2`
- **GoJek**: `https://gofood.link/a/qpKr7VkG`

## Performance Expectations
- **First request after deployment**: 60-90 seconds (Chrome startup overhead)
- **Subsequent requests**: 20-30 seconds (Chrome warm)
- **Memory usage**: ~150-200MB per parsing operation
- **Success rate**: >95% for valid restaurant URLs