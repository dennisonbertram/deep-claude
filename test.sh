#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

bash -n bin/deep-claude
bash -n deep-claude
bash -n install.sh
node --check bin/deep-claude-proxy
node --check bin/deep-claude-pick
node --check bin/deep-claude-cli
node --check bin/deep-claude-statusline

# --- run: personal endpoints (claude replaced by /bin/echo; DEEP_CLAUDE_ENV_FILE
#     points at /dev/null so a real .env can't interfere). -----------------------
adhoc="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi 2>/dev/null)"
[[ "$adhoc" == "--model m -p hi" ]]

# --api-key-env resolution + the -- separator.
sep="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null MYKEY=secret \
  ./bin/deep-claude --base-url http://x --api-key-env MYKEY --model m -- -p hi 2>/dev/null)"
[[ "$sep" == "--model m -p hi" ]]

# --- saved endpoints CLI + --endpoint run -------------------------------------
tmpenv="$(mktemp)"
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude endpoints add deepseek https://api.deepseek.com/anthropic DEEPSEEK_API_KEY >/dev/null
grep -q 'DEEP_ENDPOINTS=.*deepseek|https://api.deepseek.com/anthropic|DEEPSEEK_API_KEY' "$tmpenv"
ep="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" DEEPSEEK_API_KEY=k \
  ./bin/deep-claude --endpoint deepseek --model deepseek-v4-pro -p hi 2>/dev/null)"
[[ "$ep" == "--model deepseek-v4-pro -p hi" ]]
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude endpoints remove deepseek >/dev/null
! grep -q 'DEEP_ENDPOINTS=deepseek' "$tmpenv"
rm -f "$tmpenv"

# --- per-endpoint models: default resolution + /model slot wiring -------------
tmpenv="$(mktemp)"
{
  echo 'DEEP_ENDPOINTS="ds|https://api.deepseek.com/anthropic|"'
  echo 'DEEP_EP_MODELS_DS="deepseek-chat,deepseek-reasoner"'
  echo 'DEEP_EP_DEFAULT_DS="deepseek-reasoner"'
} >"$tmpenv"
# No --model -> launches on the configured default.
epdef="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" \
  ./bin/deep-claude --endpoint ds -p hi 2>/dev/null)"
[[ "$epdef" == "--model deepseek-reasoner -p hi" ]]
# --model still overrides the configured default at launch.
epov="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" \
  ./bin/deep-claude --endpoint ds --model deepseek-chat -p hi 2>/dev/null)"
[[ "$epov" == "--model deepseek-chat -p hi" ]]
# Without explicit slots, the endpoint's models populate /model positionally
# (opus<-first, sonnet<-second).
stub="$(mktemp)"; printf '#!/bin/sh\necho "OPUS=$ANTHROPIC_DEFAULT_OPUS_MODEL SONNET=$ANTHROPIC_DEFAULT_SONNET_MODEL HAIKU=$ANTHROPIC_DEFAULT_HAIKU_MODEL"\n' >"$stub"; chmod +x "$stub"
slots="$(CLAUDE_BIN="$stub" DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude --endpoint ds 2>/dev/null)"
[[ "$slots" == "OPUS=deepseek-chat SONNET=deepseek-reasoner HAIKU=deepseek-reasoner" ]]
# Explicit per-slot assignments (set in the picker) override the positional default.
{
  echo 'DEEP_EP_SLOT_OPUS_DS="deepseek-reasoner"'
  echo 'DEEP_EP_SLOT_SONNET_DS="deepseek-chat"'
  echo 'DEEP_EP_SLOT_HAIKU_DS="deepseek-chat"'
} >>"$tmpenv"
eslots="$(CLAUDE_BIN="$stub" DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude --endpoint ds 2>/dev/null)"
[[ "$eslots" == "OPUS=deepseek-reasoner SONNET=deepseek-chat HAIKU=deepseek-chat" ]]
rm -f "$tmpenv" "$stub"

# --- OpenRouter model-curation CLI --------------------------------------------
tmpenv="$(mktemp)"
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude models add google/gemini-3.5-flash gemini >/dev/null
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude models add deepseek/deepseek-v4-flash deepseek >/dev/null
grep -q '^ROUTER_MODELS=.*google/gemini-3.5-flash' "$tmpenv"
grep -q 'gemini=google/gemini-3.5-flash' "$tmpenv"
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude models remove gemini >/dev/null
! grep -q 'google/gemini-3.5-flash' "$tmpenv"
grep -q 'deepseek/deepseek-v4-flash' "$tmpenv"
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude models default deepseek >/dev/null
grep -q 'ROUTER_DEFAULT_MODEL=.*deepseek' "$tmpenv"
rm -f "$tmpenv"

