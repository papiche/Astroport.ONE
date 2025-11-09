# N8N Workflow Builder - Cookie-Based Automation System

## Overview

The N8N Workflow Builder is a visual workflow automation system that allows users to program their AI assistant using cookie-based data sources. Users can create workflows that chain data sources (cookie scrapers) → processing (AI, image recognition) → outputs → actions, all stored and executed via NOSTR events.

## Architecture

### Frontend Interface

**Location**: `UPassport/templates/n8n.html`  
**Access**: `http://localhost:54321/n8n` or `https://u.copylaradio.com/n8n`

#### Features

- **Visual Node Editor**: Drag-and-drop interface for building workflows
- **Node Categories**:
  - **Data Sources**: Cookie Scraper, NOSTR Query
  - **Processing**: AI Question, Image Recognition, Image Generation, Filter, Transform
  - **Outputs**: Publish NOSTR, Save to uDRIVE, Send Email
- **Workflow Management**: Save/load workflows from NOSTR (kind 31900)
- **Node Configuration**: Double-click nodes to configure parameters
- **Visual Connections**: Click connectors to link nodes together
- **Workflow Settings**: Configure triggers (manual, scheduled, event-based)

#### Technology Stack

- **Bootstrap 5**: UI framework
- **NostrTools.js**: NOSTR protocol integration
- **Vanilla JavaScript**: No external dependencies for workflow logic
- **SVG**: Visual connection lines between nodes

### Backend Components

#### 1. Workflow Execution Engine

**Location**: `Astroport.ONE/IA/cookie_workflow_engine.sh`

**Functionality**:
- Loads workflow definitions from NOSTR (kind 31900)
- Executes nodes in sequence
- Handles different node types:
  - `cookie_scraper`: Executes domain-specific scrapers (youtube.com.sh, leboncoin.fr.sh, etc.)
  - `ai_question`: Processes with Ollama AI
  - `filter`: Filters data using jq
  - `nostr_publish`: Publishes NOSTR events
- Returns execution results

**Usage**:
```bash
cookie_workflow_engine.sh <workflow_id> <user_email> <pubkey> <event_id>
```

#### 2. IA Responder Integration

**Location**: `Astroport.ONE/IA/UPlanet_IA_Responder.sh`

**Cookie Tag Support**:
- Detects `#cookie` tag in messages
- Extracts workflow identifier from message
- Calls `cookie_workflow_engine.sh` for execution
- Returns results to user via NOSTR message

**Example Usage**:
```
#BRO #cookie youtube_workflow
```

#### 3. API Route

**Location**: `UPassport/54321.py`

**Route**: `GET /n8n`
- Serves the n8n.html template
- Includes IPFS gateway configuration

## NOSTR Event Kinds

### Kind 31900: Workflow Definition

**Type**: Replaceable event (uses `d` tag for workflow ID)

**Structure**:
```jsonc
{
  "kind": 31900,
  "tags": [
    ["d", "workflow_id"],
    ["t", "cookie-workflow"],
    ["t", "uplanet"],
    ["cookie", "youtube.com"]
  ],
  "content": "{WORKFLOW_JSON}"
}
```

**Workflow JSON**:
```jsonc
{
  "name": "YouTube to Blog Workflow",
  "description": "Auto-generate blog posts from YouTube liked videos",
  "version": "1.0.0",
  "nodes": [
    {
      "id": "source_1",
      "type": "cookie_scraper",
      "name": "YouTube Scraper",
      "position": { "x": 100, "y": 100 },
      "parameters": {
        "domain": "youtube.com",
        "scraper": "youtube.com.sh",
        "output": "liked_videos"
      }
    },
    {
      "id": "filter_1",
      "type": "filter",
      "name": "Filter Recent",
      "position": { "x": 300, "y": 100 },
      "parameters": {
        "field": "published_at",
        "operator": ">",
        "value": "7 days ago"
      },
      "connections": {
        "input": ["source_1"]
      }
    }
  ],
  "connections": [
    {
      "from": "source_1",
      "to": "filter_1",
      "fromType": "output",
      "toType": "input"
    }
  ],
  "triggers": [
    {
      "type": "manual",
      "tag": "#cookie"
    }
  ]
}
```

### Kind 31901: Workflow Execution Request

**Type**: Regular event

**Structure**:
```jsonc
{
  "kind": 31901,
  "tags": [
    ["e", "<workflow_event_id>"],
    ["t", "cookie-workflow-exec"],
    ["cookie", "youtube.com"]
  ],
  "content": "{EXECUTION_PARAMETERS_JSON}"
}
```

### Kind 31902: Workflow Execution Result

**Type**: Regular event

**Structure**:
```jsonc
{
  "kind": 31902,
  "tags": [
    ["e", "<workflow_event_id>"],
    ["e", "<execution_request_id>"],
    ["t", "cookie-workflow-result"],
    ["status", "success"]
  ],
  "content": "{EXECUTION_RESULT_JSON}"
}
```

## Node Types

### Data Sources

#### `cookie_scraper`
- **Purpose**: Execute domain-specific scraper using uploaded cookies
- **Parameters**:
  - `domain`: Cookie domain (e.g., "youtube.com", "leboncoin.fr")
  - `scraper`: Scraper script name (optional, defaults to `{domain}.sh`)
  - `output`: Output variable name
- **Output**: JSON array of scraped data
- **Implementation**: Calls `{domain}.sh` script in `Astroport.ONE/IA/`

#### `nostr_query`
- **Purpose**: Query NOSTR relay for events
- **Parameters**:
  - `kind`: Event kind to query
  - `author`: Author pubkey (optional)
  - `tags`: Tag filters
  - `limit`: Result limit
- **Output**: Array of NOSTR events
- **Status**: Not yet implemented in workflow engine

