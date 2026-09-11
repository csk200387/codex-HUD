#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$REPO_DIR/patches/codex-statusline-command.patch"
INSTALL_BIN_DIR="$HOME/.local/bin"
CODE_MODE_HOST="codex-code-mode-host"

# Codex 소스를 고정할 ref. 기본값은 openai/codex 의 최신 안정 릴리스 태그다.
# main HEAD 를 그대로 받으면 (a) 패치가 안 붙는 날이 생기고 (b) 배포판에서 가져온
# code-mode 호스트와 커밋이 어긋난다. --codex-ref 로 덮어쓸 수 있고, keep 을 주면
# 이미 있는 체크아웃의 HEAD 를 건드리지 않는다.
CODEX_REF="${CODEX_REF:-auto}"
BUILD_CODE_MODE_HOST=0

print_step() {
  # stdout 은 ensure_codex_repo 같은 함수가 값을 돌려주는 통로다. 진행 로그가
  # 섞이면 그 값이 오염되므로 반드시 stderr 로 보낸다.
  printf '\n[install] %s\n' "$1" >&2
}

fatal() {
  echo "[install] ERROR: $1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --codex-ref <ref>        Codex 소스를 고정할 git ref.
                           auto (기본) = openai/codex 최신 안정 릴리스 태그
                           keep        = 기존 체크아웃의 HEAD 를 그대로 사용
                           그 외        = 해당 태그/커밋으로 체크아웃
  --build-code-mode-host   code-mode 호스트를 소스에서 빌드 시도.
                           v8 의 v8_enable_sandbox 프리빌트가 없어 보통 실패하며,
                           성공하려면 V8_FROM_SOURCE=1 과 depot_tools 가 필요하다.
  -h, --help               이 도움말
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --codex-ref)
        [[ $# -ge 2 ]] || fatal "--codex-ref requires a value"
        CODEX_REF="$2"
        shift 2
        ;;
      --codex-ref=*)
        CODEX_REF="${1#*=}"
        shift
        ;;
      --build-code-mode-host)
        BUILD_CODE_MODE_HOST=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        fatal "Unknown option: $1"
        ;;
    esac
  done
}

ensure_command() {
  local cmd="$1"
  local hint="${2:-Install '$cmd' and rerun install.sh}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fatal "$hint"
  fi
}

ensure_rust_toolchain() {
  if command -v cargo >/dev/null 2>&1; then
    return 0
  fi

  print_step "Rust toolchain not found. Installing via rustup"
  ensure_command curl "curl is required to install Rust (install curl first)"
  curl https://sh.rustup.rs -sSf | sh -s -- -y

  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1090
    . "$HOME/.cargo/env"
  fi
  ensure_command cargo "cargo still not found after rustup install"
}

ensure_linux_build_deps() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    return 0
  fi

  local missing=0
  command -v clang >/dev/null 2>&1 || missing=1
  command -v clang++ >/dev/null 2>&1 || missing=1
  command -v pkg-config >/dev/null 2>&1 || missing=1
  command -v cmake >/dev/null 2>&1 || missing=1
  command -v make >/dev/null 2>&1 || missing=1

  if command -v pkg-config >/dev/null 2>&1; then
    pkg-config --exists libcap || missing=1
    pkg-config --exists libseccomp || missing=1
  fi

  if [[ $missing -eq 0 ]]; then
    return 0
  fi

  print_step "Installing Linux build deps (clang/cmake/pkg-config/libcap/libseccomp)"
  local run_as_root=()
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      run_as_root=(sudo)
    else
      fatal "Need root or sudo to install packages. Install clang/cmake/pkg-config/libcap/libseccomp manually and rerun."
    fi
  fi

  if command -v apt-get >/dev/null 2>&1; then
    "${run_as_root[@]}" apt-get update
    "${run_as_root[@]}" apt-get install -y clang build-essential cmake pkg-config libcap-dev libseccomp-dev
  elif command -v dnf >/dev/null 2>&1; then
    "${run_as_root[@]}" dnf install -y clang clang-tools-extra gcc gcc-c++ make cmake pkgconf-pkg-config libcap-devel libseccomp-devel
  elif command -v pacman >/dev/null 2>&1; then
    "${run_as_root[@]}" pacman -Sy --noconfirm clang base-devel cmake pkgconf libcap libseccomp
  elif command -v zypper >/dev/null 2>&1; then
    "${run_as_root[@]}" zypper --non-interactive install clang gcc gcc-c++ make cmake pkg-config libcap-devel libseccomp-devel
  else
    fatal "Unsupported package manager. Install clang/cmake/pkg-config/libcap/libseccomp manually and rerun."
  fi

  command -v pkg-config >/dev/null 2>&1 || fatal "pkg-config not found after dependency install"
  pkg-config --exists libcap || fatal "libcap not visible via pkg-config after dependency install"
  pkg-config --exists libseccomp || fatal "libseccomp not visible via pkg-config after dependency install"
}

