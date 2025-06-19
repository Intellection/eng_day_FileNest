#!/usr/bin/env ruby

# Test script to check MIME type detection for various file extensions
# Run with: ruby script/test_mime_types.rb

require 'marcel'
require 'tempfile'
require 'pathname'

# Test file extensions and their expected content
test_files = {
  'test.txt' => 'This is a plain text file.',
  'test.md' => '# Markdown File\n\nThis is a markdown file with some content.',
  'test.markdown' => '## Another Markdown\n\n- List item 1\n- List item 2',
  'test.csv' => 'name,age,city\nJohn,30,NYC\nJane,25,LA',
  'README.md' => '# README\n\nThis is a README file.',
  'notes.txt' => 'Some plain text notes here.',
  'data.csv' => 'id,value\n1,100\n2,200'
}

puts "Testing MIME type detection with Marcel gem:\n"
puts "=" * 60

test_files.each do |filename, content|
  # Create a temporary file with the content
  Tempfile.create([File.basename(filename, '.*'), File.extname(filename)]) do |tempfile|
    tempfile.write(content)
    tempfile.rewind

    # Detect MIME type using Marcel
    detected_type = Marcel::MimeType.for(tempfile)

    puts "File: #{filename}"
    puts "  Content-based detection: #{detected_type || 'nil'}"
    puts "  Extension: #{File.extname(filename)}"
    puts ""
  end
end

puts "Current ALLOWED_CONTENT_TYPES in UserFile model:"
puts "=" * 60

# Define the current allowed types (copy from model)
allowed_types = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/gif",
  "image/svg+xml",
  "text/plain",
  "text/markdown",
  "text/x-markdown",
  "application/x-markdown",
  "text/x-web-markdown",
  "text/csv",
  "application/csv"
]

allowed_types.each do |type|
  puts "  - #{type}"
end

puts "\nRecommendations:"
puts "=" * 60
puts "1. Check the detected MIME types above"
puts "2. Add any missing MIME types to ALLOWED_CONTENT_TYPES"
puts "3. Consider using filename-based fallback for ambiguous files"
puts "4. Test with actual files to verify detection works correctly"
