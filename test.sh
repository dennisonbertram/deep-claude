#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# Hermetic test home AND state dir. Both are mandatory now that session-sharing
# and inherit default ON: a bare ./bin/deep-claude invocation symlinks the state
# dir's projects/ into $HOME/.claude — so without overriding BOTH, a test run
# would mutate (and, on cleanup, dangle) the developer's real ~/.claude and the
# real .deep-claude-home. Per-test DEEP_CLAUDE_STATE_DIR overrides still win.
export HOME="$(mktemp -d)/fakehome"; mkdir -p "$HOME"
export DEEP_CLAUDE_STATE_DIR="$(mktemp -d)/state"
trap 'rm -rf "$(dirname "$HOME")" "$(dirname "$DEEP_CLAUDE_STATE_DIR")"' EXIT

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

# --- sub-agents / resumed sessions stay logged in. The launch auth only lives on
#     the main process env; a claude that doesn't inherit it (a sub-agent spawned
#     with a sanitized env, `claude --resume`, a background/fleet spawn) would
#     otherwise see no credentials and drop to `/login`. So the auth must be
#     persisted into the isolated settings.json `env`, which every process using
#     that config dir reads. (DEEP_CLAUDE_STATE_DIR isolates the throwaway home.)
tmpenv="$(mktemp)"; printf 'ROUTER_MODELS="google/gemini-3.5-flash"\n' >"$tmpenv"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  OPENROUTER_API_KEY=k ROUTER_PORT=8913 \
  ./bin/deep-claude --model google/gemini-3.5-flash -p hi >/dev/null 2>&1
# OpenRouter mode: base URL points at the local proxy, token is the literal
# "router" (no real secret on disk), and the key entry exists.
node -e '
  const fs=require("fs");
  const e=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).env)||{};
  if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(e.ANTHROPIC_BASE_URL||"")) { console.error("proxy base url not persisted:",e.ANTHROPIC_BASE_URL); process.exit(1); }
  if(e.ANTHROPIC_AUTH_TOKEN!=="router") { console.error("auth token not persisted:",e.ANTHROPIC_AUTH_TOKEN); process.exit(1); }
  if(!("ANTHROPIC_API_KEY" in e)) { console.error("api key entry missing"); process.exit(1); }
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"; rm -f "$tmpenv"

# Direct-endpoint mode persists that endpoint's base URL + key the same way, so
# its sub-agents/resumes authenticate too.
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url https://api.example.com/anthropic --api-key sekret --model m -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const e=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).env)||{};
  if(e.ANTHROPIC_BASE_URL!=="https://api.example.com/anthropic"){console.error("direct base url not persisted:",e.ANTHROPIC_BASE_URL);process.exit(1);}
  if(e.ANTHROPIC_AUTH_TOKEN!=="sekret"){console.error("direct key not persisted as token");process.exit(1);}
  if(e.ANTHROPIC_API_KEY!=="sekret"){console.error("direct key not persisted as api key");process.exit(1);}
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"

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

# =============================================================================
# STEP 1: Model-tier persistence
# =============================================================================

# OpenRouter mode: extend the existing persistence block to assert all 6 model
# tier keys are in settings.env, and there is NO top-level `model` pin.
tmpenv="$(mktemp)"; printf 'ROUTER_MODELS="google/gemini-3.5-flash"\n' >"$tmpenv"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  OPENROUTER_API_KEY=k ROUTER_PORT=8914 \
  ./bin/deep-claude --model google/gemini-3.5-flash -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=s.env||{};
  const keys=["ANTHROPIC_MODEL","ANTHROPIC_DEFAULT_OPUS_MODEL","ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL","ANTHROPIC_DEFAULT_FABLE_MODEL","ANTHROPIC_SMALL_FAST_MODEL"];
  for(const k of keys){ if(!(k in e)){console.error("missing model tier key:",k);process.exit(1);} }
  if("model" in s){console.error("top-level model pin must not exist");process.exit(1);}
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"; rm -f "$tmpenv"

