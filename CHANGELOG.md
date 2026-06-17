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
