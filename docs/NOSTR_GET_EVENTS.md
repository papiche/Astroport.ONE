# 📡 nostr_get_events.sh - NOSTR Event Query Tool

## 📋 Overview

`nostr_get_events.sh` is a powerful shell script for querying NOSTR events from a local `strfry` relay. It provides a flexible command-line interface for searching and retrieving events based on various filters.

**Location**: `Astroport.ONE/tools/nostr_get_events.sh`

**Purpose**: Query the local strfry NOSTR relay database for events matching specific criteria (kind, author, tags, timestamps, etc.)

---

## 🎯 Key Features

- **Multiple Filter Options**: Search by kind, author, tags (`d`, `p`, `e`), timestamps
- **Flexible Output**: JSON (one event per line) or count mode
- **Efficient Querying**: Direct strfry database access for fast results
- **Integration Ready**: Designed for use by `oracle_system.py` and other scripts
- **Parameterized Queries**: Support for complex multi-criteria searches

---

## 🔧 Usage

### Basic Syntax

```bash
./nostr_get_events.sh [OPTIONS]
```

### Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--kind KIND` | Filter by event kind | `--kind 30500` |
| `--author HEX` | Filter by author public key (hex) | `--author abc123...` |
| `--tag-d VALUE` | Filter by 'd' tag | `--tag-d did` |
| `--tag-p HEX` | Filter by 'p' tag (person) | `--tag-p abc123...` |
| `--tag-e ID` | Filter by 'e' tag (event reference) | `--tag-e event123...` |
| `--since TIMESTAMP` | Events created after this Unix timestamp | `--since 1698000000` |
| `--until TIMESTAMP` | Events created before this Unix timestamp | `--until 1699000000` |
| `--limit N` | Maximum number of events to return | `--limit 100` |
| `--output MODE` | Output mode: `json` (default) or `count` | `--output count` |

---

## 📖 Examples

### Example 1: Get All Permit Definitions (kind 30500)

```bash
./nostr_get_events.sh --kind 30500 --limit 10
```

**Output**: JSON events (one per line)
```json
{"id":"...","pubkey":"...","created_at":1698000000,"kind":30500,"tags":[...],"content":"...","sig":"..."}
{"id":"...","pubkey":"...","created_at":1698000100,"kind":30500,"tags":[...],"content":"...","sig":"..."}
```

### Example 2: Get Permit Requests by Author

```bash
./nostr_get_events.sh --kind 30501 --author abc123def456... --limit 5
```

**Use Case**: Find all permit requests submitted by a specific user

### Example 3: Count Attestations (kind 30502)

```bash
./nostr_get_events.sh --kind 30502 --output count
```

**Output**:
```
127
```

### Example 4: Get Recent Credentials (last 7 days)

```bash
SINCE=$(date -d '7 days ago' +%s)
./nostr_get_events.sh --kind 30503 --since $SINCE
```

### Example 5: Get DID Documents with 'd' Tag

```bash
./nostr_get_events.sh --kind 30800 --tag-d did --limit 20
```

### Example 6: Get Events Referencing a Specific Event (tag 'e')

```bash
./nostr_get_events.sh --tag-e event123abc... --limit 10
```

---

## 🔌 Integration with oracle_system.py

The `oracle_system.py` module uses `nostr_get_events.sh` as its primary method for querying NOSTR events:

### Python Integration Example

```python
def fetch_nostr_events(self, kind: int, author_hex: Optional[str] = None, 
                       since_timestamp: Optional[int] = None) -> List[Dict[str, Any]]:
    """Fetch NOSTR events from strfry relay using nostr_get_events.sh"""
    import subprocess
    
    # Find the script
    nostr_script = Path.home() / ".zen" / "Astroport.ONE" / "tools" / "nostr_get_events.sh"
    
    # Build command
    cmd = [str(nostr_script), '--kind', str(kind)]
    
    if author_hex:
        cmd.extend(['--author', author_hex])
    
    if since_timestamp:
        cmd.extend(['--since', str(since_timestamp)])
    
    # Execute query
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    
    # Parse JSON events (one per line)
    events = []
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            events.append(json.loads(line))
    
    return events
```

### Oracle-Specific Queries

```python
# Fetch all permit definitions (kind 30500)
definitions = oracle.fetch_permit_definitions_from_nostr()

# Fetch all permit requests (kind 30501)
requests = oracle.fetch_permit_requests_from_nostr()

# Fetch credentials for a specific user
credentials = oracle.fetch_permit_credentials_from_nostr(npub="npub1...")

# Fetch attestations for a specific request
attestations = oracle.fetch_nostr_events(
    kind=30502,
    tag_d=request_id
)
```

---

## 🧪 Testing

### Test 1: Basic Connectivity

```bash
# Check if strfry is accessible
./nostr_get_events.sh --kind 1 --limit 1 --output count
```

**Expected**: Returns a count (0 or more)

### Test 2: Oracle Event Types

```bash
# Test each Oracle kind
for kind in 30500 30501 30502 30503; do
    echo "Kind $kind:"
    ./nostr_get_events.sh --kind $kind --output count
done
```

**Expected Output**:
```
Kind 30500:
5
Kind 30501:
12
Kind 30502:
48
Kind 30503:
8
```

### Test 3: Author Filter

```bash
# Get your public key
MY_PUB=$(cat ~/.zen/game/nostr/$(cat ~/.zen/game/players/.current)/secret.nostr | grep "pub:" | cut -d' ' -f2)

# Query your events
./nostr_get_events.sh --author $MY_PUB --limit 5
```

