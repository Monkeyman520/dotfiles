#!/bin/bash

set -euo pipefail

print_help() {
    cat <<'EOF'
用法:
  bash install-mac.sh [--help]

说明:
  自动安装 Homebrew、常用工具、zinit、相关插件，并同步 dotfiles。

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
ZINIT_REPO_URL="https://github.com/zdharma-continuum/zinit.git"
ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git}"
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

install_or_update_zinit() {
    if [ -d "$ZINIT_HOME/.git" ]; then
        echo "Updating zinit..."
        run git -C "$ZINIT_HOME" pull --ff-only
    else
        echo "Installing zinit..."
        run mkdir -p "$(dirname "$ZINIT_HOME")"
        run git clone --depth 1 "$ZINIT_REPO_URL" "$ZINIT_HOME"
    fi
}

install_fzf_with_mise() {
    if ! command -v mise >/dev/null 2>&1 && ! is_dry_run; then
        echo 'command "mise" does not exist on system, skipping fzf install.' >&2
        return
    fi

    if command -v fzf >/dev/null 2>&1 && ! is_dry_run; then
        return
    fi

    echo 'Installing fzf with mise...'
    run mise use -g fzf@latest
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

resolve_symlink_target() {
    local link_path=$1
    local link_target
    local target_dir
    local target_name

    link_target="$(readlink "$link_path")"

    case "$link_target" in
        /*)
            printf '%s\n' "$link_target"
            ;;
        *)
            target_dir="$(dirname "$link_target")"
            target_name="$(basename "$link_target")"
            (
                cd "$(dirname "$link_path")"
                cd "$target_dir" 2>/dev/null
                printf '%s/%s\n' "$(pwd -P)" "$target_name"
            )
            ;;
    esac
}

migrate_legacy_stow_links() {
    local relative_paths=(
        ".config"
        ".profile"
        ".zprofile"
        ".zshenv"
        ".zshrc"
        ".gitconfig"
        ".gitflow_export"
        ".gitignore_global"
        ".tmux.conf"
        ".tmux.conf.local"
        ".config/atuin"
        ".config/fish"
        ".config/nvim"
        ".config/pip"
        ".config/starship.toml"
        ".config/wezterm"
    )
    local relative_path
    local target_path
    local resolved_target

    for relative_path in "${relative_paths[@]}"; do
        target_path="$HOME/$relative_path"

        if [ ! -L "$target_path" ]; then
            continue
        fi

        if ! resolved_target="$(resolve_symlink_target "$target_path")"; then
            continue
        fi

        case "$resolved_target" in
            "$DOTFILES_DIR"/*)
                echo "Removing legacy stow link: $relative_path"
                run unlink "$target_path"
                ;;
        esac
    done
}

backup_stow_conflicts() {
    local relative_paths=(
        ".profile"
        ".zprofile"
        ".zshenv"
        ".zshrc"
        ".gitconfig"
        ".gitflow_export"
        ".gitignore_global"
        ".tmux.conf"
        ".tmux.conf.local"
        ".config/atuin/config.toml"
        ".config/fish/config.fish"
        ".config/fish/fish_variables"
        ".config/pip/pip.conf"
        ".config/starship.toml"
    )
    local backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    local relative_path
    local target_path
    local backup_path

    for relative_path in "${relative_paths[@]}"; do
        target_path="$HOME/$relative_path"

        if [ ! -e "$target_path" ] || [ -L "$target_path" ] || [ -d "$target_path" ]; then
            continue
        fi

        backup_path="$backup_dir/$relative_path"
        echo "Backing up existing file before stow: $relative_path"
        run mkdir -p "$(dirname "$backup_path")"
        run mv "$target_path" "$backup_path"
    done
}

apply_dotfiles() {
    backup_stow_conflicts
    run stow --restow -d "$DOTFILES_DIR" -t "$HOME" shell git tmux atuin nvim wezterm fish pip starship
}

warmup_tools() {
    if command -v nvim >/dev/null 2>&1 || is_dry_run; then
        run nvim --headless -c "quitall"
    fi
}

restore_brew_packages() {
    local brewfile_path
    local missing_packages=()
    local package

    if ! brewfile_path="$(resolve_brewfile_path)"; then
        echo "brew-file not found, skipping Homebrew bundle restore."
        return
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo 'command "brew" does not exist on system, skipping Homebrew bundle restore.' >&2
        return
    fi

    if is_dry_run; then
        echo "DRY_RUN mode: skipping per-package brew checks."
        echo "Restoring Homebrew packages from $(basename "$brewfile_path")..."
        run brew bundle --file="$brewfile_path"
        return
    fi

    while IFS= read -r package; do
        if brew list --versions "$package" >/dev/null 2>&1; then
            continue
        fi

        missing_packages+=("$package")
    done < <(sed -n 's/^brew "\([^"]*\)".*/\1/p' "$brewfile_path")

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo "All brew packages in $(basename "$brewfile_path") already exist, skipping Homebrew bundle restore."
        return
    fi

    echo "Missing brew packages from $(basename "$brewfile_path"): ${missing_packages[*]}"
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
    "atuin:atuin"
    "git:git"
    "tmux:tmux"
    "mise:mise"
    "fd:fd"
    "ripgrep:rg"
    "neovim:nvim"
    "stow:stow"
    "starship:starship"
)

for package_spec in "${packages[@]}"; do
    IFS=":" read -r package_name command_name tap_source <<< "$package_spec"
    install_package_if_missing "$package_name" "$command_name" "$tap_source"
done

install_fzf_with_mise

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

install_or_update_zinit
update_or_clone_plugin "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

sync_dotfiles_repo
restore_brew_packages
migrate_legacy_stow_links
apply_dotfiles
warmup_tools
