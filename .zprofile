toolbox_scripts_dir="$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
if [ -d "$toolbox_scripts_dir" ]; then
  export PATH="$PATH:$toolbox_scripts_dir"
fi

source ~/.zshrc
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh --shims)"
