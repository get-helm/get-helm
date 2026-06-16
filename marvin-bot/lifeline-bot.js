/**
 * HELM Lifeline Bot — backup Discord bot that works even when the main HELM bot is down.
 *
 * Accepts recovery commands via Discord message or slash command.
 * Proxies actions to the local recovery server (port 8080).
 * Runs on the VPS independently of the Mac Mini or main bot.
 *
 * VPS-BRAIN-OPTION-A-001: Claude API call when cascade exhausts all steps (ESCALATE result)
 * VPS-BRAIN-OPTION-B-001: Cold standby mode when Mac heartbeat goes silent >2 min
 */
'use strict';
const { Client, GatewayIntentBits, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle } = require('discord.js');
const http = require('http');
const https = require('https');
const fs = require('fs');

const TOKEN = process.env.LIFELINE_BOT_TOKEN;
const RECOVERY_API = 'http://localhost:8080/api';
const RECOVERY_PASSWORD = process.env.HELM_RECOVERY_PASSWORD || process.env.RECOVERY_PASSWORD || process.env.HELM_RECOVERY_TOKEN || '';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || '';
const LOG_FILE = process.env.HOME ? `${process.env.HOME}/marvin-bot/lifeline-bot.log` : '/var/log/helm-lifeline.log';

// VPS-NTFY-WIRING-001: ntfy topic for push notifications even when Discord is down
const NTFY_TOPIC_FILE = '/opt/pap-health/.ntfy-topic';
let NTFY_TOPIC = null;
try { NTFY_TOPIC = fs.readFileSync(NTFY_TOPIC_FILE, 'utf8').trim(); } catch (_) {}

const ALLOWED_CHANNELS = null; // null = accept in all channels
const RECOVERY_CHANNEL_ID = process.env.RECOVERY_CHANNEL_ID || '1510783392021745756';
const LIFELINE_MSG_KEY = '/tmp/lifeline-pinned-msg.json';

// VPS-BRAIN-OPTION-B-001: heartbeat file written by Mac Mini via Tailscale
const HEARTBEAT_FILE = '/opt/pap-health/last-heartbeat.txt';
const STANDBY_STALE_MS = 2 * 60 * 1000; // 2 min without heartbeat → standby
let standbyMode = false;
let standbyEnteredAt = null;

function log(msg) {
  const line = `[${new Date().toISOString()}] [lifeline-bot] ${msg}\n`;
  process.stdout.write(line);
  try { fs.appendFileSync(LOG_FILE, line); } catch (_) {}
}

// VPS-NTFY-WIRING-001: fire-and-forget ntfy push notification
function ntfyPost(title, message, priority) {
  if (!NTFY_TOPIC) return;
  const body = message || '';
  const req = https.request({
    hostname: 'ntfy.sh',
    path: `/${NTFY_TOPIC}`,
    method: 'POST',
    headers: {
      'Title': title.slice(0, 100),
      'Priority': priority || 'default',
      'Content-Type': 'text/plain',
      'Content-Length': Buffer.byteLength(body),
    },
  }, () => {});
  req.on('error', (e) => log(`ntfy post failed: ${e.message}`));
  req.write(body);
  req.end();
}

function apiCall(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body || {});
    const opts = {
      hostname: 'localhost',
      port: 8080,
      path,
      method: body ? 'POST' : 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-Recovery-Token': RECOVERY_PASSWORD,
        'Content-Length': Buffer.byteLength(data),
      },
    };
    const req = http.request(opts, (res) => {
      let raw = '';
      res.on('data', (c) => { raw += c; });
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(raw) }); }
        catch (_) { resolve({ status: res.statusCode, body: raw }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(data);
    req.end();
  });
}

function pollUntilDone(timeout = 780000) {
  return new Promise((resolve) => {
    const start = Date.now();
    const iv = setInterval(async () => {
      if (Date.now() - start > timeout) {
        clearInterval(iv);
        resolve({ status: 'timeout', result: `no response within ${Math.round(timeout/60000)}min` });
        return;
      }
      try {
        const r = await apiCall('/api/recovery-status');
        if (r.body && r.body.status === 'done') {
          clearInterval(iv);
          resolve(r.body);
        }
      } catch (_) {}
    }, 3000);
  });
}