ensure_macos_build_deps() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    return 0
  fi

  local missing=0
  command -v clang >/dev/null 2>&1 || missing=1
  command -v clang++ >/dev/null 2>&1 || missing=1
  command -v make >/dev/null 2>&1 || missing=1
  command -v xcode-select >/dev/null 2>&1 || missing=1

  if [[ $missing -eq 0 ]] && xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  # Linux 쪽은 패키지 매니저로 알아서 깔아 주는데 macOS 는 안내만 하고 끝나서
  # 여기서 멈춰 있는 사람이 많았다. CLT 는 비대화식 설치가 불가능하므로,
  # 설치 GUI 만 띄워 주고 끝난 뒤 다시 실행하도록 한다.
  if command -v xcode-select >/dev/null 2>&1; then
    print_step "Xcode Command Line Tools not found. Launching the installer"
    xcode-select --install >/dev/null 2>&1 || true
    fatal "Finish the Command Line Tools install, then rerun install.sh"
  fi

  fatal "macOS build tools not found. Install Xcode Command Line Tools with: xcode-select --install"
}

ensure_build_deps() {
  ensure_linux_build_deps
  ensure_macos_build_deps
}

ensure_local_bin_precedence() {
  mkdir -p "$INSTALL_BIN_DIR"
  export PATH="$INSTALL_BIN_DIR:$PATH"

  local marker_start="# >>> codex-hud path >>>"
  local marker_end="# <<< codex-hud path <<<"
  local line='export PATH="$HOME/.local/bin:$PATH"'
  local rc_files=("$HOME/.bashrc")

  if [[ "${SHELL##*/}" == "zsh" ]]; then
    rc_files+=("$HOME/.zshrc" "$HOME/.zprofile")
  else
    rc_files+=("$HOME/.zshrc")
  fi

  for rc in "${rc_files[@]}"; do
    if [[ ! -f "$rc" ]]; then
      : > "$rc"
    fi
    if grep -Fq "$marker_start" "$rc"; then
      continue
    fi
    {
      echo ""
      echo "$marker_start"
      echo "$line"
      echo "$marker_end"
    } >> "$rc"
  done
}

is_codex_repo() {
  local p="$1"
  [[ -d "$p/.git" && -f "$p/codex-rs/Cargo.toml" && -f "$p/README.md" ]]
}

find_codex_repo() {
  local candidates=(
    "$REPO_DIR/_upstream/openai-codex"
    "$REPO_DIR/openai-codex"
    "$HOME/openai-codex"
    "$HOME/codex"
    "$HOME/src/openai-codex"
    "$HOME/.codex-hud/vendor/openai-codex"
  )

  for c in "${candidates[@]}"; do
    if is_codex_repo "$c"; then
      echo "$c"
      return 0
    fi
  done

  return 1
}

# openai/codex 의 최신 안정 릴리스 태그. 알파/베타와 과거의 오타 태그(rust-vv…)를
# 걸러 내고 버전 역순 첫 줄을 쓴다. curl·jq 없이 git 만으로 해결한다.
latest_codex_release_tag() {
  git ls-remote --tags --refs --sort=-v:refname https://github.com/openai/codex 'rust-v*' 2>/dev/null \
    | sed 's#.*refs/tags/##' \
    | grep -E '^rust-v[0-9]+\.[0-9]+\.[0-9]+$' \
    | head -1
}

resolve_codex_ref() {
  if [[ "$CODEX_REF" != "auto" ]]; then
    echo "$CODEX_REF"
    return 0
  fi

  local tag
  tag="$(latest_codex_release_tag)"
  if [[ -z "$tag" ]]; then
    print_step "Notice: could not resolve the latest Codex release tag; falling back to the default branch"
    echo "keep"
    return 0
  fi
  echo "$tag"
}

ensure_codex_repo() {
  local found
  if found="$(find_codex_repo)"; then
    echo "$found"
    return 0
  fi

  local target="$HOME/.codex-hud/vendor/openai-codex"
  local ref
  ref="$(resolve_codex_ref)"

  mkdir -p "$(dirname "$target")"
  if [[ "$ref" == "keep" ]]; then
    print_step "openai/codex source not found. Cloning default branch to $target"
    git clone --depth 1 https://github.com/openai/codex "$target"
  else
    print_step "openai/codex source not found. Cloning $ref to $target"
    git clone --depth 1 --branch "$ref" https://github.com/openai/codex "$target"
  fi
  echo "$target"
}

