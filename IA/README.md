# 🤖 UPlanet IA Bot System

Welcome to the UPlanet IA Bot System! This is a powerful, multi-functional AI assistant that integrates with the UPlanet geolocated social network. The bot can generate images, videos, music, search the web, and maintain contextual conversations across 12 different memory slots.

## 🌟 Key Features

### 🧠 **12-Slot Memory System**
- **600 messages total**: 12 slots × 50 messages each
- **Contextual conversations**: Each slot maintains separate conversation history
- **Multi-user support**: Each user has their own private memory slots
- **Geolocated memory**: Memories are tied to specific locations and users
- **Access control**: Slots 1-12 reserved for CopyLaRadio sociétaires (ZenCard holders)

### 🎨 **AI Generation Capabilities**
- **Image generation** with ComfyUI
- **Video creation** with Text2Video models
- **Music composition** with AI audio models
- **Text-to-speech** with multiple voices (Pierre, Amélie)

### 🔍 **Information & Media**
- **Web search** with Perplexica
- **YouTube download** with format conversion
- **Image analysis** with LLaVA vision model

## 🚀 Quick Start

### Basic Usage
```
#BRO Hello, how are you?
#BOT What's the weather like?
```

### Memory Management
```
#rec #3 Meeting notes: Discussed Q4 goals
#BRO #3 What were our action items?
#mem #3 Show me the meeting notes
#reset #3 Clear meeting memory
```

## 📋 Complete Command Reference

### 🤖 **Core Bot Commands**

| Command | Description | Example |
|---------|-------------|---------|
| `#BRO` | Activate bot with question | `#BRO What's the capital of France?` |
| `#BOT` | Alternative bot activation | `#BOT Tell me a joke` |

### 🧠 **Memory Management**

| Command | Description | Example | Access |
|---------|-------------|---------|---------|
| `#rec` | Record message in memory | `#rec #3 Meeting notes` | All users |
| `#rec #N` | Record in specific slot (1-12) | `#rec #5 Personal reminder` | Sociétaires only |
| `#rec2` | Auto-record bot response | `#rec2 #3 Ask about meeting` | All users |
| `#rec2 #N` | Auto-record bot response in slot | `#rec2 #5 Ask for reminder` | Sociétaires only |
| `#mem` | Show slot 0 memory | `#mem` | All users |
| `#mem #N` | Show specific slot memory | `#mem #3` | Sociétaires only |
| `#reset` | Clear slot 0 | `#reset` | All users |
| `#reset #N` | Clear specific slot | `#reset #3` | Sociétaires only |
| `#reset #all` | Clear all slots (0-12) | `#reset #all` | Sociétaires only |

### 🎨 **AI Generation Commands**

| Command | Description | Example | Access |
|---------|-------------|---------|---------|
| `#image` | Generate image | `#BRO #image A sunset over mountains` | All users |
| `#video` | Generate video | `#BRO #video A cat playing in the garden` | All users |
| `#music` | Generate music | `#BRO #music A peaceful piano melody` | All users |
| `#parole` | Add lyrics to music | `#BRO #music #parole A song about friendship` | All users |
| `#BRO #N` | Use slot context for AI | `#BRO #3 #image Dashboard design` | Sociétaires only |
| `#BOT #N` | Use slot context for AI | `#BOT #5 #music Personal theme` | Sociétaires only |

### 🎤 **Voice Synthesis**

| Command | Description | Example |
|---------|-------------|---------|
| `#pierre` | Generate speech with Pierre voice | `#BRO #pierre Welcome to UPlanet` |
| `#amelie` | Generate speech with Amélie voice | `#BRO #amelie Thank you for visiting` |

### 🔍 **Information & Media**

| Command | Description | Example | Access |
|---------|-------------|---------|---------|
| `#search` | Web search | `#BRO #search Latest AI developments` | All users |
| `#youtube` | Download YouTube video | `#BRO #youtube https://youtube.com/watch?v=...` | All users |
| `#mp3` | Convert YouTube to MP3 | `#BRO #youtube #mp3 https://youtube.com/...` | All users |

### 🔐 **Privacy & Communication**

| Command | Description | Example | Access |
|---------|-------------|---------|---------|
| `#secret` | Send private DM instead of public reply | `#BRO #secret Tell me something private` | All users |
| `#secret #N` | Private DM with slot context | `#BRO #secret #3 Private meeting notes` | Sociétaires only |