# OpenRouter with ROUTER_SLOT_* set: assert slot ids land in tier keys.
tmpenv="$(mktemp)"
{
  printf 'ROUTER_MODELS="google/gemini-3.5-flash,deepseek/deepseek-v4-pro"\n'
  printf 'ROUTER_SLOT_OPUS="deepseek/deepseek-v4-pro"\n'
  printf 'ROUTER_SLOT_SONNET="google/gemini-3.5-flash"\n'
} >"$tmpenv"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  OPENROUTER_API_KEY=k ROUTER_PORT=8915 \
  ./bin/deep-claude --model google/gemini-3.5-flash -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const e=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).env)||{};
  if(e.ANTHROPIC_DEFAULT_OPUS_MODEL!=="deepseek/deepseek-v4-pro"){console.error("slot opus wrong:",e.ANTHROPIC_DEFAULT_OPUS_MODEL);process.exit(1);}
  if(e.ANTHROPIC_DEFAULT_SONNET_MODEL!=="google/gemini-3.5-flash"){console.error("slot sonnet wrong:",e.ANTHROPIC_DEFAULT_SONNET_MODEL);process.exit(1);}
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"; rm -f "$tmpenv"

# Direct-endpoint mode: assert all 6 tier keys persist.
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url https://api.example.com/anthropic --api-key sekret --model m -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=s.env||{};
  const keys=["ANTHROPIC_MODEL","ANTHROPIC_DEFAULT_OPUS_MODEL","ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL","ANTHROPIC_DEFAULT_FABLE_MODEL","ANTHROPIC_SMALL_FAST_MODEL"];
  for(const k of keys){ if(!(k in e)){console.error("endpoint missing tier key:",k);process.exit(1);} }
  if(e.ANTHROPIC_MODEL!=="m"){console.error("ANTHROPIC_MODEL wrong:",e.ANTHROPIC_MODEL);process.exit(1);}
  if("model" in s){console.error("top-level model pin must not exist in endpoint mode");process.exit(1);}
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"

# Direct-endpoint with slot assignments.
tmpenv="$(mktemp)"
{
  printf 'DEEP_ENDPOINTS="myep|https://api.example.com/anthropic|"\n'
  printf 'DEEP_EP_MODELS_MYEP="chat,reasoner"\n'
  printf 'DEEP_EP_DEFAULT_MYEP="reasoner"\n'
  printf 'DEEP_EP_SLOT_OPUS_MYEP="reasoner"\n'
  printf 'DEEP_EP_SLOT_SONNET_MYEP="chat"\n'
} >"$tmpenv"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --endpoint myep -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const e=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).env)||{};
  if(e.ANTHROPIC_DEFAULT_OPUS_MODEL!=="reasoner"){console.error("ep slot opus:",e.ANTHROPIC_DEFAULT_OPUS_MODEL);process.exit(1);}
  if(e.ANTHROPIC_DEFAULT_SONNET_MODEL!=="chat"){console.error("ep slot sonnet:",e.ANTHROPIC_DEFAULT_SONNET_MODEL);process.exit(1);}
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"; rm -f "$tmpenv"

# Bare --base-url no-models case: all tiers = launch model.
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url https://api.example.com/anthropic --api-key k --model mymodel -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const e=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).env)||{};
  const tiers=["ANTHROPIC_DEFAULT_OPUS_MODEL","ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL","ANTHROPIC_DEFAULT_FABLE_MODEL","ANTHROPIC_SMALL_FAST_MODEL"];
  for(const k of tiers){ if(e[k]!=="mymodel"){console.error("bare no-models tier wrong for",k,":",e[k]);process.exit(1);} }
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"

# =============================================================================
# STEP 2: Session sharing
# =============================================================================

# Seed real ~/.claude/projects, run wrapper, assert projects is a symlink.
mkdir -p "$HOME/.claude/projects"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ -L "$tmpstate/home/.claude/projects" ]] || { echo "FAIL: projects not a symlink after share_sessions"; exit 1; }
real_target="$(readlink "$tmpstate/home/.claude/projects")"
[[ "$real_target" == "$HOME/.claude/projects" ]] || { echo "FAIL: projects symlink target wrong: $real_target"; exit 1; }
# settings.json and .claude.json must NOT be symlinks (auth stays isolated).
if [[ -e "$tmpstate/home/.claude/settings.json" ]]; then
  [[ ! -L "$tmpstate/home/.claude/settings.json" ]] || { echo "FAIL: settings.json became a symlink"; exit 1; }
fi
rm -rf "$tmpstate"

