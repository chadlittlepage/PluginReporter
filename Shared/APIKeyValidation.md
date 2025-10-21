# OpenAI API Key Validation

## Overview

The `APIKeyManager` now includes strong validation before storing API keys in the Keychain. This prevents invalid keys from being saved and provides helpful error messages to users.

## Validation Rules

### 1. Prefix Check
- **Required prefix**: `sk-` or `sk-proj-`
- **Error message**: "Invalid format: OpenAI API keys must start with 'sk-' or 'sk-proj-'"
- **Rationale**: All OpenAI API keys follow this format

### 2. Length Validation
- **Minimum length**: 40 characters
- **Maximum length**: 200 characters
- **Error messages**:
  - "Invalid length: OpenAI API keys must be at least 40 characters"
  - "Invalid length: Key is too long (max 200 characters)"
- **Rationale**: OpenAI keys are typically 48-56 characters; we allow 40-200 for flexibility

### 3. Character Set
- **Allowed characters**: Letters (a-z, A-Z), Numbers (0-9), Hyphens (-), Underscores (_)
- **Error message**: "Invalid characters: API key can only contain letters, numbers, hyphens, and underscores"
- **Rationale**: OpenAI keys only use these characters

### 4. Placeholder Detection
- **Blocked placeholders**:
  - `sk-...`
  - `sk-your-key-here`
  - `sk-1234567890`
  - `sk-placeholder`
- **Error message**: "Placeholder detected: Please enter your actual OpenAI API key"
- **Rationale**: Prevents users from accidentally saving example/placeholder values

### 5. Whitespace Handling
- **Action**: Automatically trimmed before validation
- **Rationale**: Users may accidentally copy extra whitespace

## Valid Examples

✅ `sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz1234567890AbCdEf`
✅ `sk-1234567890abcdefghijklmnopqrstuvwxyz1234567890ab`
✅ `sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz-1234_567890`

## Invalid Examples

❌ `api-key-12345` - Doesn't start with `sk-`
❌ `sk-123` - Too short (< 40 characters)
❌ `sk-...` - Blocked placeholder
❌ `sk-key with spaces` - Contains invalid characters (spaces)
❌ `sk-key@example.com` - Contains invalid characters (@, .)

## User Experience

### Error Display
- Validation errors appear in real-time as a red warning below the API key field
- Icon: ⚠️ `exclamationmark.triangle.fill`
- Color: Red text
- Position: Between input field and info link

### Empty State
- Empty API keys are allowed (deletes key from Keychain)
- No error shown when field is empty
- Shows "Local AI mode (works offline)" status

### Valid Key State
- No error message shown
- Shows "OpenAI mode (requires internet)" status (macOS)
- Key saved securely to Keychain

## Implementation Details

### Files Modified
1. `Shared/APIKeyManager.swift` - Core validation logic
2. `AISuggestionsView.swift` - macOS UI with error display
3. `iOS/AISuggestionsView.swift` - iOS UI with error display

### Methods Added
- `validateOpenAIKey(_ key: String) -> String?` - Returns error message or nil
- `isValidOpenAIKey(_ key: String) -> Bool` - Quick boolean check
- `@Published var validationError: String?` - Published error for UI binding

### Security Benefits
1. **Format validation** - Ensures only properly formatted keys are stored
2. **Length checks** - Prevents buffer overflow or excessively long strings
3. **Character validation** - Blocks injection attempts with special characters
4. **Placeholder detection** - Prevents accidental submission of example keys
5. **Keychain protection** - Only valid keys reach secure storage

## Testing

To test validation:
1. Try entering `sk-...` - Should show placeholder error
2. Try entering `sk-123` - Should show length error
3. Try entering `test-key` - Should show prefix error
4. Enter a valid `sk-` key with 48+ characters - Should save successfully
5. Clear the field - Should delete key from Keychain

## Future Enhancements

Potential improvements:
- [ ] Optional: Verify key with OpenAI API (test request)
- [ ] Track last validation timestamp
- [ ] Suggest common mistakes (e.g., "Did you copy the full key?")
- [ ] Auto-detect and warn about expired keys (if API returns 401)
