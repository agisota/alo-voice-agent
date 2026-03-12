#!/usr/bin/env bash
# Start the full Alo Agent stack:
# 1. LiveKit server (dev mode) — OR use LiveKit Cloud
# 2. Python agent backend
# 3. macOS Swift app (build & run)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="$PROJECT_DIR/agent-backend"
SWIFT_DIR="$PROJECT_DIR/AloAgent"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[alo]${NC} $1"; }
ok()  { echo -e "${GREEN}[alo]${NC} $1"; }
err() { echo -e "${RED}[alo]${NC} $1"; }

LIVEKIT_PID=""
AGENT_PID=""

cleanup() {
    log "Shutting down..."
    [ -n "$LIVEKIT_PID" ] && kill "$LIVEKIT_PID" 2>/dev/null || true
    [ -n "$AGENT_PID" ] && kill "$AGENT_PID" 2>/dev/null || true
    exit 0
}
trap cleanup EXIT INT TERM

# Check if using LiveKit Cloud
source "$AGENT_DIR/.env.local" 2>/dev/null || true
if [[ "${LIVEKIT_URL:-}" == wss://* ]]; then
    ok "Using LiveKit Cloud: $LIVEKIT_URL"
else
    # Start local LiveKit server
    log "Starting LiveKit server (dev mode)..."
    if command -v livekit-server &>/dev/null; then
        livekit-server --dev --bind 0.0.0.0 --port 7880 &
        LIVEKIT_PID=$!
        ok "LiveKit server started (PID: $LIVEKIT_PID)"
    else
        err "livekit-server not found. Install: brew install livekit"
        exit 1
    fi
    sleep 2
fi

# Start Python agent
log "Starting agent backend..."
cd "$AGENT_DIR"

if [ ! -d ".venv" ]; then
    log "Creating Python venv..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

python agent.py start &
AGENT_PID=$!
ok "Agent started (PID: $AGENT_PID)"

# Build and run Swift app
log "Building Swift app..."
cd "$SWIFT_DIR"
swift build 2>&1 | tail -5

if [ $? -eq 0 ]; then
    ok "Swift app built successfully"
    log "Launching app..."
    swift run AloAgent &
else
    err "Swift build failed"
fi

log "Stack is running. Press Ctrl+C to stop."
wait
