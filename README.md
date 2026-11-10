<p align="center">
  <img src="assets/banner.png" alt="deep-claude" width="100%">
</p>

# deep-claude 🐋

`deep-claude` runs [Claude Code](https://claude.com/claude-code) on other models. It points Claude Code at
[OpenRouter](https://openrouter.ai) (Gemini, GPT, DeepSeek, Grok, Qwen, Claude and others) through a small
local proxy, or directly at any Anthropic-compatible endpoint such as DeepSeek, a local Ollama, or a
self-hosted gateway. Claude Code's state is redirected into a private directory, so your normal Claude
config and Anthropic login are never read or changed.

**Status:** working tool, released as v1.1.0 (see [CHANGELOG.md](CHANGELOG.md)). Linux and macOS.
Website: [dennisonbertram.github.io/deep-claude](https://dennisonbertram.github.io/deep-claude/).

```console
$ deep-claude pick                                          # choose models from OpenRouter's catalog
$ deep-claude -p "refactor this module and run the tests"   # Claude Code on your default model
$ deep-claude --model opus -p "review this diff"            # switch model per run
$ deep-claude --endpoint deepseek --model deepseek-v4-pro   # or hit a provider directly
```

What you get:

- **Any model, one key.** An OpenRouter key covers hundreds of models. Any Anthropic-compatible URL also works as a [personal endpoint](#personal-endpoints).
- **Model picker.** `deep-claude pick` is a searchable multi-select over the catalog and assigns your picks to Claude Code's `/model` slots, so you can switch models mid-session.
- **Mixed models in one workflow.** A sub-agent's `model:` can name any model in your set, so the orchestrator and its sub-agents can run on different models.
- **Your setup carries over.** Skills, agents, plugins, hooks and MCP servers from `~/.claude` are inherited by default (your Anthropic login is not). Use `--no-inherit` to turn this off.
- **Isolated state.** Session history, projects and MCP config live in a private state directory. `$HOME` is left alone so the macOS keychain keeps working.

## Install

Requirements: macOS or Linux, `claude` on `PATH` ([install Claude Code](https://claude.com/claude-code)), [Node.js](https://nodejs.org/), and an [OpenRouter API key](https://openrouter.ai/keys) (or a key for any personal endpoint you add).

```bash
git clone https://github.com/dennisonbertram/deep-claude
cd deep-claude
./install.sh
export PATH="$HOME/.local/bin:$PATH"     # if it isn't already
```

Then run it. The first run opens the provider picker: press `e` on OpenRouter to paste your key, then `↵` to pick models.

```bash
deep-claude              # first run → setup wizard, then starts the session
```

Re-run the wizard any time with `deep-claude cli`, change models with `deep-claude pick`, and choose a different default with `deep-claude --model <alias>`.

| Command                       | What it does                                                  |
| ----------------------------- | ------------------------------------------------------------ |
| `deep-claude`                 | Run Claude Code on your default model (first run: setup wizard). |
| `deep-claude --model X`       | Run on a specific model (alias or full id) for this session. |
| `deep-claude cli`             | The setup wizard: enter your key and pick models.            |
| `deep-claude pick`            | Interactive model picker over OpenRouter's catalog.          |
| `deep-claude models …`        | Curate the model set non-interactively.                      |
| `deep-claude endpoints …`     | Manage personal (non-OpenRouter) endpoints.                  |
| `deep-claude --endpoint NAME` | Run on a saved personal endpoint.                            |
| `deep-claude --no-inherit`    | Run without linking your real `~/.claude` (default: inherit on). |

Anything that is not a `deep-claude` flag passes straight through to `claude`.

## Repo map

| Path                         | Purpose                                                             |
| ---------------------------- | ------------------------------------------------------------------- |
| `bin/deep-claude`            | The one command: run, `cli`, `pick`, `models`, `endpoints`.         |
| `bin/deep-claude-cli`        | Setup wizard key-entry step (internal).                             |
| `bin/deep-claude-pick`       | Interactive model picker and slot assignment (internal).            |
| `bin/deep-claude-proxy`      | Anthropic-to-OpenRouter passthrough proxy (internal).               |
| `bin/deep-claude-statusline` | Status-line script showing the live route (internal).               |
| `deep-claude`                | Top-level shim that `exec`s `bin/deep-claude`.                      |
| `install.sh`                 | Symlinks `deep-claude` into `~/.local/bin`.                         |
| `test.sh`                    | Syntax checks, argument passthrough, CLI and live proxy tests.      |
| `.env.example`               | Template; copy to `.env` for keys, the curated set and endpoints.   |
| `docs/`                      | Source of the GitHub Pages site.                                    |

## Configuring the key

`deep-claude` looks for `OPENROUTER_API_KEY` in this order:

1. **Shell environment:** `export OPENROUTER_API_KEY="sk-or-..."`
2. **`.env` next to this repo:** `cp .env.example .env && $EDITOR .env`
3. **macOS Keychain:** `security add-generic-password -s deep-router -a openrouter -U -w`

Keychain details: service `deep-router`, account `openrouter`. The `security` binary handles all reads, so the key never appears in `.env`, shell history or process listings. The first read after a reboot may show a prompt; click **Always Allow** once. To rotate the key, re-run the `add-generic-password` command (`-U` updates in place). To inspect it: `security find-generic-password -s deep-router -a openrouter -w`.

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

The picker has two levels. The first screen lists every provider. `e` sets that provider's API key (including OpenRouter's), and `＋ Add provider` adds a new endpoint inline (name, URL, key). Press `↵` on a provider to open its model list, where `space`/`↵` toggle a model and typing searches. `⌃S` saves everything.

`🎚 Map /model slots` maps Claude Code's fixed `/model` tiers (Default, Opus, Sonnet, Haiku, Fable) to your chosen models. Tiers can use models from different providers, and the proxy routes each one with the right key:

```
  ❯ Default ‹ x-ai/grok-4.3 ›            ← runs when you don't pass --model
    Opus     z-ai-glm/glm-5-turbo        (direct to z.ai, your key)
    Sonnet   deepseek-custom/deepseek-v4-pro   (direct to DeepSeek)
    Haiku    x-ai/grok-4.3               (OpenRouter)
    Fable    (use default)
```

Claude Code's built-in `/model` discovery only lists `anthropic/*` models, which is why the slot mapping exists. The mapping is saved as `ROUTER_MODELS`, `ROUTER_ALIASES`, `ROUTER_DEFAULT_MODEL` and `ROUTER_SLOT_*` in `.env`; each endpoint also keeps `DEEP_EP_MODELS_<name>` and `DEEP_EP_DEFAULT_<name>`.

To curate models without the TUI:

```bash
deep-claude models add google/gemini-3.5-flash      gemini   # id + optional alias
deep-claude models add anthropic/claude-opus-4.8    opus
deep-claude models default gemini
deep-claude models list
deep-claude models remove opus
```

Model ids change over time; check [openrouter.ai/models](https://openrouter.ai/models) for current slugs.

### Run

```bash
deep-claude                                # default model (ROUTER_DEFAULT_MODEL)
deep-claude --model opus                   # by alias
deep-claude --model x-ai/grok-4.1          # or a full OpenRouter id
deep-claude -p "explain this repo"         # non-interactive
deep-claude --model gemini -- -p "hi"      # -- stops deep-claude's own option parsing
```

### Use your existing Claude setup

Inheritance is on by default. Your `~/.claude` skills, agents, workflows, rules, hooks, plugins, `settings.json`, `CLAUDE.md` and MCP servers are linked into the isolated home on every launch. Your Anthropic login and credentials are never imported. To opt out:

```bash
deep-claude --no-inherit            # one run
echo 'DEEP_CLAUDE_INHERIT="0"' >> .env   # persist it
```

When inheriting `settings.json`, deep-claude removes any top-level `model` pin, `apiKeyHelper`, `awsAuthRefresh` and all `ANTHROPIC_*` env keys so they cannot override routing. Other env keys (for example `PERPLEXITY_API_KEY`) are kept so inherited MCP servers keep working.

### Session sharing with `~/.claude` (on by default)

Sessions started in deep-claude can be resumed with plain `claude --resume`, and the reverse. The `projects/` transcript store in the isolated home is symlinked to `~/.claude/projects/` on each launch. On first run, existing isolated transcripts are migrated into the shared store without overwriting real-home files. `settings.json`, `.credentials.json`, `sessions/` and `file-history/` stay isolated. To opt out:

```bash
deep-claude --no-share-sessions     # one run
echo 'DEEP_CLAUDE_SHARE_SESSIONS="0"' >> .env   # persist it
```

### Filesystem sandbox (opt-in)

Confine Claude Code's writes to the working directory, deep-claude's state directory and `/tmp`. Reads, exec and network are unrestricted:

```bash
deep-claude --sandbox -p "refactor this"     # enable for this run
DEEP_CLAUDE_SANDBOX=1 deep-claude            # or via env
DEEP_CLAUDE_SANDBOX_NET=loopback deep-claude --sandbox    # loopback-only net (macOS)
```

It uses `sandbox-exec` on macOS and `bwrap` on Linux. If `--sandbox` is requested but the tool is not on `PATH`, deep-claude exits non-zero and does not run. Disable explicitly with `--no-sandbox`.

## Personal endpoints

Any Anthropic-compatible endpoint (DeepSeek, a local Ollama, a self-hosted gateway) can be added. The interactive form prompts for a name, base URL and key (input hidden), stores the key in your Keychain or `.env`, and saves the endpoint:

```bash
deep-claude endpoints add        # prompts: Name → Base URL → API key
```

Or in one line, where the third argument is the name of the environment variable that holds the key (resolved from your shell, `.env` or Keychain):

```bash
deep-claude endpoints add deepseek https://api.deepseek.com/anthropic DEEPSEEK_API_KEY
deep-claude endpoints add ollama   http://localhost:11434             # no key needed
deep-claude endpoints list

deep-claude --endpoint deepseek --model deepseek-v4-pro
deep-claude --endpoint ollama   --model qwen3-coder -p "write a test"
```

To skip saving, pass everything inline:

```bash
deep-claude --base-url https://api.deepseek.com/anthropic --api-key-env DEEPSEEK_API_KEY \
  --model deepseek-v4-pro -p "hello"
```

### Several models per endpoint

The interactive `endpoints add` also asks for a comma-separated list of model ids and a default:

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

To browse the endpoint's own `/v1/models` list instead of typing ids, run `deep-claude endpoints pick deepseek-custom` (multi-select plus a default). If the endpoint has no model-list API, the picker says so and you type ids instead. Configured models are mapped onto the `/model` slots, and `deep-claude endpoints list` prints each endpoint's models and default.

### Direct routing inside OpenRouter mode

A saved endpoint also becomes a per-model direct route in the default OpenRouter flow. The endpoint name is matched against a model's provider prefix, so once you add a `deepseek` endpoint, any `deepseek/*` model routes straight to your DeepSeek API with your key, and every other model still goes through OpenRouter:

```bash
deep-claude endpoints add deepseek https://api.deepseek.com/anthropic DEEPSEEK_API_KEY
deep-claude --model deepseek      # deepseek/* → your DeepSeek API
deep-claude --model gemini        # google/*   → OpenRouter
```

The proxy strips the provider prefix for the direct call (`deepseek/deepseek-v4-pro` becomes `deepseek-v4-pro`). The author's benchmark of the same model measured DeepSeek-direct at about 87 tok/s against about 44 tok/s through OpenRouter, with half the time-to-first-token. The benchmark data is not in this repo.

The session status line shows the live route (`🐋 <model> · ⚡ direct (deepseek)` or `· openrouter`) and follows `/model` switches. It never overrides a status line you already have. Disable it with `DEEP_CLAUDE_STATUSLINE=0`.

## How it works

**OpenRouter mode (default).** `deep-claude` starts a local proxy (`bin/deep-claude-proxy`, Node only, no dependencies) in front of OpenRouter's Anthropic Messages endpoint and points Claude Code at it:

```
ANTHROPIC_BASE_URL=http://127.0.0.1:<free port>   # the local proxy (8787+, auto-chosen)
ANTHROPIC_AUTH_TOKEN=router                       # the proxy injects your real OpenRouter key
CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1       # surfaces your Claude models in /model
ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL  # your slot assignments (any provider)
```

The proxy resolves model aliases, enforces your curated allow-list, injects the OpenRouter key, strips the Anthropic-only `context_management` field (which returns a 400 on non-Claude models), and strips out-of-order `redacted_thinking` blocks that OpenRouter emits for models like Gemini and that otherwise leave Claude Code showing an empty response. Real Claude models pass through untouched; set `ROUTER_KEEP_THINKING=1` to keep the thinking blocks. The proxy log is `.deep-claude-home/proxy.log`.

**Personal-endpoint mode.** `--endpoint` or `--base-url` sets `ANTHROPIC_BASE_URL` to the endpoint and talks to it directly, with no proxy.

**State isolation (both modes).** Claude Code's state is redirected with `CLAUDE_CONFIG_DIR` and the XDG directories into `<repo>/.deep-claude-home/` (gitignored), so your real `~/.claude/` is untouched.

## Troubleshooting

**`deep-claude: missing OPENROUTER_API_KEY`**
No key in the shell environment, `.env` or Keychain. See [Configuring the key](#configuring-the-key).

**`deep-claude: no model selected`**
You have not picked a model. Run `deep-claude pick` (or `deep-claude models add <id> <alias>`), or pass `--model <id>`.

**A non-Claude model returns an empty response**
This is the `redacted_thinking` issue described above. Unset `ROUTER_KEEP_THINKING` if you set it. Personal endpoints do not strip these blocks, so use OpenRouter mode for non-Claude reasoning models.

**Keychain prompt appears repeatedly**
Click **Always Allow** once. macOS ties the access list to the `security` binary, so later reads are silent.

**Argument passthrough**
`deep-claude` consumes its own flags (`--model`, `--endpoint`, `--base-url`, and so on) and passes the rest to `claude`. Use `--` to be explicit: `deep-claude --model gemini -- -p "hello"`.

**See what would run without running it**
```bash
CLAUDE_BIN=/bin/echo deep-claude --base-url http://x --api-key k --model m -p hi
# prints: --model m -p hi
```

## Development

```bash
./test.sh
```

The tests use `CLAUDE_BIN=/bin/echo` to check argument handling without running real binaries, and start a fake upstream to exercise the proxy. They cover:

- Bash syntax (`bash -n`) and `node --check` for every script
- Run-argument handling for OpenRouter and personal-endpoint modes, including the `--` separator
- The `models` and `endpoints` curation commands
- Proxy behavior: alias resolution, `context_management` stripping, beta-header sanitizing, key injection and thinking-block stripping for non-Claude models

## License

MIT. See [LICENSE](LICENSE).
