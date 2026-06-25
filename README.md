<p align="center">
  <img src="assets/banner.png" alt="deep-claude" width="100%">
</p>

<h1 align="center">deep-claude 🐋</h1>

<p align="center">
  <b>Drive Claude Code with any model.</b><br>
  OpenRouter by default — Gemini, GPT, DeepSeek, Grok, Qwen, Claude, and more — or any
  Anthropic-compatible endpoint you point it at. Same harness, a different mind, cleanly isolated.
</p>

<p align="center">
  <a href="https://dennisonbertram.github.io/deep-claude/">Website</a> ·
  <a href="#quickstart">Install</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#personal-endpoints">Endpoints</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#troubleshooting">Troubleshooting</a>
</p>

<p align="center">
  <code>deep-claude</code> points <a href="https://claude.com/claude-code">Claude Code</a> at
  <a href="https://openrouter.ai">OpenRouter</a> through a tiny local proxy and redirects its state
  into a private home, so your real Anthropic login is never touched. Pick the models you want, then
  type <code>deep-claude</code> followed by any normal <code>claude</code> arguments — you get the full
  agentic harness (tools, MCP, slash commands, sub-agents) running on whichever model you chose.
</p>

```console
$ deep-claude pick                       # choose your models from OpenRouter's catalog
$ deep-claude -p "refactor this module and run the tests"
…the Claude Code agent loop you know — planning, editing, running — on your default model…

$ deep-claude --model opus -p "review this diff"          # switch model per run
$ deep-claude --endpoint deepseek --model deepseek-v4-pro # or hit a provider directly
```

## Why?

Claude Code is one of the best agentic coding harnesses there is: the planning loop, tool use, MCP
servers, sub-agents, permissions, and slash commands are all _harness_, not _model_. Lots of models
speak (or can be made to speak) the Anthropic API — so you can keep every bit of that machinery and
swap the brain.

- **One key, any model.** An OpenRouter key gets you Gemini, GPT, DeepSeek, Grok, Qwen, Claude, and
  hundreds more behind a single endpoint.
- **A curated, pretty picker.** `deep-claude pick` is a searchable, multi-select TUI over the whole
  catalog (with context windows and pricing), and assigns your picks to Claude Code's switch slots so
  you can flip between them in-session. It's a **two-level provider picker**: the first screen lists
  every provider (OpenRouter plus each personal endpoint) — set a provider's API key with `e`, add a
  new one with `＋ Add provider`, then press `↵` to drill into that provider's models. The OpenRouter
  key itself lives here too, so one screen manages every key. `⌃S` saves everything.
- **Real multi-model workflows.** A sub-agent's `model:` accepts a full model id, so one workflow can
  run many models at once — the orchestrator on one, sub-agents pinned to others (proven end-to-end).
