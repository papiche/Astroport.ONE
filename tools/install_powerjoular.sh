#!/bin/bash
########################################################################
# install_powerjoular.sh
# Install PowerJoular - Power consumption monitoring tool
# https://www.noureddine.org/research/joular/powerjoular
# https://github.com/papiche/powerjoular
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

echo "[install_powerjoular][$(timestamp)] Starting PowerJoular installation" >&2

# Check if PowerJoular is already installed
if command -v powerjoular >/dev/null 2>&1; then
    echo "[install_powerjoular][$(timestamp)] PowerJoular is already installed: $(which powerjoular)" >&2
    echo "[install_powerjoular][$(timestamp)] Skipping installation. Run uninstall first if you want to reinstall." >&2
    exit 0
fi

# Install dependencies (gnat and gprbuild)
echo "[install_powerjoular][$(timestamp)] Checking Ada compiler dependencies..." >&2

if ! command -v gnat >/dev/null 2>&1 || ! command -v gprbuild >/dev/null 2>&1; then
    echo "[install_powerjoular][$(timestamp)] Installing GNAT and GPRBuild..." >&2
    
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu/Raspberry Pi OS
        sudo apt-get update
        sudo apt-get install -y gnat gprbuild
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        sudo dnf install -y fedora-gnat-project-common gprbuild gcc-gnat
    elif command -v yum >/dev/null 2>&1; then
        # RHEL/CentOS (may need EPEL)
        sudo yum install -y gcc-gnat gprbuild || {
            echo "[install_powerjoular][$(timestamp)] ERROR: GNAT not available in default repos. Please install manually." >&2
            exit 1
        }
    else
        echo "[install_powerjoular][$(timestamp)] ERROR: Unsupported package manager. Please install gnat and gprbuild manually." >&2
        exit 1
    fi
else
    echo "[install_powerjoular][$(timestamp)] GNAT and GPRBuild are already installed" >&2
fi

# Clone or update PowerJoular repository
POWERJOULAR_DIR="$HOME/.zen/workspace/powerjoular"

if [[ -d "$POWERJOULAR_DIR" ]]; then
    echo "[install_powerjoular][$(timestamp)] PowerJoular repository exists, updating..." >&2
    cd "$POWERJOULAR_DIR"
    git fetch origin
    git checkout astroport 2>/dev/null || git checkout main 2>/dev/null || git checkout master 2>/dev/null
    git pull origin astroport 2>/dev/null || git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
else
    echo "[install_powerjoular][$(timestamp)] Cloning PowerJoular repository..." >&2
    mkdir -p "$HOME/.zen/workspace"
    cd "$HOME/.zen/workspace"
    git clone --depth 1 --branch astroport https://github.com/papiche/powerjoular.git 2>/dev/null || \
    git clone --depth 1 --branch main https://github.com/papiche/powerjoular.git 2>/dev/null || \
    git clone --depth 1 https://github.com/papiche/powerjoular.git
    cd "$POWERJOULAR_DIR"
fi

# Build PowerJoular
echo "[install_powerjoular][$(timestamp)] Building PowerJoular..." >&2

# Create obj directory if needed
mkdir -p obj

# Build using gprbuild
if command -v gprbuild >/dev/null 2>&1; then
    gprbuild powerjoular.gpr 2>&1 | tee "$HOME/.zen/tmp/powerjoular_build.log" || {
        echo "[install_powerjoular][$(timestamp)] ERROR: Build failed. Check log: $HOME/.zen/tmp/powerjoular_build.log" >&2
        exit 1
    }
else
    # Fallback to gnatmake if gprbuild is not available
    echo "[install_powerjoular][$(timestamp)] WARNING: gprbuild not found, using gnatmake..." >&2
    cd obj
    gnatmake ../src/powerjoular.adb 2>&1 | tee "$HOME/.zen/tmp/powerjoular_build.log" || {
        echo "[install_powerjoular][$(timestamp)] ERROR: Build failed. Check log: $HOME/.zen/tmp/powerjoular_build.log" >&2
        exit 1
    }
    cd ..
fi

# Find the built binary
POWERJOULAR_BINARY=""
if [[ -f "obj/powerjoular" ]]; then
    POWERJOULAR_BINARY="obj/powerjoular"
elif [[ -f "powerjoular" ]]; then
    POWERJOULAR_BINARY="powerjoular"
else
    echo "[install_powerjoular][$(timestamp)] ERROR: PowerJoular binary not found after build" >&2
    exit 1
fi

# Install binary to /usr/local/bin (or /usr/bin if preferred)
echo "[install_powerjoular][$(timestamp)] Installing PowerJoular binary..." >&2
sudo cp "$POWERJOULAR_BINARY" /usr/bin/powerjoular
sudo chmod +x /usr/bin/powerjoular

# Install systemd service if available
if [[ -f "systemd/powerjoular.service" ]]; then
    echo "[install_powerjoular][$(timestamp)] Installing systemd service..." >&2
    sudo cp "systemd/powerjoular.service" /etc/systemd/system/powerjoular.service
    sudo systemctl daemon-reload
    echo "[install_powerjoular][$(timestamp)] PowerJoular systemd service installed" >&2
fi

# Verify installation
if command -v powerjoular >/dev/null 2>&1; then
    echo "[install_powerjoular][$(timestamp)] PowerJoular installed successfully: $(which powerjoular)" >&2
    powerjoular -v 2>&1 | head -1 || true
    echo "[install_powerjoular][$(timestamp)] Installation completed successfully" >&2
    echo "[install_powerjoular][$(timestamp)] Usage: sudo powerjoular (requires root for RAPL access on Linux 5.10+)" >&2
else
    echo "[install_powerjoular][$(timestamp)] ERROR: PowerJoular binary not found in PATH after installation" >&2
    exit 1
fi
