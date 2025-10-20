#!/usr/bin/env ruby

#
# add_parsers_to_ios.rb
# Adds parser files to iOS and iPad targets
#

require 'xcodeproj'

# Configuration
PROJECT_PATH = '/Users/chadlittlepage/Documents/APPs/PluginReporter/PluginReporter.xcodeproj'
SOURCE_DIR = '/Users/chadlittlepage/Documents/APPs/PluginReporter'

# Parsers to add
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

CORE_FILES = [
  'DAWParserProtocol.swift'
]

puts "🚀 Plugin Reporter - iOS Target Integration"
puts "=" * 50
puts ""

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

# Find the iOS targets
ios_target = project.targets.find { |t| t.name == 'PR iPHONE' }
ipad_target = project.targets.find { |t| t.name == 'PR iPAD' }

if ios_target.nil? && ipad_target.nil?
  puts "❌ Could not find iOS or iPad targets"
  puts "Available targets:"
  project.targets.each { |t| puts "  - #{t.name}" }
  exit 1
end

targets_to_update = []
targets_to_update << ios_target if ios_target
targets_to_update << ipad_target if ipad_target

puts "🎯 Found targets: #{targets_to_update.map(&:name).join(', ')}"
puts ""

# Find the DAW Parsers group
main_group = project.main_group
parsers_group = main_group.groups.find { |g| g.name == 'DAW Parsers' }

if parsers_group.nil?
  puts "❌ Could not find 'DAW Parsers' group"
  puts "Run add_parsers_to_xcode.rb first to create the group and add files to macOS target"
  exit 1
end

puts "📁 Found 'DAW Parsers' group"
puts ""

ALL_FILES = CORE_FILES + PARSERS_TO_ADD

added_count = 0
skipped_count = 0

puts "Adding parser files to iOS/iPad targets..."
puts "-" * 50

targets_to_update.each do |target|
  puts ""
  puts "Target: #{target.name}"
  puts ""

  ALL_FILES.each do |filename|
    # Find the file reference in the parsers group
    file_ref = parsers_group.files.find { |f| f.path == filename }

    unless file_ref
      puts "⚠️  #{filename} - not found in DAW Parsers group, skipping"
      skipped_count += 1
      next
    end

    # Check if already in this target's build phase
    if target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
      puts "⏭️  #{filename} - already in #{target.name}"
      skipped_count += 1
      next
    end

    begin
      # Add to build phase
      target.source_build_phase.add_file_reference(file_ref)

      puts "✅ #{filename} - added to #{target.name}"
      added_count += 1
    rescue => e
      puts "❌ #{filename} - error: #{e.message}"
    end
  end
end

puts ""
puts "-" * 50
puts ""

# Summary
puts "📊 SUMMARY"
puts "=" * 50
puts "Files added:   #{added_count}"
puts "Files skipped: #{skipped_count}"
puts ""

# Save the project
if added_count > 0
  puts "💾 Saving Xcode project..."
  begin
    project.save
    puts "✅ Project saved successfully!"
    puts ""
    puts "🎉 iOS Integration complete!"
    puts ""
    puts "Next steps:"
    puts "  1. Build the iOS target: Cmd+B (select PR iPHONE scheme)"
    puts "  2. Build the iPad target: Cmd+B (select PR iPAD scheme)"
    puts ""
  rescue => e
    puts "❌ Error saving project: #{e.message}"
    exit 1
  end
else
  puts "ℹ️  No files were added (all already in targets)"
  puts ""
end

puts "=" * 50
puts "Done!"
