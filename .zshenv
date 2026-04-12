if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

case ":$PATH:" in
  *":/opt/zerobrew/prefix/bin:"*) ;;
  *) export PATH="/opt/zerobrew/prefix/bin:$PATH" ;;
esac
