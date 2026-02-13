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

# 1. Add PBXBuildFile entries (after last ProToolsTextParser build file)
pattern1 = r'(D1891BAF228442DEA184DA15 /\* ProToolsTextParser\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 228B693A5B6949329474DC02 /\* ProToolsTextParser\.swift \*/; \};)'
replacement1 = (
    r'\1\n'
    f'\t\t{build_file_mac_uuid} /* BitwigParser.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* BitwigParser.swift */; }};\n'
    f'\t\t{build_file_ipad_uuid} /* BitwigParser.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* BitwigParser.swift */; }};\n'
    f'\t\t{build_file_iphone_uuid} /* BitwigParser.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* BitwigParser.swift */; }};'
)
content = re.sub(pattern1, replacement1, content, count=1)

# 2. Add PBXFileReference entry (after ProToolsTextParser file reference)
pattern2 = r'(228B693A5B6949329474DC02 /\* ProToolsTextParser\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = ProToolsTextParser\.swift; sourceTree = "<group>"; \};)'
replacement2 = (
    r'\1\n'
    f'\t\t{file_ref_uuid} /* BitwigParser.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BitwigParser.swift; sourceTree = "<group>"; }};'
)
content = re.sub(pattern2, replacement2, content, count=1)

# 3. Add to source group (after ProToolsTextParser.swift in the file list)
pattern3 = r'(228B693A5B6949329474DC02 /\* ProToolsTextParser\.swift \*/,)'
replacement3 = (
    r'\1\n'
    f'\t\t\t\t{file_ref_uuid} /* BitwigParser.swift */,'
)
content = re.sub(pattern3, replacement3, content, count=1)

# 4. Add to PBXSourcesBuildPhase for PR iPHONE target
pattern4 = r'(D1891BAF228442DEA184DA15 /\* ProToolsTextParser\.swift in Sources \*/,)'
replacement4 = (
    r'\1\n'
    f'\t\t\t\t{build_file_iphone_uuid} /* BitwigParser.swift in Sources */,'
)
content = re.sub(pattern4, replacement4, content, count=1)

# 5. Add to PBXSourcesBuildPhase for PR MAC target
pattern5 = r'(81502849DE874B46A932D781 /\* ProToolsTextParser\.swift in Sources \*/,)'
replacement5 = (
    r'\1\n'
    f'\t\t\t\t{build_file_mac_uuid} /* BitwigParser.swift in Sources */,'
)
content = re.sub(pattern5, replacement5, content, count=1)

# 6. Add to PBXSourcesBuildPhase for PR iPAD target
pattern6 = r'(E659D398D9484318A5D73B70 /\* ProToolsTextParser\.swift in Sources \*/,)'
replacement6 = (
    r'\1\n'
    f'\t\t\t\t{build_file_ipad_uuid} /* BitwigParser.swift in Sources */,'
)
content = re.sub(pattern6, replacement6, content, count=1)

# Write the modified content
with open('PluginReporter.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ BitwigParser.swift added to all three targets!")