# 이미 있는 체크아웃은 기본적으로 건드리지 않는다. 남의 작업 트리를 말없이
# 옮기면 곤란하고, 패치가 적용된 상태라 체크아웃이 실패하기도 한다.
# --codex-ref 를 명시했을 때만 그 ref 로 옮긴다.
repin_codex_repo_if_requested() {
  local codex_repo="$1"

  if [[ "$CODEX_REF" == "auto" || "$CODEX_REF" == "keep" ]]; then
    return 0
  fi

  local current
  current="$(git -C "$codex_repo" rev-parse HEAD)"
  if git -C "$codex_repo" rev-parse --verify "$CODEX_REF^{commit}" >/dev/null 2>&1 \
    && [[ "$(git -C "$codex_repo" rev-parse "$CODEX_REF^{commit}")" == "$current" ]]; then
    print_step "Codex source already at $CODEX_REF"
    return 0
  fi

  print_step "Moving Codex source to $CODEX_REF"
  # 패치가 적용돼 있으면 체크아웃이 막힌다. 우리 패치라면 되돌리고 진행한다.
  if git -C "$codex_repo" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    git -C "$codex_repo" apply --reverse "$PATCH_FILE"
  fi
  if [[ -n "$(git -C "$codex_repo" status --porcelain)" ]]; then
    fatal "Codex source at $codex_repo has local changes. Commit or discard them, then rerun."
  fi

  git -C "$codex_repo" fetch --depth 1 origin "$CODEX_REF" \
    || fatal "Could not fetch $CODEX_REF from origin"
  git -C "$codex_repo" checkout --detach FETCH_HEAD \
    || fatal "Could not check out $CODEX_REF"
}

apply_patch_if_needed() {
  local codex_repo="$1"

  if git -C "$codex_repo" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    print_step "Patch already applied at $codex_repo"
    return 0
  fi

  print_step "Applying Codex status-line command patch"
  if ! git -C "$codex_repo" apply --check "$PATCH_FILE" 2>/dev/null; then
    print_step "The patch does not apply to this Codex revision: $(git -C "$codex_repo" rev-parse --short HEAD)"
    fatal "Rebase patches/codex-statusline-command.patch onto this revision, or pick a matching one with --codex-ref"
  fi
  git -C "$codex_repo" apply "$PATCH_FILE"
}

build_hud() {
  print_step "Building codex-hud"
  ensure_command npm "npm is required (install Node.js + npm first)"
  cd "$REPO_DIR"
  npm ci
  npm run build
}

configure_codex() {
  print_step "Configuring ~/.codex/config.toml"
  "$REPO_DIR/scripts/configure-codex-statusline.sh" --repo-dir "$REPO_DIR"
}

# 배포판 Codex 가 같이 싣고 다니는 code-mode 호스트를 찾는다.
# 값만 stdout 으로 내보내고 로그는 stderr 로 보낸다.
find_prebuilt_code_mode_host() {
  local codex_repo="$1"
  local -a dirs=("$codex_repo/codex-rs/target/release")

  # PATH 에 있는 다른 Codex 설치(우리 것 제외).
  local IFS=':'
  local entry
  for entry in $PATH; do
    [[ -n "$entry" && "$entry" != "$INSTALL_BIN_DIR" ]] && dirs+=("$entry")
  done
  unset IFS

  # Homebrew cask 는 버전 디렉터리 아래에 둔다. 최신 버전부터 본다.
  local caskroom
  for caskroom in /opt/homebrew/Caskroom/codex /usr/local/Caskroom/codex; do
    [[ -d "$caskroom" ]] || continue
    local version
    while IFS= read -r version; do
      [[ -n "$version" ]] && dirs+=("$caskroom/$version/bin")
    done < <(ls -1 "$caskroom" 2>/dev/null | sort -Vr)
  done

  dirs+=("/usr/local/bin" "/opt/codex/bin")

  local dir
  for dir in "${dirs[@]}"; do
    if [[ -x "$dir/$CODE_MODE_HOST" ]]; then
      echo "$dir/$CODE_MODE_HOST"
      return 0
    fi
  done

  return 1
}

