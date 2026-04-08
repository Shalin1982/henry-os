#!/usr/bin/env node
/**
 * social-automation-v2.js — Fixed Social Media Automation
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const STATE_DIR = path.join(process.env.HOME, '.openclaw/social-state');
if (!fs.existsSync(STATE_DIR)) fs.mkdirSync(STATE_DIR, { recursive: true });

async function postToX(email, password, text) {
  console.log('🐦 Posting to X...');
  
  const browser = await chromium.launch({ headless: false, slowMo: 1000 });
  const page = await browser.newPage();
  
  try {
    await page.goto('https://twitter.com/i/flow/login', { timeout: 60000 });
    await page.waitForTimeout(3000);
    
    // Email
    await page.fill('input[autocomplete="username"]', email);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);
    
    // Check for unusual activity
    const unusual = await page.locator('input[name="text"]').isVisible().catch(() => false);
    if (unusual) {
      await page.fill('input[name="text"]', 'shannon_linnan');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(3000);
    }
    
    // Password - try multiple selectors
    await page.waitForSelector('input[type="password"]', { timeout: 10000 });
    await page.fill('input[type="password"]', password);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(5000);
    
    // Post
    await page.click('[data-testid="SideNav_NewTweet_Button"]');
    await page.waitForTimeout(2000);
    await page.fill('[data-testid="tweetTextarea_0"]', text);
    await page.waitForTimeout(1000);
    await page.click('[data-testid="tweetButton"]');
    await page.waitForTimeout(5000);
    
    console.log('✅ Posted to X!');
    await browser.close();
    return { success: true };
    
  } catch (error) {
    console.error('❌ X Error:', error.message);
    await page.screenshot({ path: `${STATE_DIR}/x-error.png` });
    await browser.close();
    throw error;
  }
}

async function postToReddit(username, password, subreddit, title, body) {
  console.log(`📱 Posting to Reddit r/${subreddit}...`);
  
  const browser = await chromium.launch({ headless: false, slowMo: 1000 });
  const page = await browser.newPage();
  
  try {
    // Go to Reddit login first
    await page.goto('https://www.reddit.com/login/', { timeout: 60000 });
    await page.waitForTimeout(3000);
    
    // Fill login form
    await page.fill('input[name="username"]', username);
    await page.fill('input[name="password"]', password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(5000);
    
    // Go to submit page
    await page.goto(`https://www.reddit.com/r/${subreddit}/submit`, { timeout: 60000 });
    await page.waitForTimeout(3000);
    
    // Fill post
    await page.fill('textarea[placeholder="Title"]', title);
    await page.fill('textarea[placeholder="Text (optional)"]', body);
    await page.waitForTimeout(1000);
    await page.click('button:has-text("Post")');
    await page.waitForTimeout(5000);
    
    console.log('✅ Posted to Reddit!');
    await browser.close();
    return { success: true };
    
  } catch (error) {
    console.error('❌ Reddit Error:', error.message);
    await page.screenshot({ path: `${STATE_DIR}/reddit-error.png` });
    await browser.close();
    throw error;
  }
}

async function launchHenryOS() {
  console.log('🚀 LAUNCHING HENRY OS\n');
  
  const results = [];
  
  // X
  try {
    await postToX(
      process.env.X_EMAIL,
      process.env.X_PASSWORD,
      'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic'
    );
    results.push({ platform: 'X', status: '✅ SUCCESS' });
  } catch (e) {
    results.push({ platform: 'X', status: '❌ FAILED', error: e.message });
  }
  
  // Reddit
  try {
    await postToReddit(
      process.env.REDDIT_USERNAME,
      process.env.REDDIT_PASSWORD,
      'OpenClaw',
      'Henry OS — pre-configured OpenClaw chief of staff, 5-min install',
      `After weeks of refining my OpenClaw setup, I packaged it into a one-line installer.

**Henry OS** deploys a complete AI chief of staff with 7 agents, Mission Control dashboard, smart model routing, and security hardening.

**Install:**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/Shalin1982/henry-os/main/install.sh | bash
\`\`\`

**Repo:** https://github.com/Shalin1982/henry-os

Questions welcome!`
    );
    results.push({ platform: 'Reddit', status: '✅ SUCCESS' });
  } catch (e) {
    results.push({ platform: 'Reddit', status: '❌ FAILED', error: e.message });
  }
  
  console.log('\n📊 RESULTS:');
  results.forEach(r => console.log(`${r.platform}: ${r.status}`));
  
  return results;
}

require('dotenv').config({ path: `${process.env.HOME}/.openclaw/.env` });
launchHenryOS();
