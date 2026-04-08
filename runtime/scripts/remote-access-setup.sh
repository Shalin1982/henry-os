#!/bin/bash
# Remote Mission Control Access via SSH Tunnel + Telegram
# This creates a secure tunnel you can access from anywhere

# ============ OPTION 1: SSH Tunnel (Recommended) ============
# From any computer, run:
# ssh -L 3333:localhost:3333 shannon@your-mac-ip
# Then open http://localhost:3333 on that computer

# ============ OPTION 2: Cloudflare Tunnel (No SSH needed) ============
# Install cloudflared:
# brew install cloudflared

# Create tunnel:
# cloudflared tunnel create henry-remote

# Route traffic:
# cloudflared tunnel route dns henry-remote henry-remote.yourdomain.com

# Config file at ~/.cloudflared/config.yml:
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: YOUR_TUNNEL_ID
 credentials-file: /Users/shannonlinnan/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: henry.yourdomain.com
    service: http://localhost:3333
  - service: http_status:404
EOF

# Start tunnel:
# cloudflared tunnel run henry-remote

# Now access https://henry.yourdomain.com from anywhere
# No SSH needed, works on phone, tablet, any browser

# ============ OPTION 3: Tailscale (Private network) ============
# Install Tailscale on this Mac and your other devices
# They all get private IPs on same network
# Access http://mac-tailscale-ip:3333 from any device

# ============ SECURITY WARNING ============
# Never expose Mission Control to public internet without:
# 1. HTTPS (Cloudflare provides this)
# 2. Authentication (add password protection)
# 3. IP whitelist (if possible)

# Add basic auth to Mission Control:
# npm install http-auth
# Add middleware to server.js
