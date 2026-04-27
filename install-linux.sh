#!/usr/bin/env bash

set -euo pipefail

print_help() {
    cat <<'EOF'
用法:
  bash install-linux.sh [--help]

说明:
  面向 Ubuntu 24.04 的快速安装脚本。
  自动安装基础命令行工具、atuin、mise、starship、zinit，并同步 dotfiles。

选项:
  -h, --help
      显示这段帮助并立即退出。

环境变量:
  DRY_RUN=1
      只打印将要执行的命令，不真正执行。

  TEST_HOME=/tmp/some-dir
      将 HOME 切换到测试目录，适合在沙盒目录中验证脚本行为。
      注意：如果不同时设置 DRY_RUN=1，apt/curl/git 等操作仍会真实执行。

  DOTFILES_REPO_URL=https://example.com/dotfiles.git
      指定 dotfiles 仓库地址。

  DOTFILES_BRANCH=main
      指定 dotfiles 分支。

推荐用法:
  DRY_RUN=1 TEST_HOME=/tmp/dotfiles-linux-test bash install-linux.sh
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
            echo "Run 'bash install-linux.sh --help' for usage." >&2
            exit 1
            ;;
    esac
done

DRY_RUN=${DRY_RUN:-0}
TEST_HOME=${TEST_HOME:-}
TARGET_HOME=${TEST_HOME:-$HOME}

export HOME="$TARGET_HOME"

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/Monkeyman520/dotfiles.git}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
DOTFILES_DIR="${HOME}/dotfiles"
ZINIT_REPO_URL="https://github.com/zdharma-continuum/zinit.git"
ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git}"

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

run_shell() {
    local command_text=$1

    if is_dry_run; then
        print_command bash -lc "$command_text"
        return 0
    fi

    bash -lc "$command_text"
}

require_ubuntu_2404() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    fi

    if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
        echo "Warning: this script is designed for Ubuntu 24.04, current system is ${PRETTY_NAME:-unknown}." >&2
    fi
}

sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_sudo() {
    if is_dry_run; then
        if [ "$(id -u)" -eq 0 ]; then
            print_command "$@"
        else
            print_command sudo "$@"
        fi
        return 0
    fi

    sudo_cmd "$@"
}

install_apt_packages() {
    local package_specs=(
        "ca-certificates:update-ca-certificates"
        "curl:curl"
        "git:git"
        "zsh:zsh"
        "tmux:tmux"
        "stow:stow"
        "fzf:fzf"
        "fd-find:fdfind"
        "ripgrep:rg"
        "neovim:nvim"
        "unzip:unzip"
        "xz-utils:xz"
        "build-essential:gcc"
    )
    local packages_to_install=()
    local package_spec
    local package_name
    local command_name

    for package_spec in "${package_specs[@]}"; do
        IFS=":" read -r package_name command_name <<< "$package_spec"

        if command -v "$command_name" >/dev/null 2>&1; then
            continue
        fi

        packages_to_install+=("$package_name")
    done

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo "All apt-managed commands already exist, skipping apt install."
        return
    fi

    echo "Installing missing apt packages: ${packages_to_install[*]}"
    run_sudo apt-get update
    run_sudo apt-get install -y "${packages_to_install[@]}"
}

install_atuin_if_missing() {
    if command -v atuin >/dev/null 2>&1; then
        return
    fi

    echo 'Installing atuin...'
    run_shell 'curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh'
}

install_mise_if_missing() {
    if command -v mise >/dev/null 2>&1; then
        return
    fi

    echo 'Installing mise...'
    run_shell 'curl https://mise.run | sh'
}

install_starship_if_missing() {
    if command -v starship >/dev/null 2>&1; then
        return
    fi

    echo 'Installing starship...'
    run mkdir -p "$HOME/.local/bin"
    run_shell "curl -sS https://starship.rs/install.sh | sh -s -- -y -b '$HOME/.local/bin'"
}

ensure_fd_command() {
    if command -v fd >/dev/null 2>&1; then
        return
    fi

    if command -v fdfind >/dev/null 2>&1 || is_dry_run; then
        run mkdir -p "$HOME/.local/bin"
        run ln -sf "$(command -v fdfind 2>/dev/null || echo /usr/bin/fdfind)" "$HOME/.local/bin/fd"
    fi
}

update_or_clone_repo() {
    local repo_url=$1
    local target_dir=$2
    local branch=${3:-}

    if [ -d "$target_dir/.git" ]; then
        echo "Updating $(basename "$target_dir")..."
        run git -C "$target_dir" pull --ff-only --recurse-submodules
    else
        echo "Cloning $(basename "$target_dir")..."
        if [ -n "$branch" ]; then
            run git clone -b "$branch" --depth 1 --recurse-submodules "$repo_url" "$target_dir"
        else
            run git clone --depth 1 "$repo_url" "$target_dir"
        fi
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

sync_dotfiles_repo() {
    update_or_clone_repo "$DOTFILES_REPO_URL" "$DOTFILES_DIR" "$DOTFILES_BRANCH"
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

change_login_shell() {
    if [ -n "$TEST_HOME" ]; then
        echo "Skipping login shell change in TEST_HOME mode."
        return
    fi

    local zsh_path
    zsh_path="$(command -v zsh)"

    if [ "${SHELL:-}" = "$zsh_path" ]; then
        echo "Login shell is already zsh."
        return
    fi

    if ! grep -qxF "$zsh_path" /etc/shells; then
        run_shell "echo '$zsh_path' | sudo tee -a /etc/shells >/dev/null"
    fi

    echo "Changing login shell to zsh..."
    run chsh -s "$zsh_path"
}

warmup_tools() {
    if command -v nvim >/dev/null 2>&1 || is_dry_run; then
        run nvim --headless -c "quitall"
    fi
}

if [ -n "$TEST_HOME" ]; then
    echo "TEST_HOME mode enabled: $HOME"
fi

if is_dry_run; then
    echo "DRY_RUN mode enabled."
fi

require_ubuntu_2404
install_apt_packages
install_atuin_if_missing
install_mise_if_missing
install_starship_if_missing
ensure_fd_command
change_login_shell
install_or_update_zinit
update_or_clone_repo "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"
sync_dotfiles_repo
migrate_legacy_stow_links
apply_dotfiles
warmup_tools