// Recovery: hand the user a ready-to-paste prompt for any chat AI.
// Subscription-only — no Anthropic API key, no API call ({{USER_JERRY}} directive 2026-06-15).
function callClaudeForRecovery(diagnosticCtx) {
  const uptime = standbyEnteredAt ? `Mac offline for ${Math.round((Date.now() - standbyEnteredAt) / 60000)}min` : 'Mac online';
  return `🧠 **HELM is down and automatic recovery couldn't restore it.**
Copy everything in the block below into Claude (claude.ai) or any chat AI — it will walk you through the fix:

\`\`\`
You are helping me recover my self-hosted HELM bot. The automated recovery cascade ran every step and still could not restart it.

Diagnostic context:
${diagnosticCtx}
Host status: ${uptime}

Tell me, in plain language and under 200 words:
1. What likely happened (2-3 sentences)
2. The single most likely fix to try manually
3. A fallback if that doesn't work
4. When to consider a full power-cycle restart
\`\`\`

Or use a manual recovery command right here: \`!fix\`, \`!restart\`, \`!rollback\`, \`!status\`.`;
}

// Standby chat: subscription-only — no API key. Hand the user a paste-able prompt
// plus the live diagnostic, so they can get help from any chat AI ({{USER_JERRY}} directive 2026-06-15).
function callClaudeStandby(userMessage, conversationHistory) {
  try {
    let recentLog = '';
    try {
      recentLog = fs.readFileSync(LOG_FILE, 'utf8').split('\n').slice(-30).join('\n');
    } catch (_) {}

    const offlineDuration = standbyEnteredAt ? Math.round((Date.now() - standbyEnteredAt) / 60000) : 0;
    return `🧠 **HELM (Mac Mini) is offline (~${offlineDuration} min).** I'm the standby line — I can run recovery commands but can't reach your Mac's files or agents.

Try a command here: \`!fix\` (full recovery), \`!restart\`, \`!rollback\`, \`!status\`.

Want AI help diagnosing it? Copy the block below into Claude (claude.ai) or any chat AI:

\`\`\`
My self-hosted HELM bot (on a Mac Mini) is offline and I can't reach it. My question: ${userMessage}

Recent recovery log:
${recentLog}

Explain what's likely wrong and the most practical fix, under 300 words, plain language.
\`\`\``;
  } catch (e) {
    return `AI call failed: ${e.message}`;
  }
}

const COMMANDS = {
  fix: { action: 'auto_recover', label: 'Fix HELM', emoji: '🛡️', desc: 'Auto-recovery cascade — tries everything until HELM is back (~2-4min)' },
  restart: { action: 'restart_bot', label: 'Restart Bot', emoji: '🔄', desc: 'SSH-restart the main HELM bot (~30s)' },
  rollback: { action: 'rollback', label: 'Roll Back', emoji: '⏪', desc: 'Revert to last good commit and restart (~60s)' },
  status: { action: 'test_ping', label: 'Connection Test', emoji: '📡', desc: 'Check VPS → Mac Mini link' },
};

const HELP_TEXT = `**🛡️ HELM Lifeline Bot — Recovery Commands**

\`!fix\` — One-button recovery (tries everything, escalates to AI if stuck)
\`!restart\` — SSH-restart the main HELM bot (~30s)
\`!rollback\` — Revert to last working version and restart (~60s)
\`!status\` — Test VPS → Mac connection
\`!help\` — Show this message

These commands work even when the main HELM bot is completely silent.`;

