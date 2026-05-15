# deep-claude

Run Claude Code against DeepSeek's Anthropic-compatible endpoint without changing your normal Claude Code setup.

`deep-claude` is a tiny Bash wrapper around `claude`. It sets DeepSeek-specific environment variables only for the launched process and stores Claude Code state in this project directory, not your normal home config.

## Install

Clone the repo, then either run it from the checkout:

```bash
./deep-claude
```

or add the repo's `bin` directory to your shell `PATH`:

```bash
export PATH="/path/to/deep-claude/bin:$PATH"
```

Set your DeepSeek API key using any of these (precedence: shell env > .env > Keychain):

```bash
# 1. Export in your shell
export DEEPSEEK_API_KEY="sk-..."

# 2. Or copy the template and fill it in
cp .env.example .env && $EDITOR .env

# 3. Or store it in the macOS Keychain (recommended; never lives on disk in plaintext)
security add-generic-password -s deep-claude -a deepseek -U -w
# (you'll be prompted to paste the key; press return when done)
```

Keychain item: service `deep-claude`, account `deepseek`. The `security` binary handles all access, so the secret never appears in `.env`, shell history, or process listings.

## Usage

```bash
deep-claude
deep-claude --model flash
deep-claude --model pro
deep-claude -p "hello"
deep-claude --model flash -- -p "hello from flash"
```

`pro` is the default model.

Model aliases:

- `pro` -> `deepseek-v4-pro`
- `flash` -> `deepseek-v4-flash`

You can also pass a full model name:

```bash
deep-claude --model deepseek-v4-pro
```

All other arguments are passed through to `claude`. Use `--` if you want to stop `deep-claude` option parsing explicitly.

## Sandboxed: `deep-cco`

`deep-cco` is the same wrapper composed with [nikvdp/cco](https://github.com/nikvdp/cco), which runs Claude Code inside a native macOS/Linux sandbox (Seatbelt on macOS, bubblewrap on Linux) or a Docker container as fallback. Use it when you want DeepSeek-via-Claude-Code with `--dangerously-skip-permissions` but without giving the agent free reign over `$HOME`.

```bash
deep-cco                    # sandboxed DeepSeek session on deepseek-v4-pro
deep-cco --model flash      # flash model
deep-cco --safe -p "hi"     # cco's experimental tighter sandbox (hides $HOME)
```

Args are split: `--model` is consumed locally, everything else is passed through to `cco` (and then to `claude` per cco's rules). State is shared with `deep-claude` — same `.deep-claude-home/` dir — so DeepSeek session history is consistent whether you launch sandboxed or not.

Requires `cco` on `PATH`. Install it first via `https://github.com/nikvdp/cco`.

## How It Stays Isolated

The wrapper sets:

- `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`
- `ANTHROPIC_AUTH_TOKEN=$DEEPSEEK_API_KEY`
- `ANTHROPIC_API_KEY=$DEEPSEEK_API_KEY`
- `ANTHROPIC_MODEL=<selected model>`

It also points `HOME` and XDG config/cache/data/state paths at `.deep-claude-home/`, so Claude Code does not write to your normal `~/.claude.json` or regular Claude Code state.

## Development

Run the wrapper checks without making API calls:

```bash
./test.sh
```

## License

MIT
