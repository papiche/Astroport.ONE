# Workflow Automation Integration - Complete Architecture

## Overview

This document describes the complete integration between **n8n.html** (visual workflow builder), **cookie.html** (cookie management), and **UPlanet_IA_Responder.sh** (AI responder) to create a fully automated system that transforms Web2 data extraction into NOSTR messages that trigger AI commands.

## Architecture Flow

```
┌─────────────────┐
│   cookie.html   │  User uploads cookies for authenticated web scraping
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   n8n.html      │  User creates visual workflows:
│                 │  - cookie_scraper → filter → ai_question → nostr_publish
│                 │  - Workflows saved as NOSTR events (kind 31900)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Workflow Engine │  Executes workflows:
│                 │  - Uses cookies from MULTIPASS
│                 │  - Processes data with AI
│                 │  - Publishes NOSTR messages
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  NOSTR Relay    │  Messages published:
│                 │  - Regular events (kind 1)
│                 │  - Articles (kind 30023)
│                 │  - With #BRO tag to trigger AI
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│UPlanet_IA_      │  Detects #BRO tag and processes:
│Responder.sh     │  - AI analysis
│                 │  - Image generation
│                 │  - Video processing
│                 │  - Plant recognition
└─────────────────┘
```

## Components

### 1. Cookie Management (`cookie.html`)

**Purpose**: Upload and manage authentication cookies for Web2 sites

**Location**: `UPassport/templates/cookie.html`

**Features**:
- Upload Netscape format cookie files
- Automatic domain detection
- Secure storage in MULTIPASS directory (`.domain.cookie` format)
- No API keys required - uses your authenticated sessions

**Cookie Storage**:
```
~/.zen/game/nostr/<user_email>/.youtube.com.cookie
~/.zen/game/nostr/<user_email>/.leboncoin.fr.cookie
```

### 2. Workflow Builder (`n8n.html`)

**Purpose**: Visual drag-and-drop workflow creation

**Location**: `UPassport/templates/n8n.html`

**Access**: `http://localhost:54321/n8n` or `https://u.copylaradio.com/n8n`

**Node Types**:

#### Data Sources
- **cookie_scraper**: Execute domain-specific scraper using uploaded cookies
  - Parameters: `domain`, `scraper`, `output`
  - Example: Scrape YouTube liked videos using `.youtube.com.cookie`

- **nostr_query**: Query NOSTR relay for events
  - Parameters: `kind`, `author`, `tags`, `limit`

#### Processing
- **ai_question**: Ask AI using Ollama
  - Parameters: `prompt` (supports `{variable}` substitution), `model`, `slot`
  - Example: `"Summarize this video: {video_title}"`

- **filter**: Filter data based on conditions
  - Parameters: `field`, `operator` (==, !=, >, <, contains, regex), `value`

- **transform**: Transform data structure
  - Parameters: `mapping`, `format`

#### Outputs
- **nostr_publish**: Publish NOSTR event
  - Parameters: `kind`, `tags`, `content_template`, **`send_bro`** (NEW!)
  - **NEW Feature**: `send_bro` checkbox prepends `#BRO` to content
  - This triggers `UPlanet_IA_Responder.sh` automatically

- **udrive_save**: Save to uDRIVE
- **email_send**: Send email notification

**Workflow Storage**:
- Workflows saved as NOSTR events (kind 31900)
- Replaceable events (can be updated)
- Tagged with `cookie-workflow` and `uplanet`

### 3. Workflow Execution Engine (`cookie_workflow_engine.sh`)

**Purpose**: Execute workflows defined in n8n.html

**Location**: `Astroport.ONE/IA/cookie_workflow_engine.sh`

**Usage**:
```bash
cookie_workflow_engine.sh <workflow_id> <user_email> <user_pubkey> <request_event_id>
```

