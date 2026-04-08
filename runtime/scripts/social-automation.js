#!/usr/bin/env node
/**
 * social-automation.js — Unified Social Media Automation
 * Uses multiple fallback methods for reliability
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const STATE_DIR = path.join(process.env.HOME, '.openclaw/social-state');
if (!fs.existsSync(STATE_DIR)) fs.mkdirSync(STATE_DIR, { recursive: true });

/**
 * Post to X using browser automation with session persistence
 */
async function postToX(email, password, text) {
  console.log('🐦 Posting to X...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 500 });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    storageState: fs.existsSync(`${STATE_DIR}/x-state.json`) ? `${STATE_DIR}/x-state.json` : undefined
  });
  
  const page = await context.newPage();
  
  try {
    // Try to go to home first (if logged in)
    await page.goto('https://twitter.com/home', { timeout: 30000 });
    await page.waitForTimeout(3000);
    
    // Check if we need to login
    const needsLogin = await page.locator('text=Sign in').first().isVisible().catch(() => false);
    
    if (needsLogin) {
      console.log('🔐 Logging in...');
      await page.goto('https://twitter.com/i/flow/login');
      await page.waitForTimeout(2000);
      
      // Enter email
      await page.fill('input[autocomplete="username"]', email);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(2000);
      
      // Check for username verification
      const hasUsernameField = await page.locator('input[name="text"]').isVisible().catch(() => false);
      if (hasUsernameField) {
        await page.fill('input[name="text"]', 'shannon_linnan');
        await page.keyboard.press('Enter');
        await page.waitForTimeout(2000);
      }
      
      // Enter password
      await page.fill('input[type="password"]', password);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(5000);
      
      // Save session
      await context.storageState({ path: `${STATE_DIR}/x-state.json` });
      console.log('✅ Session saved');
    }
    
    // Now post
    console.log('📝 Composing tweet...');
    
    // Click compose button
    await page.click('[data-testid="SideNav_NewTweet_Button"]');
    await page.waitForTimeout(2000);
    
    // Type tweet
    await page.fill('[data-testid="tweetTextarea_0"]', text);
    await page.waitForTimeout(1000);
    
    // Click post
    await page.click('[data-testid="tweetButton"]');
    await page.waitForTimeout(5000);
    
    console.log('✅ Posted to X!');
    
    // Save updated session
    await context.storageState({ path: `${STATE_DIR}/x-state.json` });
    
    await browser.close();
    return { success: true, platform: 'X' };
    
  } catch (error) {
    console.error('❌ X Error:', error.message);
    await page.screenshot({ path: `${STATE_DIR}/x-error.png` });
    await browser.close();
    throw error;
  }
}

/**
 * Post to Discord via webhook
 */
async function postToDiscord(webhookUrl, text) {
  console.log('💬 Posting to Discord...');
  
  const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));
  
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: text })
  });
  
  if (!response.ok) throw new Error(`Discord error: ${response.status}`);
  
  console.log('✅ Posted to Discord!');
  return { success: true, platform: 'Discord' };
}

/**
 * Post to Reddit
 */
async function postToReddit(username, password, subreddit, title, body) {
  console.log(`📱 Posting to Reddit r/${subreddit}...`);
  
  const browser = await chromium.launch({ headless: false, slowMo: 500 });
  const context = await browser.newContext({
    storageState: fs.existsSync(`${STATE_DIR}/reddit-state.json`) ? `${STATE_DIR}/reddit-state.json` : undefined
  });
  
  const page = await context.newPage();
  
  try {
    // Go to subreddit
    await page.goto(`https://www.reddit.com/r/${subreddit}/submit`, { timeout: 60000 });
    await page.waitForTimeout(3000);
    
    // Check if logged in
    const needsLogin = await page.locator('text=Log In').first().isVisible().catch(() => false);
    
    if (needsLogin) {
      console.log('🔐 Logging into Reddit...');
      await page.click('text=Log In');
      await page.waitForTimeout(2000);
      
      // Reddit login iframe
      const frame = page.frameLocator('iframe').first();
      await frame.fill('input[name="username"]', username);
      await frame.fill('input[name="password"]', password);
      await frame.click('button[type="submit"]');
      await page.waitForTimeout(5000);
      
      await context.storageState({ path: `${STATE_DIR}/reddit-state.json` });
    }
    
    // Fill post
    await page.fill('textarea[placeholder="Title"]', title);
    await page.fill('textarea[placeholder="Text (optional)"]', body);
    await page.waitForTimeout(1000);
    
    // Submit
    await page.click('button:has-text("Post")');
    await page.waitForTimeout(5000);
    
    console.log('✅ Posted to Reddit!');
    
    await context.storageState({ path: `${STATE_DIR}/reddit-state.json` });
    await browser.close();
    return { success: true, platform: 'Reddit' };
    
  } catch (error) {
    console.error('❌ Reddit Error:', error.message);
    await page.screenshot({ path: `${STATE_DIR}/reddit-error.png` });
    await browser.close();
    throw error;
  }
}

