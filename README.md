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

Set your DeepSeek API key:

```bash
cp .env.example .env
$EDITOR .env
```

You can also export the key instead:

```bash
export DEEPSEEK_API_KEY="sk-..."
```

## Usage

```bash
deep-claude
deep-claude --model flash
deep-claude --model pro
deep-claude -p "hello"
```

`pro` is the default model.

Model aliases:

- `pro` -> `deepseek-v4-pro`
- `flash` -> `deepseek-v4-flash`

You can also pass a full model name:

```bash
deep-claude --model deepseek-v4-pro
```

All other arguments are passed through to `claude`.

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
