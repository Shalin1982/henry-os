#!/usr/bin/env node
/**
 * auto-post-firefox.js — Use Firefox for X and Reddit
 */

const { firefox } = require('playwright');

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
  }
};

async function postX(email, password) {
  console.log('🐦 X: Launching Firefox...');
  
  const browser = await firefox.launch({ 
    headless: false,
    slowMo: 1000
  });
  
  const page = await browser.newPage();
  
  try {
    await page.goto('https://twitter.com/i/flow/login');
    await page.waitForTimeout(4000);
    
    // Email
    await page.fill('input[autocomplete="username"]', email);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);
    
    // Check for username verification
    const hasUnusual = await page.locator('input[name="text"]').isVisible().catch(() => false);
    if (hasUnusual) {
      await page.fill('input[name="text"]', 'shannon_linnan');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(3000);
    }
    
    // Password
    await page.waitForSelector('input[type="password"]', { timeout: 20000 });
    await page.fill('input[type="password"]', password);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(6000);
    
    // Post
    await page.click('[data-testid="SideNav_NewTweet_Button"]');
    await page.waitForTimeout(2000);
    await page.fill('[data-testid="tweetTextarea_0"]', CONTENT.x);
    await page.waitForTimeout(1000);
    await page.click('[data-testid="tweetButton"]');
    await page.waitForTimeout(5000);
    
    console.log('✅ X: Posted!');
    await browser.close();
    return true;
  } catch (e) {
    console.error('❌ X Error:', e.message);
    await page.screenshot({ path: '/Users/shannonlinnan/.openclaw/x-firefox-error.png' });
    await browser.close();
    return false;
  }
}

async function postReddit(username, password) {
  console.log('📱 Reddit: Launching Firefox...');
  
  const browser = await firefox.launch({ 
    headless: false,
    slowMo: 1000
  });
  
  const page = await browser.newPage();
  
  try {
    // Use old.reddit.com
    await page.goto('https://old.reddit.com/login');
    await page.waitForTimeout(3000);
    
    await page.fill('input[name="user"]', username);
    await page.fill('input[name="passwd"]', password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(5000);
    
    await page.goto('https://old.reddit.com/r/OpenClaw/submit');
    await page.waitForTimeout(3000);
    
    await page.fill('input[name="title"]', CONTENT.reddit.title);
    await page.fill('textarea[name="text"]', CONTENT.reddit.body);
    await page.waitForTimeout(1000);
    await page.click('button[name="submit"]');
    await page.waitForTimeout(5000);
    
    console.log('✅ Reddit: Posted!');
    await browser.close();
    return true;
  } catch (e) {
    console.error('❌ Reddit Error:', e.message);
    await page.screenshot({ path: '/Users/shannonlinnan/.openclaw/reddit-firefox-error.png' });
    await browser.close();
    return false;
  }
}

async function main() {
  require('dotenv').config({ path: `${process.env.HOME}/.openclaw/.env` });
  
  console.log('🚀 FIREFOX LAUNCH\n');
  
  const x = await postX(process.env.X_EMAIL, process.env.X_PASSWORD);
  const reddit = await postReddit(process.env.REDDIT_USERNAME, process.env.REDDIT_PASSWORD);
  
  console.log('\n📊 RESULTS:');
  console.log(`X: ${x ? '✅ SUCCESS' : '❌ FAILED'}`);
  console.log(`Reddit: ${reddit ? '✅ SUCCESS' : '❌ FAILED'}`);
}

main();
