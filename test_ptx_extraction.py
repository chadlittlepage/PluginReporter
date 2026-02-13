#!/usr/bin/env python3
"""
Quick test to verify PTX string extraction logic
This mimics what the Swift parser will do
"""

import sys

def extract_strings(data, min_length=4):
    """Extract printable ASCII strings from binary data"""
    strings = []
    current = bytearray()

    for byte in data:
        # Printable ASCII range (including space)
        if 0x20 <= byte <= 0x7E:
            current.append(byte)
        else:
            if len(current) >= min_length:
                try:
                    strings.append(current.decode('utf-8'))
                except:
                    pass
            current = bytearray()

    # Don't forget the last string
    if len(current) >= min_length:
        try:
            strings.append(current.decode('utf-8'))
        except:
            pass

    return strings

def is_likely_track_name(s):
    """Check if a string looks like a valid track name"""
    # Must be reasonable length
    if len(s) < 3 or len(s) > 50:
        return False

    # Must have mostly alphanumeric and common punctuation
    valid_chars = sum(1 for c in s if c.isalnum() or c in ' -_.,()#')
    if valid_chars < len(s) * 0.8:  # At least 80% valid chars
        return False

    # Must have some letters
    if not any(c.isalpha() for c in s):
        return False

    # Skip strings with too many special characters in a row
    special_count = 0
    for c in s:
        if not c.isalnum() and c != ' ':
            special_count += 1
            if special_count > 2:
                return False
        else:
            special_count = 0

    lower_s = s.lower()

    # Skip system strings
    skip_keywords = ['protools', '.pt', 'media', 'audio', 'session', 'tracks',
                     'backup', 'info #', 'wavecache', 'fade']
    if any(keyword in lower_s for keyword in skip_keywords):
        return False

    # Skip dates
    if any(year in s for year in ['2024-', '2023-', '2022-', '202']):
        return False

    # Skip paths and extensions
    if '/' in s or '\\' in s or s.startswith('.'):
        return False

    return True

def extract_tracks(data):
    """Extract track names from PTX binary data"""
    strings = extract_strings(data, min_length=3)

    track_names = []
    seen_tracks = set()

    # Count occurrences and filter
    string_counts = {}
    for s in strings:
        if is_likely_track_name(s):
            string_counts[s] = string_counts.get(s, 0) + 1

    # Track names typically appear 2-5 times
    # Also include standard Pro Tools tracks that appear more
    for s, count in string_counts.items():
        if ((2 <= count <= 6) or
            (s in ['Click 1', 'Inst 1', 'Master 1'] and count >= 2)) and \
           s not in seen_tracks:
            track_names.append(s)
            seen_tracks.add(s)

    return sorted(track_names)

def main():
    ptx_file = "/Volumes/Media/Tracks/Rob/B4 U Go/ProTools/B4 U GO PT/B4 U GO PT.ptx"

    print("🧪 Testing PTX String Extraction")
    print(f"File: {ptx_file}")

    with open(ptx_file, 'rb') as f:
        data = f.read()

    print(f"Size: {len(data):,} bytes")
    print()

    # Extract all strings
    all_strings = extract_strings(data, min_length=5)
    print(f"📝 Found {len(all_strings)} strings (min length 5)")
    print()

    # Find session name
    session_name = None
    for s in all_strings:
        if s.endswith('.ptx') or s.endswith('.PTX'):
            session_name = s.replace('.ptx', '').replace('.PTX', '')
            break

    if session_name:
        print(f"📊 Session Name: {session_name}")
    print()

    # Extract tracks
    tracks = extract_tracks(data)
    print(f"🎵 Tracks Found: {len(tracks)}")
    for i, track in enumerate(tracks, 1):
        print(f"   [{i}] {track}")

    print()
    print("ℹ️  Note: PTX files are encrypted binary format.")
    print("   For complete plugin information, export session info as text from Pro Tools.")
    print()

    # Also show some interesting strings for debugging
    print("🔍 Interesting strings found:")
    interesting = [s for s in all_strings if 5 <= len(s) <= 30 and not any(x in s.lower() for x in ['protools', 'backup', 'session'])]
    for s in interesting[:20]:
        print(f"   - {s}")

if __name__ == '__main__':
    main()
