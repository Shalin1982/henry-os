#!/usr/bin/env node
/**
 * auto-post.js — Fully automated posting without browser restart
 * Uses Playwright to launch and control browsers independently
 */

const { chromium, firefox, webkit } = require('playwright');

const CONTENT = {
  x: 'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic',
  reddit: {
    title: 'Henry OS — pre-configured OpenClaw chief of staff, 5-min install',
    body: `After weeks of refining my OpenClaw setup, I packaged it into a one-line installer.

**Henry OS** deploys a complete AI chief of staff with 7 agents, Mission Control dashboard, smart model routing, and security hardening.

**Install:**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/Shalin1982/henry-os/main/install.sh | bash
\`\`\`

**Repo:** https://github.com/Shalin1982/henry-os

Questions welcome!`
  },
  linkedin: `Just launched Henry OS 🦞

A pre-configured OpenClaw chief of staff that deploys in 5 minutes.

✓ Smart model routing (fraction of typical costs)
✓ Mission Control dashboard (16 pages)
✓ Security hardened
✓ Learning loop built in

Perfect for automating your business operations.

GitHub: https://github.com/Shalin1982/henry-os

#OpenClaw #AI #Automation #Productivity`
};

async function postX(email, password) {
  console.log('🐦 X: Launching browser...');
  const browser = await chromium.launch({ headless: false, slowMo: 800 });
  const page = await browser.newPage();
  
  try {
    // Login flow
    await page.goto('https://twitter.com/i/flow/login');
    await page.waitForTimeout(3000);
    
    // Email
    await page.fill('input[autocomplete="username"]', email);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);
    
    // Check for username verification
    const hasUnusual = await page.locator('text=Enter your phone number or username').isVisible().catch(() => false);
    if (hasUnusual) {
      await page.fill('input[name="text"]', 'shannon_linnan');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(3000);
    }
    
    // Password - wait and retry
    await page.waitForSelector('input[type="password"]', { timeout: 15000 });
    await page.fill('input[type="password"]', password);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(5000);
    
    // Post
    await page.click('[data-testid="SideNav_NewTweet_Button"]');
    await page.waitForTimeout(2000);
    await page.fill('[data-testid="tweetTextarea_0"]', CONTENT.x);
    await page.waitForTimeout(1000);
    await page.click('[data-testid="tweetButton"]');
    await page.waitForTimeout(4000);
    
    console.log('✅ X: Posted!');
    await browser.close();
    return true;
  } catch (e) {
    console.error('❌ X Error:', e.message);
    await page.screenshot({ path: '/Users/shannonlinnan/.openclaw/x-error.png' });
    await browser.close();
    return false;
  }
}

async function postReddit(username, password) {
  console.log('📱 Reddit: Launching browser...');
  const browser = await chromium.launch({ headless: false, slowMo: 800 });
  const page = await browser.newPage();
  
  try {
    // Login
    await page.goto('https://www.reddit.com/login/');
    await page.waitForTimeout(3000);
    
    // Try different selectors for Reddit login
    const usernameInput = await page.locator('input#loginUsername, input[name="username"], input[placeholder*="username" i]').first();
    await usernameInput.fill(username);
    
    const passwordInput = await page.locator('input#loginPassword, input[name="password"], input[type="password"]').first();
    await passwordInput.fill(password);
    
    await page.click('button[type="submit"], button:has-text("Log In")');
    await page.waitForTimeout(5000);
    
    // Post
    await page.goto('https://www.reddit.com/r/OpenClaw/submit');
    await page.waitForTimeout(3000);
    
    await page.fill('textarea[placeholder="Title"], input[placeholder="Title"]', CONTENT.reddit.title);
    await page.fill('textarea[placeholder="Text (optional)"], textarea[placeholder="Body"]', CONTENT.reddit.body);
    await page.waitForTimeout(1000);
    
    await page.click('button:has-text("Post"), button[type="submit"]');
    await page.waitForTimeout(4000);
    
    console.log('✅ Reddit: Posted!');
    await browser.close();
    return true;
  } catch (e) {
    console.error('❌ Reddit Error:', e.message);
    await page.screenshot({ path: '/Users/shannonlinnan/.openclaw/reddit-error.png' });
    await browser.close();
    return false;
  }
}

async function postLinkedIn(email, password) {
  console.log('💼 LinkedIn: Launching browser...');
  const browser = await chromium.launch({ headless: false, slowMo: 800 });
  const page = await browser.newPage();
  
  try {
    // Login
    await page.goto('https://www.linkedin.com/login');
    await page.waitForTimeout(2000);
    
    await page.fill('input#username', email);
    await page.fill('input#password', password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(5000);
    
    // Click start post
    await page.click('button:has-text("Start a post")');
    await page.waitForTimeout(2000);
    
    // Fill post
    await page.fill('div[contenteditable="true"]', CONTENT.linkedin);
    await page.waitForTimeout(1000);
    
    // Post
    await page.click('button:has-text("Post")');
    await page.waitForTimeout(4000);
    
    console.log('✅ LinkedIn: Posted!');
    await browser.close();
    return true;
  } catch (e) {
    console.error('❌ LinkedIn Error:', e.message);
    await page.screenshot({ path: '/Users/shannonlinnan/.openclaw/linkedin-error.png' });
    await browser.close();
    return false;
  }
}

async function launchAll() {
  require('dotenv').config({ path: `${process.env.HOME}/.openclaw/.env` });
  
  console.log('🚀 HENRY OS FULL LAUNCH\n');
  
  const results = [];
  
  // X
  if (process.env.X_EMAIL && process.env.X_PASSWORD) {
    const x = await postX(process.env.X_EMAIL, process.env.X_PASSWORD);
    results.push({ platform: 'X', success: x });
  }
  
  // Reddit
  if (process.env.REDDIT_USERNAME && process.env.REDDIT_PASSWORD) {
    const reddit = await postReddit(process.env.REDDIT_USERNAME, process.env.REDDIT_PASSWORD);
    results.push({ platform: 'Reddit', success: reddit });
  }
  
  // LinkedIn
  if (process.env.LINKEDIN_EMAIL && process.env.LINKEDIN_PASSWORD) {
    const linkedin = await postLinkedIn(process.env.LINKEDIN_EMAIL, process.env.LINKEDIN_PASSWORD);
    results.push({ platform: 'LinkedIn', success: linkedin });
  }
  
  console.log('\n📊 RESULTS:');
  results.forEach(r => console.log(`${r.platform}: ${r.success ? '✅ SUCCESS' : '❌ FAILED'}`));
}

launchAll();
