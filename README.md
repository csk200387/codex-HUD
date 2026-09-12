# Codex HUD (macOS Fork)

> **⚠ Archived.** Codex CLI's built-in `[tui] status_line` is enough of
> a substitute for what this project provided, so patching and building
> Codex from source is no longer necessary. Check `[tui] status_line` in
> your `~/.codex/config.toml` first. This repo is kept only for reference
> and is no longer maintained.

**[English](#codex-hud-macos-fork) · [한국어](#한국어)**

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
git clone https://github.com/csk200387/codex-HUD.git
cd codex-HUD/Codex-HUD
./install.sh
```

> **Note:** `install.sh` compiles the entire `codex-rs` workspace from
> source (~200 crates) to produce the patched binary. On an M5 chip,
> this takes about 10–15 minutes and uses significant CPU.

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

## How It Works

Codex CLI's TUI has no built-in way to run an external command for its status
line, so this project is split into two halves:

- **HUD renderer** (`src/`, TypeScript) — parses Codex's own session log
  (`~/.codex/sessions/**/rollout-*.jsonl`), computes model/context/rate-limit
  info, and prints one colored line via `dist/index.js --status-line --once`.
  This half is fully independent of Codex's source and never touches it.
- **Codex patch** (`patches/codex-statusline-command.patch`) — a diff against
  [openai/codex](https://github.com/openai/codex) that adds a new
  `[tui] status_line_command` config key. Once applied and built, the patched
  `codex` binary runs that command each time it redraws its status line, and
  renders the output (ANSI colors included) inline.

`install.sh` ties them together: it clones a pinned openai/codex release,
applies the patch, builds the HUD, wires `status_line_command` into
`~/.codex/config.toml`, and installs the patched binary to `~/.local/bin/codex`
(ahead of any Homebrew-installed `codex` on `PATH`).

```
codex (patched)  ──run──►  node dist/index.js  ──stdout──►  status line
     ▲ redraws on tool calls / turn changes         (colored text)
```

## License & Compliance

openai/codex is distributed under the [Apache License 2.0](https://github.com/openai/codex/blob/main/LICENSE),
which explicitly permits modifying and building derivative works. This
project stays well inside that grant:

- It distributes only a **patch file** (a diff), never a built or
  redistributed copy of OpenAI's binary or full modified source — each user
  clones the official source and builds locally via `install.sh`.
- Original copyright/attribution (`NOTICE`: `Copyright 2025 OpenAI`, plus the
  Ratatui MIT notice) is left untouched.
- Nothing here changes how the CLI talks to OpenAI's API — only local status
  line rendering — so it doesn't intersect with OpenAI's API usage policies.
- No OpenAI trademark is used to brand this project; it's named "Codex HUD"
  as a distinct companion tool, not a redistribution of "Codex" itself.

## Upstream
- Original project: [anhannin/codex-hud](https://github.com/anhannin/codex-hud)
- macOS fork (immediate parent of this repo): [Qifei-C/codex-HUD](https://github.com/Qifei-C/codex-HUD)
- Sync upstream: `git fetch upstream && git merge upstream/master`

## Support
- Bug reports: [github.com/csk200387/codex-HUD/issues](https://github.com/csk200387/codex-HUD/issues)
- Upstream issues: [github.com/anhannin/codex-hud/issues](https://github.com/anhannin/codex-hud/issues)

---

## 한국어

> **⚠ 보관됨(Archived).** 이 프로젝트가 제공하던 걸 Codex CLI 자체
> `status_line` 기능으로 충분히 대체할 수 있어서, 소스를 패치해서
> 빌드하는 방식이 더 이상 필요하지 않습니다. `~/.codex/config.toml`의
> `[tui] status_line` 설정을 먼저 확인해보세요. 이 저장소는 참고용으로만
> 남겨두며 더 이상 유지보수하지 않습니다.

**[English](#codex-hud-macos-fork) · [한국어](#한국어)**

_최근 검증: 2026-09 (openai/codex 안정 릴리스 rust-v0.154.0 기준)_

[anhannin/codex-hud](https://github.com/anhannin/codex-hud) — [Codex CLI](https://github.com/openai/codex)용 실시간 상태줄 HUD — 의 macOS 호환 포크입니다.

Codex 터미널 하단에 모델명, Git 브랜치, 컨텍스트 사용량, 5시간/7일 사용 한도를 직접 표시합니다.

### 업스트림에서 바뀐 점
- macOS 빌드 지원 (Apple Silicon / Intel)
- 설치 스크립트에 Xcode Command Line Tools 감지 추가
- zsh 프로필(`.zprofile`) PATH 연동
- 현재 Codex 코드베이스(`tui_app_server` 포함)에 맞춘 패치 갱신
- macOS용 경로 이스케이프 처리 수정

### 빠른 시작
```bash
git clone https://github.com/csk200387/codex-HUD.git
cd codex-HUD/Codex-HUD
./install.sh
```

> **참고:** `install.sh`는 패치된 바이너리를 만들기 위해 `codex-rs`
> 워크스페이스 전체(크레이트 약 200개)를 소스부터 컴파일합니다.
> M5 기준 약 10~15분 소요되며, CPU 자원을 많이 사용합니다.

### 지원 환경
- macOS (Apple Silicon / Intel) — 주 타깃
- Linux (Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE)
- 셸: bash, zsh
- 런타임: Node.js + npm, Rust (`cargo`)
- macOS 사전 요구사항: Xcode Command Line Tools (`xcode-select --install`)

### 설치 확인
```bash
codex --version
grep -n "status_line_command" ~/.codex/config.toml
cd codex-HUD/Codex-HUD && node dist/index.js --status-line --once --no-clear
```

### 작동 원리
Codex CLI의 TUI에는 상태줄에서 외부 명령을 실행하는 기능이 원래 없어서, 이 프로젝트는 두 부분으로 나뉩니다:

- **HUD 렌더러** (`src/`, TypeScript) — Codex가 남기는 세션 로그(`~/.codex/sessions/**/rollout-*.jsonl`)를 파싱해서 모델/컨텍스트/사용 한도 정보를 계산하고, `dist/index.js --status-line --once`로 색깔 있는 한 줄을 출력합니다. 이 부분은 Codex 소스와 완전히 독립적이며 건드리지 않습니다.
- **Codex 패치** (`patches/codex-statusline-command.patch`) — [openai/codex](https://github.com/openai/codex)에 대한 diff로, 새 `[tui] status_line_command` 설정 키를 추가합니다. 패치를 적용해 빌드한 `codex` 바이너리는 상태줄을 다시 그릴 때마다 그 명령을 실행하고, 출력(ANSI 색상 포함)을 그대로 이어붙여 렌더링합니다.

`install.sh`가 이 둘을 하나로 묶습니다: 고정된 openai/codex 릴리스를 clone하고, 패치를 적용하고, HUD를 빌드하고, `~/.codex/config.toml`에 `status_line_command`를 연결하고, 패치된 바이너리를 `~/.local/bin/codex`에 설치합니다 (PATH상에서 Homebrew로 설치된 `codex`보다 우선하도록).

```
codex (패치됨)  ──실행──►  node dist/index.js  ──stdout──►  상태줄
     ▲ 도구 호출/턴 전환마다 다시 그림                (색깔 있는 텍스트)
```

### 라이선스 및 정책 준수
openai/codex는 [Apache License 2.0](https://github.com/openai/codex/blob/main/LICENSE)으로 배포되며, 이는 수정과 파생 저작물 빌드를 명시적으로 허용합니다. 이 프로젝트는 그 범위 안에서만 동작합니다:

- **패치 파일(diff)만 배포**합니다 — OpenAI의 바이너리나 전체 수정 소스를 재배포하지 않고, 각 사용자가 공식 소스를 직접 clone해서 `install.sh`로 로컬 빌드합니다.
- 원본 저작권/크레딧 표기(`NOTICE`: `Copyright 2025 OpenAI`, Ratatui MIT 고지)를 그대로 유지합니다.
- CLI가 OpenAI API와 통신하는 방식은 전혀 바꾸지 않습니다 — 로컬 상태줄 렌더링만 바꾸므로 OpenAI의 API 이용 정책과 무관합니다.
- OpenAI 상표를 이 프로젝트를 브랜딩하는 데 쓰지 않습니다 — "Codex" 자체의 재배포가 아니라 별개의 동반 도구 "Codex HUD"로 이름 붙였습니다.

### 저장소 구조
```
Codex-HUD/
├── src/         # HUD 파서/렌더러 (TypeScript)
├── patches/     # status_line_command용 Codex TUI 패치
├── scripts/     # 설치/패치/설정 헬퍼
├── tests/       # 테스트 파일
└── install.sh   # 원스텝 설치 스크립트
```

### 업스트림
- 원본 프로젝트: [anhannin/codex-hud](https://github.com/anhannin/codex-hud)
- macOS 포크 (이 저장소가 직접 포크해온 곳): [Qifei-C/codex-HUD](https://github.com/Qifei-C/codex-HUD)
- 업스트림 동기화: `git fetch upstream && git merge upstream/master`

### 지원
- 버그 신고: [github.com/csk200387/codex-HUD/issues](https://github.com/csk200387/codex-HUD/issues)
- 업스트림 이슈: [github.com/anhannin/codex-hud/issues](https://github.com/anhannin/codex-hud/issues)

[↑ 맨 위로](#codex-hud-macos-fork)
