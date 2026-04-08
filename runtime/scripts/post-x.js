#!/usr/bin/env node
/**
 * post-x.js — X (Twitter) Automation
 * Uses twitter-api-v2 with readWrite client
 */

require('dotenv').config({ path: `${process.env.HOME}/.openclaw/.env` });
const { TwitterApi } = require('twitter-api-v2');

// Initialize X client with OAuth 1.0a
const client = new TwitterApi({
  appKey: process.env.X_API_KEY,
  appSecret: process.env.X_API_SECRET,
  accessToken: process.env.X_ACCESS_TOKEN,
  accessSecret: process.env.X_ACCESS_TOKEN_SECRET,
});

// Get read-write client
const rwClient = client.readWrite;

/**
 * Post a tweet
 * @param {string} text - Tweet text
 * @returns {Promise<object>} Tweet data
 */
async function postTweet(text) {
  try {
    const tweet = await rwClient.v2.tweet(text);
    console.log('✅ Tweet posted:', tweet.data.id);
    return tweet;
  } catch (error) {
    console.error('❌ Failed to post tweet:', error.message);
    throw error;
  }
}

// Post the launch tweet
const launchTweet = 'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic';

postTweet(launchTweet)
  .then(tweet => {
    console.log('🚀 Launch tweet posted successfully!');
    console.log('Tweet URL:', `https://twitter.com/${process.env.X_ACCOUNT || 'shannon_linnan'}/status/${tweet.data.id}`);
    process.exit(0);
  })
  .catch(err => {
    console.error('Launch failed:', err);
    process.exit(1);
  });
