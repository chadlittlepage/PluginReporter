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

# 1. Add PBXBuildFile entries (after AbletonLiveParser entries on lines 105-107)
pattern1 = r'(405CCAE52EA300B7001268F0 /\* AbletonLiveParser\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 405CCAE22EA300B7001268F0 /\* AbletonLiveParser\.swift \*/; \};)'
replacement1 = (
    r'\1\n'
    f'\t\t{build_file_mac_uuid} /* ProToolsTextParser.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* ProToolsTextParser.swift */; }};\n'
    f'\t\t{build_file_ipad_uuid} /* ProToolsTextParser.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* ProToolsTextParser.swift */; }};\n'
    f'\t\t{build_file_iphone_uuid} /* ProToolsTextParser.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* ProToolsTextParser.swift */; }};'
)
content = re.sub(pattern1, replacement1, content, count=1)

# 2. Add PBXFileReference entry (after AbletonLiveParser file reference)
pattern2 = r'(405CCAE22EA300B7001268F0 /\* AbletonLiveParser\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = AbletonLiveParser\.swift; sourceTree = "<group>"; \};)'
replacement2 = (
    r'\1\n'
    f'\t\t{file_ref_uuid} /* ProToolsTextParser.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProToolsTextParser.swift; sourceTree = "<group>"; }};'
)
content = re.sub(pattern2, replacement2, content, count=1)

# 3. Add to source group (after AbletonLiveParser.swift in the file list)
pattern3 = r'(405CCAE22EA300B7001268F0 /\* AbletonLiveParser\.swift \*/,)'
replacement3 = (
    r'\1\n'
    f'\t\t\t\t{file_ref_uuid} /* ProToolsTextParser.swift */,'
)
content = re.sub(pattern3, replacement3, content, count=1)

# 4. Add to PBXSourcesBuildPhase for PR iPHONE target (line 695)
pattern4 = r'(405CCAE52EA300B7001268F0 /\* AbletonLiveParser\.swift in Sources \*/,)'
replacement4 = (
    r'\1\n'
    f'\t\t\t\t{build_file_iphone_uuid} /* ProToolsTextParser.swift in Sources */,'
)
content = re.sub(pattern4, replacement4, content, count=1)

# 5. Add to PBXSourcesBuildPhase for PR MAC target (line 747)
pattern5 = r'(405CCAE32EA300B7001268F0 /\* AbletonLiveParser\.swift in Sources \*/,)'
replacement5 = (
    r'\1\n'
    f'\t\t\t\t{build_file_mac_uuid} /* ProToolsTextParser.swift in Sources */,'
)
content = re.sub(pattern5, replacement5, content, count=1)

# 6. Add to PBXSourcesBuildPhase for PR iPAD target
# Need to find the iPad-specific AbletonLiveParser entry
pattern6 = r'(405CCAE42EA300B7001268F0 /\* AbletonLiveParser\.swift in Sources \*/,)'
replacement6 = (
    r'\1\n'
    f'\t\t\t\t{build_file_ipad_uuid} /* ProToolsTextParser.swift in Sources */,'
)
content = re.sub(pattern6, replacement6, content, count=1)

# Write the modified content
with open('PluginReporter.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ ProToolsTextParser.swift added to all three targets!")