# Regression: model ids with shell-active chars (~ for "latest", : in :free)
# must be quoted so the written .env still sources cleanly.
tmpenv="$(mktemp)"
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude models add '~anthropic/claude-opus-latest' opuslatest >/dev/null
DEEP_CLAUDE_ENV_FILE="$tmpenv" ./bin/deep-claude models add 'google/gemma-4-31b-it:free' gemma >/dev/null
( set -a; source "$tmpenv"; set +a; [[ "$(printf '%s' "$ROUTER_MODELS" | tr ',' '\n' | grep -c .)" == "2" ]] )
rm -f "$tmpenv"

# --- default (OpenRouter): boots the proxy, health-checks, then execs claude. --
or_boot="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null OPENROUTER_API_KEY=k ROUTER_PORT=8911 \
  ./bin/deep-claude --model google/gemini-3.5-flash -p hi 2>/dev/null)"
[[ "$or_boot" == "--model google/gemini-3.5-flash -p hi" ]]

# --- proxy: live end-to-end behavior against a fake upstream. ------------------
node - <<'NODE'
const http = require('http');
const { spawn } = require('child_process');

const UP_PORT = 8901, PROXY_PORT = 8902, EP_PORT = 8905;
let captured = null, epCaptured = null;

const upstream = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    captured = { url: req.url, headers: req.headers, body: JSON.parse(body || '{}') };
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 'msg_1', type: 'message', role: 'assistant', content: [], model: captured.body.model }));
  });
});

// A personal-endpoint upstream — models prefixed "myep/" must route here direct.
const epstream = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    epCaptured = { url: req.url, headers: req.headers, body: JSON.parse(body || '{}') };
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 'msg_2', type: 'message', role: 'assistant', content: [], model: epCaptured.body.model }));
  });
});

function die(msg) { console.error('FAIL:', msg); process.exit(1); }

epstream.listen(EP_PORT, '127.0.0.1', () => upstream.listen(UP_PORT, '127.0.0.1', () => {
  const proxy = spawn('node', [__dirname + '/bin/deep-claude-proxy'], {
    env: {
      ...process.env,
      ROUTER_PORT: String(PROXY_PORT),
      OPENROUTER_API_KEY: 'testkey',
      OPENROUTER_BASE_URL: `http://127.0.0.1:${UP_PORT}`,
      // Unified allow-list mixing an OpenRouter model and an endpoint-prefixed one.
      ROUTER_MODELS: 'anthropic/claude-opus-4.8,myep/foo-pro',
      ROUTER_ALIASES: 'gemini=google/gemini-3.5-flash',
      DEEP_ENDPOINTS: `myep|http://127.0.0.1:${EP_PORT}|DEEP_KEY_MYEP`,
      DEEP_KEY_MYEP: 'epsecret',
    },
    stdio: 'ignore',
  });

  const done = (ok) => { proxy.kill(); upstream.close(); epstream.close(); process.exit(ok ? 0 : 1); };

  const wait = async () => {
    for (let i = 0; i < 50; i++) {
      try { const r = await fetch(`http://127.0.0.1:${PROXY_PORT}/health`); if (r.ok) return; } catch {}
      await new Promise((r) => setTimeout(r, 100));
    }
    die('proxy did not start');
  };

  (async () => {
    await wait();

    const models = await (await fetch(`http://127.0.0.1:${PROXY_PORT}/v1/models`)).json();
    const ids = models.data.map((m) => m.id);
    if (!ids.includes('anthropic/claude-opus-4.8') || !ids.includes('google/gemini-3.5-flash'))
      die('/v1/models missing curated entries: ' + JSON.stringify(ids));

    const resp = await fetch(`http://127.0.0.1:${PROXY_PORT}/v1/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'anthropic-beta': 'context-management-2025-06-27,fine-grained-tool-streaming' },
      body: JSON.stringify({ model: 'gemini', context_management: { edits: [] }, max_tokens: 16, messages: [{ role: 'user', content: 'hi' }] }),
    });
    if (!resp.ok) die('proxy returned ' + resp.status);

    if (captured.body.model !== 'google/gemini-3.5-flash') die('alias not resolved: ' + captured.body.model);
    if ('context_management' in captured.body) die('context_management not stripped');
    if (captured.headers['authorization'] !== 'Bearer testkey') die('key not injected: ' + captured.headers['authorization']);
    const beta = captured.headers['anthropic-beta'] || '';
    if (beta.includes('context-management')) die('context-management beta not stripped: ' + beta);
    if (!beta.includes('fine-grained-tool-streaming')) die('other betas dropped: ' + beta);

    // Cross-provider: an endpoint-prefixed model routes DIRECT to that endpoint
    // (its own key, prefix stripped) instead of OpenRouter — the basis of mixing
    // providers across the /model tiers in one session.
    const r2 = await fetch(`http://127.0.0.1:${PROXY_PORT}/v1/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ model: 'myep/foo-pro', max_tokens: 16, messages: [{ role: 'user', content: 'hi' }] }),
    });
    if (!r2.ok) die('direct route returned ' + r2.status);
    if (!epCaptured) die('endpoint-prefixed model did not route to the endpoint upstream');
    if (epCaptured.body.model !== 'foo-pro') die('provider prefix not stripped: ' + epCaptured.body.model);
    if (epCaptured.headers['x-api-key'] !== 'epsecret') die("endpoint's own key not used: " + epCaptured.headers['x-api-key']);

    done(true);
  })().catch((e) => { console.error(e); done(false); });
}));
NODE

