const { chromium } = require('playwright');

async function browse(url, task) {
  const browser = await chromium.launch({
    headless: true
  });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  });
  const page = await context.newPage();

  try {
    await page.goto(url, {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    // Take screenshot for visual confirmation
    await page.screenshot({
      path: '/tmp/browse-screenshot.png',
      fullPage: false
    });

    // Get full page text
    const text = await page.evaluate(() =>
      document.body.innerText
    );

    // Get all clickable elements
    const buttons = await page.evaluate(() => {
      return Array.from(
        document.querySelectorAll(
          'button, a, input[type="submit"], [role="button"]'
        )
      ).map(el => ({
        text: el.innerText?.trim(),
        type: el.tagName,
        href: el.href || null
      })).filter(el => el.text);
    });

    return { url, text, buttons };

  } finally {
    await browser.close();
  }
}

async function clickButton(url, buttonText) {
  const browser = await chromium.launch({
    headless: true
  });
  const page = await browser.newPage();

  try {
    await page.goto(url, { waitUntil: 'networkidle' });

    // Try multiple selector strategies
    await page.getByText(buttonText, { exact: false })
      .first()
      .click();

    await page.waitForLoadState('networkidle');

    const result = await page.evaluate(() =>
      document.body.innerText
    );

    await page.screenshot({
      path: '/tmp/after-click.png'
    });

    return result;

  } finally {
    await browser.close();
  }
}

async function fillForm(url, fields, submitText) {
  const browser = await chromium.launch({
    headless: true
  });
  const page = await browser.newPage();

  try {
    await page.goto(url, { waitUntil: 'networkidle' });

    // Fill each field
    for (const [selector, value] of Object.entries(fields)) {
      await page.fill(selector, value);
    }

    // Submit
    if (submitText) {
      await page.getByText(submitText, { exact: false })
        .first()
        .click();
      await page.waitForLoadState('networkidle');
    }

    return await page.evaluate(() =>
      document.body.innerText
    );

  } finally {
    await browser.close();
  }
}

// CLI usage
const args = process.argv.slice(2);
if (args[0] === '--browse') {
  browse(args[1]).then(r => {
    console.log('URL:', r.url);
    console.log('Buttons found:', r.buttons.length);
    console.log(r.buttons);
  });
}

module.exports = { browse, clickButton, fillForm };