/**
 * Launch Henry OS to all platforms
 */
async function launchHenryOS() {
  console.log('🚀 LAUNCHING HENRY OS\n');
  
  const results = [];
  
  // Discord (most reliable)
  try {
    const discordWebhook = process.env.DISCORD_WEBHOOK_URL;
    const discordMsg = `🦞 **Henry OS is live!**

Pre-configured OpenClaw chief of staff that deploys in 5 minutes.

✓ Smart model routing (fraction of typical costs)
✓ Mission Control dashboard (16 pages) 
✓ Security hardened (CVE-2026-25253 patched)
✓ Learning loop built in
✓ Resurrection protocol included

GitHub: https://github.com/Shalin1982/henry-os

Built by @shannon_linnan — running my own business on this daily. Feedback welcome! 🙏`;
    
    await postToDiscord(discordWebhook, discordMsg);
    results.push({ platform: 'Discord', status: '✅ SUCCESS' });
  } catch (e) {
    results.push({ platform: 'Discord', status: '❌ FAILED', error: e.message });
  }
  
  // X
  try {
    const xEmail = process.env.X_EMAIL || 'shannon.linnan@gmail.com';
    const xPassword = process.env.X_PASSWORD;
    const xText = 'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic';
    
    if (!xPassword) throw new Error('X_PASSWORD not set');
    
    await postToX(xEmail, xPassword, xText);
    results.push({ platform: 'X', status: '✅ SUCCESS' });
  } catch (e) {
    results.push({ platform: 'X', status: '❌ FAILED', error: e.message });
  }
  
  // Reddit
  try {
    const redditUser = process.env.REDDIT_USERNAME || 'Shalin1982';
    const redditPass = process.env.REDDIT_PASSWORD || process.env.X_PASSWORD;
    const redditTitle = 'Henry OS — pre-configured OpenClaw chief of staff, 5-min install';
    const redditBody = `After weeks of refining my OpenClaw setup, I packaged it into a one-line installer.

**Henry OS** deploys a complete AI chief of staff with 7 agents, Mission Control dashboard, smart model routing, and security hardening.

**Install:**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/Shalin1982/henry-os/main/install.sh | bash
\`\`\`

**Repo:** https://github.com/Shalin1982/henry-os

Questions welcome!`;
    
    await postToReddit(redditUser, redditPass, 'OpenClaw', redditTitle, redditBody);
    results.push({ platform: 'Reddit', status: '✅ SUCCESS' });
  } catch (e) {
    results.push({ platform: 'Reddit', status: '❌ FAILED', error: e.message });
  }
  
  // Report
  console.log('\n📊 LAUNCH RESULTS:');
  console.log('==================');
  results.forEach(r => {
    console.log(`${r.platform}: ${r.status}`);
    if (r.error) console.log(`  Error: ${r.error}`);
  });
  
  return results;
}

// Run if called directly
if (require.main === module) {
  require('dotenv').config({ path: `${process.env.HOME}/.openclaw/.env` });
  
  if (process.argv.includes('--launch')) {
    launchHenryOS().then(() => process.exit(0)).catch(() => process.exit(1));
  } else {
    console.log('Usage: node social-automation.js --launch');
  }
}

module.exports = { postToX, postToDiscord, postToReddit, launchHenryOS };
