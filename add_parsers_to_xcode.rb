#!/usr/bin/env ruby

#
# add_parsers_to_xcode.rb
# Automatically adds parser files to Xcode project
#
# This script uses the xcodeproj gem to safely modify the Xcode project
# without manually editing the complex pbxproj file
#

require 'xcodeproj'

# Configuration
PROJECT_PATH = '/Users/chadlittlepage/Documents/APPs/PluginReporter/PluginReporter.xcodeproj'
SOURCE_DIR = '/Users/chadlittlepage/Documents/APPs/PluginReporter'

# Parsers to add (already verified to exist)
PARSERS_TO_ADD = [
  'ArdourParser.swift',
  'CubaseParser.swift',
  'DigitalPerformerParser.swift',
  'FairlightParser.swift',
  'FLStudioParser.swift',
  'GarageBandParser.swift',
  'LogicProParser.swift',
  'MainStageParser.swift',
  'MixbusParser.swift',
  'ProToolsParser.swift',
  'ReaperParser.swift',
  'ReasonParser.swift',
  'RenoiseParser.swift',
  'StudioOneParser.swift',
  'TracktionParser.swift'
]

# Also ensure these core files are added
CORE_FILES = [
  'DAWParserProtocol.swift'
]

puts "🚀 Plugin Reporter - Xcode Integration Script"
puts "=" * 50
puts ""

# Check if xcodeproj gem is available
begin
  require 'xcodeproj'
rescue LoadError
  puts "❌ Error: xcodeproj gem not found"
  puts ""
  puts "To install:"
  puts "  sudo gem install xcodeproj"
  puts ""
  puts "Or if using Homebrew Ruby:"
  puts "  gem install xcodeproj"
  puts ""
  exit 1
end

# Open the Xcode project
puts "📂 Opening Xcode project..."
begin
  project = Xcodeproj::Project.open(PROJECT_PATH)
  puts "✅ Project opened successfully"
rescue => e
  puts "❌ Error opening project: #{e.message}"
  exit 1
end

puts ""

# Find the main target (PR MAC)
target = project.targets.find { |t| t.name == 'PR MAC' }

if target.nil?
  puts "❌ Could not find 'PR MAC' target"
  puts "Available targets:"
  project.targets.each { |t| puts "  - #{t.name}" }
  exit 1
end

puts "🎯 Found target: #{target.name}"
puts ""

# Find or create a group for parsers
main_group = project.main_group
parsers_group = main_group.groups.find { |g| g.name == 'DAW Parsers' }

if parsers_group.nil?
  puts "📁 Creating 'DAW Parsers' group..."
  parsers_group = main_group.new_group('DAW Parsers')
  puts "✅ Group created"
else
  puts "📁 Found existing 'DAW Parsers' group"
end

puts ""
puts "Adding parser files to project..."
puts "-" * 50

added_count = 0
skipped_count = 0
errors = []

ALL_FILES = CORE_FILES + PARSERS_TO_ADD

ALL_FILES.each do |filename|
  file_path = File.join(SOURCE_DIR, filename)

  # Check if file exists
  unless File.exist?(file_path)
    puts "⚠️  #{filename} - FILE NOT FOUND, skipping"
    skipped_count += 1
    next
  end

  # Check if already in project
  existing_file = parsers_group.files.find { |f| f.path == filename }

  if existing_file
    puts "⏭️  #{filename} - already in project"
    skipped_count += 1
    next
  end

  begin
    # Add file to group
    file_ref = parsers_group.new_file(file_path)

    # Add to build phase
    target.source_build_phase.add_file_reference(file_ref)

    puts "✅ #{filename} - added successfully"
    added_count += 1
  rescue => e
    puts "❌ #{filename} - error: #{e.message}"
    errors << { file: filename, error: e.message }
  end
end

puts "-" * 50
puts ""

# Summary
puts "📊 SUMMARY"
puts "=" * 50
puts "Files added:   #{added_count}"
puts "Files skipped: #{skipped_count}"
puts "Errors:        #{errors.count}"
puts ""

if errors.any?
  puts "⚠️  Errors encountered:"
  errors.each do |err|
    puts "  - #{err[:file]}: #{err[:error]}"
  end
  puts ""
end

# Save the project
if added_count > 0
  puts "💾 Saving Xcode project..."
  begin
    project.save
    puts "✅ Project saved successfully!"
    puts ""
    puts "🎉 Integration complete!"
    puts ""
    puts "Next steps:"
    puts "  1. Open Xcode: open #{PROJECT_PATH}"
    puts "  2. Build the project: Cmd+B"
    puts "  3. Run the app: Cmd+R"
    puts ""
  rescue => e
    puts "❌ Error saving project: #{e.message}"
    puts ""
    puts "The project may be in an inconsistent state."
    puts "You may need to revert changes and try again."
    exit 1
  end
else
  puts "ℹ️  No files were added (all already in project or missing)"
  puts ""
end

puts "=" * 50
puts "Done!"
