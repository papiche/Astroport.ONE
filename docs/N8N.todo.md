# N8N Workflow Builder - TODO & Roadmap

## 🎯 Goal

Make the N8N Workflow Builder a **complete, dynamic, and operational** system for programming cookie-based automation workflows. When a workflow model is proven effective, it can be implemented as a new BRO command (like `#search` that generates blog articles).

## 📋 Current Status

### ✅ Completed

- [x] Visual workflow builder interface (n8n.html)
- [x] Basic node types (cookie_scraper, ai_question, filter, nostr_publish)
- [x] Workflow save/load from NOSTR (kind 31900)
- [x] #cookie tag support in UPlanet_IA_Responder.sh
- [x] Basic workflow execution engine (cookie_workflow_engine.sh)
- [x] Node drag-and-drop interface
- [x] Node configuration modals
- [x] Visual connection lines between nodes
- [x] API route `/n8n`

### 🚧 In Progress

- [ ] Variable substitution in node parameters
- [ ] Dependency resolution for node execution
- [ ] Error handling and retry logic
- [ ] Execution result visualization

### ❌ Not Started

- [ ] Scheduled workflow triggers (cron)
- [ ] Event-based workflow triggers
- [ ] All node types fully implemented
- [ ] Workflow sharing mechanism
- [ ] Workflow templates library
- [ ] Execution history and logs
- [ ] BRO command integration (#cookie as built-in command)

---

## 🔧 Core Functionality Improvements

### 1. Variable Substitution System

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Implement variable substitution in node parameters
  - Support `{variable_name}` syntax in prompts, templates, etc.
  - Track variable outputs from each node
  - Pass variables to connected nodes
- [ ] Add variable preview in node configuration
- [ ] Validate variable references before execution
- [ ] Support nested variables (e.g., `{video.title}`)

**Example**:
```json
{
  "type": "ai_question",
  "parameters": {
    "prompt": "Summarize this video: {video_title}\nURL: {video_url}"
}
```

### 2. Dependency Resolution & Parallel Execution

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Build dependency graph from workflow connections
- [ ] Execute nodes in correct order (respecting dependencies)
- [ ] Support parallel execution of independent nodes
- [ ] Handle circular dependencies (detect and error)
- [ ] Optimize execution order for performance

**Current Limitation**: Nodes execute sequentially in array order, ignoring connections.

### 3. Complete Node Type Implementation

**Priority**: MEDIUM  
**Status**: Partially Complete

#### Data Sources

- [x] `cookie_scraper` - ✅ Implemented
- [ ] `nostr_query` - Query NOSTR relay for events
  - [ ] Implement NOSTR query execution
  - [ ] Support filters (kind, author, tags, limit)
  - [ ] Return event array to workflow

#### Processing Nodes

- [x] `ai_question` - ✅ Implemented
- [ ] `image_recognition` - PlantNet recognition
  - [ ] Call `plantnet_recognition.py`
  - [ ] Handle image URL from variables
  - [ ] Return recognition JSON
- [ ] `image_generation` - ComfyUI generation
  - [ ] Call `generate_image.sh`
  - [ ] Support prompt variables
  - [ ] Return generated image URL
- [x] `filter` - ✅ Implemented (basic)
- [ ] `transform` - Data transformation
  - [ ] Implement field mapping
  - [ ] Support JSON, CSV, text formats
  - [ ] Handle nested data structures

#### Output Nodes

- [x] `nostr_publish` - ✅ Implemented (basic)
- [ ] `udrive_save` - Save to uDRIVE
  - [ ] Implement file saving
  - [ ] Support JSON, text, CSV formats
  - [ ] Return saved file path
- [ ] `email_send` - Send email notification
  - [ ] Call `mailjet.sh`
  - [ ] Support email templates
  - [ ] Handle variable substitution in templates

### 4. Error Handling & Retry Logic

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Implement comprehensive error handling
  - [ ] Catch and log node execution errors
  - [ ] Continue workflow execution on non-critical errors
  - [ ] Stop workflow execution on critical errors
- [ ] Add retry logic for transient failures
  - [ ] Configurable retry count per node
  - [ ] Exponential backoff for retries
  - [ ] Skip node after max retries
- [ ] Error reporting to user
  - [ ] Detailed error messages
  - [ ] Node-level error tracking
  - [ ] Execution result with error details

### 5. Workflow Validation

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Validate workflow before saving
  - [ ] Check for required nodes (at least one source, one output)
  - [ ] Validate node connections (output → input only)
  - [ ] Check for circular dependencies
  - [ ] Validate node parameters
- [ ] Validate workflow before execution
  - [ ] Check cookie files exist for cookie_scraper nodes
  - [ ] Verify user has access to required resources
  - [ ] Check workflow ownership
- [ ] Provide validation feedback in UI
  - [ ] Highlight invalid nodes
  - [ ] Show validation errors
  - [ ] Prevent saving invalid workflows

---

## 🚀 Advanced Features

### 6. Scheduled Workflow Triggers

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Implement cron expression parsing
- [ ] Add scheduled workflow execution to `NOSTRCARD.refresh.sh`
  - [ ] Check for workflows with scheduled triggers
  - [ ] Evaluate cron expressions
  - [ ] Execute workflows at scheduled times
- [ ] Support timezone configuration
- [ ] Add execution history tracking
- [ ] Prevent duplicate executions

**Implementation Location**: `Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh`

### 7. Event-Based Workflow Triggers

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Define event trigger conditions
  - [ ] NOSTR event filters (kind, author, tags)
  - [ ] Data conditions (field values)
- [ ] Monitor NOSTR relay for trigger events
- [ ] Execute workflows when conditions met
- [ ] Pass trigger event data to workflow

**Example**: New YouTube video liked → trigger blog generation workflow

### 8. Workflow Templates Library

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Create common workflow templates
  - [ ] YouTube to Blog
  - [ ] Leboncoin Price Alert
  - [ ] Image Recognition → NOSTR Post
  - [ ] Data Scraping → Email Report
- [ ] Add template selection in UI
- [ ] Allow users to customize templates
- [ ] Share popular workflows as templates

### 9. Workflow Sharing & Discovery

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add workflow sharing mechanism
  - [ ] Public/private workflow flag
  - [ ] Workflow discovery interface
  - [ ] Import shared workflows
- [ ] Add workflow ratings/reviews
- [ ] Create workflow marketplace
- [ ] Support workflow forking

### 10. Execution History & Logs

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Store execution history (kind 31902)
- [ ] Display execution logs in UI
  - [ ] Execution status (success/failed/partial)
  - [ ] Node-level execution times
  - [ ] Error messages
  - [ ] Output data preview
- [ ] Add execution statistics
  - [ ] Success rate
  - [ ] Average execution time
  - [ ] Most used nodes
- [ ] Support execution replay/debugging

---

## 🎨 UI/UX Improvements

### 11. Enhanced Node Editor

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Add node search/filter in sidebar
- [ ] Improve node preview (show more details)
- [ ] Add node validation indicators
- [ ] Support node grouping/collapsing
- [ ] Add zoom/pan controls for canvas
- [ ] Improve connection line rendering
- [ ] Add connection validation (type checking)

### 12. Workflow Execution UI

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Add execution progress indicator
  - [ ] Show current executing node
  - [ ] Display execution status per node
  - [ ] Show execution time
- [ ] Real-time execution updates
  - [ ] WebSocket or polling for status
  - [ ] Live node execution visualization
- [ ] Execution result display
  - [ ] Show output data
  - [ ] Display errors
  - [ ] Export execution results

### 13. Workflow Management

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add workflow versioning
- [ ] Support workflow duplication
- [ ] Add workflow tags/categories
- [ ] Implement workflow search
- [ ] Add workflow export/import (JSON)

---

## 🔌 Integration Features

### 14. BRO Command Integration

**Priority**: HIGH  
**Status**: Not Started

**Goal**: Make `#cookie` a built-in BRO command (like `#search`)

**Tasks**:
- [ ] Enhance `#cookie` command in `UPlanet_IA_Responder.sh`
  - [ ] List available workflows if no ID provided
  - [ ] Show workflow details
  - [ ] Support workflow creation via chat
- [ ] Add workflow templates as BRO commands
  - [ ] `#cookie youtube_blog` → Execute YouTube to Blog workflow
  - [ ] `#cookie leboncoin_alert` → Execute Leboncoin alert workflow
- [ ] Create workflow from BRO command
  - [ ] `#cookie create youtube_blog` → Interactive workflow creation
  - [ ] Use AI to suggest workflow structure
- [ ] Workflow execution as article generation
  - [ ] If workflow produces article (kind 30023), format like `#search`
  - [ ] Include workflow metadata in article
  - [ ] Add workflow tags

**Example Integration**:
```
User: #BRO #cookie youtube_blog
Bot: ✅ Executing YouTube to Blog workflow...
     📝 Generated article: [link]
     🎨 Illustration: [image]
     📊 Processed 3 videos from last 7 days
```

### 15. Workflow API Endpoints

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add REST API endpoints in `54321.py`
  - [ ] `GET /api/workflows` - List user workflows
  - [ ] `GET /api/workflows/{id}` - Get workflow details
  - [ ] `POST /api/workflows` - Create workflow
  - [ ] `PUT /api/workflows/{id}` - Update workflow
  - [ ] `DELETE /api/workflows/{id}` - Delete workflow
  - [ ] `POST /api/workflows/{id}/execute` - Execute workflow
- [ ] Add workflow execution status endpoint
- [ ] Support API authentication (NIP-42)

### 16. Workflow Monitoring & Analytics

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Track workflow execution metrics
  - [ ] Execution count
  - [ ] Success/failure rate
  - [ ] Average execution time
  - [ ] Resource usage
- [ ] Add workflow health monitoring
- [ ] Alert on workflow failures
- [ ] Performance optimization suggestions

---

## 📚 Documentation & Testing

### 17. Documentation

**Priority**: MEDIUM  
**Status**: In Progress

**Tasks**:
- [x] Create `docs/N8N.md` - System documentation
- [x] Create `docs/N8N.todo.md` - This file
- [ ] Create user guide
  - [ ] Getting started tutorial
  - [ ] Node type reference
  - [ ] Workflow examples
  - [ ] Troubleshooting guide
- [ ] Create developer guide
  - [ ] Adding new node types
  - [ ] Workflow engine architecture
  - [ ] Testing workflows

### 18. Testing

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Create test workflows
  - [ ] Simple workflow (1 node)
  - [ ] Complex workflow (multiple nodes)
  - [ ] Error handling workflow
- [ ] Add unit tests for workflow engine
- [ ] Add integration tests
- [ ] Test with real cookie scrapers
- [ ] Performance testing

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Basic workflow builder interface
- ✅ Workflow save/load from NOSTR
- ✅ Basic workflow execution
- ✅ #cookie tag support

### Phase 2: Complete Functionality (Next)
- [ ] Variable substitution
- [ ] Dependency resolution
- [ ] All node types implemented
- [ ] Error handling
- [ ] Workflow validation

### Phase 3: Advanced Features
- [ ] Scheduled triggers
- [ ] Event triggers
- [ ] Workflow templates
- [ ] Execution history

### Phase 4: Integration
- [ ] BRO command integration
- [ ] Workflow API
- [ ] Monitoring & analytics

### Phase 5: Production Ready
- [ ] Complete documentation
- [ ] Comprehensive testing
- [ ] Performance optimization
- [ ] User feedback integration

---

## 💡 Future Ideas

- **AI-Powered Workflow Generation**: Use AI to suggest workflow structure based on user goals
- **Workflow Marketplace**: Community-driven workflow sharing and discovery
- **Visual Workflow Debugging**: Step-through execution with data inspection
- **Workflow Version Control**: Git-like versioning for workflows
- **Multi-User Workflows**: Collaborative workflow editing
- **Workflow Scheduling UI**: Visual cron expression builder
- **Workflow Analytics Dashboard**: Visualize workflow performance and usage
- **Mobile Workflow Builder**: Responsive design for mobile devices
- **Workflow Templates from BRO**: Generate workflows from successful BRO commands
- **Automated Workflow Testing**: Test workflows before production use

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: Active Development


## 🎯 Goal

Make the N8N Workflow Builder a **complete, dynamic, and operational** system for programming cookie-based automation workflows. When a workflow model is proven effective, it can be implemented as a new BRO command (like `#search` that generates blog articles).

## 📋 Current Status

### ✅ Completed

- [x] Visual workflow builder interface (n8n.html)
- [x] Basic node types (cookie_scraper, ai_question, filter, nostr_publish)
- [x] Workflow save/load from NOSTR (kind 31900)
- [x] #cookie tag support in UPlanet_IA_Responder.sh
- [x] Basic workflow execution engine (cookie_workflow_engine.sh)
- [x] Node drag-and-drop interface
- [x] Node configuration modals
- [x] Visual connection lines between nodes
- [x] API route `/n8n`

### 🚧 In Progress

- [ ] Variable substitution in node parameters
- [ ] Dependency resolution for node execution
- [ ] Error handling and retry logic
- [ ] Execution result visualization

### ❌ Not Started

- [ ] Scheduled workflow triggers (cron)
- [ ] Event-based workflow triggers
- [ ] All node types fully implemented
- [ ] Workflow sharing mechanism
- [ ] Workflow templates library
- [ ] Execution history and logs
- [ ] BRO command integration (#cookie as built-in command)

---

## 🔧 Core Functionality Improvements

### 1. Variable Substitution System

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Implement variable substitution in node parameters
  - Support `{variable_name}` syntax in prompts, templates, etc.
  - Track variable outputs from each node
  - Pass variables to connected nodes
- [ ] Add variable preview in node configuration
- [ ] Validate variable references before execution
- [ ] Support nested variables (e.g., `{video.title}`)

**Example**:
```json
{
  "type": "ai_question",
  "parameters": {
    "prompt": "Summarize this video: {video_title}\nURL: {video_url}"
}
```

### 2. Dependency Resolution & Parallel Execution

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Build dependency graph from workflow connections
- [ ] Execute nodes in correct order (respecting dependencies)
- [ ] Support parallel execution of independent nodes
- [ ] Handle circular dependencies (detect and error)
- [ ] Optimize execution order for performance

**Current Limitation**: Nodes execute sequentially in array order, ignoring connections.

### 3. Complete Node Type Implementation

**Priority**: MEDIUM  
**Status**: Partially Complete

#### Data Sources

- [x] `cookie_scraper` - ✅ Implemented
- [ ] `nostr_query` - Query NOSTR relay for events
  - [ ] Implement NOSTR query execution
  - [ ] Support filters (kind, author, tags, limit)
  - [ ] Return event array to workflow

#### Processing Nodes

- [x] `ai_question` - ✅ Implemented
- [ ] `image_recognition` - PlantNet recognition
  - [ ] Call `plantnet_recognition.py`
  - [ ] Handle image URL from variables
  - [ ] Return recognition JSON
- [ ] `image_generation` - ComfyUI generation
  - [ ] Call `generate_image.sh`
  - [ ] Support prompt variables
  - [ ] Return generated image URL
- [x] `filter` - ✅ Implemented (basic)
- [ ] `transform` - Data transformation
  - [ ] Implement field mapping
  - [ ] Support JSON, CSV, text formats
  - [ ] Handle nested data structures

#### Output Nodes

- [x] `nostr_publish` - ✅ Implemented (basic)
- [ ] `udrive_save` - Save to uDRIVE
  - [ ] Implement file saving
  - [ ] Support JSON, text, CSV formats
  - [ ] Return saved file path
- [ ] `email_send` - Send email notification
  - [ ] Call `mailjet.sh`
  - [ ] Support email templates
  - [ ] Handle variable substitution in templates

### 4. Error Handling & Retry Logic

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Implement comprehensive error handling
  - [ ] Catch and log node execution errors
  - [ ] Continue workflow execution on non-critical errors
  - [ ] Stop workflow execution on critical errors
- [ ] Add retry logic for transient failures
  - [ ] Configurable retry count per node
  - [ ] Exponential backoff for retries
  - [ ] Skip node after max retries
- [ ] Error reporting to user
  - [ ] Detailed error messages
  - [ ] Node-level error tracking
  - [ ] Execution result with error details

### 5. Workflow Validation

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Validate workflow before saving
  - [ ] Check for required nodes (at least one source, one output)
  - [ ] Validate node connections (output → input only)
  - [ ] Check for circular dependencies
  - [ ] Validate node parameters
- [ ] Validate workflow before execution
  - [ ] Check cookie files exist for cookie_scraper nodes
  - [ ] Verify user has access to required resources
  - [ ] Check workflow ownership
- [ ] Provide validation feedback in UI
  - [ ] Highlight invalid nodes
  - [ ] Show validation errors
  - [ ] Prevent saving invalid workflows

---

## 🚀 Advanced Features

### 6. Scheduled Workflow Triggers

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Implement cron expression parsing
- [ ] Add scheduled workflow execution to `NOSTRCARD.refresh.sh`
  - [ ] Check for workflows with scheduled triggers
  - [ ] Evaluate cron expressions
  - [ ] Execute workflows at scheduled times
- [ ] Support timezone configuration
- [ ] Add execution history tracking
- [ ] Prevent duplicate executions

**Implementation Location**: `Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh`

### 7. Event-Based Workflow Triggers

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Define event trigger conditions
  - [ ] NOSTR event filters (kind, author, tags)
  - [ ] Data conditions (field values)
- [ ] Monitor NOSTR relay for trigger events
- [ ] Execute workflows when conditions met
- [ ] Pass trigger event data to workflow

**Example**: New YouTube video liked → trigger blog generation workflow

### 8. Workflow Templates Library

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Create common workflow templates
  - [ ] YouTube to Blog
  - [ ] Leboncoin Price Alert
  - [ ] Image Recognition → NOSTR Post
  - [ ] Data Scraping → Email Report
- [ ] Add template selection in UI
- [ ] Allow users to customize templates
- [ ] Share popular workflows as templates

### 9. Workflow Sharing & Discovery

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add workflow sharing mechanism
  - [ ] Public/private workflow flag
  - [ ] Workflow discovery interface
  - [ ] Import shared workflows
- [ ] Add workflow ratings/reviews
- [ ] Create workflow marketplace
- [ ] Support workflow forking

### 10. Execution History & Logs

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Store execution history (kind 31902)
- [ ] Display execution logs in UI
  - [ ] Execution status (success/failed/partial)
  - [ ] Node-level execution times
  - [ ] Error messages
  - [ ] Output data preview
- [ ] Add execution statistics
  - [ ] Success rate
  - [ ] Average execution time
  - [ ] Most used nodes
- [ ] Support execution replay/debugging

---

## 🎨 UI/UX Improvements

### 11. Enhanced Node Editor

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Add node search/filter in sidebar
- [ ] Improve node preview (show more details)
- [ ] Add node validation indicators
- [ ] Support node grouping/collapsing
- [ ] Add zoom/pan controls for canvas
- [ ] Improve connection line rendering
- [ ] Add connection validation (type checking)

### 12. Workflow Execution UI

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Add execution progress indicator
  - [ ] Show current executing node
  - [ ] Display execution status per node
  - [ ] Show execution time
- [ ] Real-time execution updates
  - [ ] WebSocket or polling for status
  - [ ] Live node execution visualization
- [ ] Execution result display
  - [ ] Show output data
  - [ ] Display errors
  - [ ] Export execution results

### 13. Workflow Management

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add workflow versioning
- [ ] Support workflow duplication
- [ ] Add workflow tags/categories
- [ ] Implement workflow search
- [ ] Add workflow export/import (JSON)

---

## 🔌 Integration Features

### 14. BRO Command Integration

**Priority**: HIGH  
**Status**: Not Started

**Goal**: Make `#cookie` a built-in BRO command (like `#search`)

**Tasks**:
- [ ] Enhance `#cookie` command in `UPlanet_IA_Responder.sh`
  - [ ] List available workflows if no ID provided
  - [ ] Show workflow details
  - [ ] Support workflow creation via chat
- [ ] Add workflow templates as BRO commands
  - [ ] `#cookie youtube_blog` → Execute YouTube to Blog workflow
  - [ ] `#cookie leboncoin_alert` → Execute Leboncoin alert workflow
- [ ] Create workflow from BRO command
  - [ ] `#cookie create youtube_blog` → Interactive workflow creation
  - [ ] Use AI to suggest workflow structure
- [ ] Workflow execution as article generation
  - [ ] If workflow produces article (kind 30023), format like `#search`
  - [ ] Include workflow metadata in article
  - [ ] Add workflow tags

**Example Integration**:
```
User: #BRO #cookie youtube_blog
Bot: ✅ Executing YouTube to Blog workflow...
     📝 Generated article: [link]
     🎨 Illustration: [image]
     📊 Processed 3 videos from last 7 days
```

### 15. Workflow API Endpoints

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add REST API endpoints in `54321.py`
  - [ ] `GET /api/workflows` - List user workflows
  - [ ] `GET /api/workflows/{id}` - Get workflow details
  - [ ] `POST /api/workflows` - Create workflow
  - [ ] `PUT /api/workflows/{id}` - Update workflow
  - [ ] `DELETE /api/workflows/{id}` - Delete workflow
  - [ ] `POST /api/workflows/{id}/execute` - Execute workflow
- [ ] Add workflow execution status endpoint
- [ ] Support API authentication (NIP-42)

### 16. Workflow Monitoring & Analytics

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Track workflow execution metrics
  - [ ] Execution count
  - [ ] Success/failure rate
  - [ ] Average execution time
  - [ ] Resource usage
- [ ] Add workflow health monitoring
- [ ] Alert on workflow failures
- [ ] Performance optimization suggestions

---

## 📚 Documentation & Testing

### 17. Documentation

**Priority**: MEDIUM  
**Status**: In Progress

**Tasks**:
- [x] Create `docs/N8N.md` - System documentation
- [x] Create `docs/N8N.todo.md` - This file
- [ ] Create user guide
  - [ ] Getting started tutorial
  - [ ] Node type reference
  - [ ] Workflow examples
  - [ ] Troubleshooting guide
- [ ] Create developer guide
  - [ ] Adding new node types
  - [ ] Workflow engine architecture
  - [ ] Testing workflows

### 18. Testing

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Create test workflows
  - [ ] Simple workflow (1 node)
  - [ ] Complex workflow (multiple nodes)
  - [ ] Error handling workflow
- [ ] Add unit tests for workflow engine
- [ ] Add integration tests
- [ ] Test with real cookie scrapers
- [ ] Performance testing

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Basic workflow builder interface
- ✅ Workflow save/load from NOSTR
- ✅ Basic workflow execution
- ✅ #cookie tag support

### Phase 2: Complete Functionality (Next)
- [ ] Variable substitution
- [ ] Dependency resolution
- [ ] All node types implemented
- [ ] Error handling
- [ ] Workflow validation

### Phase 3: Advanced Features
- [ ] Scheduled triggers
- [ ] Event triggers
- [ ] Workflow templates
- [ ] Execution history

### Phase 4: Integration
- [ ] BRO command integration
- [ ] Workflow API
- [ ] Monitoring & analytics

### Phase 5: Production Ready
- [ ] Complete documentation
- [ ] Comprehensive testing
- [ ] Performance optimization
- [ ] User feedback integration

---

## 💡 Future Ideas

- **AI-Powered Workflow Generation**: Use AI to suggest workflow structure based on user goals
- **Workflow Marketplace**: Community-driven workflow sharing and discovery
- **Visual Workflow Debugging**: Step-through execution with data inspection
- **Workflow Version Control**: Git-like versioning for workflows
- **Multi-User Workflows**: Collaborative workflow editing
- **Workflow Scheduling UI**: Visual cron expression builder
- **Workflow Analytics Dashboard**: Visualize workflow performance and usage
- **Mobile Workflow Builder**: Responsive design for mobile devices
- **Workflow Templates from BRO**: Generate workflows from successful BRO commands
- **Automated Workflow Testing**: Test workflows before production use

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: Active Development


## 🎯 Goal

Make the N8N Workflow Builder a **complete, dynamic, and operational** system for programming cookie-based automation workflows. When a workflow model is proven effective, it can be implemented as a new BRO command (like `#search` that generates blog articles).

## 📋 Current Status

### ✅ Completed

- [x] Visual workflow builder interface (n8n.html)
- [x] Basic node types (cookie_scraper, ai_question, filter, nostr_publish)
- [x] Workflow save/load from NOSTR (kind 31900)
- [x] #cookie tag support in UPlanet_IA_Responder.sh
- [x] Basic workflow execution engine (cookie_workflow_engine.sh)
- [x] Node drag-and-drop interface
- [x] Node configuration modals
- [x] Visual connection lines between nodes
- [x] API route `/n8n`

### 🚧 In Progress

- [ ] Variable substitution in node parameters
- [ ] Dependency resolution for node execution
- [ ] Error handling and retry logic
- [ ] Execution result visualization

### ❌ Not Started

- [ ] Scheduled workflow triggers (cron)
- [ ] Event-based workflow triggers
- [ ] All node types fully implemented
- [ ] Workflow sharing mechanism
- [ ] Workflow templates library
- [ ] Execution history and logs
- [ ] BRO command integration (#cookie as built-in command)

---

## 🔧 Core Functionality Improvements

### 1. Variable Substitution System

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Implement variable substitution in node parameters
  - Support `{variable_name}` syntax in prompts, templates, etc.
  - Track variable outputs from each node
  - Pass variables to connected nodes
- [ ] Add variable preview in node configuration
- [ ] Validate variable references before execution
- [ ] Support nested variables (e.g., `{video.title}`)

**Example**:
```json
{
  "type": "ai_question",
  "parameters": {
    "prompt": "Summarize this video: {video_title}\nURL: {video_url}"
}
```

### 2. Dependency Resolution & Parallel Execution

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Build dependency graph from workflow connections
- [ ] Execute nodes in correct order (respecting dependencies)
- [ ] Support parallel execution of independent nodes
- [ ] Handle circular dependencies (detect and error)
- [ ] Optimize execution order for performance

**Current Limitation**: Nodes execute sequentially in array order, ignoring connections.

### 3. Complete Node Type Implementation

**Priority**: MEDIUM  
**Status**: Partially Complete

#### Data Sources

- [x] `cookie_scraper` - ✅ Implemented
- [ ] `nostr_query` - Query NOSTR relay for events
  - [ ] Implement NOSTR query execution
  - [ ] Support filters (kind, author, tags, limit)
  - [ ] Return event array to workflow

#### Processing Nodes

- [x] `ai_question` - ✅ Implemented
- [ ] `image_recognition` - PlantNet recognition
  - [ ] Call `plantnet_recognition.py`
  - [ ] Handle image URL from variables
  - [ ] Return recognition JSON
- [ ] `image_generation` - ComfyUI generation
  - [ ] Call `generate_image.sh`
  - [ ] Support prompt variables
  - [ ] Return generated image URL
- [x] `filter` - ✅ Implemented (basic)
- [ ] `transform` - Data transformation
  - [ ] Implement field mapping
  - [ ] Support JSON, CSV, text formats
  - [ ] Handle nested data structures

#### Output Nodes

- [x] `nostr_publish` - ✅ Implemented (basic)
- [ ] `udrive_save` - Save to uDRIVE
  - [ ] Implement file saving
  - [ ] Support JSON, text, CSV formats
  - [ ] Return saved file path
- [ ] `email_send` - Send email notification
  - [ ] Call `mailjet.sh`
  - [ ] Support email templates
  - [ ] Handle variable substitution in templates

### 4. Error Handling & Retry Logic

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Implement comprehensive error handling
  - [ ] Catch and log node execution errors
  - [ ] Continue workflow execution on non-critical errors
  - [ ] Stop workflow execution on critical errors
- [ ] Add retry logic for transient failures
  - [ ] Configurable retry count per node
  - [ ] Exponential backoff for retries
  - [ ] Skip node after max retries
- [ ] Error reporting to user
  - [ ] Detailed error messages
  - [ ] Node-level error tracking
  - [ ] Execution result with error details

### 5. Workflow Validation

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Validate workflow before saving
  - [ ] Check for required nodes (at least one source, one output)
  - [ ] Validate node connections (output → input only)
  - [ ] Check for circular dependencies
  - [ ] Validate node parameters
- [ ] Validate workflow before execution
  - [ ] Check cookie files exist for cookie_scraper nodes
  - [ ] Verify user has access to required resources
  - [ ] Check workflow ownership
- [ ] Provide validation feedback in UI
  - [ ] Highlight invalid nodes
  - [ ] Show validation errors
  - [ ] Prevent saving invalid workflows

---

## 🚀 Advanced Features

### 6. Scheduled Workflow Triggers

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Implement cron expression parsing
- [ ] Add scheduled workflow execution to `NOSTRCARD.refresh.sh`
  - [ ] Check for workflows with scheduled triggers
  - [ ] Evaluate cron expressions
  - [ ] Execute workflows at scheduled times
- [ ] Support timezone configuration
- [ ] Add execution history tracking
- [ ] Prevent duplicate executions

**Implementation Location**: `Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh`

### 7. Event-Based Workflow Triggers

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Define event trigger conditions
  - [ ] NOSTR event filters (kind, author, tags)
  - [ ] Data conditions (field values)
- [ ] Monitor NOSTR relay for trigger events
- [ ] Execute workflows when conditions met
- [ ] Pass trigger event data to workflow

**Example**: New YouTube video liked → trigger blog generation workflow

### 8. Workflow Templates Library

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Create common workflow templates
  - [ ] YouTube to Blog
  - [ ] Leboncoin Price Alert
  - [ ] Image Recognition → NOSTR Post
  - [ ] Data Scraping → Email Report
- [ ] Add template selection in UI
- [ ] Allow users to customize templates
- [ ] Share popular workflows as templates

### 9. Workflow Sharing & Discovery

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add workflow sharing mechanism
  - [ ] Public/private workflow flag
  - [ ] Workflow discovery interface
  - [ ] Import shared workflows
- [ ] Add workflow ratings/reviews
- [ ] Create workflow marketplace
- [ ] Support workflow forking

### 10. Execution History & Logs

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Store execution history (kind 31902)
- [ ] Display execution logs in UI
  - [ ] Execution status (success/failed/partial)
  - [ ] Node-level execution times
  - [ ] Error messages
  - [ ] Output data preview
- [ ] Add execution statistics
  - [ ] Success rate
  - [ ] Average execution time
  - [ ] Most used nodes
- [ ] Support execution replay/debugging

---

## 🎨 UI/UX Improvements

### 11. Enhanced Node Editor

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Add node search/filter in sidebar
- [ ] Improve node preview (show more details)
- [ ] Add node validation indicators
- [ ] Support node grouping/collapsing
- [ ] Add zoom/pan controls for canvas
- [ ] Improve connection line rendering
- [ ] Add connection validation (type checking)

### 12. Workflow Execution UI

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Add execution progress indicator
  - [ ] Show current executing node
  - [ ] Display execution status per node
  - [ ] Show execution time
- [ ] Real-time execution updates
  - [ ] WebSocket or polling for status
  - [ ] Live node execution visualization
- [ ] Execution result display
  - [ ] Show output data
  - [ ] Display errors
  - [ ] Export execution results

### 13. Workflow Management

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add workflow versioning
- [ ] Support workflow duplication
- [ ] Add workflow tags/categories
- [ ] Implement workflow search
- [ ] Add workflow export/import (JSON)

---

## 🔌 Integration Features

### 14. BRO Command Integration

**Priority**: HIGH  
**Status**: Not Started

**Goal**: Make `#cookie` a built-in BRO command (like `#search`)

**Tasks**:
- [ ] Enhance `#cookie` command in `UPlanet_IA_Responder.sh`
  - [ ] List available workflows if no ID provided
  - [ ] Show workflow details
  - [ ] Support workflow creation via chat
- [ ] Add workflow templates as BRO commands
  - [ ] `#cookie youtube_blog` → Execute YouTube to Blog workflow
  - [ ] `#cookie leboncoin_alert` → Execute Leboncoin alert workflow
- [ ] Create workflow from BRO command
  - [ ] `#cookie create youtube_blog` → Interactive workflow creation
  - [ ] Use AI to suggest workflow structure
- [ ] Workflow execution as article generation
  - [ ] If workflow produces article (kind 30023), format like `#search`
  - [ ] Include workflow metadata in article
  - [ ] Add workflow tags

**Example Integration**:
```
User: #BRO #cookie youtube_blog
Bot: ✅ Executing YouTube to Blog workflow...
     📝 Generated article: [link]
     🎨 Illustration: [image]
     📊 Processed 3 videos from last 7 days
```

### 15. Workflow API Endpoints

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Add REST API endpoints in `54321.py`
  - [ ] `GET /api/workflows` - List user workflows
  - [ ] `GET /api/workflows/{id}` - Get workflow details
  - [ ] `POST /api/workflows` - Create workflow
  - [ ] `PUT /api/workflows/{id}` - Update workflow
  - [ ] `DELETE /api/workflows/{id}` - Delete workflow
  - [ ] `POST /api/workflows/{id}/execute` - Execute workflow
- [ ] Add workflow execution status endpoint
- [ ] Support API authentication (NIP-42)

### 16. Workflow Monitoring & Analytics

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Track workflow execution metrics
  - [ ] Execution count
  - [ ] Success/failure rate
  - [ ] Average execution time
  - [ ] Resource usage
- [ ] Add workflow health monitoring
- [ ] Alert on workflow failures
- [ ] Performance optimization suggestions

---

## 📚 Documentation & Testing

### 17. Documentation

**Priority**: MEDIUM  
**Status**: In Progress

**Tasks**:
- [x] Create `docs/N8N.md` - System documentation
- [x] Create `docs/N8N.todo.md` - This file
- [ ] Create user guide
  - [ ] Getting started tutorial
  - [ ] Node type reference
  - [ ] Workflow examples
  - [ ] Troubleshooting guide
- [ ] Create developer guide
  - [ ] Adding new node types
  - [ ] Workflow engine architecture
  - [ ] Testing workflows

### 18. Testing

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Create test workflows
  - [ ] Simple workflow (1 node)
  - [ ] Complex workflow (multiple nodes)
  - [ ] Error handling workflow
- [ ] Add unit tests for workflow engine
- [ ] Add integration tests
- [ ] Test with real cookie scrapers
- [ ] Performance testing

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Basic workflow builder interface
- ✅ Workflow save/load from NOSTR
- ✅ Basic workflow execution
- ✅ #cookie tag support

### Phase 2: Complete Functionality (Next)
- [ ] Variable substitution
- [ ] Dependency resolution
- [ ] All node types implemented
- [ ] Error handling
- [ ] Workflow validation

### Phase 3: Advanced Features
- [ ] Scheduled triggers
- [ ] Event triggers
- [ ] Workflow templates
- [ ] Execution history

### Phase 4: Integration
- [ ] BRO command integration
- [ ] Workflow API
- [ ] Monitoring & analytics

### Phase 5: Production Ready
- [ ] Complete documentation
- [ ] Comprehensive testing
- [ ] Performance optimization
- [ ] User feedback integration

---

## 💡 Future Ideas

- **AI-Powered Workflow Generation**: Use AI to suggest workflow structure based on user goals
- **Workflow Marketplace**: Community-driven workflow sharing and discovery
- **Visual Workflow Debugging**: Step-through execution with data inspection
- **Workflow Version Control**: Git-like versioning for workflows
- **Multi-User Workflows**: Collaborative workflow editing
- **Workflow Scheduling UI**: Visual cron expression builder
- **Workflow Analytics Dashboard**: Visualize workflow performance and usage
- **Mobile Workflow Builder**: Responsive design for mobile devices
- **Workflow Templates from BRO**: Generate workflows from successful BRO commands
- **Automated Workflow Testing**: Test workflows before production use

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: Active Development

