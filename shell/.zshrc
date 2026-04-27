# OPENSPEC:START
# OpenSpec shell 补全目录
[[ -d "$HOME/.zsh/completions" ]] && fpath=("$HOME/.zsh/completions" $fpath)
if [[ ! -o interactive ]]; then
  autoload -Uz compinit
  compinit
fi
# OPENSPEC:END

# 基础语言与工具链
export GOPROXY=https://goproxy.io,direct
export GOPATH="$HOME/Data/go"
export NODE_OPTIONS="--experimental-sqlite"

# 包管理器镜像
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_PIP_INDEX_URL="https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"
export HOMEBREW_NO_AUTO_UPDATE=true

# 路径与编译参数
export GIT_HOME="/usr/local/git"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
case ":$PATH:" in
  *":$HOME/.antigravity/antigravity/bin:"*) ;;
  *) export PATH="$HOME/.antigravity/antigravity/bin:$PATH" ;;
esac
export PATH="$PATH:$GOPATH/bin"
[[ -n "$GOROOT" ]] && export PATH="$PATH:$GOROOT:$GOROOT/bin"
export PATH="$PATH:$GIT_HOME/bin"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# Rust 镜像
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup

# 常用别名
alias code="open -a 'Visual Studio Code'"
alias wgon="wg-quick up wg0"
alias wgoff="wg-quick down wg0"
alias ll='ls -l'
alias la='ls -a'
alias grep="grep --color=auto"
alias -s gz='tar -xzvf'
alias -s tgz='tar -xzvf'
alias -s zip='unzip'
alias -s bz2='tar -xjvf'
alias cdd='cd ~/Desktop/'
alias cdc='cd ~/Code/'
alias cdp='cd ~/Personal/'

[[ -o interactive ]] || return

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=30'
if [ -z "$ZSH_COMPDUMP" ]; then
  ZSH_COMPDUMP="${ZDOTDIR:-${HOME}}/.cache/zsh/zcompdump-${SHORT_HOST:-${HOST%%.*}}-${ZSH_VERSION}"
fi
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

if [[ ! -r "$ZINIT_HOME/zinit.zsh" && -z "$CODEX_SANDBOX" ]]; then
  command mkdir -p "${ZINIT_HOME:h}"
  command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  source "$ZINIT_HOME/zinit.zsh"
  DOTFILES_ZINIT_READY=1

  zinit ice blockf
  zinit light zsh-users/zsh-completions

  autoload -Uz compinit
  compinit -d "$ZSH_COMPDUMP"
  zinit cdreplay -q

  zinit light Aloxaf/fzf-tab
  zinit light zsh-users/zsh-autosuggestions
else
  autoload -Uz compinit
  compinit -d "$ZSH_COMPDUMP"
fi

if [[ -r /Applications/WezTerm.app/Contents/Resources/wezterm.sh ]]; then
  source /Applications/WezTerm.app/Contents/Resources/wezterm.sh
fi

# 更新常用 CLI 工具
cli-update() {
  local verbose=""
  local tools_to_update=()
  local all_tools=("codex" "claude" "gemini" "uipro" "jules" "copilot" "opencode" "openspec" "spec-kit")

  for arg in "$@"; do
    if [[ "$arg" == "--verbose" ]]; then
      verbose="--verbose"
    else
      tools_to_update+=("$arg")
    fi
  done

  if [ ${#tools_to_update[@]} -eq 0 ]; then
    tools_to_update=("${all_tools[@]}")
  fi

  for tool in "${tools_to_update[@]}"; do
    case $tool in
      codex)
        npm install -g @openai/codex $verbose
        ;;
      claude)
        npm install -g @anthropic-ai/claude-code $verbose
        ;;
      gemini)
        npm install -g @google/gemini-cli@latest $verbose
        ;;
      uipro)
        npm install -g uipro-cli $verbose
        ;;
      jules)
        npm install -g @google/jules $verbose
        ;;
      copilot)
        npm install -g @github/copilot $verbose
        ;;
      opencode)
        npm install -g opencode-ai $verbose
        ;;
      openspec)
        npm install -g @fission-ai/openspec@latest $verbose
        ;;
      spec-kit)
        uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
        ;;
      *)
        echo "Unknown tool: $tool"
        ;;
    esac
  done
}

# 历史记录与交互选项
export HISTSIZE=10000
export SAVEHIST=10000
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_fcntl_lock 2>/dev/null
setopt hist_reduce_blanks
setopt SHARE_HISTORY