# Migration: pre-seed isolated projects/<slug>/x.jsonl, run, assert it moved
# into real ~/.claude/projects/<slug>/x.jsonl and isolated projects is now a link.
mkdir -p "$HOME/.claude/projects"
tmpstate="$(mktemp -d)"
mkdir -p "$tmpstate/home/.claude/projects/oldslug"
touch "$tmpstate/home/.claude/projects/oldslug/x.jsonl"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ -L "$tmpstate/home/.claude/projects" ]] || { echo "FAIL: projects not a symlink after migration"; exit 1; }
[[ -f "$HOME/.claude/projects/oldslug/x.jsonl" ]] || { echo "FAIL: isolated transcript not migrated to shared store"; exit 1; }
rm -rf "$tmpstate"

# Migration merges at FILE granularity inside a project dir present in BOTH homes:
# a colliding file keeps the real-home copy (never clobbered) AND a non-colliding
# isolated file in that same dir survives into the shared store (not deleted by the
# dir replacement). This is the regression guard for the dir-level-skip data loss.
mkdir -p "$HOME/.claude/projects/dupslug"
printf 'REAL' >"$HOME/.claude/projects/dupslug/dup.jsonl"
tmpstate="$(mktemp -d)"
mkdir -p "$tmpstate/home/.claude/projects/dupslug"
printf 'ISO'  >"$tmpstate/home/.claude/projects/dupslug/dup.jsonl"   # collides with REAL
printf 'ONLY' >"$tmpstate/home/.claude/projects/dupslug/uniq.jsonl"  # no collision
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ "$(cat "$HOME/.claude/projects/dupslug/dup.jsonl")" == "REAL" ]] || { echo "FAIL: migration clobbered a real-home transcript"; exit 1; }
[[ "$(cat "$HOME/.claude/projects/dupslug/uniq.jsonl" 2>/dev/null)" == "ONLY" ]] || { echo "FAIL: migration LOST a non-colliding isolated transcript in a shared project dir"; exit 1; }
rm -rf "$tmpstate" "$HOME/.claude/projects/dupslug"

# Round-trip: touch real ~/.claude/projects/foo.jsonl, assert visible via state dir.
touch "$HOME/.claude/projects/foo.jsonl"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ -f "$tmpstate/home/.claude/projects/foo.jsonl" ]] || { echo "FAIL: foo.jsonl not visible via state dir symlink"; exit 1; }
rm -rf "$tmpstate"

# Opt-out: DEEP_CLAUDE_SHARE_SESSIONS=0 => projects not a symlink.
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  DEEP_CLAUDE_SHARE_SESSIONS=0 \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ ! -L "$tmpstate/home/.claude/projects" ]] || { echo "FAIL: projects is a symlink even with DEEP_CLAUDE_SHARE_SESSIONS=0"; exit 1; }
rm -rf "$tmpstate"

# No-leak: seed a real ~/.claude/settings.json, assert it is byte-identical after a run.
cat >"$HOME/.claude/settings.json" <<'JSON'
{"version":1,"env":{"MY_KEY":"myval"}}
JSON
orig_sum="$(shasum "$HOME/.claude/settings.json" | awk '{print $1}')"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  OPENROUTER_API_KEY=k ROUTER_PORT=8916 \
  ROUTER_MODELS="google/gemini-3.5-flash" \
  ./bin/deep-claude --model google/gemini-3.5-flash -p hi >/dev/null 2>&1
after_sum="$(shasum "$HOME/.claude/settings.json" | awk '{print $1}')"
[[ "$orig_sum" == "$after_sum" ]] || { echo "FAIL: real ~/.claude/settings.json was modified"; exit 1; }
rm -rf "$tmpstate"

# =============================================================================
# STEP 3: Inherit default ON
# =============================================================================

# Inherit default ON: seed ~/.claude/skills, run with NO flag, assert symlinked.
mkdir -p "$HOME/.claude/skills"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ -L "$tmpstate/home/.claude/skills" ]] || { echo "FAIL: skills not linked with default inherit"; exit 1; }
rm -rf "$tmpstate"

# --no-inherit: assert skills NOT present.
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --no-inherit --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1
[[ ! -e "$tmpstate/home/.claude/skills" ]] || { echo "FAIL: skills present with --no-inherit"; exit 1; }
rm -rf "$tmpstate"

