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

# 检查当前登录 shell 是否是 zsh
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "Changing login shell to zsh..."
  chsh -s "$(command -v zsh)"
else
  echo "Login shell is already zsh."
fi

if [ "$(command -v omz)" ]; then
    echo "Updating oh-my-zsh..."
    omz update 
else
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ -d "~/dotfiles" ]; then
    echo "Updating dotfiles..."
    cd ~/dotfiles ; git pull --recurse-submodules ; cd -
else
    echo "Cloning dotfiles..."
    git clone -b main --depth 1 --recurse-submodule https://github.com/Monkeyman520/dotfiles.git ~/dotfiles
fi

# 定义插件目录
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# 检查并处理 zsh-autosuggestions 插件
if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "Updating zsh-autosuggestions..."
  cd "$ZSH_CUSTOM/plugins/zsh-autosuggestions" && git pull
else
  echo "Cloning zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# 检查并处理 zsh-syntax-highlighting 插件
if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "Updating zsh-syntax-highlighting..."
  cd "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" && git pull
else
  echo "Cloning zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# 检查并处理 zsh-history-substring-search 插件
if [ -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]; then
  echo "Updating zsh-history-substring-search..."
  cd "$ZSH_CUSTOM/plugins/zsh-history-substring-search" && git pull
else
  echo "Cloning zsh-history-substring-search..."
  git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
fi

# 检查并处理 tmux-plugins/tpm 插件
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Updating tpm..."
  cd "$HOME/.tmux/plugins/tpm" && git pull
else
  echo "Cloning tpm..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

stow -R --adopt -d ~/dotfiles -t ~/ .

/bin/zsh -c "source ~/.zshrc"
