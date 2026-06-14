<p align="center">
  <img src="assets/banner.png" alt="deep-claude" width="100%">
</p>

<h1 align="center">deep-claude 🐋</h1>

<p align="center">
  <b>Drive Claude Code with DeepSeek's V4 models.</b><br>
  Same harness you already love. A different mind behind it. Cleanly isolated, optionally sandboxed.
</p>

<p align="center">
  <a href="https://dennisonbertram.github.io/deep-claude/">Website</a> ·
  <a href="#quickstart">Install</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#configuring-the-api-key">API key</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#troubleshooting">Troubleshooting</a>
</p>

<p align="center">
  <code>deep-claude</code> points <a href="https://claude.com/claude-code">Claude Code</a> at DeepSeek's
  Anthropic-compatible endpoint and redirects its state into a private home, so your real
  Anthropic login is never touched. Type <code>deep-claude</code> followed by any normal
  <code>claude</code> arguments and you get the full agentic harness — tools, MCP, slash
  commands, sub-agents, the works — running on <code>deepseek-v4-pro</code>.
</p>

```console
$ deep-claude -p "refactor this module and run the tests"
…the Claude Code agent loop you know — planning, editing, running — on DeepSeek V4…

$ deep-claude --open-router --model gemini -p "triage these failing tests"
…same harness, on any OpenRouter model you've picked…
```

## Why run DeepSeek in the Claude harness?

Claude Code is one of the best agentic coding harnesses there is: the planning loop, tool
use, MCP servers, sub-agents, permissions, and slash commands are all _harness_, not
_model_. DeepSeek's V4 models speak the Anthropic API, so you can keep every bit of that
machinery and just swap the brain.

- **Run real workflows, not just chat.** Multi-step edits, test loops, MCP tools, and
  sub-agents all work — DeepSeek V4 drives the same agent loop Claude Code gives you.
- **Genuinely strong at code.** V4-pro is sharp on reasoning, refactors, and long-context
  work; `flash` is fast and cheap for triage, scripting, and bulk passes.
- **Cost-effective.** Pay DeepSeek's API rates for heavy autonomous runs while keeping your
  Anthropic subscription pristine for everything else.
- **Zero contamination.** Session history, projects, MCP config, and `~/.claude.json` live
  in a private state dir — your normal Claude Code setup is untouched.
- **Any model via OpenRouter.** `deep-claude --open-router` drives the same harness with
  Gemini, GPT, DeepSeek, Grok, Qwen, Claude, and more — pick the ones you want with a
  built-in model picker.

> **Your normal setup is safe.** The wrappers only set a few environment variables and
> redirect Claude Code's state directory per launch. They never read, move, or modify your
> Anthropic credentials.

| Command       | What it does                                                                 |
| ------------- | ---------------------------------------------------------------------------- |
| `deep-claude` | Runs `claude` against DeepSeek (default) or, with `--open-router`, OpenRouter. |
| `deep-router` | Curate the OpenRouter model set (`pick`, `models …`).                        |

## Contents