# Must-never-override: seed ~/.claude/settings.json with evil routing vars.
# Run OpenRouter with default --inherit; assert routing env is correct (not evil).
cat >"$HOME/.claude/settings.json" <<'JSON'
{"model":"claude-x","apiKeyHelper":"evil","env":{"ANTHROPIC_BASE_URL":"https://evil","ANTHROPIC_MODEL":"evil/x","PERPLEXITY_API_KEY":"p123"}}
JSON
tmpenv="$(mktemp)"; printf 'ROUTER_MODELS="google/gemini-3.5-flash"\n' >"$tmpenv"
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE="$tmpenv" DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  OPENROUTER_API_KEY=k ROUTER_PORT=8917 \
  ./bin/deep-claude --model google/gemini-3.5-flash -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=s.env||{};
  // routing env must point at our proxy (not evil)
  if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(e.ANTHROPIC_BASE_URL||"")){ console.error("FAIL: evil base url not overridden:",e.ANTHROPIC_BASE_URL); process.exit(1); }
  // no top-level model pin
  if("model" in s){ console.error("FAIL: top-level model pin present"); process.exit(1); }
  // no apiKeyHelper
  if("apiKeyHelper" in s){ console.error("FAIL: apiKeyHelper present"); process.exit(1); }
  // no ANTHROPIC_* leaked from evil (other than the routing ones we wrote)
  // specifically evil/x must not survive
  if(e.ANTHROPIC_MODEL==="evil/x"){ console.error("FAIL: evil ANTHROPIC_MODEL leaked"); process.exit(1); }
  // non-ANTHROPIC keys from inherited settings must be preserved
  if(e.PERPLEXITY_API_KEY!=="p123"){ console.error("FAIL: PERPLEXITY_API_KEY not preserved:",e.PERPLEXITY_API_KEY); process.exit(1); }
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"; rm -f "$tmpenv"

# Must-never-override: direct endpoint mode — base url must be endpoint url, not evil.
tmpstate="$(mktemp -d)"
CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null DEEP_CLAUDE_STATE_DIR="$tmpstate" \
  ./bin/deep-claude --base-url https://myendpoint.example.com/anthropic --api-key sekret --model m -p hi >/dev/null 2>&1
node -e '
  const fs=require("fs");
  const e=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).env)||{};
  if(e.ANTHROPIC_BASE_URL!=="https://myendpoint.example.com/anthropic"){ console.error("FAIL: direct base url wrong:",e.ANTHROPIC_BASE_URL); process.exit(1); }
  if(e.ANTHROPIC_BASE_URL==="https://evil"){ console.error("FAIL: evil base url survived in direct mode"); process.exit(1); }
' "$tmpstate/home/.claude/settings.json"
rm -rf "$tmpstate"

# =============================================================================
# STEP 4: Sandbox
# =============================================================================

# Arg-plumbing (any OS): fake sandbox-exec stub on PATH that drops -f profile and
# execs rest; DEEP_CLAUDE_SANDBOX=1 run prepends stub marker and still ends with
# --model m -p hi; without the flag the marker is absent.
if [[ "$(uname -s)" == "Darwin" ]]; then
  # Real enforce smoke: have build_sandbox_prefix generate the ACTUAL seatbelt
  # profile (run with a fake sandbox-exec so launch succeeds), then enforce it
  # with the real /usr/bin/sandbox-exec. Tests the generated artifact directly,
  # so a regression that breaks profile syntax or drops the write subpaths fails
  # here instead of passing silently.
  repo_bin="$PWD/bin/deep-claude"
  sbcwd="$(mktemp -d)"; sbstate="$(mktemp -d)"; sbstub="$(mktemp -d)"
  printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do case "$1" in -f) shift 2;; *) break;; esac; done\nexec "$@"\n' >"$sbstub/sandbox-exec"
  chmod +x "$sbstub/sandbox-exec"
  ( cd "$sbcwd" && PATH="$sbstub:$PATH" CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
      DEEP_CLAUDE_STATE_DIR="$sbstate" DEEP_CLAUDE_SANDBOX=1 \
      "$repo_bin" --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1 )
  sb="$sbstate/seatbelt.sb"
  [[ -f "$sb" ]] || { echo "FAIL: seatbelt profile not generated"; exit 1; }
  # (a) compiles + allows a write inside the state dir
  /usr/bin/sandbox-exec -f "$sb" /usr/bin/touch "$sbstate/ok.txt" || { echo "FAIL: seatbelt denied an allowed state-dir write"; exit 1; }
  [[ -f "$sbstate/ok.txt" ]] || { echo "FAIL: allowed write did not happen under seatbelt"; exit 1; }
  # (b) DENIES a write outside the allow-list
  if /usr/bin/sandbox-exec -f "$sb" /usr/bin/touch /etc/dc_should_fail 2>/dev/null; then echo "FAIL: seatbelt allowed a write to /etc"; exit 1; fi
  # (c) process-exec is allowed (subagents/bash need it)
  /usr/bin/sandbox-exec -f "$sb" /bin/sh -c 'true' || { echo "FAIL: seatbelt blocked process-exec"; exit 1; }
  # loopback net variant must also compile
  ( cd "$sbcwd" && PATH="$sbstub:$PATH" CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
      DEEP_CLAUDE_STATE_DIR="$sbstate" DEEP_CLAUDE_SANDBOX=1 DEEP_CLAUDE_SANDBOX_NET=loopback \
      "$repo_bin" --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1 )
  /usr/bin/sandbox-exec -f "$sb" /usr/bin/true || { echo "FAIL: loopback-net seatbelt profile does not compile"; exit 1; }
  rm -rf "$sbcwd" "$sbstate" "$sbstub"

  stubdir="$(mktemp -d)"
  cat >"$stubdir/sandbox-exec" <<'SH'
