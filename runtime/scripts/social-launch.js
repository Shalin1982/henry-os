#!/usr/bin/env node
/**
 * social-launch.js — Launch using existing browser sessions
 * Opens browsers and guides through posting
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

async function openXCompose() {
  console.log('🐦 Opening X compose window...');
  
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  
  // Open compose directly - if logged in, it works. If not, user logs in manually
  await page.goto('https://twitter.com/compose/tweet');
  
  console.log('✅ X compose window opened');
  console.log('📝 Tweet text (copied to clipboard):');
  console.log(TWEET_TEXT);
  
  // Try to pre-fill if possible
  try {
    await page.waitForTimeout(3000);
    const composeBox = await page.locator('[data-testid="tweetTextarea_0"]').isVisible().catch(() => false);
    if (composeBox) {
      await page.fill('[data-testid="tweetTextarea_0"]', TWEET_TEXT);
      console.log('✅ Tweet text pre-filled! Just click Post.');
    } else {
      console.log('⚠️ Please log in, then run this script again');
    }
  } catch (e) {
    console.log('⚠️ Please log in to X manually in the opened window');
  }
  
  return browser;
}

async function openRedditSubmit() {
  console.log('📱 Opening Reddit submit window...');
  
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  
  await page.goto('https://www.reddit.com/r/OpenClaw/submit');
  
  console.log('✅ Reddit submit window opened');
  console.log('📝 Title (copy this):');
  console.log(REDDIT_TITLE);
  console.log('\n📝 Body (copy this):');
  console.log(REDDIT_BODY);
  
  // Try to pre-fill
  try {
    await page.waitForTimeout(3000);
    await page.fill('textarea[placeholder="Title"]', REDDIT_TITLE);
    await page.fill('textarea[placeholder="Text (optional)"]', REDDIT_BODY);
    console.log('✅ Reddit post pre-filled! Just click Post.');
  } catch (e) {
    console.log('⚠️ Please log in to Reddit manually');
  }
  
  return browser;
}

async function launch() {
  console.log('🚀 HENRY OS LAUNCH\n');
  console.log('Opening browser windows for manual posting...\n');
  
  // Open both
  const xBrowser = await openXCompose();
  const redditBrowser = await openRedditSubmit();
  
  console.log('\n✅ Both windows opened!');
  console.log('1. Post to X (tweet is pre-filled if logged in)');
  console.log('2. Post to Reddit (post is pre-filled if logged in)');
  console.log('\nPress Ctrl+C when done to close browsers');
  
  // Keep running
  await new Promise(() => {});
}

launch();