async function runCommand(message, cmdKey) {
  const cmd = COMMANDS[cmdKey];
  if (!cmd) {
    await message.reply(HELP_TEXT);
    return;
  }

  const working = await message.reply(`${cmd.emoji} **${cmd.label}** starting… (checking in ~${cmdKey === 'status' ? '5' : '30'}s)`);
  log(`Command: ${cmd.action} requested by ${message.author.tag}`);
  if (cmdKey === 'fix') ntfyPost('🛡️ HELM recovery started', `Fix cascade triggered by ${message.author.tag}`, 'high');

  try {
    const r = await apiCall('/api/recovery-action', { action: cmd.action });
    if (r.body && r.body.error) {
      await working.edit(`❌ Error: ${r.body.error}`);
      return;
    }
    const result = await pollUntilDone();
    const ok = result.result && result.result.startsWith('ok');
    const escalate = result.result && result.result.startsWith('ESCALATE');
    const icon = ok ? '✅' : (escalate ? '🆘' : '⚠️');
    let reply = `${icon} **${cmd.label} complete**\n${result.result || 'no result'}`;

    // VPS-BRAIN-OPTION-A-001: Claude API triage when cascade exhausts
    if (escalate) {
      const diagCtx = [
        `Cascade result: ${result.result}`,
        `Steps attempted: ${result.steps_attempted || 'unknown'}`,
        `Last error: ${result.last_error || 'none reported'}`,
        `Recovery server reachable: yes (responded with status)`,
        `Time elapsed: ${result.elapsed_ms ? Math.round(result.elapsed_ms/1000) + 's' : 'unknown'}`,
      ].join('\n');
      await working.edit(`🆘 **All cascade steps exhausted** — asking Claude for triage...`);
      const aiAdvice = await callClaudeForRecovery(diagCtx);
      reply = `🆘 **Cascade exhausted — AI Assessment:**\n\n${aiAdvice}`;
      ntfyPost('🆘 HELM cascade exhausted', 'Claude API triage posted in Discord', 'urgent');
    }

    await working.edit(reply);
    log(`Command: ${cmd.action} done — ${result.result}`);
    if (ok) ntfyPost('✅ HELM recovery succeeded', result.result || 'ok', 'default');
    else if (!escalate) ntfyPost('⚠️ HELM recovery issue', result.result || 'no result', 'high');
  } catch (e) {
    log(`Command: ${cmd.action} error — ${e.message}`);
    ntfyPost('❌ HELM recovery server unreachable', e.message, 'urgent');
    await working.edit(`❌ Recovery server unreachable: ${e.message}`);
  }
}

if (!TOKEN) {
  log('ERROR: LIFELINE_BOT_TOKEN not set. Exiting.');
  process.exit(1);
}

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// Conversation history per channel for standby mode (Option B)
const standbyHistory = new Map();

client.once('ready', async () => {
  log(`Lifeline bot ready: ${client.user.tag}`);
  await postLifelineButton();
  startHeartbeatWatcher(); // VPS-BRAIN-OPTION-B-001
});

client.on('messageCreate', async (message) => {
  if (message.author.bot) return;
  if (ALLOWED_CHANNELS !== null && !ALLOWED_CHANNELS.includes(message.channelId)) return;

  const rawContent = message.content || '';
  if (!rawContent) { log('WARN: empty message content — MESSAGE_CONTENT intent may be off'); return; }
  const content = rawContent.trim().toLowerCase();

  // Always handle ! commands regardless of standby mode
  if (content.startsWith('!')) {
    const cmd = content.slice(1).split(/\s+/)[0];
    log(`Received command: ${cmd} in channel ${message.channelId} from ${message.author.tag}`);
    await runCommand(message, cmd);
    return;
  }

  // VPS-BRAIN-OPTION-B-001: in standby mode, answer ALL messages in recovery channel
  if (standbyMode && message.channelId === RECOVERY_CHANNEL_ID) {
    log(`Standby mode: routing message from ${message.author.tag} to Claude API`);
    const typing = await message.channel.sendTyping().catch(() => {});
    const history = standbyHistory.get(message.channelId) || [];
    const aiReply = await callClaudeStandby(rawContent, history);
    // Keep rolling window of last 6 messages for context
    history.push({ role: 'user', content: rawContent });
    history.push({ role: 'assistant', content: aiReply });
    if (history.length > 12) history.splice(0, history.length - 12);
    standbyHistory.set(message.channelId, history);
    await message.reply(`🧠 **VPS Brain** (Mac offline):\n${aiReply}`).catch(() => {});
  }
});

