#!/bin/bash

# 检查是否存在 homebrew
if [[ -z "$(command -v brew)" ]]; then
    # 不存在homebrew 检查是否存在 curl 命令
    if [ -z "$(command -v curl)" ]; then
        echo "command \"curl\" exists on system"
        exit 1
    fi

    # 安装 brew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

install_package_if_missing() {
    local package_name=$1
    local tap_source=$2

    if [ -z "$(command -v $package_name)" ]; then
        echo "Shell \"$package_name\" does not exist on the system, trying to install it"

        if [ -n "$tap_source" ]; then
            brew tap $tap_source
        fi

        brew install $package_name
    fi
}

# 更换brew镜像仓库和相关环境变量
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_NO_AUTO_UPDATE=true
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=true

# 包列表
packages=("zsh" "git" "tmux" "vfox" "fd" "ripgrep" "fzf" "neovim" "stow")

# 可选的 tap 源（为空表示没有）
tap_sources=("version-fox/tap")

for package in "${packages[@]}"; do
    tap_source=""
    if [[ "$package" == "vfox" ]]; then
        tap_source="version-fox/tap"
    fi
    install_package_if_missing $package $tap_source
done

chsh -s "$(command -v zsh)"

git clone -b main --depth 1 --recurse-submodule https://github.com/Monkeyman520/dotfiles.git ~/dotfiles

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

stow -R --adopt -d ~/dotfiles -t ~/ .

source ~/.zshrc

nvim --headless -c 'quitall'