**Execution Flow**:
1. Load workflow from NOSTR (kind 31900)
2. Find user's cookie files in MULTIPASS directory
3. Execute nodes in sequence:
   - `cookie_scraper` → runs domain scraper script with cookie file
   - `filter` → filters data using jq
   - `ai_question` → calls `question.py` with Ollama
   - `nostr_publish` → publishes NOSTR event (with #BRO if enabled)
4. Return execution results

**Cookie Integration**:
- Automatically finds `.domain.cookie` files in user's MULTIPASS
- Passes cookie file to scraper scripts
- No API keys needed - uses your authenticated sessions

**BRO Command Support**:
- When `nostr_publish` node has `send_bro: true`:
  - Prepends `#BRO` to content
  - Triggers `UPlanet_IA_Responder.sh` automatically
  - Enables AI processing of workflow results

### 4. Workflow Scheduler (`workflow_scheduler.sh`)

**Purpose**: Automatically execute scheduled workflows

**Location**: `Astroport.ONE/IA/workflow_scheduler.sh`

**Usage**:
```bash
# Check all workflows
workflow_scheduler.sh --check-all

# Check workflows for specific user
workflow_scheduler.sh --user <email>
```

**Scheduling**:
- Queries NOSTR for workflows with `schedule` triggers
- Checks cron expressions against current time
- Executes matching workflows automatically

**Cron Format**:
```
0 2 * * *  # Daily at 2 AM
0 */6 * * *  # Every 6 hours
0 0 * * 1  # Every Monday at midnight
```

**Integration with 20h12.process.sh**:
- Can be called from daily maintenance script
- Or run via cron every hour

### 5. AI Responder (`UPlanet_IA_Responder.sh`)

**Purpose**: Process NOSTR messages with #BRO tag

**Location**: `Astroport.ONE/IA/UPlanet_IA_Responder.sh`

**Integration**:
- Detects `#BRO` tag in NOSTR messages
- Processes content with AI (Ollama)
- Supports tags: `#search`, `#image`, `#video`, `#plantnet`, etc.
- Publishes responses back to NOSTR

**Workflow Integration**:
- Workflows can publish messages with `#BRO` tag
- These messages automatically trigger AI processing
- Enables chaining: Web2 data → Workflow → NOSTR → AI → Response

## Complete Example Workflow

### Scenario: YouTube to Blog Auto-Post

1. **User uploads cookies** (`cookie.html`):
   - Uploads `cookies.txt` for YouTube
   - System saves as `.youtube.com.cookie` in MULTIPASS

2. **User creates workflow** (`n8n.html`):
   ```
   cookie_scraper (youtube.com)
     ↓
   filter (liked_at > 1 day ago)
     ↓
   ai_question ("Write blog post about: {video_title}")
     ↓
   nostr_publish (kind 30023, send_bro: true)
   ```

3. **Workflow saved**:
   - Stored as NOSTR event (kind 31900)
   - Tagged with `cookie-workflow` and `youtube.com`

4. **Workflow execution** (manual or scheduled):
   ```bash
   # Manual trigger
   #BRO #cookie <workflow_id>
   
   # Or scheduled (daily at 2 AM)
   # Set in workflow triggers: cron "0 2 * * *"
   ```

5. **Execution flow**:
   - `cookie_workflow_engine.sh` loads workflow
   - Finds `.youtube.com.cookie` file
   - Executes `youtube.com.sh` scraper with cookie
   - Filters recent liked videos
   - Generates blog post with AI
   - Publishes NOSTR article with `#BRO` tag

6. **AI processing**:
   - `UPlanet_IA_Responder.sh` detects `#BRO` tag
   - Processes article content
   - Can generate images, search, etc.
   - Publishes enhanced response

## Key Features

### 1. No API Keys Required
- Uses your authenticated cookie sessions
- No need for YouTube API, Leboncoin API, etc.
- Works with any site you're logged into

### 2. Visual Workflow Builder
- Drag-and-drop interface
- No coding required
- Workflows stored on NOSTR (portable, shareable)

### 3. Automatic Execution
- Scheduled workflows run automatically
- Manual triggers via `#cookie` tag
- Event-based triggers (future)

### 4. BRO Command Integration
- Workflows can trigger AI responder
- Chain: Web2 → Workflow → NOSTR → AI → Response
- Enables complex automation pipelines

### 5. Privacy & Security
- Cookies stored in your MULTIPASS (encrypted)
- Workflows stored on your relay
- Only you can access your cookies

## Usage Examples

### Example 1: Daily YouTube Digest

**Workflow**:
```
cookie_scraper (youtube.com) 
  → filter (published_at > 1 day ago)
  → ai_question ("Create daily digest of: {video_titles}")
  → nostr_publish (kind 1, send_bro: true)
```

**Schedule**: `0 8 * * *` (Daily at 8 AM)

**Result**: Every morning, system scrapes your YouTube liked videos, creates a digest with AI, and publishes it as a NOSTR message that triggers AI processing.

### Example 2: Leboncoin Price Alert

**Workflow**:
```
cookie_scraper (leboncoin.fr)
  → filter (price < 100)
  → nostr_publish (kind 1, content: "New cheap item: {title} - {price}€", send_bro: true)
```

**Schedule**: `0 */2 * * *` (Every 2 hours)

**Result**: System checks Leboncoin for items under 100€ and sends NOSTR alert that triggers AI notification.

### Example 3: Web2 Data → AI Analysis → Blog Post

**Workflow**:
```
cookie_scraper (any-site.com)
  → filter (date > 7 days ago)
  → ai_question ("Analyze this data: {data}")
  → nostr_publish (kind 30023, send_bro: true)
```

**Result**: Scrapes data from any authenticated site, analyzes with AI, publishes as blog article that triggers further AI processing.

## Setup Instructions

### 1. Upload Cookies
1. Visit `http://localhost:54321/cookie` or `https://u.copylaradio.com/cookie`
2. Connect with NOSTR extension
3. Upload `cookies.txt` files for each domain

### 2. Create Workflow
1. Visit `http://localhost:54321/n8n` or `https://u.copylaradio.com/n8n`
2. Connect with NOSTR extension
3. Drag nodes onto canvas
4. Configure each node
5. Connect nodes
6. Save workflow

### 3. Execute Workflow

**Manual**:
```
#BRO #cookie <workflow_name_or_id>
```

**Scheduled**:
- Set cron expression in workflow settings
- Add to cron (or call from 20h12.process.sh):
  ```bash
  # Every hour
  0 * * * * $HOME/.zen/Astroport.ONE/IA/workflow_scheduler.sh
  ```

## Technical Details

### NOSTR Event Kinds

- **31900**: Workflow Definition (replaceable event)
- **31901**: Workflow Execution Request
- **31902**: Workflow Execution Result

### Cookie File Format

- **Netscape HTTP Cookie File** format
- Stored as `.domain.cookie` in user's MULTIPASS directory
- Permissions: 600 (owner read/write only)

### Scraper Scripts

- Location: `Astroport.ONE/IA/` or `Astroport.ONE/scrapers/`
- Format: `domain.sh` (e.g., `youtube.com.sh`)
- Input: Cookie file path
- Output: JSON array of scraped data

### Workflow JSON Structure

```json
{
  "name": "Workflow Name",
  "description": "Description",
  "version": "1.0.0",
  "nodes": [
    {
      "id": "node_1",
      "type": "cookie_scraper",
      "name": "Scraper",
      "position": {"x": 100, "y": 100},
      "parameters": {
        "domain": "youtube.com",
        "scraper": "youtube.com.sh",
        "output": "data"
      },
      "connections": {
        "input": [],
        "output": ["node_2"]
      }
    }
  ],
  "connections": [
    {"from": "node_1", "to": "node_2"}
  ],
  "triggers": [
    {"type": "schedule", "cron": "0 2 * * *"},
    {"type": "manual", "tag": "#cookie"}
  ]
}
```

## Future Enhancements

1. **Event Triggers**: Trigger workflows on specific NOSTR events
2. **More Node Types**: Add more processing and output nodes
3. **Workflow Templates**: Pre-built workflows for common tasks
4. **Workflow Sharing**: Share workflows between users
5. **Error Handling**: Better error reporting and retry logic
6. **Workflow Monitoring**: Real-time execution status

## Troubleshooting

### Workflow Not Executing
- Check workflow ID is correct
- Verify user has cookies uploaded
- Check logs: `~/.zen/tmp/cookie_workflow.log`

### Cookies Not Found
- Verify cookie file exists: `~/.zen/game/nostr/<email>/.domain.cookie`
- Check file permissions (should be 600)
- Ensure domain matches exactly

### Scraper Script Not Found
- Check script exists: `Astroport.ONE/IA/domain.sh`
- Verify script is executable: `chmod +x domain.sh`
- Check script accepts cookie file as argument

### BRO Command Not Triggering
- Verify `send_bro: true` in `nostr_publish` node
- Check message published to NOSTR relay
- Verify `UPlanet_IA_Responder.sh` is running
- Check logs: `~/.zen/tmp/IA.log`

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**Author**: UPlanet/Astroport.ONE Team

