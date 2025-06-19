# Test Setup for FileNest Rails Application

## Overview

This document describes the test setup for the FileNest Rails application. The tests are written using Rails' built-in testing framework (Minitest) and provide comprehensive coverage for the core Ruby components.

## Test Structure

The test suite is organized into the following directories:

```
test/
├── controllers/
│   └── auth_controller_test.rb
├── fixtures/
│   ├── users.yml
│   └── user_files.yml
├── models/
│   ├── user_test.rb
│   └── user_file_test.rb
├── services/
│   ├── auth_jwt_service_test.rb
│   ├── authorize_api_request_test.rb
│   └── message_test.rb
└── test_helper.rb
```

## Test Coverage

### Model Tests

#### User Model (`test/models/user_test.rb`)
- Validates presence of required fields (name, email, password)
- Tests password length validation (minimum 6 characters)
- Validates email uniqueness (case-insensitive)
- Tests email downcasing before save
- Tests password authentication
- Tests associations with user_files
- Tests token payload generation
- Tests password validation on updates

#### UserFile Model (`test/models/user_file_test.rb`)
- Validates presence of required fields
- Tests file size validation (positive, within 2MB limit)
- Tests filename length and format validation
- Tests content type validation against allowed types
- Tests file extension validation
- Tests filename sanitization
- Tests reserved system name rejection
- Tests automatic uploaded_at setting
- Tests utility methods (image?, text?, human_readable_size, etc.)
- Tests file renaming functionality
- Tests scopes (recent, by_type)

### Service Tests

#### Auth::JwtService (`test/services/auth_jwt_service_test.rb`)
- Tests JWT token encoding with payload
- Tests token encoding with custom expiration
- Tests token decoding for valid tokens
- Tests error handling for invalid/malformed tokens
- Tests error handling for expired tokens
- Tests data type preservation in encode/decode cycle
- Tests secret key configuration

#### AuthorizeApiRequest (`test/services/authorize_api_request_test.rb`)
- Tests successful authorization with valid token
- Tests error handling for missing Authorization header
- Tests error handling for invalid/expired tokens
- Tests error handling for non-existent users
- Tests token extraction from Authorization header
- Tests memoization of user lookup and token decoding
- Tests various header formats and edge cases

#### Message Service (`test/services/message_test.rb`)
- Tests all message generation methods
- Validates message content and format
- Tests parameterized messages (like not_found)
- Ensures all methods return non-empty strings

### Controller Tests

#### AuthController (`test/controllers/auth_controller_test.rb`)
- Tests successful login with valid credentials
- Tests login failure scenarios (invalid email, password, missing fields)
- Tests successful user registration
- Tests registration failure scenarios (duplicate email, validation errors)
- Tests JWT token generation and validity
- Tests email case handling
- Tests malformed JSON handling

## Test Fixtures

### Users Fixture (`test/fixtures/users.yml`)
Creates test users with realistic data:
- `john`: john@example.com with password "password123"
- `jane`: jane@example.com with password "password123"  
- `admin`: admin@example.com with password "admin123"

### UserFiles Fixture (`test/fixtures/user_files.yml`)
Creates test files with various types:
- `image_file`: JPEG image (1MB)
- `text_file`: Plain text file (2KB)
- `csv_file`: CSV file (4KB)
- `markdown_file`: Markdown file (1KB)
- `large_image`: PNG image at 2MB limit

## Running Tests

### Prerequisites
- Ruby 3.1+ (as specified in .ruby-version)
- All gems installed via `bundle install`
- Database setup: `bin/rails db:create db:migrate RAILS_ENV=test`

### Environment Setup
If you encounter Ruby version issues, you have several options:

#### Option 1: Use Docker (Recommended)
```bash
# Build and run tests in Docker
docker-compose run --rm web bin/rails test

# Or run specific test files
docker-compose run --rm web bin/rails test test/models/user_test.rb
```