## 🏗️ **Technical Architecture**

### **Service Connection Management**

The UPlanet IA system uses a sophisticated connection management architecture that ensures all AI services are available before processing requests. This system is crucial for the bot's functionality and will evolve significantly in production.

#### **Current Architecture (Development)**
- **Ollama** (Port 11434) - Core AI conversations
- **ComfyUI** (Port 8188) - Image/video/music generation  
- **Perplexica** (Port 3001) - Web search
- **Orpheus TTS** (Port 5005) - Text-to-speech

#### **Connection Verification Process**
1. **Ollama verification** (mandatory) - Bot stops if unavailable
2. **Specialized service verification** (on-demand based on tags)
3. **SSH tunnel fallback** to `scorpio.copylaradio.com` if local services unavailable
4. **Error handling** with specific messages per service

#### **Future Architecture (Production UPlanet ẐEN[0])**
All services will migrate to **IPFS P2P connections** via the `DRAGON_p2p_ssh.sh` system:

- **Decentralized discovery** - Each node publishes available services
- **Load balancing** - Automatic selection of best available node
- **Resilience** - No single point of failure
- **Security** - End-to-end encrypted P2P connections

### **File Structure**
```
~/.zen/tmp/flashmem/
├── {user_email}/
│   ├── slot0.json      # General conversations
│   ├── slot1.json      # Work discussions
│   ├── slot2.json      # Personal projects
│   └── ...
└── uplanet_memory/     # Legacy coordinate-based memory
    ├── {coord_key}.json
    └── pubkey/
        └── {pubkey}.json
```

### **Memory File Format**
```json
{
  "user_id": "user@example.com",
  "slot": 3,
  "messages": [
    {
      "timestamp": "2024-01-01T12:00:00Z",
      "event_id": "event123",
      "latitude": "48.86",
      "longitude": "2.22",
      "content": "Meeting notes: Discussed Q4 goals"
    }
  ]
}
```

### **AI Context Loading**
- **Slot-based context**: Last 20 messages from specified slot
- **Fallback**: Legacy pubkey or coordinate-based memory
- **Token optimization**: Limits context to prevent AI token overflow

## 🧠 **Memory System Deep Dive**

### Why 12 Slots?

The 12-slot system allows you to organize conversations by context:

- **Slot 0**: General conversations (default) - **All users**
- **Slot 1**: Work/Professional discussions - **Sociétaires only**
- **Slot 2**: Personal projects - **Sociétaires only**
- **Slot 3**: Meeting notes - **Sociétaires only**
- **Slot 4**: Creative ideas - **Sociétaires only**
- **Slot 5**: Personal reminders - **Sociétaires only**
- **Slot 6**: Technical discussions - **Sociétaires only**
- **Slot 7**: Learning topics - **Sociétaires only**
- **Slot 8**: Travel plans - **Sociétaires only**
- **Slot 9**: Health & wellness - **Sociétaires only**
- **Slot 10**: Financial planning - **Sociétaires only**
- **Slot 11**: Family matters - **Sociétaires only**
- **Slot 12**: Hobbies & interests - **Sociétaires only**

### Memory Recording Types

#### `#rec` vs `#rec2`

- **`#rec`**: Records only the user's message in memory
  ```
  User: #BRO #rec #3 Meeting notes: Discussed Q4 goals
  Bot: Here's a summary of your meeting...
  → Only "Meeting notes: Discussed Q4 goals" is stored in slot 3
  ```

- **`#rec2`**: Automatically records the bot's response in memory
  ```
  User: #BRO #rec2 #3 What were our Q4 goals?
  Bot: Based on our previous discussion, your Q4 goals are...
  → The bot's response is automatically stored in slot 3
  ```

#### **Combined Usage**
```
#rec #3 Meeting notes: Discussed Q4 goals
#BRO #rec2 #3 What were our action items?
#mem #3 Show me both the notes and the bot's response
```

## 🎯 **Best Practices**

### 1. **Organize by Context**
- Use consistent slots for similar topics
- Keep work and personal conversations separate
- Use slot 0 for general chit-chat

### 2. **Effective Memory Usage**
- Record important information immediately with `#rec`
- Use descriptive content for better AI context
- Review memory regularly with `#mem`

