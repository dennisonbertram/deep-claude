#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

bash -n bin/deep-claude
bash -n bin/deep-router
bash -n deep-claude
bash -n deep-router
bash -n install.sh
node --check bin/deep-router-proxy
node --check bin/deep-router-pick

default_output="$(CLAUDE_BIN=/bin/echo ./bin/deep-claude)"
flash_output="$(CLAUDE_BIN=/bin/echo ./bin/deep-claude --model flash hello)"
pro_output="$(CLAUDE_BIN=/bin/echo ./bin/deep-claude --model pro hello)"
passthrough_output="$(CLAUDE_BIN=/bin/echo ./bin/deep-claude -p "hello there" --output-format json)"
separator_output="$(CLAUDE_BIN=/bin/echo ./bin/deep-claude --model flash -- -p "hello from flash")"

[[ "$default_output" == "--model deepseek-v4-pro" ]]
[[ "$flash_output" == "--model deepseek-v4-flash hello" ]]
[[ "$pro_output" == "--model deepseek-v4-pro hello" ]]
[[ "$passthrough_output" == "--model deepseek-v4-pro -p hello there --output-format json" ]]
[[ "$separator_output" == "--model deepseek-v4-flash -p hello from flash" ]]

# deep-claude --open-router: boots the proxy, health-checks, then execs claude
# (replaced by /bin/echo). Verifies the model id flows through to claude.
router_or="$(CLAUDE_BIN=/bin/echo OPENROUTER_API_KEY=k ROUTER_PORT=8911 \
  ./bin/deep-claude --open-router --model google/gemini-3-flash -p hi 2>/dev/null)"
[[ "$router_or" == "--model google/gemini-3-flash -p hi" ]]

# deep-router models: curation CLI edits an isolated env file.
tmpenv="$(mktemp)"
DEEP_ROUTER_ENV_FILE="$tmpenv" ./bin/deep-router models add google/gemini-3-flash gemini >/dev/null
DEEP_ROUTER_ENV_FILE="$tmpenv" ./bin/deep-router models add deepseek/deepseek-chat-v3 deepseek >/dev/null
grep -q '^ROUTER_MODELS=.*google/gemini-3-flash' "$tmpenv"
grep -q 'gemini=google/gemini-3-flash' "$tmpenv"
DEEP_ROUTER_ENV_FILE="$tmpenv" ./bin/deep-router models remove gemini >/dev/null
! grep -q 'google/gemini-3-flash' "$tmpenv"
grep -q 'deepseek/deepseek-chat-v3' "$tmpenv"
DEEP_ROUTER_ENV_FILE="$tmpenv" ./bin/deep-router models default deepseek >/dev/null
grep -q '^ROUTER_DEFAULT_MODEL=deepseek$' "$tmpenv"
rm -f "$tmpenv"

# deep-router proxy: live end-to-end behavior against a fake upstream.
node - <<'NODE'
const http = require('http');
const { spawn } = require('child_process');

const UP_PORT = 8901, PROXY_PORT = 8902;
let captured = null;

const upstream = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    captured = { url: req.url, headers: req.headers, body: JSON.parse(body || '{}') };
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 'msg_1', type: 'message', role: 'assistant', content: [], model: captured.body.model }));
  });
});

function die(msg) { console.error('FAIL:', msg); process.exit(1); }