- [Requirements](#requirements)
- [Quickstart](#quickstart)
- [Configuring the API key](#configuring-the-api-key)
- [Usage](#usage)
- [OpenRouter mode](#openrouter-mode)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## Requirements

- **macOS or Linux**
- **[Claude Code](https://claude.com/claude-code)** — `claude` on `PATH`. Install via the [official installer](https://claude.com/claude-code) or `npm i -g @anthropic-ai/claude-code`.
- **An API key** — a [DeepSeek](https://platform.deepseek.com/) key for the default mode, and/or an [OpenRouter](https://openrouter.ai/keys) key for `--open-router`.
- **[Node.js](https://nodejs.org/)** — only required for `--open-router` (the local proxy and model picker run on `node`).

## Quickstart

```bash
git clone https://github.com/dennisonbertram/deep-claude
cd deep-claude
./install.sh
```

This symlinks `deep-claude` and `deep-router` into `~/.local/bin`. Make sure that directory is on your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Set your DeepSeek API key (Keychain is recommended on macOS — see all options below):

```bash
security add-generic-password -s deep-claude -a deepseek -U -w
# (paste the key, then return)
```

Run it:

```bash
deep-claude              # interactive session on deepseek-v4-pro
```

Or use OpenRouter ([OpenRouter mode](#openrouter-mode)):

```bash
deep-router pick                 # choose your models (interactive)
deep-claude --open-router        # run Claude Code on them
```

## Configuring the API key

The wrappers look for `DEEPSEEK_API_KEY` in this order:

1. **Shell environment** — `export DEEPSEEK_API_KEY="sk-..."`
2. **`.env` next to this repo** — `cp .env.example .env && $EDITOR .env`
3. **macOS Keychain** — `security add-generic-password -s deep-claude -a deepseek -U -w`

The literal placeholder `sk-...` (as committed in `.env.example`) is treated as **unset**, so a stale `.env` won't shadow a real Keychain entry.

### Keychain details (macOS)

- Service: `deep-claude` — Account: `deepseek`
- The `security` binary handles all reads, so the key never lives in `.env`, shell history, or process listings.
- The first read after a reboot may show a Keychain access prompt. Click **Always Allow** once and subsequent calls are silent.
- To rotate the key: re-run the `security add-generic-password` command (the `-U` flag updates in place).
- To inspect: `security find-generic-password -s deep-claude -a deepseek -w`
- To remove: `security delete-generic-password -s deep-claude -a deepseek`

### `.env` details

Copy `.env.example` to `.env` (gitignored) and set `DEEPSEEK_API_KEY=...`. You can also override the executables:

```bash
# Optional
CLAUDE_BIN=claude   # override the claude executable
```

## Usage

### `deep-claude` — unsandboxed

```bash
deep-claude                                # interactive, deepseek-v4-pro (default)
deep-claude --model flash                  # deepseek-v4-flash
deep-claude --model deepseek-v4-pro        # full model name also works
deep-claude -p "hello"                     # non-interactive prompt
deep-claude --model flash -- -p "hello"    # -- stops deep-claude option parsing
```

Model aliases:

- `pro` → `deepseek-v4-pro` (default)
- `flash` → `deepseek-v4-flash`

All arguments other than `--model` pass straight through to `claude`. Use `--` to be explicit when `claude`'s own flags overlap with the wrapper's.

## OpenRouter mode

`deep-claude --open-router` points Claude Code at [OpenRouter](https://openrouter.ai) instead of DeepSeek, so you can drive the same harness with Gemini, GPT, DeepSeek, Grok, Qwen, Claude, and anything else OpenRouter serves — including a curated `/model` picker and per-sub-agent model selection.

It works because OpenRouter exposes a **native Anthropic Messages endpoint** (`/api/v1/messages`) that accepts any model on the platform. A tiny local proxy (`bin/deep-router-proxy`, no dependencies beyond `node`) sits in front of it to (1) advertise only your curated model list to Claude Code's `/model` picker, and (2) strip the Anthropic-only `context_management` field that 400s on non-Claude models.

### Setup

Store your OpenRouter key (env, `.env`, or Keychain):

```bash
security add-generic-password -s deep-router -a openrouter -U -w   # macOS Keychain
# …or put OPENROUTER_API_KEY=sk-or-... in .env
```

Curate the models you want to expose. The easiest way is the interactive picker — a searchable, multi-select chooser over OpenRouter's whole catalog (with context windows and pricing), which writes your selection, auto-aliases, and default to `.env`:

```bash
deep-router pick
```

```
  Select models to expose  (these appear in Claude Code’s /model picker)
  17/337 models  ·  2 selected
  search: gemini▏

  ◉ google/gemini-2.5-flash      1.0M  $0.30/$2.50   Google: Gemini 2.5 Flash
> ◉ google/gemini-2.5-pro        1.0M  $1.25/$10     Google: Gemini 2.5 Pro
    ↑/↓ move · space select · type to search · ↵ confirm · esc cancel
```

Or edit the set non-interactively:

```bash
deep-router models add google/gemini-3.5-flash      gemini
deep-router models add anthropic/claude-opus-4.8    opus
deep-router models add deepseek/deepseek-v4-flash   deepseek
deep-router models default gemini
deep-router models list
```

(Model ids change over time — check [openrouter.ai/models](https://openrouter.ai/models) for current slugs.)

### Use

```bash
deep-claude --open-router                          # uses ROUTER_DEFAULT_MODEL
deep-claude --open-router --model opus             # by alias
deep-claude --open-router --model x-ai/grok-4.1    # or a full OpenRouter id
deep-claude --or -p "explain this repo"            # --or is shorthand
```

> **Non-Claude reasoning models:** OpenRouter's Anthropic skin injects (out-of-order) `redacted_thinking` blocks for models like Gemini, which would otherwise make Claude Code show an empty response. `deep-router-proxy` strips those blocks for non-`anthropic/` models so the visible text comes through; genuine Claude models pass through untouched. Disable with `ROUTER_KEEP_THINKING=1`.

Inside the session, `/model` lists exactly your curated set (via gateway discovery). And because a sub-agent's `model:` frontmatter accepts a full model id, a single workflow can run **many** OpenRouter models at once — the orchestrator on one model, sub-agents pinned to others.

### Curate

| Command | Effect |
| --- | --- |
| `deep-router models add <id> [alias]` | Add an OpenRouter model id (optionally with a `--model` alias) |
| `deep-router models remove <id\|alias>` | Drop a model (removing an alias also drops its model) |
| `deep-router models default <alias\|id>` | Set the model used when `--model` is omitted |
| `deep-router models list` | Show the curated set, aliases, and default |
| `deep-router serve` | Run the proxy in the foreground (rarely needed; `--open-router` boots it for you) |

These edit `ROUTER_MODELS` / `ROUTER_ALIASES` / `ROUTER_DEFAULT_MODEL` in `.env`.

> **Note:** OpenRouter recommends pinning the Anthropic first-party provider for genuine Claude models; non-Claude models work but won't honor Claude-only features like prompt caching.

## How it works

In the default (DeepSeek) mode, `deep-claude` sets:

```
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN=$DEEPSEEK_API_KEY
ANTHROPIC_API_KEY=$DEEPSEEK_API_KEY
ANTHROPIC_MODEL=<selected model>
```

…and points `CLAUDE_CONFIG_DIR` plus the XDG `config`/`cache`/`data`/`state` directories into `<repo>/.deep-claude-home/`. Claude Code's state — session history, projects, MCP configuration, `~/.claude.json` — lives there instead of in your real `~/.claude/`. (`$HOME` is deliberately left alone so the macOS login keychain keeps working.) Your normal Anthropic Claude Code setup is untouched.

With `--open-router`, `deep-claude` instead boots the local proxy (`bin/deep-router-proxy`), points `ANTHROPIC_BASE_URL` at it, enables gateway model discovery, and isolates state in `.deep-router-home/`. See [OpenRouter mode](#openrouter-mode).

### Files

| Path                       | Purpose                                                                  |
| -------------------------- | ------------------------------------------------------------------------ |
| `bin/deep-claude`          | The wrapper script (DeepSeek, or OpenRouter with `--open-router`)        |
| `bin/deep-router`          | Curation CLI (`pick`, `models add/remove/list/default`, `serve`)        |
| `bin/deep-router-proxy`    | The Node Anthropic→OpenRouter passthrough proxy                          |
| `bin/deep-router-pick`     | The Node interactive model picker (`deep-router pick`)                   |
| `deep-claude`, `deep-router` | Top-level shims that `exec bin/...`                                    |
| `install.sh`               | Symlinks `deep-claude`, `deep-router` into `~/.local/bin`                |
| `test.sh`                  | Syntax, arg-passthrough, and live proxy tests                            |
| `.env.example`             | Template; copy to `.env` to set keys and the curated model set           |
| `.deep-claude-home/`       | gitignored; isolated Claude Code state for DeepSeek mode                 |
| `.deep-router-home/`       | gitignored; isolated Claude Code state for OpenRouter mode               |

## Troubleshooting

**`deep-claude: missing DEEPSEEK_API_KEY`**
No key found in shell env, `.env`, or Keychain. Set one (see [Configuring the API key](#configuring-the-api-key)). Common gotcha: a `.env` file containing the literal `DEEPSEEK_API_KEY=sk-...` placeholder is treated as unset starting from `7629c8b` — if you're on an older version, replace `sk-...` with a real key or `rm .env`.

**`deep-claude: missing OPENROUTER_API_KEY for --open-router`**
No OpenRouter key found in shell env, `.env`, or Keychain (service `deep-router`, account `openrouter`). See [OpenRouter mode](#openrouter-mode).

**Keychain prompt appears repeatedly**
Click **Always Allow** once. macOS pins the access ACL to the `security` binary, so subsequent reads are silent — even across reboots.

**Argument passthrough confusion**
The wrappers eat `--model X` themselves. Everything else passes through. Use `--` to be explicit: `deep-claude --model flash -- -p "hello"` is unambiguous.

**Want to see what the wrapper would run without actually running it?**
Override the executable:
```bash
CLAUDE_BIN=/bin/echo deep-claude --model flash -p hi
# prints: --model deepseek-v4-flash -p hi
```

## Development

```bash
./test.sh
```

The tests use `CLAUDE_BIN=/bin/echo` to verify argument passthrough without invoking real binaries, and spin up a fake upstream to exercise the proxy. They cover:

- Bash syntax (`bash -n`) and `node --check` for every script
- Model alias resolution (`pro` / `flash` / explicit name)
- Argument passthrough (`-p`, `--output-format`, etc.) and the `--` separator
- The `deep-router` model-curation CLI (add/remove/default)
- Proxy behavior: alias resolution, `context_management` stripping, beta-header sanitizing, key injection, and thinking-block stripping for non-Claude models

## License

MIT — see [LICENSE](LICENSE).
