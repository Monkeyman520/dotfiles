if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

vmoptions_shell_file="${HOME}/.jetbrains.vmoptions.sh"
if [ -f "$vmoptions_shell_file" ]; then
  . "$vmoptions_shell_file"
fi