### Processing Nodes

#### `ai_question`
- **Purpose**: Ask AI question using Ollama
- **Parameters**:
  - `prompt`: Question prompt (supports `{variable}` substitution)
  - `model`: Ollama model name (default: "gemma3:12b")
  - `slot`: Memory slot (0-12)
- **Output**: AI response text
- **Implementation**: Calls `question.py` with specified parameters

#### `image_recognition`
- **Purpose**: Recognize image using PlantNet
- **Parameters**:
  - `image_url`: Image URL (from input or variable)
  - `latitude`: GPS latitude
  - `longitude`: GPS longitude
- **Output**: PlantNet recognition JSON
- **Status**: Not yet implemented in workflow engine

#### `image_generation`
- **Purpose**: Generate image using ComfyUI
- **Parameters**:
  - `prompt`: Image generation prompt
  - `output_path`: uDRIVE output path
- **Output**: Generated image URL
- **Status**: Not yet implemented in workflow engine

#### `filter`
- **Purpose**: Filter data based on conditions
- **Parameters**:
  - `field`: Field to filter
  - `operator`: "==", "!=", ">", "<", "contains", "regex"
  - `value`: Filter value
- **Output**: Filtered data array
- **Implementation**: Uses `jq` for JSON filtering

#### `transform`
- **Purpose**: Transform data structure
- **Parameters**:
  - `mapping`: Field mapping JSON
  - `format`: Output format
- **Output**: Transformed data
- **Status**: Not yet implemented in workflow engine

### Output Nodes

#### `nostr_publish`
- **Purpose**: Publish NOSTR event
- **Parameters**:
  - `kind`: Event kind
  - `tags`: Tag array (JSON)
  - `content_template`: Content template with `{variables}`
- **Output**: Published event ID
- **Implementation**: Calls `nostr_send_note.py`

#### `udrive_save`
- **Purpose**: Save data to uDRIVE
- **Parameters**:
  - `path`: uDRIVE path (e.g., "Documents/workflow_output.json")
  - `format`: "json" | "text" | "csv"
- **Output**: Saved file path
- **Status**: Not yet implemented in workflow engine

#### `email_send`
- **Purpose**: Send email notification
- **Parameters**:
  - `to`: Recipient email
  - `subject`: Email subject
  - `template`: Email template
- **Output**: Email sent confirmation
- **Status**: Not yet implemented in workflow engine

## Workflow Execution Flow

```
1. User creates workflow in n8n.html interface
   ↓
2. Workflow Definition (kind 31900) stored on NOSTR
   ↓
3. User sends message: #BRO #cookie <workflow_id>
   ↓
4. 1.sh detects #cookie tag and passes to UPlanet_IA_Responder.sh
   ↓
5. UPlanet_IA_Responder.sh detects #cookie tag
   ↓
6. cookie_workflow_engine.sh loads workflow from NOSTR
   ↓
7. Workflow engine executes nodes in sequence:
   - cookie_scraper → executes domain.sh script
   - filter → filters data
   - ai_question → processes with Ollama
   - nostr_publish → publishes results
   ↓
8. Execution result returned to user via NOSTR message
```

## Integration with Cookie System

Workflows automatically access cookie-based scrapers:

1. **Cookie Detection**: System finds `.{domain}.cookie` file in user's MULTIPASS directory
2. **Scraper Execution**: Calls `{domain}.sh` script with user email
3. **Data Return**: Scraper outputs JSON data to workflow
4. **Processing**: Workflow processes data through configured nodes

**Example**:
- User uploads `.youtube.com.cookie` via `/cookie` interface
- Workflow includes `cookie_scraper` node with `domain: "youtube.com"`
- Engine automatically finds cookie file and executes `youtube.com.sh`
- Scraped data (liked videos) flows to next node

## Example Workflows

### 1. YouTube to Blog Auto-Post

**Workflow**:
```
Cookie Scraper (youtube.com)
  ↓
Filter (recent videos, last 7 days)
  ↓
AI Question (generate blog post summary)
  ↓
Publish NOSTR (kind 30023 article)
```

**Usage**:
```
#BRO #cookie youtube_blog_workflow
```

### 2. Leboncoin Price Alert

**Workflow**:
```
Cookie Scraper (leboncoin.fr)
  ↓
Filter (price < 100€)
  ↓
Email Send (alert notification)
```

**Usage**:
```
#BRO #cookie leboncoin_alert_workflow
```

## Security Considerations

- **Cookie Access**: Only workflow owner can access their cookies
- **Workflow Privacy**: Workflows stored on user's own relay
- **Execution Validation**: Verify workflow ownership before execution
- **Rate Limiting**: Prevent workflow execution abuse
- **NIP-42 Authentication**: Required for workflow creation and execution

## Current Limitations

1. **Sequential Execution**: Nodes execute in order, no dependency resolution
2. **Variable Substitution**: Limited support for `{variable}` in prompts
3. **Error Handling**: Basic error handling, no retry logic
4. **Node Types**: Not all node types fully implemented
5. **Scheduled Triggers**: Not yet implemented
6. **Event Triggers**: Not yet implemented
7. **Connection Validation**: No validation of node connections
8. **Workflow Sharing**: No mechanism to share workflows between users

## Related Documentation

- **[NIP-101 Cookie Workflow Extension](../nostr-nips/101-cookie-workflow-extension.md)**: Complete NIP specification
- **[COOKIE_SYSTEM.md](../IA/COOKIE_SYSTEM.md)**: Cookie management system
- **[DOMAIN_SCRAPERS.md](../IA/DOMAIN_SCRAPERS.md)**: Guide to creating custom scrapers

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-09  
**Status**: Active Development  
**Author**: UPlanet/Astroport.ONE Team