#!/bin/sh
# Stub: drop -f <profile> args and exec the rest.
while [ $# -gt 0 ]; do
  case "$1" in
    -f) shift 2 ;;
    *) break ;;
  esac
done
exec "$@"
SH
  chmod +x "$stubdir/sandbox-exec"
  sandbox_out="$(PATH="$stubdir:$PATH" CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
    DEEP_CLAUDE_SANDBOX=1 \
    ./bin/deep-claude --base-url http://x --api-key k --model m -p hi 2>/dev/null)"
  [[ "$sandbox_out" == "--model m -p hi" ]] || { echo "FAIL: sandbox arg-plumbing: got '$sandbox_out'"; exit 1; }
  no_sandbox_out="$(PATH="$stubdir:$PATH" CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
    ./bin/deep-claude --base-url http://x --api-key k --model m -p hi 2>/dev/null)"
  [[ "$no_sandbox_out" == "--model m -p hi" ]] || { echo "FAIL: no-sandbox pass-through: got '$no_sandbox_out'"; exit 1; }
  rm -rf "$stubdir"

  # Fail-closed: DEEP_CLAUDE_SANDBOX=1 with PATH lacking sandbox-exec exits non-zero.
  # Build a shadow dir that has all of /usr/bin EXCEPT sandbox-exec, so the script
  # can still find dirname/grep/etc. but not sandbox-exec.
  shadowdir="$(mktemp -d)"
  for _f in /usr/bin/*; do
    _n="$(basename "$_f")"
    if [[ "$_n" != "sandbox-exec" ]]; then
      ln -s "$_f" "$shadowdir/$_n" 2>/dev/null || true
    fi
  done
  _safe_path="$shadowdir:$(echo "$PATH" | tr ':' '\n' | grep -v '^/usr/bin$' | tr '\n' ':' | sed 's/:$//')"
  ( PATH="$_safe_path" DEEP_CLAUDE_SANDBOX=1 CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
    ./bin/deep-claude --base-url http://x --api-key k --model m -p hi >/dev/null 2>&1 ) && \
    { echo "FAIL: sandbox fail-closed: should have exited non-zero"; exit 1; } || true
  rm -rf "$shadowdir"
fi

# =============================================================================
# STEP 5: Arg forwarding
# =============================================================================

# --resume <id> and --continue forward verbatim to the stub.
resume_out="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
  ./bin/deep-claude --base-url http://x --api-key k --model m --resume abc123 2>/dev/null)"
[[ "$resume_out" == "--model m --resume abc123" ]] || { echo "FAIL: --resume not forwarded: got '$resume_out'"; exit 1; }

continue_out="$(CLAUDE_BIN=/bin/echo DEEP_CLAUDE_ENV_FILE=/dev/null \
  ./bin/deep-claude --base-url http://x --api-key k --model m --continue 2>/dev/null)"
[[ "$continue_out" == "--model m --continue" ]] || { echo "FAIL: --continue not forwarded: got '$continue_out'"; exit 1; }

echo "ok"