# --- proxy: thinking-block stripping for non-Claude SSE responses. -------------
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
  const proxy = spawn('node', [__dirname + '/bin/deep-claude-proxy'], {
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
    const g = await post('google/x');
    if (g.includes('redacted_thinking')) die('redacted_thinking not stripped for non-Claude');
    if (g.includes('SECRET')) die('thinking data leaked');
    if (!g.includes('hello world')) die('visible text lost during strip');
    if (!g.includes('"type":"text"')) die('text block start dropped');
    const a = await post('anthropic/y');
    if (!a.includes('redacted_thinking')) die('thinking wrongly stripped for Claude model');
    done(true);
  })().catch((e) => { console.error(e); done(false); });
});
NODE

# deep-claude proxy: per-model DIRECT routing via DEEP_ENDPOINTS.
node - <<'NODE'
const http = require('http');
const { spawn } = require('child_process');
const OR = 8905, DIR = 8906, PROXY = 8907;
let hitOR = null, hitDIR = null;
const mk = (sink) => http.createServer((req, res) => {
  let b = ''; req.on('data', c => (b += c));
  req.on('end', () => { sink({ headers: req.headers, body: JSON.parse(b || '{}') });
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 'm', type: 'message', role: 'assistant', content: [], model: 'x' })); });
});
function die(m) { console.error('FAIL:', m); process.exit(1); }
const sOR = mk(x => (hitOR = x)), sDIR = mk(x => (hitDIR = x));
sOR.listen(OR, '127.0.0.1', () => sDIR.listen(DIR, '127.0.0.1', () => {
  const proxy = spawn('node', [__dirname + '/bin/deep-claude-proxy'], {
    env: { ...process.env, ROUTER_PORT: String(PROXY), OPENROUTER_API_KEY: 'ork',
      OPENROUTER_BASE_URL: `http://127.0.0.1:${OR}`,
      DEEP_ENDPOINTS: `myprov|http://127.0.0.1:${DIR}|MYKEY`, MYKEY: 'secret',
      ROUTER_MODELS: 'myprov/foo,other/bar' },
    stdio: 'ignore',
  });
  const done = (ok) => { proxy.kill(); sOR.close(); sDIR.close(); process.exit(ok ? 0 : 1); };
  const post = (model) => fetch(`http://127.0.0.1:${PROXY}/v1/messages`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ model, max_tokens: 8, messages: [{ role: 'user', content: 'hi' }] }) });
  (async () => {
    for (let i = 0; i < 50; i++) { try { if ((await fetch(`http://127.0.0.1:${PROXY}/health`)).ok) break; } catch {} await new Promise(r => setTimeout(r, 100)); }
    await post('myprov/foo');   // -> direct
    if (!hitDIR) die('direct endpoint not hit for myprov/*');
    if (hitDIR.body.model !== 'foo') die('prefix not stripped for direct: ' + hitDIR.body.model);
    if (hitDIR.headers['x-api-key'] !== 'secret') die('direct key not sent: ' + hitDIR.headers['x-api-key']);
    hitOR = null;
    await post('other/bar');    // -> OpenRouter
    if (!hitOR) die('OpenRouter not hit for other/*');
    if (hitOR.body.model !== 'other/bar') die('OpenRouter model altered: ' + hitOR.body.model);
    if (hitOR.headers['authorization'] !== 'Bearer ork') die('OpenRouter key missing');
    done(true);
  })().catch(e => { console.error(e); done(false); });
}));
NODE