client.on('error', (e) => log(`Discord error: ${e.message}`));
client.on('disconnect', () => log('Disconnected from Discord'));

// VPS-BRAIN-OPTION-B-001: poll heartbeat file every 60s; enter/exit standby mode
function startHeartbeatWatcher() {
  setInterval(async () => {
    try {
      let heartbeatAge = Infinity;
      if (fs.existsSync(HEARTBEAT_FILE)) {
        const lastHb = fs.readFileSync(HEARTBEAT_FILE, 'utf8').trim();
        const lastTs = new Date(lastHb).getTime();
        if (!isNaN(lastTs)) heartbeatAge = Date.now() - lastTs;
      }

      if (!standbyMode && heartbeatAge > STANDBY_STALE_MS) {
        // Enter standby mode
        standbyMode = true;
        standbyEnteredAt = Date.now();
        log(`[standby] Mac heartbeat stale (${Math.round(heartbeatAge/1000)}s) — entering standby mode`);
        ntfyPost('🔴 HELM offline — VPS brain active', 'Mac Mini went silent. VPS brain is now answering questions.', 'urgent');
        try {
          const recoveryCh = await client.channels.fetch(RECOVERY_CHANNEL_ID).catch(() => null);
          if (recoveryCh) {
            await recoveryCh.send(`🧠 **VPS Brain active** — Mac Mini has been silent for ${Math.round(heartbeatAge/60000)} min.\n\nI can answer questions and guide recovery. Use \`!fix\` to trigger auto-recovery, or ask me anything.\n\n_I have limited context — I can't access Mac files or run workspace agents._`).catch(() => {});
          }
        } catch (e) { log(`[standby] Discord notify error: ${e.message}`); }
      } else if (standbyMode && heartbeatAge < STANDBY_STALE_MS) {
        // Exit standby mode
        const offlineDuration = standbyEnteredAt ? Math.round((Date.now() - standbyEnteredAt) / 60000) : 0;
        standbyMode = false;
        standbyEnteredAt = null;
        standbyHistory.clear();
        log('[standby] Mac heartbeat restored — exiting standby mode');
        ntfyPost('🟢 HELM restored — handing off', `Mac Mini is back after ${offlineDuration} min offline.`, 'high');
        try {
          const recoveryCh = await client.channels.fetch(RECOVERY_CHANNEL_ID).catch(() => null);
          if (recoveryCh) {
            await recoveryCh.send(`✅ **HELM restored** — Mac Mini is back online after ~${offlineDuration} min. Handing off to main HELM bot.`).catch(() => {});
          }
        } catch (e) { log(`[standby] Discord handoff error: ${e.message}`); }
      }
    } catch (e) { log(`[standby-watcher] error: ${e.message}`); }
  }, 60 * 1000); // check every 60s
}

