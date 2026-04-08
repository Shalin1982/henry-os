#!/usr/bin/env node
/**
 * Reddit Browser Automation with Playwright
 * 
 * Functions:
 * - postToSubreddit(subreddit, title, body) — posts to r/subreddit
 * - monitorSubreddits(subreddits[], keywords[]) — scrapes for keywords, saves to state.json
 * 
 * Usage:
 *   node post-reddit-playwright.js --test          # Run test mode (headless: false)
 *   node post-reddit-playwright.js --monitor       # Run monitoring only
 *   node post-reddit-playwright.js --post <subreddit> <title> <body>  # Post to subreddit
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
  headless: !process.argv.includes('--test'),
  screenshotDir: path.join(process.env.HOME, '.openclaw', 'screenshots'),
  stateFile: path.join(process.env.HOME, '.openclaw', 'mission-control', 'state.json'),
  envFile: path.join(process.env.HOME, '.openclaw', '.env'),
  redditUrl: 'https://www.reddit.com',
  timeout: 30000,
};

// Default subreddits to monitor
const DEFAULT_SUBREDDITS = [
  'OpenClaw',
  'SideProject',
  'entrepreneur',
  'freelance',
  'artificial',
  'MachineLearning',
  'ProductivityApps'
];

// Default keywords to monitor
const DEFAULT_KEYWORDS = [
  'openclaw too expensive',
  'openclaw hard to set up',
  'ai assistant setup',
  'automate my business'
];

/**
 * Load credentials from .env file
 */
function loadCredentials() {
  try {
    const envContent = fs.readFileSync(CONFIG.envFile, 'utf8');
    const credentials = {};
    envContent.split('\n').forEach(line => {
      const [key, value] = line.split('=');
      if (key && value) {
        credentials[key.trim()] = value.trim();
      }
    });
    return credentials;
  } catch (error) {
    console.error('Error loading credentials:', error.message);
    throw new Error('Failed to load credentials from .env file');
  }
}

/**
 * Ensure screenshot directory exists
 */
function ensureScreenshotDir() {
  if (!fs.existsSync(CONFIG.screenshotDir)) {
    fs.mkdirSync(CONFIG.screenshotDir, { recursive: true });
  }
}

/**
 * Take screenshot on failure
 */