# deep-claude proxy: survives a mid-stream upstream reset (ECONNRESET) instead of
# crashing the whole process. Regression for the proxy dying mid-code-review and
# leaving every later request with ConnectionRefused. Exercises BOTH streaming
# paths (passthrough for anthropic/*, sse-strip for non-anthropic) then proves
# the proxy still serves a clean request.
node - <<'NODE'
const http = require('http');
const { spawn } = require('child_process');
const UP = 8908, PROXY = 8909;
let n = 0;
function die(m) { console.error('FAIL:', m); process.exit(1); }
const upstream = http.createServer((req, res) => {
  let b = ''; req.on('data', c => (b += c));
  req.on('end', () => {
    n++;
    if (n <= 2) {
      // open an SSE stream, emit a couple events, then hard-reset the socket
      // mid-stream — exactly what a flaky upstream does on a long request.
      res.writeHead(200, { 'content-type': 'text/event-stream' });
      res.write('event: message_start\ndata: {"type":"message_start","message":{"id":"m","type":"message","role":"assistant","content":[],"model":"x"}}\n\n');
      res.write('event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n');
      setTimeout(() => { try { res.socket.destroy(); } catch {} }, 20);
    } else {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ id: 'ok', type: 'message', role: 'assistant', content: [{ type: 'text', text: 'alive' }], model: 'x' }));
    }
  });
});
upstream.listen(UP, '127.0.0.1', () => {
  const proxy = spawn('node', [__dirname + '/bin/deep-claude-proxy'], {
    env: { ...process.env, ROUTER_PORT: String(PROXY), OPENROUTER_API_KEY: 'k',
      OPENROUTER_BASE_URL: `http://127.0.0.1:${UP}`,
      ROUTER_MODELS: 'anthropic/y,google/x' },
    stdio: 'ignore',
  });
  const done = (ok) => { proxy.kill(); upstream.close(); process.exit(ok ? 0 : 1); };
  const post = (model) => fetch(`http://127.0.0.1:${PROXY}/v1/messages`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ model, stream: true, max_tokens: 8, messages: [{ role: 'user', content: 'hi' }] }),
  });
  const alive = async () => { try { return (await fetch(`http://127.0.0.1:${PROXY}/health`)).ok; } catch { return false; } };
  // A truncated stream must reach the client as truncated (threw, or partial
  // body with no clean message_stop) — never masked as a complete response.
  const readBroken = async (model) => { try { const r = await post(model); return await r.text(); } catch { return '__threw__'; } };
  (async () => {
    for (let i = 0; i < 50; i++) { if (await alive()) break; await new Promise(r => setTimeout(r, 100)); }
    // 1) passthrough path (anthropic/*) — upstream resets mid-stream
    const b1 = await readBroken('anthropic/y');
    if (b1.includes('message_stop')) die('passthrough reset masked as a clean completion');
    await new Promise(r => setTimeout(r, 150));
    if (!(await alive())) die('proxy CRASHED after passthrough mid-stream reset');
    // 2) sse-strip path (non-anthropic) — upstream resets mid-stream
    const b2 = await readBroken('google/x');
    if (b2.includes('message_stop')) die('sse-strip reset masked as a clean completion');
    await new Promise(r => setTimeout(r, 150));
    if (!(await alive())) die('proxy CRASHED after sse-strip mid-stream reset');
    // 3) the proxy must still serve a clean request afterward
    const ok = await (await fetch(`http://127.0.0.1:${PROXY}/v1/messages`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ model: 'anthropic/y', max_tokens: 8, messages: [{ role: 'user', content: 'hi' }] }),
    })).json();
    if (!(ok.content && ok.content[0] && ok.content[0].text === 'alive')) die('proxy did not recover: ' + JSON.stringify(ok));
    done(true);
  })().catch(e => { console.error(e); done(false); });
});
NODE

echo "ok"