### 3. **AI Generation Tips**
- Be specific in your descriptions
- Combine commands: `#BRO #3 #image A modern office space`
- Use context: `#BRO #4 Based on our previous discussion, generate...`

### 4. **Memory Management**
- Reset slots when starting new projects
- Use `#reset #all` sparingly
- Keep important memories in dedicated slots

## 🌍 **Geolocation Integration**

The bot integrates with UPlanet's geolocation system:

- **Location-aware**: Memories are tied to GPS coordinates
- **Local context**: AI can reference location-specific information
- **Community memory**: Shared memories at specific locations

## 🔒 **Privacy & Security**

- **User isolation**: Each user's memory is completely separate
- **Local storage**: All memory files stored locally
- **No cloud sync**: Your conversations stay private
- **Optional sharing**: Choose what to share with the community
- **Access control**: Slots 1-12 protected for CopyLaRadio sociétaires
- **Secure verification**: User status verified via `~/.zen/game/players/` directory
- **Private messaging**: `#secret` tag enables encrypted NOSTR direct messages
- **Event filtering**: Secret messages are rejected from public relay storage

## 🚀 **Advanced Features**

### **Combined Commands**
```
#BRO #3 #image A dashboard based on our meeting requirements
#BOT #5 #music #parole A song about my personal goals
#BRO #search #1 Latest developments in AI for business
```

### **Context Switching**
```
#rec #1 Work meeting about project timeline
#rec #5 Personal: Need to buy groceries
#BRO #1 What's our project deadline?
#BRO #5 What was I supposed to buy?
```

### **Creative Workflows**
```
#rec #4 Art project: Abstract painting series
#BRO #4 #image An abstract painting with blue and gold
#BRO #4 #music Ambient music for the art gallery
#BRO #4 #video A timelapse of the painting process
```

### **Private Communication**
```
#BRO #secret Can you help me with a personal matter?
#BRO #secret #3 Private meeting notes for tomorrow
#BRO #secret #5 Personal reminder about doctor appointment
```

## 🎉 **Why This System is Amazing**

### **1. Unprecedented Context Management**
- **600 total messages** across 12 slots
- **Instant context switching** between topics
- **Persistent memory** across sessions

### **2. Multi-Modal AI Integration**
- **Text, image, video, audio** generation
- **Seamless workflow** between different AI models
- **Context-aware generation** based on conversation history

### **3. Real-World Practicality**
- **Work organization**: Separate slots for different projects
- **Personal management**: Health, finance, family in dedicated slots
- **Creative projects**: Track ideas and generate related content

### **4. Geolocation Intelligence**
- **Location-aware conversations**
- **Community memory** at specific places
- **Local context** for better AI responses

### **5. Privacy-First Design**
- **Local storage** of all memories
- **User isolation** for complete privacy
- **No cloud dependencies**
- **Encrypted private messaging** via NOSTR direct messages
- **Event filtering** prevents secret messages from public storage

## 🔐 **Private Messaging with #secret**

### How It Works

The `#secret` tag enables completely private communication between you and the UPlanet IA Bot:

- **Encrypted delivery**: Messages are sent as NOSTR kind 4 (encrypted direct messages)
- **Private storage**: Secret messages are not stored on public relays
- **User verification**: Uses your NOSTR email (KNAME) for secure delivery
- **Memory integration**: Works with all memory slots and AI generation features

### Usage Examples

#### **Basic Private Communication**
```
#BRO #secret Can you help me with a personal matter?
#BOT #secret Tell me something private about AI
```

#### **Private Memory Operations**
```
#rec #secret #3 Private meeting notes for tomorrow
#mem #secret #5 Show my personal reminders privately
#reset #secret #3 Clear private meeting memory
```

#### **Private AI Generation**
```
#BRO #secret #image A private logo design for my startup
#BOT #secret #music A personal theme song
#BRO #secret #search Private research on sensitive topic
```

### Technical Details

#### **NOSTR Integration**
- **Encryption**: Uses NIP-04 encryption for message privacy
- **Key management**: Automatically retrieves user's hex key from `~/.zen/game/nostr/{KNAME}/HEX`
- **Relay handling**: Sends via configured NOSTR relay with proper error handling
- **Event filtering**: Secret messages return exit code 1 to prevent relay storage

