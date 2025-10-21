#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'PluginReporter.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'PR MAC' }

file_path = 'DAWImportView.swift'

# Check if file is already in project
existing = project.files.find { |f| f.path == file_path }
if existing
  puts "✅ #{file_path} already in project"
  exit 0
end

# Add file to project
file_ref = project.main_group.new_file(file_path)
target.add_file_references([file_ref])

# Save
project.save

puts "✅ Added #{file_path} to #{target.name} target"
