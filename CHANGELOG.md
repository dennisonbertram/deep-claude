# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Model-tier persistence into `settings.json`.** The 6 model-tier env vars
  (`ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL`,
  `ANTHROPIC_SMALL_FAST_MODEL`) are now written into the isolated
  `settings.json` `env` block on every launch (alongside the auth vars already
  persisted there). Any inherited top-level `model` pin is deleted so it can
  never shadow routing. In OpenRouter mode the gateway-discovery flags are also
  persisted, so sub-agents, `claude --resume`, and background/fleet spawns
  inherit the same model tiers as the main process without any re-setup.
- **Session sharing with real `~/.claude` (ON by default).** The transcript
  store (`projects/`) is now symlinked from the isolated home to the real
  `~/.claude/projects/` so sessions started in deep-claude are resumable with
  plain `claude --resume` — and real-home sessions are resumable inside
  deep-claude — without any extra flags. On first run, any existing isolated
  transcripts are migrated into the shared store (never clobbering a real-home
  file). Auth files (`settings.json`, `.credentials.json`), `sessions/`, and
  `file-history/` stay isolated. Opt out with `--no-share-sessions` or
  `DEEP_CLAUDE_SHARE_SESSIONS=0`.
- **Config inheritance ON by default.** Skills, agents, workflows, rules,
  hooks, plugins, and `CLAUDE.md` from `~/.claude` are now linked into the
  isolated home on every launch without needing `--inherit`. Opt out with
  `--no-inherit` or `DEEP_CLAUDE_INHERIT=0`. The existing `--inherit` flag is
  kept for backward compat (explicit `=1`).
- **Inherited settings hardened against routing leaks.** When basing
  `settings.json` off the real `~/.claude/settings.json`, the merge now:
  deletes any top-level `model` pin; deletes `apiKeyHelper` and
  `awsAuthRefresh` (which could trigger real Anthropic auth); and strips all
  `ANTHROPIC_*` env keys so inherited routing vars can never shadow deep-claude
  routing. Non-Anthropic env keys (e.g. `PERPLEXITY_API_KEY`) are kept so
  inherited MCP servers keep working. Routing/tier env is then overlaid last
  by `write_auth_env` + `write_model_env`, so routing always wins.
- **Opt-in filesystem sandbox (`--sandbox`).** On macOS uses `sandbox-exec`
  with a generated seatbelt profile; on Linux uses `bwrap`. Confines writes to
  `cwd/`, `STATE_DIR/`, and `tmp/`; reads, exec, and network are allowed.
  `DEEP_CLAUDE_SANDBOX_NET=loopback` (Darwin) restricts network to loopback.
  **Fail-closed**: if `--sandbox` is requested but the mechanism is not on
  PATH, deep-claude exits non-zero and never runs unconfined.
  Enable: `--sandbox`, or `DEEP_CLAUDE_SANDBOX=1` in `.env`.
- **`--share-sessions`/`--no-share-sessions` flags.** Runtime override for the
  default-on session sharing.
- **`--sandbox`/`--no-sandbox` flags.** Runtime enable/disable for the
  filesystem sandbox.
- **Tests** (all existing tests continue to pass):
  - Model-tier persistence for OpenRouter mode (all 6 keys, slot ids, no
    top-level model pin).
  - Model-tier persistence for direct-endpoint mode (all 6 keys, slot
    assignments, bare no-models case where all tiers = launch model).
  - Session sharing: symlink creation, first-migration of isolated transcripts,
    round-trip visibility, opt-out with `DEEP_CLAUDE_SHARE_SESSIONS=0`, and
    no-leak assertion that `~/.claude/settings.json` is byte-identical after a
    routed run.
  - Inherit default ON: skills linked without any flag; absent with
    `--no-inherit`. Must-never-override: evil `ANTHROPIC_BASE_URL` / `model`
    pin / `apiKeyHelper` from inherited `settings.json` are stripped; routing
    env points at the proxy; non-`ANTHROPIC_*` env keys survive.
  - Sandbox arg-plumbing (Darwin): stub `sandbox-exec` on PATH strips its own
    `-f profile` and execs the rest; `--model m -p hi` still arrives at the
    stub. Fail-closed: exits non-zero when `sandbox-exec` absent from PATH.
  - Arg forwarding: `--resume <id>` and `--continue` pass through to the stub.

- **Unified provider picker (`deep-claude cli`).** One two-level TUI manages every
  provider in one place: OpenRouter plus each personal endpoint. `↑/↓` move,
  `↵` opens a provider's catalog, `e` sets a provider's API key — including
  OpenRouter's own key, so no separate key prompt — and `＋ Add provider` adds a
  custom Anthropic/OpenAI-compatible endpoint inline (name → URL → key) and
  fetches its models.