#### **Memory Handling**
- **Auto-recording**: `#rec2` works with secret messages using unique event IDs
- **Context preservation**: Slot-based memory maintains conversation context
- **Error suppression**: Public error messages are suppressed in secret mode

#### **Security Features**
- **No public trace**: Secret messages never appear in public feeds
- **Encrypted content**: All message content is encrypted end-to-end
- **User verification**: Requires valid NOSTR email and hex key
- **Graceful fallback**: Handles missing keys or relay issues gracefully

### Privacy Benefits

1. **Complete confidentiality**: Your private conversations stay private
2. **No public record**: Secret messages don't appear in public UPlanet feeds
3. **Encrypted delivery**: All communication is encrypted using NOSTR standards
4. **Memory privacy**: Private conversations can still use the memory system
5. **AI privacy**: Generate content privately without public exposure

### Best Practices

- **Use for sensitive topics**: Personal matters, confidential work, private ideas
- **Combine with memory slots**: `#secret #3` for private work discussions
- **Maintain context**: Use `#rec2` to automatically save private conversations
- **Verify delivery**: Check your NOSTR client for received messages
- **Respect others**: Only use for legitimate private communication

## 🛠️ **Troubleshooting**

### Common Issues

**Memory not found**
- Check if you're using the correct slot number
- Verify the user ID (email) is correct
- Ensure the memory file exists

**Access denied to slots 1-12**
- Verify you are a CopyLaRadio sociétaire with ZenCard
- Check if your directory exists in `~/.zen/game/players/`
- Use slot 0 for general conversations (accessible to all users)
- Contact CopyLaRadio to become a sociétaire

**AI generation fails**
- Check if required services are running (ComfyUI, Ollama)
- Verify internet connection for web search
- Ensure proper command syntax

**Reset not working**
- Confirm you're using the correct slot number
- Check file permissions in `~/.zen/tmp/flashmem/`
- Verify the user directory exists

**Secret messages not received**
- Verify your NOSTR email (KNAME) is correctly set
- Check if your hex key exists in `~/.zen/game/nostr/{KNAME}/HEX`
- Ensure your NOSTR client is configured to receive direct messages
- Verify the relay connection in `~/.zen/Astroport.ONE/tools/my.sh`

### Getting Help

1. Check the logs: `~/.zen/tmp/IA.log`
2. Verify service status: `./ollama.me.sh`
3. Test individual components: `./test_slot_memory.sh`

## 🎯 **Getting Started Checklist**

- [ ] Send your first message: `#BRO Hello!`
- [ ] Record something: `#rec My first memory` (slot 0)
- [ ] View memory: `#mem`
- [ ] Generate content: `#BRO #image A beautiful landscape`
- [ ] Search web: `#BRO #search Latest technology news`
- [ ] Create music: `#BRO #music A relaxing melody`

**For Sociétaires (slots 1-12):**
- [ ] Record in specific slot: `#rec #3 Meeting notes`
- [ ] View slot memory: `#mem #3`
- [ ] Use context for AI: `#BRO #3 #image Dashboard design`
- [ ] Reset specific slot: `#reset #3`

**For Private Communication:**
- [ ] Send private message: `#BRO #secret Hello, this is private`
- [ ] Private memory operation: `#rec #secret #3 Private notes`
- [ ] Private AI generation: `#BRO #secret #image Private design`
- [ ] Verify NOSTR client receives direct messages

## 📚 **Technical Documentation**

### **Connection Management Architecture**
For detailed information about how the IA system manages service connections, see:
- **[Connection Management Diagram](connection_management_diagram.md)** - Complete technical overview of service connection management, verification processes, and the migration to IPFS P2P architecture

### **Related Documentation**
- **[Astroport.ONE Main README](../README.md)** - Overview of the entire UPlanet ecosystem
- **[Architecture Documentation](../ARCHITECTURE.md)** - Technical system architecture
- **[Legal Framework](../LEGAL.md)** - Cooperative legal structure

---

**Welcome to the future of contextual AI conversations!** 🚀

The UPlanet IA Bot System combines the power of multiple AI models with intelligent memory management to create a truly personalized and contextually aware assistant. Whether you're managing work projects, pursuing creative endeavors, or just having a conversation, the 12-slot memory system ensures that your AI assistant always remembers what matters to you.