# Codex Reset Checker (SanHsien Maintenance Fork)

<p align="center">
  <a href="README.md">繁體中文</a> ·
  <a href="README.en.md"><strong>English</strong></a>
</p>

This repository is a Windows-first maintenance fork of [`doggy8088/codex-reset-checker`](https://github.com/doggy8088/codex-reset-checker) created by Will 保哥, licensed under the MIT License.

For fork decisions and policy, please see [`FORK.md`](FORK.md).

## What is Codex Reset Checker?

Codex Reset Checker is a CLI tool designed to inspect OpenAI Codex and ChatGPT rate limit reset credits, countdowns, and expiration timestamps directly from your local `auth.json`.

- Inspect 5-hour and weekly usage quotas.
- Check banked reset credits, grant dates, and expiration times.
- Interactive and forced credit redemption with idempotent UUID safety.
- Windows 11 native testing and verification gates.

## Quick Start on Windows

```powershell
git clone https://github.com/SanHsien/codex-reset-checker.git
cd codex-reset-checker
pwsh -NoProfile -File tools\bootstrap_dev.ps1
```

## CLI Usage

Run via Node.js:

```powershell
node bin/codex-reset-checker.js
```

Options:
- `--auth <path>`: Specify custom `auth.json` path.
- `--json`: Output single-line JSON format.
- `--reset`: Redeem one reset credit with confirmation.
- `--reset=<uuid>`: Retry an ambiguous reset using the same UUID.
- `--force`: Skip confirmation prompt when used with `--reset`.
- `--time-format <local|utc|iso>`: Date time formatting (default: local).
- `-t, --exact-time`: Display exact timestamps instead of countdowns.
- `-w, --watch`: Live refresh monitor (space to refresh, q to quit).
- `-v, --version`: Display version information.
- `-h, --help`: Display help documentation.

## License

MIT License. See [`NOTICE.md`](NOTICE.md) and [`LICENSE`](LICENSE).