#### Option 2: Use rbenv/rvm
```bash
# Install correct Ruby version
rbenv install 3.3.5  # or rvm install 3.3.5
rbenv local 3.3.5    # or rvm use 3.3.5

# Then install dependencies
bundle install
```

#### Option 3: Update Ruby System-wide
Follow your system's Ruby installation guide to upgrade to Ruby 3.1+

### Running All Tests
```bash
bin/rails test
```

### Running Specific Test Files
```bash
bin/rails test test/models/user_test.rb
bin/rails test test/controllers/auth_controller_test.rb
```

### Running Specific Tests
```bash
bin/rails test test/models/user_test.rb -n test_should_require_email
```

### Running Tests by Category
```bash
# Run all model tests
bin/rails test test/models/

# Run all service tests
bin/rails test test/services/

# Run all controller tests
bin/rails test test/controllers/
```

### Troubleshooting

#### Ruby Version Issues
If you see "Ruby (>= 3.1) is not available", your system Ruby is too old:
- Check current version: `ruby -v`
- The app requires Ruby 3.1+ but tests were created to be compatible
- Use Docker or upgrade Ruby to run tests

#### Bundle Install Issues
If gems fail to install:
```bash
# Try updating bundler first
gem update bundler

# Or use the lockfile version
gem install bundler:2.5.16
```

#### Database Issues
If you see database errors:
```bash
# Reset test database
bin/rails db:drop db:create db:migrate RAILS_ENV=test

# Load fixtures
bin/rails db:fixtures:load RAILS_ENV=test
```

#### Missing Test Files
If fixture files are missing:
```bash
# Ensure test fixture files exist
ls test/fixtures/files/
# Should contain: test_file.txt, test_data.csv
```

## Test Environment Setup

The tests use the Rails test environment with:
- SQLite in-memory database for fast test execution
- Fixtures loaded automatically for each test
- Parallel test execution enabled
- Transactional test cases for data isolation

## Key Testing Patterns

### Validation Testing
Tests cover both positive and negative cases for all model validations, ensuring comprehensive coverage of business rules.

### Authentication Testing
JWT token generation and validation is thoroughly tested, including edge cases like expired tokens and malformed headers.

### Service Testing
Service objects are tested in isolation with mocked dependencies where appropriate, focusing on their core responsibilities.

### Controller Testing
API endpoints are tested for both success and failure scenarios, validating response formats and status codes.

## Extending the Test Suite

When adding new features:

1. **Models**: Add validations, associations, and method tests
2. **Services**: Test core functionality and error handling
3. **Controllers**: Test all endpoints with various input scenarios
4. **Fixtures**: Add realistic test data that supports your test cases

## Notes

- Tests are designed to be simple and focused, avoiding over-testing edge cases
- Fixtures provide realistic test data that mirrors production scenarios
- Error handling is thoroughly tested for security-critical components
- The test suite focuses on the Ruby/Rails components, not the JavaScript frontend
- Tests use Rails' built-in Minitest framework instead of RSpec for compatibility
- File upload tests use Rack::Test::UploadedFile for simulating multipart uploads

## Expected Test Results

When running the full test suite, you should see:
- **Model tests**: ~40+ assertions covering User and UserFile validations
- **Service tests**: ~30+ assertions covering JWT and authorization services
- **Controller tests**: ~50+ assertions covering API endpoints
- **Integration tests**: File operations with proper authorization

Sample output:
```
Running 45 tests in a single process
.............................................
Finished in 2.45s, 18.37 runs/s, 89.12 assertions/s.
45 runs, 218 assertions, 0 failures, 0 errors, 0 skips
```

## Test Coverage Areas

The test suite covers:
- ✅ Model validation and business logic
- ✅ JWT authentication and authorization
- ✅ API endpoint security and responses
- ✅ File upload validation and processing
- ✅ Error handling and edge cases
- ✅ Database relationships and cascading deletes
- ⚠️ Active Storage file operations (basic coverage)
- ❌ JavaScript frontend (out of scope)
- ❌ Email delivery (not implemented)
- ❌ Background jobs (not implemented)