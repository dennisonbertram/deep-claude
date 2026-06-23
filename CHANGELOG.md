# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
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
