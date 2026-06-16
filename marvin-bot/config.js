'use strict';
// config.js — All user-specific paths and Discord channel IDs for HELM.
// Every hardcoded path in bot.js is derived from HOME here so HELM can run under any account.
// Override via environment variables or ~/helm-workspace/channels.json (created by helm-init.sh).
const path = require('path');
const fs = require('fs');

const HOME = process.env.HOME || '/Users/{{USER_HOME}}';
const WORKDIR = process.env.HELM_WORKDIR || path.join(HOME, 'helm-workspace');
// __dirname is ~/marvin-bot — avoids hardcoding the bot's own directory
const MARVIN_BOT_DIR = __dirname;
const CLAUDE = process.env.CLAUDE_PATH || path.join(HOME, '.local/bin/claude');
const AGENTS_DIR = process.env.AGENTS_DIR || path.join(HOME, '.claude', 'agents');
const PAP_IMAGES_DIR = process.env.PAP_IMAGES_DIR || path.join(HOME, 'pap-images');
const HELM_CONFIG_DIR = process.env.HELM_CONFIG_DIR || path.join(HOME, 'helm-config');
// Optional channels override file — created by @HELM init for new users.
// Format: { "GUILD_ID": "...", "GENERAL_CHANNEL": "...", "OWNER_ID": "...", ... }
let channelOverrides = {};
const channelsFile = path.join(WORKDIR, 'channels.json');
try {
  if (fs.existsSync(channelsFile)) {
    channelOverrides = JSON.parse(fs.readFileSync(channelsFile, 'utf8'));
  }
} catch {}

function ch(envKey, jsonKey, fallback) {
  return process.env[envKey] || channelOverrides[jsonKey] || fallback;
}

const GITHUB_REPO = process.env.GITHUB_REPO || channelOverrides.GITHUB_REPO || '';
// OWNER_ID must come from env or channels.json — never hardcode {{USER_JERRY}}'s ID (breaks @HELM init for new users)
const OWNER_ID = ch('DISCORD_OWNER_ID', 'OWNER_ID', '');
const OWNER_EMAIL = ch('HELM_OWNER_EMAIL', 'OWNER_EMAIL', '');

const GUILD_ID          = ch('DISCORD_GUILD_ID',          'GUILD_ID',               '');
const GENERAL_CHANNEL   = ch('DISCORD_CHANNEL_GENERAL',   'GENERAL_CHANNEL',         '');
const PAP_STATUS_CHANNEL= ch('DISCORD_CHANNEL_STATUS',    'PAP_STATUS_CHANNEL',      '');
// helm-audit (engineer/system traffic) and helm-improvements (user-facing chat)
// 2026-06-06: pap-improvements→helm-audit, pap-chat→helm-improvements
const PAP_IMPROVEMENTS_CHANNEL = ch('DISCORD_CHANNEL_AUDIT',        'PAP_IMPROVEMENTS_CHANNEL','');
const PAP_AUDIT_CHANNEL        = PAP_IMPROVEMENTS_CHANNEL;
const PAP_CHAT_CHANNEL         = ch('DISCORD_CHANNEL_IMPROVEMENTS',  'PAP_CHAT_CHANNEL',       '');
// 2026-06-10: channel IDs must come from env or channels.json — no hardcoded fallbacks.
// Run @HELM init to populate channels.json after first bot start.
const RECOVERY_CHANNEL         = ch('DISCORD_CHANNEL_RECOVERY',      'RECOVERY_CHANNEL',        '');
// FEEDBACK-CHANNEL-001: #helm-feedback — beta users type feedback here, confirmed before relay
const FEEDBACK_CHANNEL         = ch('DISCORD_CHANNEL_FEEDBACK',      'FEEDBACK_CHANNEL',        '');
const ETF_TRACKER_CHANNEL      = ch('DISCORD_CHANNEL_ETF',           'ETF_TRACKER_CHANNEL',     '');
const OPTIONS_HELPER_CHANNEL      = ch('DISCORD_CHANNEL_OPTIONS',         'OPTIONS_HELPER_CHANNEL',      '');
const TROUBLESHOOTING_CHANNEL     = ch('DISCORD_CHANNEL_TROUBLESHOOTING', 'TROUBLESHOOTING_CHANNEL',      null) || null;
const ENGINEER_CHANNEL            = PAP_IMPROVEMENTS_CHANNEL;
const AGENT_BOARD_CHANNEL         = ch('DISCORD_CHANNEL_AGENT_BOARD',    'AGENT_BOARD_CHANNEL',           '');

module.exports = {
  HOME,
  WORKDIR,
  MARVIN_BOT_DIR,
  CLAUDE,
  AGENTS_DIR,
  PAP_IMAGES_DIR,
  HELM_CONFIG_DIR,
  GITHUB_REPO,
  OWNER_ID,
  OWNER_EMAIL,
  GUILD_ID,
  GENERAL_CHANNEL,
  PAP_STATUS_CHANNEL,
  PAP_IMPROVEMENTS_CHANNEL,
  PAP_AUDIT_CHANNEL,
  PAP_CHAT_CHANNEL,
  RECOVERY_CHANNEL,
  FEEDBACK_CHANNEL,
  ETF_TRACKER_CHANNEL,
  OPTIONS_HELPER_CHANNEL,
  TROUBLESHOOTING_CHANNEL,
  ENGINEER_CHANNEL,
  AGENT_BOARD_CHANNEL,
};
