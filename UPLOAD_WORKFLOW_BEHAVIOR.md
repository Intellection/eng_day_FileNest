# Upload Workflow Behavior Documentation

## Overview
This document explains how file uploads behave in different scenarios with and without ClamAV virus scanning available.

## 🔍 Quick Answer
**YES**, the upload workflow works even if you don't have the ClamAV Docker container running, but the behavior depends on your environment and configuration.

## 📊 Behavior Matrix

| Scenario | ClamAV Status | Environment | REQUIRE_VIRUS_SCAN | Upload Result |
|----------|---------------|-------------|-------------------|---------------|
| **Development (Default)** | ❌ Not Running | development | not set | ✅ **ALLOWED** with warning |
| **Development (Strict)** | ❌ Not Running | development | `true` | ❌ **BLOCKED** |
| **Development (Skip)** | ❌ Not Running | development | any + `SKIP_VIRUS_SCAN=true` | ✅ **ALLOWED** (no scan) |
| **Production (Default)** | ❌ Not Running | production | not set | ❌ **BLOCKED** |
| **Production (Fail-Open)** | ❌ Not Running | production | any + `VIRUS_SCAN_FAIL_OPEN=true` | ✅ **ALLOWED** with warning |
| **Any Environment** | ✅ Running | any | any | ✅ **ALLOWED** (with scan) |

## 🛠️ Default Behavior

### Development Mode (Lenient)
```bash
# Start server normally in development
bin/rails server

# Result: Uploads work WITHOUT ClamAV
# Response includes:
{
  "file": {
    "virus_scan": {
      "status": "clean",
      "safe": true,
      "warning": "Virus scanning unavailable - allowed in development"
    }
  }
}
```

### Production Mode (Strict)
```bash
# In production environment
RAILS_ENV=production bin/rails server

# Result: Uploads BLOCKED without ClamAV
# Response:
{
  "message": "File upload rejected: Virus scanning service unavailable"
}
```

## 🔧 Configuration Options

### 1. Require Virus Scanning (Strict Mode)
```bash
# Force virus scanning requirement
REQUIRE_VIRUS_SCAN=true bin/rails server

# Behavior: Uploads blocked if ClamAV unavailable
# Use case: Security-critical development/staging
```

### 2. Skip Virus Scanning (Fast Development)
```bash
# Completely skip virus scanning
SKIP_VIRUS_SCAN=true bin/rails server

# Behavior: No virus scanning attempted
# Use case: Fast local development, testing
```

### 3. Fail-Open Policy (Production Fallback)
```bash
# Allow uploads when scanner unavailable (NOT RECOMMENDED for production)
VIRUS_SCAN_FAIL_OPEN=true bin/rails server

# Behavior: Uploads allowed with warning if ClamAV down
# Use case: Emergency production fallback
```

## 🧪 Test Results

### Scenario 1: Development Without ClamAV
```bash
# Setup
docker-compose stop clamav
bin/rails server

# Test Result
✅ File uploaded successfully in development mode
   Scan status: clean
   Safe: true  
   Warning: Virus scanning unavailable - allowed in development
```

### Scenario 2: Strict Mode Without ClamAV
```bash
# Setup
docker-compose stop clamav
REQUIRE_VIRUS_SCAN=true bin/rails server

# Test Result
❌ Upload correctly blocked in strict mode
   Message: File upload rejected: Virus scanning service unavailable
```

### Scenario 3: With ClamAV Running
```bash
# Setup
docker-compose up -d clamav
bin/rails server

# Test Result
✅ File uploaded successfully with virus scanning
   Scan status: clean (or infected if virus detected)
   Safe: true (or false if virus detected)
   Scanned at: 2025-06-19T13:28:32.459Z
```

## 📝 Code Logic

The upload workflow follows this decision tree:

```ruby
def perform_virus_scan(file)
  # Skip in test environment if configured
  if Rails.env.test? && ENV['SKIP_VIRUS_SCAN'] == 'true'
    return safe_result_with_skip_reason
  end

  scanner = FileProcessing::VirusScanner.instance

  # Check if ClamAV is available
  unless scanner.service_available?
    # In development, be lenient unless explicitly required
    if Rails.env.development? && ENV['REQUIRE_VIRUS_SCAN'] != 'true'
      return safe_result_with_warning  # ✅ ALLOW
    else
      return unsafe_result_with_error  # ❌ BLOCK
    end
  end

  # ClamAV is available - perform actual scan
  scanner.scan_file(file)
end
```