---

## 🔍 How It Works

### Internal Process

1. **Parse Arguments**: Extracts filter criteria from command-line options
2. **Build strfry Query**: Constructs a JSON filter object for strfry
3. **Execute strfry scan**: Runs `strfry scan` with the filter
4. **Process Results**: Outputs events as JSON or count

### strfry Integration

The script uses `strfry scan` command with a filter JSON:

```bash
echo '{"kinds":[30500],"limit":10}' | strfry scan /path/to/strfry-db
```

### Filter Format

```json
{
  "kinds": [30500, 30501],
  "authors": ["abc123..."],
  "#d": ["permit_id"],
  "#p": ["abc123..."],
  "#e": ["event123..."],
  "since": 1698000000,
  "until": 1699000000,
  "limit": 100
}
```

---

## 📊 Performance

- **Speed**: Direct database access (no WebSocket overhead)
- **Scalability**: Can handle millions of events in strfry
- **Limits**: Default limit is 100 events (can be increased with `--limit`)
- **Timeout**: No built-in timeout (controlled by calling script)

---

## 🔐 Security

- **Local Access Only**: Queries local strfry database (no external network calls)
- **Read-Only**: Only reads events, does not modify the database
- **No Authentication**: Assumes local trusted environment

---

## 🚨 Troubleshooting

### Error: "strfry: command not found"

**Solution**: Install strfry or ensure it's in your `$PATH`

```bash
# Check if strfry is installed
which strfry

# If not, install it
# (installation instructions vary by system)
```

### Error: "No such file or directory: strfry-db"

**Solution**: Verify the strfry database path

```bash
# Default path
ls -la /home/zen/.zen/tmp/strfry-db

# Or find it
find ~ -name "strfry-db" 2>/dev/null
```

### No Results Returned

**Possible Causes**:
1. No events match the filter criteria
2. Wrong kind number
3. Incorrect author hex (use hex, not npub)
4. Timestamp filters too restrictive

**Debug**:
```bash
# Check total event count
./nostr_get_events.sh --output count

# Test with minimal filters
./nostr_get_events.sh --kind 1 --limit 1
```

---

## 🔗 Related Documentation

- **[ORACLE_SYSTEM.md](./ORACLE_SYSTEM.md)**: Oracle permit management system - 100% Dynamic System with auto-proclaimed professions and unlimited progression
- **[ORACLE_NOSTR_FLOW.md](./ORACLE_NOSTR_FLOW.md)**: NOSTR event flow details
- **[DID_IMPLEMENTATION.md](../DID_IMPLEMENTATION.md)**: DID and NOSTR integration

---

## 🎓 Advanced Usage

### Combining with jq for Processing

```bash
# Get all permit definitions and extract names
./nostr_get_events.sh --kind 30500 | jq -r '.content | fromjson | .name'

# Count attestations per permit type
./nostr_get_events.sh --kind 30502 | \
  jq -r '.tags[] | select(.[0] == "permit_id") | .[1]' | \
  sort | uniq -c
```

### Integration with Daily Maintenance

```bash
# In ORACLE.refresh.sh
PENDING_REQUESTS=$(./nostr_get_events.sh --kind 30501 | \
  jq -r 'select(.tags[] | select(.[0] == "status" and .[1] == "attesting")) | .id')

for req_id in $PENDING_REQUESTS; do
    echo "Processing request: $req_id"
    # ... validation logic ...
done
```

### Monitoring Script

```bash
#!/bin/bash
# oracle_monitor.sh - Monitor Oracle activity

echo "📊 Oracle Activity Summary"
echo "=========================="
echo ""
echo "Permit Definitions: $(./nostr_get_events.sh --kind 30500 --output count)"
echo "Pending Requests:   $(./nostr_get_events.sh --kind 30501 --output count)"
echo "Total Attestations: $(./nostr_get_events.sh --kind 30502 --output count)"
echo "Issued Credentials: $(./nostr_get_events.sh --kind 30503 --output count)"
echo ""

# Recent activity (last 24h)
SINCE=$(date -d '1 day ago' +%s)
echo "📅 Last 24 Hours:"
echo "  New Requests:     $(./nostr_get_events.sh --kind 30501 --since $SINCE --output count)"
echo "  New Attestations: $(./nostr_get_events.sh --kind 30502 --since $SINCE --output count)"
echo "  New Credentials:  $(./nostr_get_events.sh --kind 30503 --since $SINCE --output count)"
```

---

## 📝 Notes

- **Hex vs Npub**: Always use **hex** public keys (not npub/nsec) for filters
- **Line-by-Line JSON**: Output is newline-delimited JSON (NDJSON), not a JSON array
- **Filter Logic**: Multiple filters use AND logic (all must match)
- **Case Sensitivity**: All hex strings are case-insensitive
- **Tag Filters**: Only `d`, `p`, and `e` tags are currently supported

---

## 🤝 Contributing

This script is part of the Astroport.ONE project. Contributions and improvements are welcome!

**Areas for Enhancement**:
- Additional tag filters (`a`, `t`, etc.)
- Regex pattern matching
- Output formatting options (table, CSV)
- Connection pooling for multiple queries
- Cache layer for frequent queries

---

## 📜 License

AGPL-3.0 - https://choosealicense.com/licenses/agpl-3.0/

---

## 👨‍💻 Author

Fred (support@qo-op.com)

---

**Last Updated**: October 30, 2025  
**Version**: 1.0
