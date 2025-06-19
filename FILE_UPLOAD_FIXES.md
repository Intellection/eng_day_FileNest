# File Upload Type Fixes

## Problem
The application was rejecting uploads of `.txt` and `.md` files despite having them listed in the `ALLOWED_CONTENT_TYPES` array. This was happening because the Marcel gem was detecting these files as `application/octet-stream` instead of their expected MIME types like `text/plain` or `text/markdown`.

## Root Cause
The Marcel MIME type detection library sometimes returns `application/octet-stream` for text-based files when it cannot definitively determine the content type based on file content alone. This is a common issue with plain text files that don't have distinctive content patterns.

## Solution
Implemented a multi-layered approach to handle file type validation:

### 1. Enhanced MIME Type Detection (`uploads_controller.rb`)
- Added fallback logic that uses file extension when Marcel returns `nil` or `application/octet-stream`
- Implemented extension-based MIME type mapping for common file types
- Added detailed logging to track MIME type detection process

```ruby
# Fallback MIME type detection based on file extension
if detected_content_type.nil? || detected_content_type == "application/octet-stream"
  extension = File.extname(file.original_filename).downcase
  content_type = case extension
  when '.txt'
    'text/plain'
  when '.md', '.markdown'
    'text/markdown'
  when '.csv'
    'text/csv'
  # ... other mappings
  end
end
```

### 2. Updated Model Validation (`user_file.rb`)
- Added `application/octet-stream` to `ALLOWED_CONTENT_TYPES` as a controlled exception
- Created `ALLOWED_FILE_EXTENSIONS` array for additional validation
- Implemented custom validation method that checks both MIME type and file extension
- Added special handling for `application/octet-stream` files to validate against allowed extensions

### 3. Improved Error Messages
- Enhanced error responses to include detected MIME types and allowed extensions
- Added more specific error messages for different validation failures
- Excluded internal MIME types from user-facing error messages

## Files Modified

### `app/models/user_file.rb`
- Added additional markdown MIME types: `text/x-markdown`, `application/x-markdown`, `text/x-web-markdown`
- Added `application/octet-stream` to allowed types
- Created `ALLOWED_FILE_EXTENSIONS` constant
- Replaced simple inclusion validation with custom `validate_file_type` method
- Updated `text?` method to recognize all markdown variants

### `app/controllers/uploads_controller.rb`
- Added Marcel MIME type detection logging
- Implemented fallback MIME type detection based on file extensions
- Added dual validation for both MIME type and file extension
- Enhanced error responses with more detailed information

## Supported File Types

| Category | Extensions | Primary MIME Types | Fallback Detection |
|----------|------------|-------------------|-------------------|
| **Images** | `.jpg`, `.jpeg`, `.png`, `.gif`, `.svg` | `image/jpeg`, `image/png`, etc. | ✅ |
| **Text** | `.txt` | `text/plain` | ✅ |
| **Markdown** | `.md`, `.markdown` | `text/markdown`, `text/x-markdown` | ✅ |
| **Data** | `.csv` | `text/csv`, `application/csv` | ✅ |

## Testing
Created test scripts to verify the fixes:

1. **`script/test_mime_types.rb`** - Tests what MIME types Marcel detects for different file types
2. **`script/test_upload.rb`** - End-to-end upload testing for all supported file types

## Usage Examples

### Successful Upload Response
```json
{
  "message": "File uploaded successfully",
  "file": {
    "id": 123,
    "filename": "notes.md",
    "content_type": "text/markdown",
    "file_size": 1024,
    "human_readable_size": "1.0 KB",
    "uploaded_at": "2024-01-01T12:00:00Z",
    "is_image": false,
    "is_text": true
  }
}
```

### Error Response for Unsupported Type
```json
{
  "message": "Invalid file type",
  "allowed_types": ["image/jpeg", "image/png", "text/plain", "text/markdown", "text/csv"],
  "detected_type": "application/pdf"
}
```

## Security Considerations
- File extension validation prevents malicious files from being uploaded as `application/octet-stream`
- MIME type detection is still the primary validation method
- Extension-based fallback only applies to known safe file types
- All uploaded files are still subject to size limits (2MB)

## Future Improvements
1. Consider using additional MIME type detection libraries for better accuracy
2. Add file content validation for extra security
3. Implement virus scanning for uploaded files
4. Add support for additional file types as needed

## Verification
To verify the fixes work correctly:

1. Start the Rails server: `rails server`
2. Run the test script: `ruby script/test_upload.rb`
3. Try uploading `.txt` and `.md` files through the web interface
4. Check server logs for MIME type detection information