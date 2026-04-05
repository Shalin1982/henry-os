# Troubleshooting Henry OS

Common issues and their solutions.

## Installation Issues

### "Node.js not found"

The installer should auto-install Node.js. If it fails:

```bash
# macOS
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Fedora
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs
```

Then re-run the installer.

### "Permission denied" when running install.sh

```bash
chmod +x install.sh
./install.sh
```

Or use the curl one-liner which doesn't require local file permissions.

### "npm install -g fails with EACCES"

Fix npm permissions:
```bash
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

## Mission Control Issues

### "Cannot connect to localhost:3333"

1. Check if Mission Control is running:
```bash
ps aux | grep "mission-control"
```

2. If not running, start it manually:
```bash
cd ~/.openclaw/workspace/mission-control
node server.js
```

3. Check for port conflicts:
```bash
lsof -i :3333
```

### "Mission Control shows offline"

Check the state file:
```bash
cat ~/.openclaw/mission-control/state.json
```

If corrupted, delete it and restart Mission Control:
```bash
rm ~/.openclaw/mission-control/state.json
cd ~/.openclaw/workspace/mission-control
node server.js
```

## OpenClaw Issues

### "openclaw command not found"

Ensure npm global bin is in your PATH:
```bash
echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Or reinstall:
```bash
npm install -g openclaw@latest
```

### "Gateway connection refused"

Check gateway configuration:
```bash
cat ~/.openclaw/config/gateway.json
```

Ensure it's bound to 127.0.0.1:
```json
{
  "bind": "127.0.0.1",
  "port": 8080
}
```

## macOS-Specific Issues

### "AppleScript execution failed"

Grant permissions:
1. System Settings → Privacy & Security → Automation
2. Ensure Terminal/iTerm has permission to control Mail, Calendar, Messages

### "Cannot access Mail.app"

Henry needs Full Disk Access:
1. System Settings → Privacy & Security → Full Disk Access
2. Add Terminal/iTerm

## Security Warnings

### "CVE-2026-25253 detected"

Your installation needs security patching:
```bash
curl -fsSL https://raw.githubusercontent.com/henry-os/henry-os/main/security/patch-cve-2026-25253.sh | bash
```

Or manually update your security config:
```bash
cat > ~/.openclaw/config/security.json <<EOF
{
  "websocket": {
    "origin_validation": "strict"
  },
  "cve_patches": {
    "CVE-2026-25253": {
      "patched": true,
      "patch_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
  }
}
EOF
```

## Performance Issues

### "High CPU usage"

Check for runaway processes:
```bash
ps aux | grep openclaw
```

Restart the gateway:
```bash
openclaw gateway restart
```

### "Memory usage growing"

Clear old logs:
```bash
rm -rf ~/.openclaw/logs/*.log
cd ~/.openclaw/workspace/memory
ls -t | tail -n +30 | xargs rm -f  # Keep last 30 days
```

## Reset Everything

**⚠️ Warning: This deletes all data**

```bash
# Stop all processes
pkill -f openclaw
pkill -f "mission-control"

# Delete everything
rm -rf ~/.openclaw

# Reinstall
curl -fsSL https://raw.githubusercontent.com/henry-os/henry-os/main/install.sh | bash
```

## Still Stuck?

1. Check logs: `~/.openclaw/logs/`
2. Run diagnostics: `openclaw doctor`
3. Join Discord: https://discord.gg/openclaw
4. Open an issue: https://github.com/henry-os/henry-os/issues

Include:
- OS version
- Node.js version (`node --version`)
- OpenClaw version (`openclaw --version`)
- Relevant log excerpts
