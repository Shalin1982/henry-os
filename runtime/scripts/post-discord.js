#!/usr/bin/env node
/**
 * post-discord.js — Discord Webhook Automation
 * Functions: postToDiscord
 */

require('dotenv').config({ path: `${process.env.HOME}/.openclaw/.env` });
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

const WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

if (!WEBHOOK_URL) {
  console.error('❌ DISCORD_WEBHOOK_URL not found in .env');
  process.exit(1);
}

/**
 * Post a message to Discord webhook
 * @param {string} message - Message content (markdown supported)
 * @returns {Promise<object>} Discord response
 */
async function postToDiscord(message) {
  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ content: message }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Discord API error: ${response.status} - ${error}`);
    }

    console.log('✅ Message posted to Discord');
    return { success: true };
  } catch (error) {
    console.error('❌ Failed to post to Discord:', error.message);
    throw error;
  }
}

// CLI handling
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.includes('--test')) {
    // Test mode
    const testMessage = `Henry OS automation test 🦞 
github.com/Shalin1982/henry-os`;
    
    postToDiscord(testMessage)
      .then(() => {
        console.log('🚀 Test message posted to Discord!');
        process.exit(0);
      })
      .catch(err => {
        console.error('Test failed:', err);
        process.exit(1);
      });
  } else if (args[0] === 'post') {
    // Post custom message
    const message = args.slice(1).join(' ');
    if (!message) {
      console.error('Usage: node post-discord.js post <message>');
      process.exit(1);
    }
    postToDiscord(message)
      .then(() => process.exit(0))
      .catch(() => process.exit(1));
  } else {
    console.log('Usage:');
    console.log('  node post-discord.js --test           # Post test message');
    console.log('  node post-discord.js post <message>   # Post custom message');
    console.log('');
    console.log('Library function:');
    console.log('  postToDiscord(message)');
  }
}

module.exports = { postToDiscord };
