# Slot-Based Memory System for UPlanet IA

## Overview

The UPlanet IA system now supports a multi-user, multi-slot memory system that allows users to organize their conversation history into 13 different memory slots (0-12).

## Features

- **Multi-user support**: Each user (identified by nostr email or pubkey) has their own memory slots
- **13 memory slots**: Slots 0-12 for organizing different conversation contexts
- **Automatic slot detection**: Detects `#1`-`#12` tags in messages
- **Backward compatibility**: Maintains legacy memory system for existing users

## Usage

### Recording Memory

To record a message in a specific memory slot, use the `#rec` tag with a slot number:

```
#rec #3 This message will be stored in slot 3
#rec #7 Another message in slot 7
#rec This message will be stored in slot 0 (default)
```

### Using Memory for IA Context

When asking the IA a question, specify which slot to use for context:

```
#BRO #3 What was our previous discussion about?
#BOT #7 Can you remind me what we talked about?
#BRO This will use slot 0 (default)
```

### Viewing Memory

To view the contents of a specific memory slot:

```
#mem #3 : Show memory from slot 3
#mem : Show memory from slot 0 (default)
```

### Resetting Memory

To reset a specific memory slot:

```
#reset #3 : Clear slot 3
#reset : Clear slot 0 (default)
#reset #all : Clear all slots (0-12)
```

**Important**: The reset functionality only affects memory files stored in `$HOME/.zen/tmp/flashmem/{user_id}/slot{N}.json`. It does not affect legacy memory files in `~/.zen/tmp/flashmem/uplanet_memory/`.

## File Structure

Memory files are stored in the following structure:

```
~/.zen/tmp/flashmem/
├── {user_email}/
│   ├── slot0.json
│   ├── slot1.json
│   ├── slot2.json
│   └── ...
└── uplanet_memory/  (legacy coordinate-based memory)
    ├── {coord_key}.json
    └── pubkey/
        └── {pubkey}.json
```

## Memory File Format

Each slot memory file contains:

```json
{
  "user_id": "user@example.com",
  "slot": 3,
  "messages": [
    {
      "timestamp": "2024-01-01T12:00:00Z",
      "event_id": "event123",
      "latitude": "0.00",
      "longitude": "0.00",
      "content": "Message content"
    }
  ]
}
```

## Implementation Details

### Updated Files

1. **`NIP-101/relay.writePolicy.plugin/filter/1.sh`**
   - Detects `#1`-`#12` tags when `#rec` is present
   - Calls `short_memory.py` with slot number and user ID

2. **`Astroport.ONE/IA/short_memory.py`**
   - Accepts slot number and user ID parameters
   - Stores memory in user-specific slot files
   - Maintains backward compatibility with legacy system

3. **`Astroport.ONE/IA/UPlanet_IA_Responder.sh`**
   - Detects slot numbers in `#BRO`/`#BOT` messages
   - Updates `#mem` and `#reset` to support slot selection
   - Passes slot and user ID to `question.py`

4. **`Astroport.ONE/IA/question.py`**
   - Added `--slot` and `--user-id` parameters
   - Loads context from slot-based memory files
   - Falls back to legacy memory system if needed

### Slot Detection Logic

- **Default slot**: 0 (when no `#1`-`#12` tag is found)
- **User identification**: Uses KNAME (nostr email) if available, falls back to pubkey
- **Tag parsing**: Searches for `#1` through `#12` in message content

### Memory Limits

- **Per slot**: Last 50 messages
- **Context for IA**: Last 20 messages (to avoid token limits)

## Testing

Run the test script to verify the implementation:

```bash
cd ~/.zen/Astroport.ONE/IA
./test_slot_memory.sh
```

## Migration

Existing users will continue to work with the legacy memory system. New slot-based memory will be created alongside existing memory files.

## Examples

### Example 1: Work-related conversations
```
#rec #1 Meeting notes: Discussed Q4 goals
#rec #1 Action items: Schedule follow-up meeting
#BRO #1 What were the action items from our meeting?
```

### Example 2: Personal conversations
```
#rec #5 Remember to buy groceries
#rec #5 Need to call mom this weekend
#mem #5 Show me my personal reminders
```

### Example 3: Project discussions
```
#rec #8 Bug in login system
#rec #8 Fixed authentication issue
#BOT #8 What was the last bug we discussed?
```

## Troubleshooting

- **Memory not found**: Check if the user ID and slot number are correct
- **Legacy memory**: Old memory files are still accessible via pubkey-based queries
- **Slot limits**: Only slots 0-12 are supported
- **File permissions**: Ensure write permissions to `~/.zen/tmp/flashmem/` 