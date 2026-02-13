#!/usr/bin/env python3
import re
import uuid

# Read the project file
with open('PluginReporter.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs for the new file
file_ref_uuid = ''.join([format(b, '02X') for b in uuid.uuid4().bytes])[:24]
build_file_mac_uuid = ''.join([format(b, '02X') for b in uuid.uuid4().bytes])[:24]
build_file_ipad_uuid = ''.join([format(b, '02X') for b in uuid.uuid4().bytes])[:24]
build_file_iphone_uuid = ''.join([format(b, '02X') for b in uuid.uuid4().bytes])[:24]

print(f"Generated UUIDs:")
print(f"  File Reference: {file_ref_uuid}")
print(f"  Build File (MAC): {build_file_mac_uuid}")
print(f"  Build File (iPad): {build_file_ipad_uuid}")
print(f"  Build File (iPhone): {build_file_iphone_uuid}")

# 1. Add PBXBuildFile entries (after AbletonLiveParser entries)
ableton_build_pattern = r'(405CCAE5[0-9A-F]{12} /\* AbletonLiveParser\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = [0-9A-F]{24} /\* AbletonLiveParser\.swift \*/; \};)'
replacement = r'\1\n\t\t' + build_file_mac_uuid + ' /* ProToolsTextParser.swift in Sources */ = {isa = PBXBuildFile; fileRef = ' + file_ref_uuid + ' /* ProToolsTextParser.swift */; };'
replacement += '\n\t\t' + build_file_ipad_uuid + ' /* ProToolsTextParser.swift in Sources */ = {isa = PBXBuildFile; fileRef = ' + file_ref_uuid + ' /* ProToolsTextParser.swift */; };'
replacement += '\n\t\t' + build_file_iphone_uuid + ' /* ProToolsTextParser.swift in Sources */ = {isa = PBXBuildFile; fileRef = ' + file_ref_uuid + ' /* ProToolsTextParser.swift */; };'

content = re.sub(ableton_build_pattern, replacement, content)

# 2. Add PBXFileReference entry (after AbletonLiveParser)
file_ref_pattern = r'(405CCAE2[0-9A-F]{12} /\* AbletonLiveParser\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = AbletonLiveParser\.swift; sourceTree = "<group>"; \};)'
file_ref_replacement = r'\1\n\t\t' + file_ref_uuid + ' /* ProToolsTextParser.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProToolsTextParser.swift; sourceTree = "<group>"; };'

content = re.sub(file_ref_pattern, file_ref_replacement, content)

# 3. Add to source group (after AbletonLiveParser.swift in the file list)
group_pattern = r'(405CCAE2[0-9A-F]{12} /\* AbletonLiveParser\.swift \*/,)'
group_replacement = r'\1\n\t\t\t\t' + file_ref_uuid + ' /* ProToolsTextParser.swift */,'

content = re.sub(group_pattern, group_replacement, content)

# 4. Add to PBXSourcesBuildPhase for each target
# Find the Sources build phases and add to each
sources_phases = re.finditer(r'/\* Sources \*/.*?files = \((.*?)\);', content, re.DOTALL)

for match in sources_phases:
    files_section = match.group(1)

    # Check which target this is by looking for characteristic files
    if 'MacPluginTable' in files_section:
        # PR MAC target
        new_entry = '\n\t\t\t\t' + build_file_mac_uuid + ' /* ProToolsTextParser.swift in Sources */,'
        # Add after AbletonLiveParser
        files_section_new = re.sub(
            r'(405CCAE3[0-9A-F]{12} /\* AbletonLiveParser\.swift in Sources \*/,)',
            r'\1' + new_entry,
            files_section
        )
        content = content.replace(match.group(1), files_section_new)
    elif 'PR iPAD' in content[max(0, match.start()-500):match.start()]:
        # PR iPAD target
        new_entry = '\n\t\t\t\t' + build_file_ipad_uuid + ' /* ProToolsTextParser.swift in Sources */,'
        files_section_new = re.sub(
            r'(405CCAE4[0-9A-F]{12} /\* AbletonLiveParser\.swift in Sources \*/,)',
            r'\1' + new_entry,
            files_section
        )
        content = content.replace(match.group(1), files_section_new)
    elif 'PR iPHONE' in content[max(0, match.start()-500):match.start()]:
        # PR iPHONE target
        new_entry = '\n\t\t\t\t' + build_file_iphone_uuid + ' /* ProToolsTextParser.swift in Sources */,'
        files_section_new = re.sub(
            r'(405CCAE5[0-9A-F]{12} /\* AbletonLiveParser\.swift in Sources \*/,)',
            r'\1' + new_entry,
            files_section
        )
        content = content.replace(match.group(1), files_section_new)

# Write the modified content
with open('PluginReporter.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ ProToolsTextParser.swift added to all three targets!")
