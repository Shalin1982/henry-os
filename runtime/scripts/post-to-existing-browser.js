#!/usr/bin/env node
/**
 * post-to-existing-browser.js — Post using existing Chrome session
 */

const { chromium } = require('playwright');

const TWEET_TEXT = 'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic';

const REDDIT_TITLE = 'Henry OS — pre-configured OpenClaw chief of staff, 5-min install';
const REDDIT_BODY = `After weeks of refining my OpenClaw setup, I packaged it into a one-line installer.

**Henry OS** deploys a complete AI chief of staff with 7 agents, Mission Control dashboard, smart model routing, and security hardening.

**Install:**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/Shalin1982/henry-os/main/install.sh | bash
\`\`\`

**Repo:** https://github.com/Shalin1982/henry-os

Questions welcome!`;

async function postToX() {
  console.log('🐦 Posting to X...');
  
  // Connect to existing Chrome
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0];
  const page = context.pages().find(p => p.url().includes('twitter.com')) || context.pages()[0];
  
  try {
    // Navigate to compose
    await page.goto('https://twitter.com/compose/tweet');
    await page.waitForTimeout(2000);
    
    // Fill tweet
    await page.fill('[data-testid="tweetTextarea_0"]', TWEET_TEXT);
    await page.waitForTimeout(1000);
    
    // Post
    await page.click('[data-testid="tweetButton"]');
    await page.waitForTimeout(3000);
    
    console.log('✅ Posted to X!');
    return true;
  } catch (e) {
    console.error('❌ X Error:', e.message);
    return false;
  }
}

async function postToReddit() {
  console.log('📱 Posting to Reddit...');
  
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0];
  const page = context.pages().find(p => p.url().includes('reddit.com')) || context.pages()[0];
  
  try {
    // Navigate to submit
    await page.goto('https://www.reddit.com/r/OpenClaw/submit');
    await page.waitForTimeout(2000);
    
    // Fill form
    await page.fill('textarea[placeholder="Title"]', REDDIT_TITLE);
    await page.fill('textarea[placeholder="Text (optional)"]', REDDIT_BODY);
    await page.waitForTimeout(1000);
    
    // Post
    await page.click('button:has-text("Post")');
    await page.waitForTimeout(3000);
    
    console.log('✅ Posted to Reddit!');
    return true;
  } catch (e) {
    console.error('❌ Reddit Error:', e.message);
    return false;
  }
}

async function main() {
  console.log('🚀 POSTING HENRY OS LAUNCH\n');
  
  const xResult = await postToX();
  const redditResult = await postToReddit();
  
  console.log('\n📊 RESULTS:');
  console.log(`X: ${xResult ? '✅ SUCCESS' : '❌ FAILED'}`);
  console.log(`Reddit: ${redditResult ? '✅ SUCCESS' : '❌ FAILED'}`);
}

main();
