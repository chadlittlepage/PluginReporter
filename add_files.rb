#!/usr/bin/env ruby
require 'securerandom'

# List of new files to add (relative paths)
new_files = [
  "AppDelegate.swift",
  "ZoomState.swift",
  "Components/FadingScrollbar.swift",
  "Components/FilterDropdowns.swift",
  "Components/StarsSelector.swift",
  "Components/SummaryBars.swift",
  "Components/TableCells/NotesCell.swift",
  "Components/TableCells/RatingCell.swift",
  "Extensions/ViewExtensions+Table.swift",
  "Helpers/PrintHelper.swift",
  "Helpers/ZoomEnvironment.swift",
  "Models/PluginDragData.swift",
  "Styles/SpaceModeButtonStyle.swift",
  "Views/Playlists/PlaylistRowView.swift",
  "Views/Playlists/PlaylistSidebarView.swift",
  "Views/PluginDetailView.swift",
  "Views/PrintablePluginTextView.swift",
  "Views/Sheets/MetadataEditorSheet.swift",
  "Views/Sheets/TagsEditorSheet.swift"
]

project_file = "PluginReporter.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Find the PBXFileReference section
file_ref_section_start = content.index("/* Begin PBXFileReference section */")
build_file_section_start = content.index("/* Begin PBXBuildFile section */")

# Find the PR MAC sources section
sources_section = content.index(/"PR MAC" \*\/;\n\t\t\tbuildPhases = \((.*?)\);/m)

file_refs = []
build_files = []
source_entries = []

new_files.each do |file_path|
  file_name = File.basename(file_path)
  
  # Generate UUIDs
  file_ref_uuid = SecureRandom.hex(12).upcase
  build_file_uuid = SecureRandom.hex(12).upcase
  
  # Create PBXFileReference entry
  file_ref = "\t\t#{file_ref_uuid} /* #{file_name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{file_name}; sourceTree = \"<group>\"; };\n"
  file_refs << file_ref
  
  # Create PBXBuildFile entry
  build_file = "\t\t#{build_file_uuid} /* #{file_name} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_uuid} /* #{file_name} */; };\n"
  build_files << build_file
  
  # Create source entry for build phase
  source_entry = "\t\t\t\t#{build_file_uuid} /* #{file_name} in Sources */,\n"
  source_entries << source_entry
  
  puts "Added #{file_name} (FileRef: #{file_ref_uuid}, BuildFile: #{build_file_uuid})"
end

puts "\n✅ Generated #{new_files.length} file references"
puts "Run this manually or create a proper Ruby script to insert them into project.pbxproj"