upstream.listen(UP_PORT, '127.0.0.1', () => {
  const proxy = spawn('node', [__dirname + '/bin/deep-router-proxy'], {
    env: {
      ...process.env,
      ROUTER_PORT: String(PROXY_PORT),
      OPENROUTER_API_KEY: 'testkey',
      OPENROUTER_BASE_URL: `http://127.0.0.1:${UP_PORT}`,
      ROUTER_MODELS: 'anthropic/claude-opus-4.8',
      ROUTER_ALIASES: 'gemini=google/gemini-3-flash',
    },
    stdio: 'ignore',
  });

  const done = (ok) => { proxy.kill(); upstream.close(); process.exit(ok ? 0 : 1); };

  const wait = async () => {
    for (let i = 0; i < 50; i++) {
      try { const r = await fetch(`http://127.0.0.1:${PROXY_PORT}/health`); if (r.ok) return; } catch {}
      await new Promise((r) => setTimeout(r, 100));
    }
    die('proxy did not start');
  };

  (async () => {
    await wait();

    // /v1/models advertises the curated set (explicit model + alias target).
    const models = await (await fetch(`http://127.0.0.1:${PROXY_PORT}/v1/models`)).json();
    const ids = models.data.map((m) => m.id);
    if (!ids.includes('anthropic/claude-opus-4.8') || !ids.includes('google/gemini-3-flash'))
      die('/v1/models missing curated entries: ' + JSON.stringify(ids));

    // /v1/messages: alias resolves, context_management stripped, beta sanitized, key injected.
    const resp = await fetch(`http://127.0.0.1:${PROXY_PORT}/v1/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'anthropic-beta': 'context-management-2025-06-27,fine-grained-tool-streaming' },
      body: JSON.stringify({ model: 'gemini', context_management: { edits: [] }, max_tokens: 16, messages: [{ role: 'user', content: 'hi' }] }),
    });
    if (!resp.ok) die('proxy returned ' + resp.status);

    if (captured.body.model !== 'google/gemini-3-flash') die('alias not resolved: ' + captured.body.model);
    if ('context_management' in captured.body) die('context_management not stripped');
    if (captured.headers['authorization'] !== 'Bearer testkey') die('key not injected: ' + captured.headers['authorization']);
    const beta = captured.headers['anthropic-beta'] || '';
    if (beta.includes('context-management')) die('context-management beta not stripped: ' + beta);
    if (!beta.includes('fine-grained-tool-streaming')) die('other betas dropped: ' + beta);

    done(true);
  })().catch((e) => { console.error(e); done(false); });
});
NODE

# deep-router proxy: thinking-block stripping for non-Claude SSE responses.
node - <<'NODE'
const http = require('http');
const { spawn } = require('child_process');

const UP = 8903, PROXY = 8904;
const SSE = [
  'event: message_start',
  'data: {"type":"message_start","message":{"id":"m","type":"message","role":"assistant","content":[],"model":"x"}}',
  '',
  'event: content_block_start',
  'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}',
  '',
  'event: content_block_delta',
  'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello world"}}',
  '',
  'event: content_block_start',
  'data: {"type":"content_block_start","index":1,"content_block":{"type":"redacted_thinking","data":"SECRET"}}',
  '',
  'event: content_block_stop',
  'data: {"type":"content_block_stop","index":1}',
  '',
  'event: content_block_stop',
  'data: {"type":"content_block_stop","index":0}',
  '',
  'event: message_delta',
  'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}',
  '',
  'event: message_stop',
  'data: {"type":"message_stop"}',
  '', '',
].join('\n');

function die(m) { console.error('FAIL:', m); process.exit(1); }

const upstream = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'text/event-stream' });
  res.end(SSE);
});

upstream.listen(UP, '127.0.0.1', () => {
  const proxy = spawn('node', [__dirname + '/bin/deep-router-proxy'], {
    env: { ...process.env, ROUTER_PORT: String(PROXY), OPENROUTER_API_KEY: 'k',
      OPENROUTER_BASE_URL: `http://127.0.0.1:${UP}`,
      ROUTER_MODELS: 'google/x,anthropic/y' },
    stdio: 'ignore',
  });
  const done = (ok) => { proxy.kill(); upstream.close(); process.exit(ok ? 0 : 1); };
  const post = (model) => fetch(`http://127.0.0.1:${PROXY}/v1/messages`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ model, stream: true, max_tokens: 16, messages: [{ role: 'user', content: 'hi' }] }),
  }).then((r) => r.text());

  (async () => {
    for (let i = 0; i < 50; i++) {
      try { if ((await fetch(`http://127.0.0.1:${PROXY}/health`)).ok) break; } catch {}
      await new Promise((r) => setTimeout(r, 100));
    }
    // Non-Claude: thinking stripped, text preserved.
    const g = await post('google/x');
    if (g.includes('redacted_thinking')) die('redacted_thinking not stripped for non-Claude');
    if (g.includes('SECRET')) die('thinking data leaked');
    if (!g.includes('hello world')) die('visible text lost during strip');
    if (!g.includes('"type":"text"')) die('text block start dropped');
    // Claude: passes through untouched.
    const a = await post('anthropic/y');
    if (!a.includes('redacted_thinking')) die('thinking wrongly stripped for Claude model');
    done(true);
  })().catch((e) => { console.error(e); done(false); });
});
NODE

echo "ok"