async function takeScreenshot(page, name) {
  ensureScreenshotDir();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const screenshotPath = path.join(CONFIG.screenshotDir, `${name}-${timestamp}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`Screenshot saved: ${screenshotPath}`);
  return screenshotPath;
}

/**
 * Load or create state.json
 */
function loadState() {
  try {
    if (fs.existsSync(CONFIG.stateFile)) {
      const content = fs.readFileSync(CONFIG.stateFile, 'utf8');
      return JSON.parse(content);
    }
  } catch (error) {
    console.error('Error loading state:', error.message);
  }
  return { leads: [] };
}

/**
 * Save state to state.json
 */
function saveState(state) {
  try {
    const dir = path.dirname(CONFIG.stateFile);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(CONFIG.stateFile, JSON.stringify(state, null, 2));
    console.log('State saved to', CONFIG.stateFile);
  } catch (error) {
    console.error('Error saving state:', error.message);
    throw error;
  }
}

/**
 * Add a lead to state
 */
function addLead(lead) {
  const state = loadState();
  if (!state.leads) {
    state.leads = [];
  }
  
  // Check for duplicates
  const exists = state.leads.some(l => l.url === lead.url);
  if (exists) {
    console.log('Lead already exists:', lead.url);
    return false;
  }
  
  state.leads.push({
    ...lead,
    date: new Date().toISOString(),
    status: 'new'
  });
  
  saveState(state);
  console.log('New lead added:', lead.title);
  return true;
}

/**
 * Login to Reddit
 */
async function loginToReddit(page, credentials) {
  console.log('Navigating to Reddit login...');
  
  await page.goto(`${CONFIG.redditUrl}/login`, { waitUntil: 'networkidle' });
  
  // Wait for login form
  await page.waitForSelector('input[name="username"]', { timeout: CONFIG.timeout });
  
  console.log('Filling in credentials...');
  
  // Fill in username
  await page.fill('input[name="username"]', credentials.REDDIT_USERNAME);
  
  // Fill in password
  await page.fill('input[name="password"]', credentials.REDDIT_PASSWORD);
  
  // Click login button
  await page.click('button[type="submit"]');
  
  // Wait for navigation or error
  try {
    await Promise.race([
      page.waitForSelector('[data-testid="user-menu-button"]', { timeout: CONFIG.timeout }),
      page.waitForSelector('.text-24', { timeout: CONFIG.timeout }), // Error message
      page.waitForURL(/reddit\.com\/?$/, { timeout: CONFIG.timeout })
    ]);
  } catch (error) {
    await takeScreenshot(page, 'login-error');
    throw new Error('Login failed - could not verify successful login');
  }
  
  // Check if we're logged in
  const userMenu = await page.$('[data-testid="user-menu-button"]');
  if (!userMenu) {
    await takeScreenshot(page, 'login-failed');
    throw new Error('Login failed - user menu not found');
  }
  
  console.log('Successfully logged in as', credentials.REDDIT_USERNAME);
}

/**
 * Post to a subreddit
 */
async function postToSubreddit(page, subreddit, title, body) {
  console.log(`Posting to r/${subreddit}...`);
  
  // Navigate to subreddit
  await page.goto(`${CONFIG.redditUrl}/r/${subreddit}/submit`, { waitUntil: 'networkidle' });
  
  // Wait for the post form
  await page.waitForTimeout(2000);
  
  // Try to find and click "Text" tab if it exists
  try {
    const textTab = await page.$('button:has-text("Text")');
    if (textTab) {
      await textTab.click();
      await page.waitForTimeout(500);
    }
  } catch (e) {
    // Text tab might not exist, continue
  }
  
  // Fill in title
  const titleInput = await page.$('[data-testid="title-input"]') || 
                     await page.$('input[placeholder*="title" i]') ||
                     await page.$('textarea[placeholder*="title" i]');
  
  if (!titleInput) {
    await takeScreenshot(page, 'post-form-error');
    throw new Error('Could not find title input field');
  }
  
  await titleInput.fill(title);
  
  // Fill in body
  const bodyInput = await page.$('[data-testid="body-input"]') ||
                    await page.$('textarea[placeholder*="body" i]') ||
                    await page.$('[contenteditable="true"]');
  
  if (bodyInput) {
    await bodyInput.fill(body);
  }
  
  // Submit the post
  const submitButton = await page.$('button[type="submit"]') ||
                       await page.$('button:has-text("Post")') ||
                       await page.$('[data-testid="submit-post-button"]');
  
  if (!submitButton) {
    await takeScreenshot(page, 'submit-button-error');
    throw new Error('Could not find submit button');
  }
  
  await submitButton.click();
  
  // Wait for post to be created
  await page.waitForTimeout(3000);
  
  // Check if we're on the post page or got an error
  const currentUrl = page.url();
  if (currentUrl.includes('/comments/')) {
    console.log('Post created successfully:', currentUrl);
    return { success: true, url: currentUrl };
  }
  
  // Check for error messages
  const errorMessage = await page.$eval('.text-24', el => el.textContent).catch(() => null);
  if (errorMessage) {
    await takeScreenshot(page, 'post-error');
    throw new Error(`Post failed: ${errorMessage}`);
  }
  
  await takeScreenshot(page, 'post-unknown-error');
  throw new Error('Post status unknown - please check manually');
}

/**
 * Scrape a subreddit for keywords
 */
async function scrapeSubreddit(page, subreddit, keywords) {
  console.log(`Scraping r/${subreddit} for keywords...`);
  
  const leads = [];
  const keywordList = Array.isArray(keywords) ? keywords : [keywords];
  
  // Navigate to subreddit
  await page.goto(`${CONFIG.redditUrl}/r/${subreddit}/new`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  
  // Get all posts on the page
  const posts = await page.$$eval('[data-testid="post-container"]', posts => {
    return posts.map(post => {
      const titleEl = post.querySelector('[data-testid="post-title"]') || 
                      post.querySelector('h3') ||
                      post.querySelector('a[href*="/r/"]');
      const linkEl = post.querySelector('a[href*="/r/"]');
      
      return {
        title: titleEl ? titleEl.textContent.trim() : '',
        url: linkEl ? linkEl.href : '',
        text: post.textContent.toLowerCase()
      };
    });
  });
  
  console.log(`Found ${posts.length} posts in r/${subreddit}`);
  
  // Check each post for keywords
  for (const post of posts) {
    for (const keyword of keywordList) {
      const keywordLower = keyword.toLowerCase();
      if (post.text.includes(keywordLower) || post.title.toLowerCase().includes(keywordLower)) {
        leads.push({
          source: `r/${subreddit}`,
          title: post.title,
          url: post.url,
          keyword: keyword,
          date: new Date().toISOString(),
          status: 'new'
        });
        console.log(`  Found match: "${keyword}" in "${post.title.substring(0, 60)}..."`);
        break; // Only add once per post even if multiple keywords match
      }
    }
  }
  
  return leads;
}

/**
 * Monitor multiple subreddits for keywords
 */
async function monitorSubreddits(page, subreddits, keywords) {
  console.log(`Monitoring ${subreddits.length} subreddits for ${keywords.length} keywords...`);
  
  const allLeads = [];
  
  for (const subreddit of subreddits) {
    try {
      const leads = await scrapeSubreddit(page, subreddit, keywords);
      allLeads.push(...leads);
      
      // Add delay between subreddits to be respectful
      if (subreddits.indexOf(subreddit) < subreddits.length - 1) {
        await page.waitForTimeout(2000);
      }
    } catch (error) {
      console.error(`Error scraping r/${subreddit}:`, error.message);
    }
  }
  
  // Save leads to state
  let newLeadsCount = 0;
  for (const lead of allLeads) {
    if (addLead(lead)) {
      newLeadsCount++;
    }
  }
  
  console.log(`\nMonitoring complete. Found ${allLeads.length} matching posts, ${newLeadsCount} new leads added.`);
  return allLeads;
}

/**
 * Run test mode
 */
async function runTest() {
  console.log('=== REDDIT AUTOMATION TEST MODE ===\n');
  console.log('Headless: false (browser will be visible)');
  console.log('This will test login and basic functionality.\n');
  
  const credentials = loadCredentials();
  let browser;
  let page;
  
  try {
    browser = await chromium.launch({ headless: false });
    page = await browser.newPage();
    
    // Test login
    console.log('Testing login...');
    await loginToReddit(page, credentials);
    
    // Take screenshot of logged-in state
    await takeScreenshot(page, 'test-logged-in');
    
    // Test monitoring (just one subreddit for test)
    console.log('\nTesting monitoring functionality...');
    const testSubreddits = ['OpenClaw'];
    const testKeywords = ['openclaw'];
    
    const leads = await monitorSubreddits(page, testSubreddits, testKeywords);
    
    console.log('\n=== TEST COMPLETE ===');
    console.log('Login: SUCCESS');
    console.log(`Monitoring: Found ${leads.length} matching posts`);
    console.log('Browser will close in 5 seconds...');
    
    await page.waitForTimeout(5000);
    
  } catch (error) {
    console.error('\n=== TEST FAILED ===');
    console.error(error.message);
    if (page) {
      await takeScreenshot(page, 'test-failure');
    }
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

/**
 * Run monitoring mode
 */
async function runMonitor() {
  console.log('=== REDDIT MONITORING MODE ===\n');
  console.log('Headless: true (running in background)');
  
  const credentials = loadCredentials();
  let browser;
  let page;
  
  try {
    browser = await chromium.launch({ headless: true });
    page = await browser.newPage();
    
    // Login
    await loginToReddit(page, credentials);
    
    // Monitor all subreddits
    const leads = await monitorSubreddits(page, DEFAULT_SUBREDDITS, DEFAULT_KEYWORDS);
    
    console.log('\n=== MONITORING COMPLETE ===');
    console.log(`Total leads found: ${leads.length}`);
    
  } catch (error) {
    console.error('\n=== MONITORING FAILED ===');
    console.error(error.message);
    if (page) {
      await takeScreenshot(page, 'monitor-failure');
    }
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

/**
 * Run post mode
 */
async function runPost(subreddit, title, body) {
  console.log('=== REDDIT POST MODE ===\n');
  console.log(`Posting to: r/${subreddit}`);
  console.log(`Title: ${title}`);
  
  const credentials = loadCredentials();
  let browser;
  let page;
  
  try {
    browser = await chromium.launch({ headless: CONFIG.headless });
    page = await browser.newPage();
    
    // Login
    await loginToReddit(page, credentials);
    
    // Post
    const result = await postToSubreddit(page, subreddit, title, body);
    
    console.log('\n=== POST COMPLETE ===');
    console.log('Success:', result.success);
    console.log('URL:', result.url);
    
    return result;
    
  } catch (error) {
    console.error('\n=== POST FAILED ===');
    console.error(error.message);
    if (page) {
      await takeScreenshot(page, 'post-failure');
    }
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

/**
 * Main entry point
 */
async function main() {
  const args = process.argv.slice(2);
  
  try {
    if (args.includes('--test')) {
      await runTest();
    } else if (args.includes('--monitor')) {
      await runMonitor();
    } else if (args.includes('--post')) {
      const postIndex = args.indexOf('--post');
      const subreddit = args[postIndex + 1];
      const title = args[postIndex + 2];
      const body = args[postIndex + 3];
      
      if (!subreddit || !title || !body) {
        console.error('Usage: node post-reddit-playwright.js --post <subreddit> <title> <body>');
        process.exit(1);
      }
      
      await runPost(subreddit, title, body);
    } else {
      console.log('Reddit Browser Automation with Playwright');
      console.log('');
      console.log('Usage:');
      console.log('  node post-reddit-playwright.js --test              # Test mode (headless: false)');
      console.log('  node post-reddit-playwright.js --monitor           # Monitor subreddits for keywords');
      console.log('  node post-reddit-playwright.js --post <subreddit> <title> <body>  # Post to subreddit');
      console.log('');
      console.log('Configuration:');
      console.log(`  Credentials: ${CONFIG.envFile}`);
      console.log(`  State file: ${CONFIG.stateFile}`);
      console.log(`  Screenshots: ${CONFIG.screenshotDir}`);
      console.log('');
      console.log('Default subreddits to monitor:');
      DEFAULT_SUBREDDITS.forEach(s => console.log(`  - r/${s}`));
      console.log('');
      console.log('Default keywords:');
      DEFAULT_KEYWORDS.forEach(k => console.log(`  - "${k}"`));
    }
  } catch (error) {
    console.error('\nFatal error:', error.message);
    process.exit(1);
  }
}

// Export functions for use as module
module.exports = {
  postToSubreddit: async (subreddit, title, body) => {
    return runPost(subreddit, title, body);
  },
  monitorSubreddits: async (subreddits, keywords) => {
    const credentials = loadCredentials();
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    
    try {
      await loginToReddit(page, credentials);
      const leads = await monitorSubreddits(page, subreddits || DEFAULT_SUBREDDITS, keywords || DEFAULT_KEYWORDS);
      return leads;
    } finally {
      await browser.close();
    }
  }
};

// Run if called directly
if (require.main === module) {
  main();
}