// Handle button interactions
client.on('interactionCreate', async (interaction) => {
  if (!interaction.isButton()) return;
  if (!['lifeline_fix', 'lifeline_restart', 'lifeline_status'].includes(interaction.customId)) return;

  const cmdMap = { lifeline_fix: 'fix', lifeline_restart: 'restart', lifeline_status: 'status' };
  const cmd = COMMANDS[cmdMap[interaction.customId]];

  await interaction.deferReply({ ephemeral: false }).catch(() => {});
  log(`Button ${interaction.customId} clicked by ${interaction.user.tag}`);
  if (interaction.customId === 'lifeline_fix') ntfyPost('🛡️ HELM recovery started', `Fix button pressed by ${interaction.user.tag}`, 'high');

  try {
    const r = await apiCall('/api/recovery-action', { action: cmd.action });
    if (r.body && r.body.error && r.body.error !== 'action already in progress') {
      await interaction.editReply(`❌ Error: ${r.body.error}`).catch(() => {});
      return;
    }
    if (r.body && r.body.error === 'action already in progress') {
      await interaction.editReply('⚠️ Recovery already in progress — check status channel for live updates.').catch(() => {});
      return;
    }
    const result = await pollUntilDone();
    const ok = result.result && result.result.startsWith('ok');
    const escalate = result.result && result.result.startsWith('ESCALATE');
    const icon = ok ? '✅' : (escalate ? '🆘' : '⚠️');
    let reply = `${icon} **${cmd.label} complete**\n${result.result || 'no result'}`;

    // VPS-BRAIN-OPTION-A-001: Claude API triage on escalation via button too
    if (escalate && interaction.customId === 'lifeline_fix') {
      await interaction.editReply('🆘 **All steps exhausted** — asking Claude for triage...').catch(() => {});
      const diagCtx = [
        `Cascade result: ${result.result}`,
        `Steps attempted: ${result.steps_attempted || 'unknown'}`,
        `Last error: ${result.last_error || 'none reported'}`,
        `Time elapsed: ${result.elapsed_ms ? Math.round(result.elapsed_ms/1000) + 's' : 'unknown'}`,
      ].join('\n');
      const aiAdvice = await callClaudeForRecovery(diagCtx);
      reply = `🆘 **Cascade exhausted — AI Assessment:**\n\n${aiAdvice}`;
      ntfyPost('🆘 HELM cascade exhausted', 'Claude API triage posted in Discord', 'urgent');
    }

    await interaction.editReply(reply).catch(() => {});
    if (interaction.customId === 'lifeline_fix') {
      if (ok) ntfyPost('✅ HELM recovery succeeded', result.result || 'ok', 'default');
      else if (!escalate) ntfyPost('⚠️ HELM recovery issue', result.result || 'no result', 'high');
    }
  } catch (e) {
    if (interaction.customId === 'lifeline_fix') ntfyPost('❌ HELM recovery server unreachable', e.message, 'urgent');
    await interaction.editReply(`❌ Recovery server unreachable: ${e.message}`).catch(() => {});
  }
});

async function postLifelineButton() {
  try {
    let ch = null;
    for (let i = 0; i < 5; i++) {
      ch = await client.channels.fetch(RECOVERY_CHANNEL_ID).catch(() => null);
      if (ch) break;
      await new Promise(r => setTimeout(r, 5000));
    }
    if (!ch) { log('Recovery channel not found after 5 retries'); return; }

    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder().setCustomId('lifeline_fix').setLabel('🛡️ Fix HELM').setStyle(ButtonStyle.Danger),
      new ButtonBuilder().setCustomId('lifeline_restart').setLabel('🔄 Restart').setStyle(ButtonStyle.Secondary),
      new ButtonBuilder().setCustomId('lifeline_status').setLabel('📡 Test Connection').setStyle(ButtonStyle.Secondary),
    );

    const content = '**⚡ Lifeline Recovery** — these buttons work even when HELM is completely silent.';

    let existingId = null;
    try { existingId = JSON.parse(fs.readFileSync(LIFELINE_MSG_KEY, 'utf8')).msgId; } catch (_) {}

    if (existingId) {
      const existing = await ch.messages.fetch(existingId).catch(() => null);
      if (existing && existing.author.id === client.user.id) {
        await existing.edit({ content, components: [row] }).catch(() => {});
        log('Updated lifeline recovery button message');
        return;
      }
    }

    const msg = await ch.send({ content, components: [row] });
    fs.writeFileSync(LIFELINE_MSG_KEY, JSON.stringify({ msgId: msg.id }));
    log(`Posted lifeline recovery button message: ${msg.id}`);
  } catch (e) {
    log(`Lifeline button post failed: ${e.message}`);
  }
}

client.login(TOKEN).catch((e) => {
  log(`Login failed: ${e.message}`);
  process.exit(1);
});
