#!/usr/bin/env node
/**
 * post-x-automation.js — X Automation using AppleScript + GUI
 * Most reliable method for macOS
 */

const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

async function postToX(text) {
  console.log('🚀 Starting X automation via Safari...');
  
  const script = `
    tell application "Safari"
      activate
      open location "https://twitter.com/compose/tweet"
      delay 3
    end tell
    
    tell application "System Events"
      tell process "Safari"
        -- Wait for page load
        delay 2
        
        -- Click on tweet text area (try multiple selectors)
        try
          click text area 1 of group 1 of group 1 of group 1 of group 1 of group 2 of group 1 of group 1 of group 1 of group 2 of UI element 1 of scroll area 1 of group 1 of group 1 of group 1 of group 1 of group 1 of group 1 of group 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1
        on error
          -- Fallback: tab to text area
          keystroke tab
          delay 0.5
          keystroke tab
          delay 0.5
        end try
        
        delay 1
        
        -- Type the tweet
        keystroke "${text.replace(/"/g, '\\"').replace(/\n/g, '\\n')}"
        delay 1
        
        -- Press Command+Return to post (or find Post button)
        keystroke return using command down
        
        delay 3
      end tell
    end tell
    
    return "Posted"
  `;
  
  try {
    const { stdout } = await execPromise(`osascript -e '${script}'`);
    console.log('✅ X post completed:', stdout);
    return { success: true };
  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  }
}

// Run
const tweet = 'Henry OS is live 🦞 github.com/Shalin1982/henry-os #OpenClaw #BuildInPublic';
postToX(tweet);
