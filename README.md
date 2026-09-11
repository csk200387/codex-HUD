# Codex HUD (macOS Fork)

_Last verified against openai/codex: 2026-09 (stable release rust-v0.154.0)_

A macOS-compatible fork of [anhannin/codex-hud](https://github.com/anhannin/codex-hud) — a real-time status line HUD for [Codex CLI](https://github.com/openai/codex).

Displays model, Git branch, context usage, and 5h/7d rate limits directly in the Codex terminal.

![Codex HUD screenshot](Codex-HUD/docs/assets/hud-example.png)

## What Changed from Upstream
- macOS build support (Apple Silicon and Intel)
- Xcode Command Line Tools detection in the installer
- zsh profile (`.zprofile`) PATH integration
- Updated Codex patch for the current codebase (including `tui_app_server`)
- Fixed path escaping for macOS in the configure script

## Quick Start
```bash
git clone https://github.com/Qifei-C/codex-HUD.git
cd codex-HUD/Codex-HUD
./install.sh
```

On macOS, the first `cargo build --release` can take several minutes.

## Supported Environment
- macOS (Apple Silicon / Intel) — primary target
- Linux (Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE)
- Shell: bash, zsh
- Runtime: Node.js + npm, Rust (`cargo`)
- macOS prerequisite: Xcode Command Line Tools (`xcode-select --install`)

## Validate Install
```bash
codex --version
grep -n "status_line_command" ~/.codex/config.toml
cd codex-HUD/Codex-HUD && node dist/index.js --status-line --once --no-clear
```

## Repository Layout
```
Codex-HUD/
├── src/         # HUD parser and renderer (TypeScript)
├── patches/     # Codex TUI patch for status_line_command
├── scripts/     # Install/patch/config helpers
├── tests/       # Test files
└── install.sh   # One-step installer
```

## Upstream
- Original project: [anhannin/codex-hud](https://github.com/anhannin/codex-hud)
- Sync upstream: `git fetch upstream && git merge upstream/master`

## Support
- Bug reports: [github.com/Qifei-C/codex-HUD/issues](https://github.com/Qifei-C/codex-HUD/issues)
- Upstream issues: [github.com/anhannin/codex-hud/issues](https://github.com/anhannin/codex-hud/issues)