# Git 别名
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add --update'
alias gap='git apply'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbda='git branch --no-color --merged | command grep -vE "^(\*|\s*(master|develop|dev)\s*$)" | command xargs -n 1 git branch -d'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gc='git commit -v'
alias 'gc!'='git commit -v --amend'
alias 'gcn!'='git commit -v --no-edit --amend'
alias gca='git commit -v -a'
alias 'gca!'='git commit -v -a --amend'
alias 'gcan!'='git commit -v -a --no-edit --amend'
alias 'gcans!'='git commit -v -a -s --no-edit --amend'
alias gcam='git commit -a -m'
alias gcsm='git commit -s -m'
alias gcb='git checkout -b'
alias gcf='git config --list'
alias gcl='git clone --recursive'
alias gclean='git clean -fd'
alias gpristine='git reset --hard && git clean -dfx'
alias gcm='git checkout master'
alias gcd='git checkout develop'
alias gcmsg='git commit -m'
alias gco='git checkout'
alias gcount='git shortlog -sn'
compdef _git gcount
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gcs='git commit -S'

# 进入 nvim 时自动切换到目标目录
nvim() {
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      local dir
      dir=$(dirname "$1")
      command nvim --cmd "cd $dir" "$1"
    elif [[ "$1" = "." || "$1" = "./" ]]; then
      command nvim .
    else
      command nvim --cmd "cd $1" "$1"
    fi
  else
    command nvim .
  fi
}

_navi_call() {
  local result
  result="$(navi "$@" </dev/tty)"
  printf "%s" "$result"
}

_navi_widget() {
  local -r input="${LBUFFER}"
  local -r last_command="$(echo "${input}" | navi fn widget::last_command)"
  local replacement="$last_command"

  if [ -z "$last_command" ]; then
    replacement="$(_navi_call --print)"
  elif [ "$LASTWIDGET" = "_navi_widget" ] && [ "$input" = "$previous_output" ]; then
    replacement="$(_navi_call --print --query "$last_command")"
  else
    replacement="$(_navi_call --print --best-match --query "$last_command")"
  fi

  if [ -n "$replacement" ]; then
    local -r find="${last_command}_NAVIEND"
    previous_output="${input}_NAVIEND"
    previous_output="${previous_output//$find/$replacement}"
  else
    previous_output="$input"
  fi

  zle kill-whole-line
  LBUFFER="${previous_output}"
  region_highlight=("P0 100 bold")
  zle redisplay
}
zle -N _navi_widget
bindkey '^g' _navi_widget

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

if command -v atuin >/dev/null 2>&1; then
  bindkey -v

  export ATUIN_NOBIND="true"
  eval "$(atuin init zsh)"

  _bind_atuin_keys() {
    bindkey -M viins '^R' atuin-search
    bindkey -M vicmd '^R' atuin-search

    bindkey -M viins '^[[A' atuin-up-search
    bindkey -M viins '^[OA' atuin-up-search
    bindkey -M vicmd '^[[A' atuin-up-search
    bindkey -M vicmd '^[OA' atuin-up-search
  }

  _bind_atuin_keys

  # zsh-vi-mode 可能重建 keymap，这里在它初始化后重新绑定 Atuin。
  function zvm_after_init() {
    zvm_bindkey viins '^R' atuin-search
    zvm_bindkey vicmd '^R' atuin-search

    zvm_bindkey viins '^[[A' atuin-up-search
    zvm_bindkey viins '^[OA' atuin-up-search
    zvm_bindkey vicmd '^[[A' atuin-up-search
    zvm_bindkey vicmd '^[OA' atuin-up-search
  }
fi

if (( ${DOTFILES_ZINIT_READY:-0} )); then
  zinit ice depth=1
  zinit light jeffreytse/zsh-vi-mode
  zinit light zsh-users/zsh-syntax-highlighting
fi

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v delta >/dev/null 2>&1 && eval "$(delta --generate-completion zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias)"
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"

export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
  --color=fg:-1,fg+:#d0d0d0,bg:-1,bg+:#262626
  --color=hl:#5f87af,hl+:#5fd7ff,info:#87b0af,marker:#00f7ef
  --color=prompt:#0081d6,spinner:#af5fff,pointer:#4ed43c,header:#36d9fa
  --color=border:#262626,preview-fg:#76eb2d,label:#aeaeae,query:#d9d9d9
  --border="rounded" --border-label="" --preview-window="border-thinblock" --prompt=":> "
  --marker="=>" --pointer="->" --separator="-" --scrollbar="|" --info="right"'

if [[ "$TERM_PROGRAM" == "kiro" ]] && command -v kiro >/dev/null 2>&1; then
  . "$(kiro --locate-shell-integration-path zsh)"
fi

export ANDROID_HOME="$HOME/Library/Android/sdk"
[[ ":$PATH:" != *":$HOME/.config/kaku/zsh/bin:"* ]] && export PATH="$HOME/.config/kaku/zsh/bin:$PATH"
[[ -f "$HOME/.config/kaku/zsh/kaku.zsh" ]] && source "$HOME/.config/kaku/zsh/kaku.zsh"

# 本机私有覆盖配置放这里，避免把密钥提交到仓库
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
