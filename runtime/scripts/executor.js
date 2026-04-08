#!/usr/bin/env node
// ============================================================
// HENRY SHELL EXECUTOR — executor.js
// ============================================================
// Local-only API server that lets Claude drive your machine
// without needing you to paste commands in Terminal.
//
// Binds to 127.0.0.1 ONLY — never exposed externally.
// All commands are logged to ~/.openclaw/logs/executor.log
//
// Start: node ~/.openclaw/scripts/executor.js
// ============================================================

const http = require('http');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const PORT = 7777;
const HOST = '0.0.0.0';
const LOG_FILE = path.join(os.homedir(), '.openclaw', 'logs', 'executor.log');
// Token stored in henry-os repo so Claude can read it via the mounted directory
const TOKEN_FILE = path.join(os.homedir(), 'projects', 'henry-os', 'executor.token');

// ── Auth token ───────────────────────────────────────────
function getOrCreateToken() {
  try {
    return fs.readFileSync(TOKEN_FILE, 'utf8').trim();
  } catch {
    const token = crypto.randomBytes(32).toString('hex');
    fs.mkdirSync(path.dirname(TOKEN_FILE), { recursive: true });
    fs.writeFileSync(TOKEN_FILE, token, { mode: 0o600 });
    return token;
  }
}

const AUTH_TOKEN = getOrCreateToken();

// ── Logging ──────────────────────────────────────────────
function log(entry) {
  const line = `[${new Date().toISOString()}] ${entry}\n`;
  fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
  fs.appendFileSync(LOG_FILE, line);
  process.stdout.write(line);
}

// ── Request handler ──────────────────────────────────────
const server = http.createServer((req, res) => {
  // CORS headers (localhost only)
  res.setHeader('Access-Control-Allow-Origin', 'http://localhost:3333');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', pid: process.pid }));
    return;
  }

  // Execute command
  if (req.method === 'POST' && req.url === '/exec') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      let parsed;
      try {
        parsed = JSON.parse(body);
      } catch {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
        return;
      }

      const { command, token, cwd } = parsed;

      // Auth check
      if (!token || token !== AUTH_TOKEN) {
        log(`AUTH FAILED — attempted: ${command?.substring(0, 50)}`);
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Unauthorized' }));
        return;
      }

      // Block dangerous patterns
      const BLOCKED = [
        /rm\s+-rf\s+\/[^/]/,           // rm -rf /anything-root
        />\s*\/etc\//,                   // write to /etc
        /sudo\s+rm/,                     // sudo rm
        /mkfs/,                          // format disk
        /dd\s+if=.*of=\/dev\//,          // disk write
      ];

      for (const pattern of BLOCKED) {
        if (pattern.test(command)) {
          log(`BLOCKED dangerous command: ${command}`);
          res.writeHead(403, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Command blocked by safety filter', command }));
          return;
        }
      }

      log(`EXEC: ${command}${cwd ? ` (cwd: ${cwd})` : ''}`);

      const options = {
        timeout: 60000,
        cwd: cwd || os.homedir(),
        env: { ...process.env, HOME: os.homedir() },
      };

      exec(command, options, (err, stdout, stderr) => {
        const exitCode = err?.code ?? 0;
        log(`DONE (exit ${exitCode}): ${command.substring(0, 60)}`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: !err || exitCode === 0,
          exitCode,
          stdout: stdout || '',
          stderr: stderr || '',
        }));
      });
    });
    return;
  }

  // Write file
  if (req.method === 'POST' && req.url === '/write') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      let parsed;
      try { parsed = JSON.parse(body); } catch {
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
        return;
      }

      const { token, filePath, content } = parsed;
      if (!token || token !== AUTH_TOKEN) {
        res.writeHead(403);
        res.end(JSON.stringify({ error: 'Unauthorized' }));
        return;
      }

      try {
        const resolved = filePath.replace('~', os.homedir());
        fs.mkdirSync(path.dirname(resolved), { recursive: true });
        fs.writeFileSync(resolved, content);
        log(`WRITE: ${resolved}`);
        res.writeHead(200);
        res.end(JSON.stringify({ success: true }));
      } catch (e) {
        res.writeHead(500);
        res.end(JSON.stringify({ error: String(e) }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, HOST, () => {
  log(`Henry Shell Executor running on ${HOST}:${PORT}`);
  log(`Token stored at: ${TOKEN_FILE}`);
  log(`All commands logged to: ${LOG_FILE}`);
  log('Ready — Claude can now drive your machine autonomously.');
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    log(`Port ${PORT} already in use — executor may already be running`);
    process.exit(0);
  }
  log(`Server error: ${err.message}`);
});