## 🚀 Practical Usage

### For Development
```bash
# Option 1: Default (works without ClamAV)
bin/rails server

# Option 2: Fast development (skip scanning)
SKIP_VIRUS_SCAN=true bin/rails server

# Option 3: Test with ClamAV
docker-compose up -d clamav
bin/rails server
```

### For Production
```bash
# Recommended: Always require ClamAV
RAILS_ENV=production REQUIRE_VIRUS_SCAN=true bin/rails server

# With ClamAV running
docker-compose up -d clamav
RAILS_ENV=production bin/rails server
```

### For Testing
```bash
# Test without virus scanning (faster)
SKIP_VIRUS_SCAN=true bin/rails test

# Test with virus scanning
docker-compose up -d clamav
bin/rails test
```

## 🛡️ Security Implications

### ✅ Safe Configurations
- **Production with ClamAV**: Full virus protection
- **Development default**: Allows development without ClamAV setup
- **Strict mode**: Ensures virus scanning when security is critical

### ⚠️ Caution Required
- **Fail-open in production**: Could allow malware if ClamAV fails
- **Skip scanning**: No virus protection at all

### ❌ Dangerous Configurations
- **Production without ClamAV + fail-open**: Security vulnerability

## 🔍 How to Check Current Behavior

### Check ClamAV Status
```bash
# Check if container is running
docker-compose ps clamav

# Test from Rails
bundle exec rails runner "puts FileProcessing::VirusScanner.instance.service_available?"
```

### Test Upload Behavior
```bash
# Quick test
ruby script/simple_virus_test.rb

# Comprehensive test
ruby script/test_virus_scanning.rb

# Test without ClamAV
ruby script/test_no_clamav.rb

# Test strict mode
ruby script/test_strict_mode.rb
```

## 📋 Environment Variables Summary

| Variable | Default | Effect |
|----------|---------|--------|
| `REQUIRE_VIRUS_SCAN` | `false` | Force virus scanning requirement |
| `SKIP_VIRUS_SCAN` | `false` | Skip virus scanning entirely |
| `VIRUS_SCAN_FAIL_OPEN` | `false` | Allow uploads when scanner fails |
| `CLAMAV_HOST` | `localhost` | ClamAV server hostname |
| `CLAMAV_PORT` | `3310` | ClamAV server port |

## 🎯 Recommendations

### For Development Teams
1. **Default setup**: Use normal development mode (works without ClamAV)
2. **Security testing**: Periodically test with ClamAV enabled
3. **CI/CD**: Use `SKIP_VIRUS_SCAN=true` for faster automated tests

### For Production Deployments
1. **Always run ClamAV**: Use `docker-compose up -d clamav`
2. **Set strict mode**: Use `REQUIRE_VIRUS_SCAN=true`
3. **Monitor health**: Check ClamAV container status regularly
4. **Never use fail-open**: Avoid `VIRUS_SCAN_FAIL_OPEN=true` in production

### For Security-Critical Applications
1. **Mandatory scanning**: Always require ClamAV
2. **Fail-closed policy**: Block uploads when scanning fails
3. **Regular testing**: Use virus scanning test scripts
4. **Monitor logs**: Watch for virus detection events

## 🚨 Troubleshooting

### Upload Blocked Unexpectedly
1. Check if ClamAV container is running: `docker-compose ps clamav`
2. Verify Rails can connect: `bundle exec rails runner "puts FileProcessing::VirusScanner.instance.service_available?"`
3. Check environment variables: `echo $REQUIRE_VIRUS_SCAN`

### Upload Allowed When It Shouldn't Be
1. Verify you're not in development mode with default settings
2. Check if `VIRUS_SCAN_FAIL_OPEN=true` is set
3. Confirm ClamAV is actually scanning: check logs

### ClamAV Connection Issues
1. Wait for container to be healthy: `docker-compose logs -f clamav`
2. Check port binding: `docker-compose ps clamav`
3. Test direct connection: `telnet localhost 3310`

## 📚 Related Documentation

- `VIRUS_SCANNING_TEST_RESULTS.md` - Detailed test results
- `script/simple_virus_test.rb` - Quick verification script
- `script/test_virus_scanning.rb` - Comprehensive test suite
- `README.md` - General setup and configuration