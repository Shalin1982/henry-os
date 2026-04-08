#!/bin/bash
# Remote Access to Mission Control
# Usage: ./remote-access.sh [start|stop|status]

TUNNEL_PORT=3333
LOCAL_PORT=3333
REMOTE_USER="shannon"
REMOTE_HOST="$(curl -s ifconfig.me)"  # Auto-detect public IP

show_help() {
    echo "Mission Control Remote Access"
    echo ""
    echo "Usage:"
    echo "  ./remote-access.sh start    - Start SSH tunnel"
    echo "  ./remote-access.sh stop     - Stop SSH tunnel"
    echo "  ./remote-access.sh status   - Check status"
    echo ""
    echo "After starting, open: http://localhost:3333"
    echo ""
    echo "Prerequisites:"
    echo "  - SSH access to this Mac enabled"
    echo "  - Port forwarding on router (if accessing from outside)"
}

start_tunnel() {
    echo "Starting SSH tunnel..."
    echo "Your Mac's IP: $REMOTE_HOST"
    echo ""
    echo "From your remote computer, run:"
    echo "  ssh -L 3333:localhost:3333 $REMOTE_USER@$REMOTE_HOST"
    echo ""
    echo "Then open: http://localhost:3333"
    echo ""
    echo "To enable SSH on this Mac:"
    echo "  System Settings → General → Sharing → Remote Login (ON)"
    echo ""
    echo "For external access, forward port 22 on your router to this Mac"
}

stop_tunnel() {
    echo "To stop tunnel, press Ctrl+C on the SSH connection"
}

check_status() {
    echo "Mission Control Status:"
    if curl -s http://localhost:3333 > /dev/null; then
        echo "  ✓ Running on http://localhost:3333"
    else
        echo "  ✗ Not running"
    fi
    
    echo ""
    echo "SSH Status:"
    if sudo systemsetup -getremotelogin | grep -q "On"; then
        echo "  ✓ Remote Login enabled"
    else
        echo "  ✗ Remote Login disabled"
        echo "    Enable: System Settings → General → Sharing → Remote Login"
    fi
    
    echo ""
    echo "Network Info:"
    echo "  Local IP: $(ipconfig getifaddr en0 2>/dev/null || echo 'Not connected')"
    echo "  Public IP: $REMOTE_HOST"
}

case "$1" in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        check_status
        ;;
    *)
        show_help
        ;;
esac
