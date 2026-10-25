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

## Install on Windows

One-line installer (no Node.js required; installs the latest release binary to `~/.codex-reset-checker`, adds it to the user PATH, and creates Start menu and desktop shortcuts):

```powershell
irm https://raw.githubusercontent.com/SanHsien/codex-reset-checker/main/scripts/install.ps1 | iex
```

Other options:

- Portable executable: download `codex-reset-checker.exe` from [Releases](https://github.com/SanHsien/codex-reset-checker/releases).
- Scoop: `scoop install https://raw.githubusercontent.com/SanHsien/codex-reset-checker/main/scoop/codex-reset-checker.json`
- System tray dashboard: `codex-reset-checker --gui`, or double-click `codex-reset-tray.bat` in the repo root. It prefers PowerShell 7 (`pwsh`) and falls back to the built-in Windows PowerShell 5.1 (`powershell.exe`) when `pwsh` is not on PATH.
- npm: `npm install -g @willh/codex-reset-checker` installs the upstream package, which does not include this fork's `--gui`/`--tray`, `--hold`, or the Windows executable.

## Development Quick Start on Windows

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
- `--gui`, `--tray`: Start the Windows system tray icon and dashboard.
- `--hold`: Keep the window open after the query until a key is pressed (the Windows executable applies it automatically when launched by double-click, except with `--json`; not detected under Node.js).
- `-v, --version`: Display version information.
- `-h, --help`: Display help documentation.

## Multi-agent pipeline

This repo is part of the [agent-relay](https://github.com/SanHsien/agent-relay) multi-agent dispatch and verification pipeline (role: quota and reset-time lookup). Integration with agent-relay is planned (Phase 2). The protocol spec and the index of all related repos live in agent-relay.

## License

MIT License. See [`NOTICE.md`](NOTICE.md) and [`LICENSE`](LICENSE).
