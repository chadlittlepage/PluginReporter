#!/usr/bin/env python3
import re
import sys

# Read the project file
with open('PluginReporter.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Find all PBXSourcesBuildPhase sections (Compile Sources)
sources_pattern = r'(/\* Sources \*/.*?isa = PBXSourcesBuildPhase;.*?files = \((.*?)\);)'
matches = list(re.finditer(sources_pattern, content, re.DOTALL))

print(f"Found {len(matches)} PBXSourcesBuildPhase sections")

# For each build phase, track file references and remove duplicates
for match in matches:
    full_section = match.group(0)
    files_section = match.group(2)

    # Extract all file reference IDs
    file_refs = re.findall(r'([A-F0-9]{24})\s*/\*.*?\*/,', files_section)

    # Find duplicates
    seen = set()
    duplicates = []
    for ref in file_refs:
        if ref in seen:
            duplicates.append(ref)
        else:
            seen.add(ref)

    if duplicates:
        print(f"Found {len(duplicates)} duplicate file references in this section")

        # Remove duplicates (keep first occurrence)
        for dup_ref in duplicates:
            # Find all occurrences of this reference
            dup_pattern = rf'{dup_ref}\s*/\*[^*]+\*/,\s*\n'
            occurrences = list(re.finditer(dup_pattern, files_section))

            if len(occurrences) > 1:
                # Remove all but the first occurrence
                for occurrence in occurrences[1:]:
                    files_section = files_section.replace(occurrence.group(0), '', 1)

        # Replace the old files section with the cleaned one
        new_section = full_section.replace(match.group(2), files_section)
        content = content.replace(full_section, new_section)

# Also remove Assets.xcassets from Compile Sources entirely if present
# (it should only be in Resources, not Sources)
content = re.sub(
    r'[A-F0-9]{24}\s*/\*\s*Assets\.xcassets\s*in\s*Sources\s*\*/,?\s*\n',
    '',
    content
)

# Write the cleaned content
with open('PluginReporter.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("Done! Duplicates removed.")