- **Global cross-provider `/model` mapping.** A single `🎚 Map /model slots`
  screen maps Claude Code's fixed in-session `/model` tiers
  (Default/Opus/Sonnet/Haiku/Fable) to your chosen models, drawing from **every
  provider at once**. Different tiers can run on different providers in the same
  session (e.g. Opus on GLM via z.ai, Sonnet on DeepSeek, Haiku on Grok via
  OpenRouter); the proxy routes each id to its provider with your key. `↑/↓`
  pick a tier, `←/→` choose the model.
- **Per-endpoint slot wiring.** `deep-claude --endpoint <name>` maps that
  endpoint's models onto the `/model` tiers (`DEEP_EP_SLOT_<TIER>_<name>`, with a
  positional fallback).
- **Provider labels in `🎚 Map /model slots`.** Each tier's model now shows the
  provider it routes through (`· OpenRouter` / `· <endpoint>`), so vendor-prefixed
  OpenRouter ids (`x-ai/…`, `google/…`, `anthropic/…`) are no longer mistaken for
  endpoint models — or for missing.
- **Manual model entry for endpoints without a listable catalog.** When a
  provider's `/v1/models` can't be listed (e.g. Fireworks' serverless endpoint
  returns an error), the picker drops into a manual mode: it shows the
  already-selected models and lets you type a model id and press `↵` to add it, so
  the provider stays fully usable from the picker like any other.
- **Per-endpoint auth scheme for direct routes.** `DEEP_EP_AUTH_<SLUG>` selects
  how the proxy authenticates a direct endpoint — `x-api-key` (default),
  `bearer`, or `api-key` — so providers that reject `x-api-key` and require
  `Authorization: Bearer`/`Api-Key` (e.g. Baseten) work as first-class endpoints.
- Tests: proxy direct-routing for endpoint-prefixed models (prefix stripped,
  endpoint's own `x-api-key`), explicit per-endpoint slot precedence, and a
  split-escape-sequence regression guard.

### Changed
- The picker writes a **unified `ROUTER_MODELS`** — every selected model across
  all providers, with endpoint models prefixed `<provider>/<model>` so the proxy
  direct-routes them — plus `ROUTER_ALIASES` / `ROUTER_DEFAULT_MODEL` /
  `ROUTER_SLOT_*` that the proxy consumes.
- `env_get` (bash) and `envGetStr` (node) now strip **all** surrounding quotes,
  so values that picked up stray quotes self-heal on the next write.

### Fixed
- **Sub-agents (and resumed sessions) dropping to `/login`.** The routing auth
  (`ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY`) was only
  exported onto the main Claude Code process, so any claude that didn't inherit
  that environment — a sub-agent spawned with a sanitized env, a `claude --resume`,
  a background/fleet spawn — saw no credentials and refused to run with
  `Not logged in · Please run /login`. The auth is now also persisted into the
  isolated `settings.json` `env` block (re-written each launch because the proxy
  port is dynamic), which every process using that config dir reads. In OpenRouter
  mode the token is the literal `router` (no real secret on disk — upstream keys
  stay inside the proxy); in direct mode it's the endpoint key, which only ever
  lands in the git-ignored isolated home. `DEEP_CLAUDE_STATE_DIR` now overrides the
  isolated-home path so this is testable without touching the real home.
- **`deep-claude cli` exiting immediately.** `export_endpoint_keys` ended a loop
  on `[[ -n "$val" ]] && export …`, which returns non-zero when an endpoint has
  no key; under `set -euo pipefail` that aborted the whole wrapper before the
  picker drew. Now uses an explicit `if`/`fi` and returns 0.
- **Picker quitting on the first arrow key over SSH/slow ptys.** Escape
  sequences split across reads (`\x1b` then `[A`) were mistaken for a bare
  Escape. A new key reader holds a lone trailing `\x1b` briefly and only treats
  it as Escape if nothing follows.
- Repaired `ROUTER_MODELS` / `ROUTER_ALIASES` values that had accumulated stray
  quote runs (which broke `~`-prefixed model ids when the `.env` was sourced).
- **OpenRouter "owning" endpoint models in the picker.** The hub seeded
  OpenRouter's selection from the entire unified `ROUTER_MODELS`, which also holds
  endpoint-prefixed ids — so OpenRouter absorbed endpoint models, cluttering the
  `🎚 Map /model slots` pool with duplicates and re-writing duplicate
  `ROUTER_MODELS` / `ROUTER_ALIASES` (`<alias>-2`) entries on every save.
  OpenRouter is now seeded with its native ids only, and the save path
  de-duplicates the unified model list.
- **`deep-claude --endpoint <name>` failing with a 401.** The direct-endpoint
  path resolved the key from the shell env and `.env` only — never the Keychain,
  where the picker stores endpoint keys by default — so it sent an empty key. It
  now uses the full env → `.env` → Keychain chain (matching the proxy path).
- **Keyless endpoints showing "no API key" instead of loading.** The picker
  bailed out before fetching when an endpoint had no key, even though the model
  fetch supports unauthenticated requests. It now attempts the fetch and only
  prompts for a key if that attempt fails.
