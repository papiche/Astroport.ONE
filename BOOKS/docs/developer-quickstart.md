# UPlanet Developer Quickstart

> **Get started building UPlanet-compatible applications in minutes**

---

## Prerequisites

- Basic knowledge of bash scripting
- Familiarity with JSON and web technologies
- A UPlanet node running locally (optional for testing)

---

## Step 1: Create Your First #BRO Service

### 1.1 Set Up Project Structure

```bash
# Create your project directory
mkdir my-uplanet-app
cd my-uplanet-app

# Create the standard UPlanet structure
mkdir -p {Documents,Images,Videos,Music,api}
touch manifest.json
```

### 1.2 Create Your Manifest

```json
{
  "name": "MyFirstApp",
  "version": "1.0.0",
  "description": "My first UPlanet-compatible application",
  "tags": ["#BRO", "#demo", "#tutorial"],
  "api": "/api/myapp.sh",
  "author": "Your Name",
  "license": "AGPL-3.0",
  "endpoints": {
    "hello": "/api/hello",
    "status": "/api/status"
  }
}
```

### 1.3 Create Your API

```bash
# Create main API script
cat > api/myapp.sh << 'EOF'
#!/bin/bash

case "$1" in
    "hello")
        echo "Hello from UPlanet!"
        echo "Current time: $(date)"
        echo "User: $(whoami)"
        ;;
    "status")
        echo "Service status: ONLINE"
        echo "Uptime: $(uptime)"
        echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
        ;;
    *)
        echo "Usage: $0 {hello|status}"
        echo "Available endpoints:"
        echo "  hello   - Greet the user"
        echo "  status  - Show service status"
        exit 1
        ;;
esac
