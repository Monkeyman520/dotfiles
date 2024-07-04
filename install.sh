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

  if [ -z "$(command -v "$package_name")" ]; then
    echo "Shell \"$package_name\" does not exist on the system, trying to install it"

    if [ -n "$tap_source" ]; then
      brew tap "$tap_source"
    fi

    brew install "$package_name"
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

for package in "${packages[@]}"; do
  tap_source=""
  if [[ "$package" == "vfox" ]]; then
    tap_source="version-fox/tap"
  fi
  install_package_if_missing "$package" $tap_source
done

# 检查当前登录 shell 是否是 zsh
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "Changing login shell to zsh..."
  chsh -s "$(command -v zsh)"
else
  echo "Login shell is already zsh."
fi

# 判断是否存在 $HOME/.oh-my-zsh 目录
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "oh-my-zsh directory found."

  # 判断是否存在 omz 命令
  if command -v omz >/dev/null 2>&1; then
    echo "Updating oh-my-zsh..."
    omz update
  else
    echo "omz command not found. Installing oh-my-zsh..."
    rm -rf "$HOME/.oh-my-zsh/"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

else
  echo "Installing oh-my-zsh..."
  rm -rf "$HOME/.oh-my-zsh/"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 定义插件目录
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# 函数：检查并更新或克隆插件
update_or_clone_plugin() {
  local repo_url=$1
  local target_dir=$2

  if [ -d "$target_dir" ]; then
    echo "Updating $(basename "$target_dir")..."
    cd "$target_dir" && git pull
  else
    echo "Cloning $(basename "$target_dir")..."
    git clone "$repo_url" "$target_dir"
  fi
}

# 检查并处理插件
update_or_clone_plugin "https://github.com/Aloxaf/fzf-tab" "$ZSH_CUSTOM/plugins/fzf-tab"
update_or_clone_plugin "https://github.com/zsh-users/zsh-completions" "$ZSH_CUSTOM/plugins/zsh-completions"
update_or_clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
update_or_clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
update_or_clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
update_or_clone_plugin "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

if [ -d "$HOME/dotfiles" ]; then
  echo "Updating dotfiles..."
  cd "$HOME/dotfiles" && git restore . && git pull --recurse-submodules
else
  echo "Cloning dotfiles..."
  git clone -b main --depth 1 --recurse-submodule https://github.com/Monkeyman520/dotfiles.git "$HOME/dotfiles"
fi

stow -D -d "$HOME/dotfiles" -t "$HOME/" .

stow -R --adopt -d "$HOME/dotfiles" -t "$HOME/" .

/bin/zsh -c "source $HOME/.zshrc"
