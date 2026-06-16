#!/usr/bin/env node
// claude-scraper.js
// Scrapes Claude.ai subscription usage percentage.
// Run modes:
//   node claude-scraper.js login <magic-link-url>   -- first-time setup: navigate magic link, save session
//   node claude-scraper.js scrape                   -- use saved session, return JSON result
//   node claude-scraper.js check                    -- print session status (valid/expired/missing)

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const SESSION_FILE = path.join(process.env.HOME, '.pap-claude-session', 'state.json');
const RESULT_FILE = path.join(process.env.HOME, 'pap-workspace', 'scripts', 'usage', 'last-result.json');
const EMAIL = '{{USER_GMAIL}}';

async function saveSession(context) {
  const state = await context.storageState();
  fs.mkdirSync(path.dirname(SESSION_FILE), { recursive: true });
  fs.writeFileSync(SESSION_FILE, JSON.stringify(state, null, 2));
  console.error('Session saved to', SESSION_FILE);
}

async function sessionExists() {
  return fs.existsSync(SESSION_FILE);
}

async function scrapeUsage(context) {
  const page = await context.newPage();

  // Try settings page first
  await page.goto('https://claude.ai/settings', { waitUntil: 'domcontentloaded', timeout: 15000 });
  await page.waitForTimeout(2000);

  // Check if we're redirected to login (session expired)
  const url = page.url();
  if (url.includes('/login') || url.includes('/auth')) {
    await page.close();
    return { error: 'session_expired', url };
  }

  // Take a screenshot for debugging
  const ssPath = path.join(process.env.HOME, 'pap-workspace', 'scripts', 'usage', 'settings-screenshot.png');
  await page.screenshot({ path: ssPath, fullPage: true });

  // Extract all text that looks like usage info
  const pageText = await page.textContent('body');

  // Look for usage patterns: "X of Y" or "X%" or "used" or quota-related text
  const usagePatterns = [
    /(\d+)%?\s+of\s+(\d+)%?\s+used/i,
    /(\d+)\s*\/\s*(\d+)\s*messages/i,
    /used\s+(\d+)\s+of\s+(\d+)/i,
    /(\d+)%\s+used/i,
  ];

  let usageData = null;
  for (const pattern of usagePatterns) {
    const match = pageText.match(pattern);
    if (match) {
      usageData = { raw: match[0], groups: match.slice(1) };
      break;
    }
  }

  // Also try to find a progress bar or usage element
  const progressBar = await page.$('[role="progressbar"], [aria-valuenow], .usage-bar, [data-usage]');
  let progressValue = null;
  if (progressBar) {
    progressValue = await progressBar.getAttribute('aria-valuenow') ||
                   await progressBar.getAttribute('data-usage');
  }

  // Try the billing page too
  let billingText = null;
  try {
    await page.goto('https://claude.ai/settings/billing', { waitUntil: 'domcontentloaded', timeout: 10000 });
    await page.waitForTimeout(2000);
    billingText = await page.textContent('body');
    const ssPath2 = path.join(process.env.HOME, 'pap-workspace', 'scripts', 'usage', 'billing-screenshot.png');
    await page.screenshot({ path: ssPath2, fullPage: true });
  } catch (e) {
    // billing page may not exist
  }

  await page.close();

  return {
    ts: new Date().toISOString(),
    settingsUrl: url,
    usageData,
    progressValue,
    pageTextSample: pageText.substring(0, 500),
    billingTextSample: billingText ? billingText.substring(0, 500) : null,
    screenshotPath: ssPath,
  };
}

async function doLogin(magicLinkUrl) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.error('Navigating to magic link:', magicLinkUrl);
  await page.goto(magicLinkUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForTimeout(3000);

  const url = page.url();
  console.error('After magic link, URL:', url);

  // Should now be logged in — navigate to verify
  if (!url.includes('/login') && !url.includes('/auth')) {
    await saveSession(context);
    const ssPath = path.join(process.env.HOME, 'pap-workspace', 'scripts', 'usage', 'login-success.png');
    await page.screenshot({ path: ssPath });
    console.log(JSON.stringify({ status: 'login_success', url, screenshot: ssPath }));
  } else {
    console.log(JSON.stringify({ status: 'login_failed', url }));
  }

  await browser.close();
}

async function doScrape() {
  if (!await sessionExists()) {
    console.log(JSON.stringify({ error: 'no_session', hint: 'Run login mode first' }));
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: true });
  const sessionState = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
  const context = await browser.newContext({ storageState: sessionState });

  const result = await scrapeUsage(context);

  // Save result to disk
  fs.writeFileSync(RESULT_FILE, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));

  await browser.close();
}

async function doCheck() {
  if (!await sessionExists()) {
    console.log(JSON.stringify({ status: 'no_session' }));
    return;
  }
  const state = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
  const cookies = state.cookies || [];
  const sessionCookie = cookies.find(c => c.domain.includes('claude.ai'));
  if (!sessionCookie) {
    console.log(JSON.stringify({ status: 'no_claude_cookie' }));
    return;
  }
  const expires = sessionCookie.expires ? new Date(sessionCookie.expires * 1000) : null;
  console.log(JSON.stringify({
    status: 'session_found',
    cookieCount: cookies.length,
    expires: expires ? expires.toISOString() : 'no expiry',
    expired: expires ? expires < new Date() : false,
  }));
}

const mode = process.argv[2] || 'scrape';
if (mode === 'login') {
  const magicLink = process.argv[3];
  if (!magicLink) {
    console.error('Usage: node claude-scraper.js login <magic-link-url>');
    process.exit(1);
  }
  doLogin(magicLink).catch(e => { console.log(JSON.stringify({ error: e.message })); process.exit(1); });
} else if (mode === 'scrape') {
  doScrape().catch(e => { console.log(JSON.stringify({ error: e.message })); process.exit(1); });
} else if (mode === 'check') {
  doCheck().catch(e => { console.log(JSON.stringify({ error: e.message })); process.exit(1); });
} else {
  console.error('Unknown mode:', mode);
  process.exit(1);
}