- **Keep your setup.** Inherit is **on by default** — your existing skills, agents, workflows,
  plugins, hooks, and MCP servers come along automatically, without importing your Anthropic login.
  Use `--no-inherit` to run fully isolated. See
  [Use your existing Claude setup](#use-your-existing-claude-setup-skills-plugins-mcp-).
- **Zero contamination.** Session history, projects, MCP config, and `~/.claude.json` live in a
  private state dir — your normal Claude Code setup is untouched, and `$HOME` is left alone so the
  macOS keychain keeps working.
- **Bring your own endpoint.** DeepSeek-direct, a local Ollama, a self-hosted gateway — any
  Anthropic-compatible URL is a [personal endpoint](#personal-endpoints) away.

> **Your normal setup is safe.** `deep-claude` only sets a few environment variables and redirects
> Claude Code's state directory per launch. It never reads, moves, or modifies your Anthropic credentials.

| Command                       | What it does                                                  |
| ----------------------------- | ------------------------------------------------------------ |
| `deep-claude`                 | Run Claude Code on your default model (first run: setup wizard). |
| `deep-claude --model X`       | Run on a specific model (alias or full id) for this session. |
| `deep-claude cli`             | The setup wizard — enter your key and pick models.           |
| `deep-claude pick`            | Interactive model picker over OpenRouter's catalog.          |
| `deep-claude models …`        | Curate the model set non-interactively.                      |
| `deep-claude endpoints …`     | Manage personal (non-OpenRouter) endpoints.                  |
| `deep-claude --endpoint NAME` | Run on a saved personal endpoint.                            |
| `deep-claude --no-inherit`    | Run without linking your real `~/.claude` (default: inherit ON). |

## Contents

- [Requirements](#requirements)
- [Quickstart](#quickstart)
- [Configuring the key](#configuring-the-key)
- [Usage](#usage)
- [Personal endpoints](#personal-endpoints)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## Requirements

- **macOS or Linux**
- **[Claude Code](https://claude.com/claude-code)** — `claude` on `PATH`. Install via the [official installer](https://claude.com/claude-code) or `npm i -g @anthropic-ai/claude-code`.
- **[Node.js](https://nodejs.org/)** — the local proxy and the model picker run on `node`.
- **An [OpenRouter API key](https://openrouter.ai/keys)** for the default path (and/or a key for any personal endpoint you add).

## Quickstart

```bash
git clone https://github.com/dennisonbertram/deep-claude
cd deep-claude
./install.sh
export PATH="$HOME/.local/bin:$PATH"     # if it isn't already
```

Then just run it — the **first run walks you through setup** in the provider picker (press `e` on
OpenRouter to paste your [OpenRouter key](https://openrouter.ai/keys), then `↵` to pick your models):

```bash
deep-claude              # first run → setup wizard, then starts the session
```

You can re-run the wizard any time with `deep-claude cli`, change models with `deep-claude pick`, and prefer a different default with `deep-claude --model <alias>`.

## Configuring the key

`deep-claude` looks for `OPENROUTER_API_KEY` in this order:

1. **Shell environment** — `export OPENROUTER_API_KEY="sk-or-..."`
2. **`.env` next to this repo** — `cp .env.example .env && $EDITOR .env`
3. **macOS Keychain** — `security add-generic-password -s deep-router -a openrouter -U -w`

### Keychain details (macOS)

- Service: `deep-router` — Account: `openrouter`
- The `security` binary handles all reads, so the key never lives in `.env`, shell history, or process listings.
- First read after a reboot may show a Keychain prompt. Click **Always Allow** once and subsequent calls are silent.
- Rotate: re-run the `add-generic-password` command (`-U` updates in place). Inspect: `security find-generic-password -s deep-router -a openrouter -w`.

## Usage

### Pick your models

```bash
deep-claude pick
```

```
  deep-claude — providers   ↵ open · e set key · ⌃S save & quit
  ────────────────────────────────────────────────

  ▸ OpenRouter            key ✓   3 selected
    z-ai-glm              key ✓   3 selected
    deepseek-custom       key ✓   2 selected

    🎚 Map /model slots
    ＋ Add provider

  ↑/↓ move · ↵ open · e set key · ⌃S save & quit · esc quit
```

The picker is **two-level**. The first screen lists every provider; `↑/↓` (or `←/→`) move, `e` sets the
selected provider's API key — **including OpenRouter's own key** — and `＋ Add provider` adds a new
endpoint inline (name → URL → key). Press `↵` on a provider to drill into its model list and pick models
(`space`/`↵` toggle, type to search). Do this for as many providers as you like.

Then open **`🎚 Map /model slots`** — one global screen that maps Claude Code's fixed in-session `/model`
tiers (Default / Opus / Sonnet / Haiku / Fable) to your chosen models, **drawing from every provider at
once**:

```
  Map /model slots   ← back · ⌃S save & quit
  Each tier can run a model from ANY provider — the proxy routes it with your key.
  In-session /model switches between them. 8 model(s) available across providers.

  ❯ Default ‹ x-ai/grok-4.3 ›            ← runs when you don't pass --model
    Opus     z-ai-glm/glm-5-turbo        (direct to z.ai, your key)
    Sonnet   deepseek-custom/deepseek-v4-pro   (direct to DeepSeek)
    Haiku    x-ai/grok-4.3               (OpenRouter)
    Fable    (use default)
  ↑/↓ tier · ←/→ choose model (any provider) · esc back · ⌃S save & quit
```

Claude Code's `/model` only exposes those fixed tiers — you can't add arbitrary-named entries — so this
maps each tier onto a real model. **Crucially, different tiers can come from different providers**: the
proxy routes each id with the right key (endpoint models are sent direct as `<provider>/<model>`,
OpenRouter ids go upstream), so one `deep-claude` session can run Opus on GLM, Sonnet on DeepSeek, and
Haiku on Grok — switch between them live with `/model`. `↑/↓` pick a tier, `←/→` choose the model
(optional tiers can be "(use default)"). **`Ctrl-S` saves and quits.** The mapping is persistent.

This writes a unified `ROUTER_MODELS` (every selected model, endpoints prefixed) plus `ROUTER_ALIASES` /
`ROUTER_DEFAULT_MODEL` / `ROUTER_SLOT_*` that the proxy consumes; each endpoint also keeps
`DEEP_EP_MODELS_<name>` / `DEEP_EP_DEFAULT_<name>` for the single-provider `deep-claude --endpoint <name>`
shortcut. Curate non-interactively if you prefer:

```bash
deep-claude models add google/gemini-3.5-flash      gemini   # id + optional alias
deep-claude models add anthropic/claude-opus-4.8    opus
deep-claude models default gemini
deep-claude models list
deep-claude models remove opus
```

(Model ids change over time — check [openrouter.ai/models](https://openrouter.ai/models) for current slugs.)

### Run

```bash
deep-claude                                # default model (ROUTER_DEFAULT_MODEL)
deep-claude --model opus                   # by alias
deep-claude --model x-ai/grok-4.1          # or a full OpenRouter id
deep-claude -p "explain this repo"         # non-interactive
deep-claude --model gemini -- -p "hi"      # -- stops deep-claude's own option parsing
```

### Switching models inside a session

Claude Code's in-session `/model` picker is Claude-centric — its gateway discovery only surfaces `anthropic/*` models. So `deep-claude pick` also lets you **assign your models to Claude Code's switch slots** (Default + Fable/Opus/Sonnet/Haiku). Those slots accept *any* provider, so after assigning (say) Gemini→Opus and Grok→Sonnet, you can flip between them mid-session with `/model` (the rows are labelled "Custom Opus/Sonnet/Haiku model" but point at whatever you assigned).

Three ways to reach your models, then:

- **`/model`** — your slot-assigned models (any provider) + any Claude models (gateway).
- **`deep-claude --model <alias>`** — launch a session on *any* of your curated models.
- **Sub-agents** — a sub-agent's `model:` frontmatter can pin *any* model in your set; the orchestrator and sub-agents run on different models concurrently (verified end-to-end via the proxy).

Everything other than `deep-claude`'s own flags passes straight through to `claude`.

### Use your existing Claude setup (skills, plugins, MCP, …)

Config inheritance is **ON by default** — your `~/.claude` skills, agents, workflows, rules, hooks, plugins, `settings.json`, `CLAUDE.md`, and MCP servers are linked into the isolated home every launch without any flags. Your Anthropic login and credentials are never imported. To opt out:

```bash
deep-claude --no-inherit            # one run
# …or persist it:
echo 'DEEP_CLAUDE_INHERIT="0"' >> .env
```

When inheriting `settings.json`, deep-claude strips any top-level `model` pin, `apiKeyHelper`, `awsAuthRefresh`, and all `ANTHROPIC_*` env keys from the inherited file so they can never shadow routing — non-Anthropic env keys (e.g. `PERPLEXITY_API_KEY`) are preserved so inherited MCP servers keep working. Routing env is then overlaid last by deep-claude, so routing always wins.

### Session sharing with `~/.claude` (ON by default)

Sessions started in deep-claude are **resumable with plain `claude --resume`** and vice-versa. The transcript store (`projects/`) in the isolated home is symlinked to `~/.claude/projects/` on every launch. On first run, any existing isolated transcripts are migrated into the shared store (never clobbering real-home files). Auth files (`settings.json`, `.credentials.json`), `sessions/`, and `file-history/` stay isolated.

To opt out:

```bash
deep-claude --no-share-sessions     # one run
# …or persist it:
echo 'DEEP_CLAUDE_SHARE_SESSIONS="0"' >> .env
```

### Filesystem sandbox (opt-in)

Confine Claude Code's writes to your working directory, deep-claude's state dir, and `/tmp` — reads, exec, and network are unrestricted:

```bash
deep-claude --sandbox -p "refactor this"     # enable for this run
DEEP_CLAUDE_SANDBOX=1 deep-claude            # or via env
DEEP_CLAUDE_SANDBOX_NET=loopback deep-claude --sandbox    # loopback-only net (macOS)
```

Uses `sandbox-exec` on macOS, `bwrap` on Linux. **Fail-closed**: if `--sandbox` is requested but the mechanism is not on PATH, deep-claude exits non-zero and never runs unconfined. Disable explicitly with `--no-sandbox`.

> **Non-Claude reasoning models:** OpenRouter's Anthropic skin emits (out-of-order) `redacted_thinking`
> blocks for models like Gemini, which would otherwise make Claude Code show an empty response. The
> proxy strips those blocks for non-`anthropic/` models so the visible text comes through; genuine
> Claude models pass through untouched. Disable with `ROUTER_KEEP_THINKING=1`.

## Personal endpoints

OpenRouter is the default, but any **Anthropic-compatible** endpoint — DeepSeek-direct, a local
Ollama, a self-hosted gateway — is a second-tier option. The quickest way is the **interactive**
form — it prompts for a name, the base URL, and your key (input hidden), stores the key in your
Keychain (or `.env`), and saves the endpoint:

```bash
deep-claude endpoints add        # prompts: Name → Base URL → API key
```

Or pass it all on one line:

```bash
deep-claude endpoints add deepseek https://api.deepseek.com/anthropic DEEPSEEK_API_KEY
deep-claude endpoints add ollama   http://localhost:11434             # no key needed
deep-claude endpoints list

deep-claude --endpoint deepseek --model deepseek-v4-pro
deep-claude --endpoint ollama   --model qwen3-coder -p "write a test"
```

The `deep-claude cli` provider picker also adds endpoints inline — `＋ Add provider` (name → URL → key),
which fetches the endpoint's models and drops you straight into selecting them.

#### Multiple models per endpoint, selectable in the CLI

The interactive `endpoints add` also asks for a **comma-separated list of model ids** and a default.
With those saved, the endpoint behaves like the OpenRouter set — you don't pass `--model` every time,
and you can switch between the models in-session:

```bash
deep-claude endpoints add
#   Name:   deepseek-custom
#   URL:    https://api.deepseek.com/anthropic
#   Key:    sk-…                       (hidden)
#   Models: deepseek-chat,deepseek-reasoner
#   Default: deepseek-chat

deep-claude --endpoint deepseek-custom                       # launches on the default model
deep-claude --endpoint deepseek-custom --model deepseek-reasoner   # pick one at launch
```

**Browse the endpoint's catalog** instead of typing ids. The interactive add offers it, or run it any
time against a saved endpoint — it's the same multi-select TUI as the OpenRouter picker, fed by the
endpoint's own `/v1/models`:

```bash
deep-claude endpoints pick deepseek-custom    # multi-select models + a default
```

(If the endpoint exposes no model-list API, the picker says so and you fall back to typing ids.)

**Selecting in the CLI** — three ways:

- **At launch:** `--model <id>` picks any of the endpoint's models for that run; omit it to get the default.
- **In-session:** the configured models are mapped onto Claude Code's `/model` switch slots, so `/model`
  flips between them live (the status line shows which one is active).
- **Review what's set:** `deep-claude endpoints list` prints each endpoint's models and default.

The third argument names the **environment variable** holding that endpoint's key (resolved from your
shell or `.env`). Or skip the save and pass it inline:

```bash
deep-claude --base-url https://api.deepseek.com/anthropic --api-key-env DEEPSEEK_API_KEY \
  --model deepseek-v4-pro -p "hello"
```

The third argument names the **environment variable** holding the key; deep-claude resolves it from
your shell, `.env`, or Keychain (`security add-generic-password -s deep-claude -a <name> -U -w`).

### Direct routing inside OpenRouter mode (faster providers)

Here's the useful part: a saved endpoint **also becomes a per-model direct route** in the default
OpenRouter flow. The endpoint *name* is matched against a model's provider prefix — so once you've
added a `deepseek` endpoint, any **`deepseek/*`** model you select routes straight to your DeepSeek
API (with your key), while every other model still goes through OpenRouter. Same session, mixed
routing, chosen per model:

```bash
deep-claude endpoints add deepseek https://api.deepseek.com/anthropic DEEPSEEK_API_KEY
deep-claude --model deepseek      # deepseek/* → your DeepSeek API (fast)
deep-claude --model gemini        # google/*   → OpenRouter
```

Why bother? Benchmarked on the same model, **DeepSeek-direct ran ~2× faster than `deepseek/*` via
OpenRouter** (≈87 vs ≈44 tok/s, half the time-to-first-token). So you get OpenRouter's breadth for
everything, and your own credentials' speed for the providers you have keys for. The proxy strips the
provider prefix for the direct call (`deepseek/deepseek-v4-pro` → `deepseek-v4-pro`).

A note on DeepSeek specifically: routing it *through* OpenRouter doesn't improve privacy — OpenRouter
becomes an additional party. A personal endpoint gives you the fewest hops *and* the speed.

**Know which route you're on.** deep-claude adds a status line to the session showing the live route —
`🐋 <model> · ⚡ direct (deepseek)` when on a direct provider, or `· openrouter` otherwise. It tracks
your `/model` switches. (Claude Code's `/model` picker itself can't be relabelled, so this is the
reliable indicator.) It never overrides a status line you already have, and with `--inherit` your real
`settings.json` is copy-merged, not modified. Disable with `DEEP_CLAUDE_STATUSLINE=0`.

## How it works

**OpenRouter mode (default).** `deep-claude` boots a tiny local proxy (`bin/deep-claude-proxy`, no
dependencies beyond `node`) in front of OpenRouter's native Anthropic Messages endpoint, then points
Claude Code at it:

```
ANTHROPIC_BASE_URL=http://127.0.0.1:<free port>   # the local proxy (8787+, auto-chosen)
ANTHROPIC_AUTH_TOKEN=router                       # the proxy injects your real OpenRouter key
CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1       # surfaces your Claude models in /model
ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL  # your slot assignments (any provider)
```

It picks a free local port (8787 is often taken by other dev servers). The proxy resolves model
aliases, enforces your curated allow-list, injects the server-side OpenRouter key, strips the
Anthropic-only `context_management` field (which 400s on non-Claude models), and strips the
out-of-order `redacted_thinking` blocks described above. Its log goes to `.deep-claude-home/proxy.log`.

> **About Claude Code's `/model` picker:** its built-in gateway discovery only lists `anthropic/*`
> models. Non-Claude models reach `/model` via the **switch slots** you assign in `deep-claude pick`;
> any model is always reachable with `deep-claude --model <alias>` or a sub-agent's `model:` field.

**Personal-endpoint mode.** `deep-claude --endpoint …` / `--base-url …` sets `ANTHROPIC_BASE_URL` to
the endpoint and talks to it directly — no proxy.

**State isolation (both modes).** Claude Code's state — session history, projects, MCP config,
`~/.claude.json` — is redirected via `CLAUDE_CONFIG_DIR` and the XDG dirs into `<repo>/.deep-claude-home/`,
so your real `~/.claude/` is untouched. `$HOME` is deliberately left alone so the macOS login keychain
keeps working.

### Files

| Path                     | Purpose                                                              |
| ------------------------ | ------------------------------------------------------------------- |
| `bin/deep-claude`        | The one command: run, `cli`, `pick`, `models`, `endpoints`.         |
| `bin/deep-claude-cli`    | The Node setup wizard's key-entry step (internal).                  |
| `bin/deep-claude-pick`   | The Node interactive model picker + slot assignment (internal).     |
| `bin/deep-claude-proxy`  | The Node Anthropic→OpenRouter passthrough proxy (internal).         |
| `bin/deep-claude-statusline` | The Node status-line script (live route indicator) (internal).  |
| `deep-claude`            | Top-level shim that `exec`s `bin/deep-claude`.                      |
| `install.sh`             | Symlinks `deep-claude` into `~/.local/bin`.                         |
| `test.sh`                | Syntax checks, arg-passthrough, CLI, and live proxy tests.          |
| `.env.example`           | Template; copy to `.env` for keys, the curated set, and endpoints.  |
| `.deep-claude-home/`     | gitignored; isolated Claude Code state.                             |

## Troubleshooting

**`deep-claude: missing OPENROUTER_API_KEY`**
No key in shell env, `.env`, or Keychain (service `deep-router`, account `openrouter`). See [Configuring the key](#configuring-the-key).

**`deep-claude: no model selected`**
You haven't picked any models yet. Run `deep-claude pick` (or `deep-claude models add <id> <alias>`), or pass `--model <id>` explicitly.

**A non-Claude model returns an empty response**
That's the out-of-order `redacted_thinking` quirk — the proxy strips it for non-`anthropic/` models by default. If you've set `ROUTER_KEEP_THINKING=1`, unset it. (Personal endpoints don't strip; use OpenRouter mode for non-Claude reasoning models.)

**Keychain prompt appears repeatedly**
Click **Always Allow** once. macOS pins the access ACL to the `security` binary, so subsequent reads are silent — even across reboots.

**Argument passthrough confusion**
`deep-claude` eats its own flags (`--model`, `--endpoint`, `--base-url`, …); everything else passes through. Use `--` to be explicit: `deep-claude --model gemini -- -p "hello"`.

**See what would run without running it**
```bash
CLAUDE_BIN=/bin/echo deep-claude --base-url http://x --api-key k --model m -p hi
# prints: --model m -p hi
```

## Development

```bash
./test.sh
```

The tests use `CLAUDE_BIN=/bin/echo` to verify argument handling without invoking real binaries, and
spin up a fake upstream to exercise the proxy. They cover:

- Bash syntax (`bash -n`) and `node --check` for every script
- Run-arg handling for OpenRouter and personal-endpoint modes (incl. the `--` separator)
- The `models` and `endpoints` curation CLIs
- Proxy behavior: alias resolution, `context_management` stripping, beta-header sanitizing, key injection, and thinking-block stripping for non-Claude models

## License

MIT — see [LICENSE](LICENSE).