# Codex 는 code-mode 호스트를 자기 실행 파일과 같은 디렉터리에서 찾는다
# (install-context 의 code_mode_host_program_from_exe). 패치한 codex 만 옮기면
# 그 옆에 호스트가 없어서 Code Mode 가 fail closed 된다 — 예전 install.sh 가
# codex-cli 하나만 빌드했기 때문에 생기던 문제다.
#
# 소스 빌드는 기본값이 아니다. code-mode-runtime 이 v8 을 v8_enable_sandbox 로
# 쓰는데 rusty_v8 릴리스에 그 조합의 프리빌트가 없어서, V8_FROM_SOURCE=1 과
# depot_tools 없이는 반드시 실패한다. 그래서 배포판이 싣고 다니는 호스트를
# 재사용하는 쪽을 먼저 시도한다.
install_code_mode_host() {
  local codex_repo="$1"
  local dest="$INSTALL_BIN_DIR/$CODE_MODE_HOST"

  if [[ "$BUILD_CODE_MODE_HOST" -eq 1 ]]; then
    print_step "Building $CODE_MODE_HOST from source (this needs a V8 build)"
    cd "$codex_repo/codex-rs"
    if cargo build --release -p codex-code-mode-host; then
      cp "$codex_repo/codex-rs/target/release/$CODE_MODE_HOST" "$dest"
      chmod +x "$dest"
      print_step "Installed $CODE_MODE_HOST to $dest"
      return 0
    fi
    print_step "Notice: source build failed. Falling back to a prebuilt host"
  fi

  local source_host
  if ! source_host="$(find_prebuilt_code_mode_host "$codex_repo")"; then
    print_step "Notice: no $CODE_MODE_HOST found, so Code Mode stays unavailable."
    print_step "Install an official Codex build (it ships the host) and rerun, or try --build-code-mode-host."
    return 0
  fi

  if [[ "$source_host" == "$dest" ]]; then
    return 0
  fi

  cp "$source_host" "$dest"
  chmod +x "$dest"
  print_step "Installed $CODE_MODE_HOST from $source_host"
}

build_patched_codex_binary() {
  local codex_repo="$1"

  ensure_rust_toolchain
  ensure_build_deps

  print_step "Building patched Codex binary"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    print_step "First macOS release builds can take several minutes"
  fi
  cd "$codex_repo/codex-rs"
  local build_log
  build_log="$(mktemp)"

  if ! cargo build --release -p codex-cli >"$build_log" 2>&1; then
    if grep -q "COMPILER BUG DETECTED" "$build_log"; then
      print_step "Detected gcc compiler bug from aws-lc-sys. Retrying with clang"
      ensure_build_deps
      if ! CC=clang CXX=clang++ cargo build --release -p codex-cli >"$build_log" 2>&1; then
        cat "$build_log" >&2
        rm -f "$build_log"
        fatal "Failed to build patched Codex binary with clang"
      fi
    else
      cat "$build_log" >&2
      rm -f "$build_log"
      fatal "Failed to build patched Codex binary"
    fi
  fi
  rm -f "$build_log"

  local built="$codex_repo/codex-rs/target/release/codex"
  if [[ ! -x "$built" ]]; then
    fatal "Patched codex binary not found at $built"
  fi

  local target="$INSTALL_BIN_DIR/codex"
  mkdir -p "$INSTALL_BIN_DIR"

  if [[ -x "$target" && ! -L "$target" ]]; then
    local backup="$INSTALL_BIN_DIR/codex.backup.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"
    print_step "Backed up existing codex binary to $backup"
  fi

  cp "$built" "$target"
  chmod +x "$target"
  print_step "Installed patched codex to $target"

  install_code_mode_host "$codex_repo"

  ensure_local_bin_precedence
  hash -r
}

main() {
  parse_args "$@"

  print_step "Starting one-shot install"
  ensure_command git "git is required (install git first)"

  if [[ ! -f "$PATCH_FILE" ]]; then
    fatal "Patch file missing: $PATCH_FILE"
  fi

  local codex_repo
  codex_repo="$(ensure_codex_repo)"
  repin_codex_repo_if_requested "$codex_repo"
  print_step "Using Codex source: $codex_repo ($(git -C "$codex_repo" rev-parse --short HEAD))"

  apply_patch_if_needed "$codex_repo"
  build_hud
  configure_codex
  build_patched_codex_binary "$codex_repo"

  local resolved
  resolved="$(command -v codex || true)"
  if [[ "$resolved" != "$INSTALL_BIN_DIR/codex" ]]; then
    print_step "Notice: current shell still resolves codex to: ${resolved:-<not found>}"
    print_step "Open a new shell or run: export PATH=\"$INSTALL_BIN_DIR:\$PATH\" && hash -r"
  fi

  print_step "Done"
  echo "Patched codex installed at: $INSTALL_BIN_DIR/codex"
  if [[ -x "$INSTALL_BIN_DIR/$CODE_MODE_HOST" ]]; then
    echo "Code-mode host installed at: $INSTALL_BIN_DIR/$CODE_MODE_HOST"
  else
    echo "Code-mode host: not installed (Code Mode stays unavailable)"
  fi
  echo "Run Codex normally: codex"
  echo "HUD command wired in ~/.codex/config.toml via [tui].status_line_command"
}

main "$@"
