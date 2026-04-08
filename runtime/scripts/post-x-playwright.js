#!/usr/bin/env node
/**
 * post-x-playwright.js — X (Twitter) Automation via Browser
 */

const { chromium } = require('playwright');

async function postTweet(text, email, password) {
  console.log('🚀 Starting X browser automation...');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 300 
  });
  
  const page = await browser.newPage();

  try {
    // Go to login
    console.log('🔐 Navigating to login...');
    await page.goto('https://twitter.com/i/flow/login', { timeout: 60000 });
    await page.waitForTimeout(3000);
    
    // Step 1: Enter email
    console.log('👤 Entering email...');
    await page.fill('input[autocomplete="username"]', email);
    await page.waitForTimeout(1000);
    
    // Click Next button (using role)
    await page.getByRole('button', { name: /next/i }).click();
    await page.waitForTimeout(3000);
    
    // Step 2: Check for unusual activity / username verification
    const unusualActivity = await page.locator('text=unusual activity').isVisible().catch(() => false);
    if (unusualActivity) {
      console.log('⚠️ Unusual activity check detected');
      await page.fill('input[name="text"]', 'shannon_linnan');
      await page.getByRole('button', { name: /next/i }).click();
      await page.waitForTimeout(3000);
    }
    
    // Step 3: Enter password
    console.log('🔑 Entering password...');
    await page.fill('input[type="password"]', password);
    await page.waitForTimeout(1000);
    
    // Click Log in
    await page.getByRole('button', { name: /log in/i }).click();
    
    // Wait for home
    console.log('⏳ Waiting for home...');
    await page.waitForSelector('[data-testid="primaryColumn"]', { timeout: 60000 });
    console.log('✅ Logged in!');
    await page.waitForTimeout(3000);
    
    // Click compose
    console.log('📝 Composing tweet...');
    await page.click('[data-testid="SideNav_NewTweet_Button"]');
    await page.waitForTimeout(2000);
    
    // Type tweet
    await page.fill('[data-testid="tweetTextarea_0"]', text);
    await page.waitForTimeout(1500);
    
    // Post
    console.log('🚀 Posting...');
    await page.click('[data-testid="tweetButton"]');
    await page.waitForTimeout(5000);
    
    console.log('✅ Tweet posted!');
    
    await browser.close();
    return { success: true };
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    await page.screenshot({ path: '/Users/shannonlinnan/.openclaw/x-error.png', fullPage: true });
    console.log('📸 Screenshot saved for debugging');
    await browser.close();
    throw error;
  }
}

// Run
const tweet = 'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic';
postTweet(tweet, 'shannon.linnan@gmail.com', 'shanTamlinnan20!6');
