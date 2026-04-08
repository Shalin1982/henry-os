#!/usr/bin/env node
/**
 * monitor-reddit.js — Reddit Monitoring via Playwright
 * Functions: scrapeSubreddit, scrapeSearch
 * Saves leads to state.json
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const STATE_PATH = path.join(process.env.HOME, '.openclaw/mission-control/state.json');

// Subreddits to monitor
const SUBREDDITS = [
  'OpenClaw',
  'SideProject',
  'entrepreneur',
  'freelance',
  'artificial',
  'MachineLearning',
  'ProductivityApps',
];

// Trigger keywords
const KEYWORDS = [
  'openclaw too expensive',
  'openclaw hard to set up',
  'openclaw not working',
  'openclaw tutorial',
  'openclaw setup',
  'ai assistant setup',
  'automate my business',
  'need help with openclaw',
];

/**
 * Load state.json
 */
function loadState() {
  try {
    const data = fs.readFileSync(STATE_PATH, 'utf8');
    return JSON.parse(data);
  } catch {
    return { leads: [] };
  }
}

/**
 * Save state.json
 */
function saveState(state) {
  fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
}

/**
 * Scrape a subreddit for new posts
 * @param {string} subreddit - Subreddit name
 * @param {string[]} keywords - Keywords to match
 * @returns {Promise<Array>} Matching posts
 */
async function scrapeSubreddit(subreddit, keywords) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  });
  const page = await context.newPage();

  try {
    console.log(`🔍 Scraping r/${subreddit}...`);
    await page.goto(`https://www.reddit.com/r/${subreddit}/new/`, { waitUntil: 'networkidle' });
    
    // Wait for posts to load
    await page.waitForSelector('[data-testid="post-container"]', { timeout: 10000 });

    const posts = await page.evaluate((keywords) => {
      const results = [];
      const postElements = document.querySelectorAll('[data-testid="post-container"]');
      
      postElements.forEach(post => {
        const titleEl = post.querySelector('h3, [data-testid="post-title"]');
        const title = titleEl?.textContent?.trim() || '';
        
        const linkEl = post.querySelector('a[href*="/r/"]');
        const url = linkEl?.href || '';
        
        const authorEl = post.querySelector('a[href^="/user/"]');
        const author = authorEl?.textContent?.trim() || '';
        
        const snippetEl = post.querySelector('[data-testid="post-content"]');
        const snippet = snippetEl?.textContent?.trim().substring(0, 200) || '';
        
        // Check if any keyword matches
        const content = (title + ' ' + snippet).toLowerCase();
        const matchedKeyword = keywords.find(kw => content.includes(kw.toLowerCase()));
        
        if (matchedKeyword) {
          results.push({
            title,
            url,
            author,
            snippet,
            keyword: matchedKeyword,
            subreddit: window.location.pathname.split('/')[2],
          });
        }
      });
      
      return results;
    }, keywords);

    console.log(`✅ Found ${posts.length} matching posts in r/${subreddit}`);
    return posts;
  } catch (error) {
    console.error(`❌ Error scraping r/${subreddit}:`, error.message);
    return [];
  } finally {
    await browser.close();
  }
}

/**
 * Scrape Reddit search
 * @param {string} query - Search query
 * @returns {Promise<Array>} Matching posts
 */
async function scrapeSearch(query) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  });
  const page = await context.newPage();

  try {
    console.log(`🔍 Searching Reddit for: "${query}"...`);
    const encodedQuery = encodeURIComponent(query);
    await page.goto(`https://www.reddit.com/search/?q=${encodedQuery}&sort=new`, { waitUntil: 'networkidle' });
    
    await page.waitForSelector('[data-testid="post-container"]', { timeout: 10000 });

    const posts = await page.evaluate(() => {
      const results = [];
      const postElements = document.querySelectorAll('[data-testid="post-container"]');
      
      postElements.forEach(post => {
        const titleEl = post.querySelector('h3, [data-testid="post-title"]');
        const title = titleEl?.textContent?.trim() || '';
        
        const linkEl = post.querySelector('a[href*="/r/"]');
        const url = linkEl?.href || '';
        
        const authorEl = post.querySelector('a[href^="/user/"]');
        const author = authorEl?.textContent?.trim() || '';
        
        const snippetEl = post.querySelector('[data-testid="post-content"]');
        const snippet = snippetEl?.textContent?.trim().substring(0, 200) || '';
        
        results.push({ title, url, author, snippet });
      });
      
      return results;
    });

    console.log(`✅ Found ${posts.length} search results`);
    return posts;
  } catch (error) {
    console.error('❌ Search error:', error.message);
    return [];
  } finally {
    await browser.close();
  }
}

/**
 * Run full monitoring cycle
 */
async function runMonitor() {
  console.log('🚀 Starting Reddit monitoring...\n');
  
  const state = loadState();
  if (!state.leads) state.leads = [];
  
  const allLeads = [];
  
  // Monitor each subreddit
  for (const subreddit of SUBREDDITS) {
    const posts = await scrapeSubreddit(subreddit, KEYWORDS);
    
    for (const post of posts) {
      // Check if already tracked
      const exists = state.leads.find(l => l.url === post.url);
      if (!exists) {
        const lead = {
          source: `r/${post.subreddit}`,
          title: post.title,
          url: post.url,
          author: post.author,
          snippet: post.snippet,
          keyword: post.keyword,
          date: new Date().toISOString(),
          status: 'new',
        };
        allLeads.push(lead);
      }
    }
    
    // Rate limiting
    await new Promise(r => setTimeout(r, 2000));
  }
  
  // Add new leads to state
  if (allLeads.length > 0) {
    state.leads.unshift(...allLeads);
    saveState(state);
    console.log(`\n✅ Saved ${allLeads.length} new leads to state.json`);
  } else {
    console.log('\n✅ No new leads found');
  }
  
  return allLeads;
}

// CLI handling
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.includes('--test')) {
    // Test mode: scrape r/OpenClaw only
    scrapeSubreddit('OpenClaw', KEYWORDS)
      .then(posts => {
        console.log('\n🧪 Test Results:');
        console.log(`Found ${posts.length} posts matching keywords`);
        posts.forEach((p, i) => {
          console.log(`\n${i + 1}. ${p.title}`);
          console.log(`   URL: ${p.url}`);
          console.log(`   Keyword: ${p.keyword}`);
        });
        process.exit(0);
      })
      .catch(err => {
        console.error('Test failed:', err);
        process.exit(1);
      });
  } else if (args[0] === 'search') {
    const query = args.slice(1).join(' ');
    if (!query) {
      console.error('Usage: node monitor-reddit.js search <query>');
      process.exit(1);
    }
    scrapeSearch(query)
      .then(posts => {
        console.log('\nSearch Results:');
        posts.forEach((p, i) => console.log(`${i + 1}. ${p.title}`));
        process.exit(0);
      })
      .catch(() => process.exit(1));
  } else {
    // Full monitoring run
    runMonitor()
      .then(() => process.exit(0))
      .catch(err => {
        console.error('Monitor failed:', err);
        process.exit(1);
      });
  }
}

module.exports = { scrapeSubreddit, scrapeSearch, runMonitor };
