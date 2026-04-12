#!/bin/bash

set -euo pipefail

print_help() {
    cat <<'EOF'
用法:
  bash install-mac.sh [--help]

说明:
  自动安装 Homebrew、常用工具、oh-my-zsh、相关插件，并同步 dotfiles。

选项:
  -h, --help
      显示这段帮助并立即退出。

环境变量:
  DRY_RUN=1
      只打印将要执行的命令，不真正执行。

  TEST_HOME=/tmp/some-dir
      将 HOME 切换到测试目录，适合在沙盒目录中验证脚本行为。
      注意：如果不同时设置 DRY_RUN=1，brew install 等系统级操作仍会真实执行。

  BREWFILE_PATH=/path/to/brew-file
      指定 Homebrew 恢复文件路径。
      默认优先读取 "$HOME/dotfiles/brew-file"，找不到时回退到脚本同目录下的 "brew-file"。

推荐用法:
  DRY_RUN=1 TEST_HOME=/tmp/dotfiles-test bash install-mac.sh
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Run 'bash install-mac.sh --help' for usage." >&2
            exit 1
            ;;
    esac
done

DRY_RUN=${DRY_RUN:-0}
TEST_HOME=${TEST_HOME:-}
BREWFILE_PATH=${BREWFILE_PATH:-}
TARGET_HOME=${TEST_HOME:-$HOME}

export HOME="$TARGET_HOME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_REPO_URL="https://github.com/Monkeyman520/dotfiles.git"
DOTFILES_BRANCH="main"
DOTFILES_DIR="${HOME}/dotfiles"
OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

is_dry_run() {
    [ "$DRY_RUN" = "1" ]
}

print_command() {
    if ! is_dry_run; then
        return
    fi

    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
}

run() {
    if is_dry_run; then
        print_command "$@"
        return 0
    fi

    "$@"
}

run_remote_script() {
    local shell_bin=$1
    local url=$2
    shift 2

    if is_dry_run; then
        print_command env "$@" "$shell_bin" -c "<downloaded script from $url>"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo 'command "curl" does not exist on system' >&2
        exit 1
    fi

    local script
    script="$(curl -fsSL "$url")"
    env "$@" "$shell_bin" -c "$script"
}

resolve_brewfile_path() {
    if [ -n "$BREWFILE_PATH" ]; then
        echo "$BREWFILE_PATH"
        return 0
    fi

    if [ -f "$DOTFILES_DIR/brew-file" ]; then
        echo "$DOTFILES_DIR/brew-file"
        return 0
    fi

    if [ -f "$SCRIPT_DIR/brew-file" ]; then
        echo "$SCRIPT_DIR/brew-file"
        return 0
    fi

    return 1
}

install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        return
    fi

    run_remote_script /bin/bash "$HOMEBREW_INSTALL_URL"

    if is_dry_run; then
        return
    fi

    if ! command -v brew >/dev/null 2>&1; then
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo 'homebrew install finished, but "brew" is still unavailable in current shell' >&2
        exit 1
    fi
}

install_package_if_missing() {
    local package_name=$1
    local command_name=$2
    local tap_source=${3:-}

    if command -v "$command_name" >/dev/null 2>&1; then
        return
    fi

    echo "Command \"$command_name\" does not exist on the system, trying to install package \"$package_name\""

    if [ -n "$tap_source" ]; then
        run brew tap "$tap_source"
    fi

    run brew install "$package_name"
}

install_oh_my_zsh() {
    run_remote_script sh "$OH_MY_ZSH_INSTALL_URL" RUNZSH=no CHSH=no KEEP_ZSHRC=yes
}

update_or_clone_plugin() {
    local repo_url=$1
    local target_dir=$2

    if [ -d "$target_dir/.git" ]; then
        echo "Updating $(basename "$target_dir")..."
        run git -C "$target_dir" pull --ff-only
    else
        echo "Cloning $(basename "$target_dir")..."
        run git clone --depth 1 "$repo_url" "$target_dir"
    fi
}

sync_dotfiles_repo() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo "Updating dotfiles..."
        run git -C "$DOTFILES_DIR" restore .
        run git -C "$DOTFILES_DIR" pull --recurse-submodules
    else
        echo "Cloning dotfiles..."
        run git clone -b "$DOTFILES_BRANCH" --depth 1 --recurse-submodules "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
    fi

    run git -C "$DOTFILES_DIR" submodule sync --recursive
    run git -C "$DOTFILES_DIR" submodule update --init --recursive
}

apply_dotfiles() {
    run stow --restow --adopt -d "$DOTFILES_DIR" -t "$HOME/" .
}

warmup_tools() {
    if command -v nvim >/dev/null 2>&1 || is_dry_run; then
        run nvim --headless -c "quitall"
    fi
}

restore_brew_packages() {
    local brewfile_path

    if ! brewfile_path="$(resolve_brewfile_path)"; then
        echo "brew-file not found, skipping Homebrew bundle restore."
        return
    fi

    echo "Restoring Homebrew packages from $(basename "$brewfile_path")..."
    run brew bundle --file="$brewfile_path"
}

install_homebrew

# 更换 brew 镜像仓库和相关环境变量
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_NO_AUTO_UPDATE=true
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=true

packages=(
    "zsh:zsh"
    "git:git"
    "tmux:tmux"
    "vfox:vfox:version-fox/tap"
    "fd:fd"
    "ripgrep:rg"
    "fzf:fzf"
    "neovim:nvim"
    "stow:stow"
    "starship:starship"
)

for package_spec in "${packages[@]}"; do
    IFS=":" read -r package_name command_name tap_source <<< "$package_spec"
    install_package_if_missing "$package_name" "$command_name" "$tap_source"
done

if [ -n "$TEST_HOME" ]; then
    echo "TEST_HOME mode enabled: $HOME"
fi

if is_dry_run; then
    echo "DRY_RUN mode enabled."
fi

if [ -n "$TEST_HOME" ]; then
    echo "Skipping login shell change in TEST_HOME mode."
elif [ "${SHELL:-}" != "$(command -v zsh)" ]; then
    echo "Changing login shell to zsh..."
    run chsh -s "$(command -v zsh)"
else
    echo "Login shell is already zsh."
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "oh-my-zsh directory found."

    if command -v omz >/dev/null 2>&1; then
        echo "Updating oh-my-zsh..."
        run omz update
    else
        echo "omz command not found. Reinstalling oh-my-zsh..."
        run rm -rf "$HOME/.oh-my-zsh/"
        install_oh_my_zsh
    fi
else
    echo "Installing oh-my-zsh..."
    install_oh_my_zsh
fi

if [ -n "$TEST_HOME" ]; then
    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
else
    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
fi

update_or_clone_plugin "https://github.com/Aloxaf/fzf-tab" "$ZSH_CUSTOM/plugins/fzf-tab"
update_or_clone_plugin "https://github.com/zsh-users/zsh-completions" "$ZSH_CUSTOM/plugins/zsh-completions"
update_or_clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
update_or_clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
update_or_clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
update_or_clone_plugin "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

sync_dotfiles_repo
restore_brew_packages
apply_dotfiles
warmup_tools
