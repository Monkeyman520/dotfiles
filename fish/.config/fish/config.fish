if status is-interactive
    # Commands to run in interactive sessions can go here
end

if test -d "$HOME/.atuin/bin"
    fish_add_path "$HOME/.atuin/bin"
end

if string match -q "$TERM_PROGRAM" "kiro"
    and command -sq kiro
    . (kiro --locate-shell-integration-path fish)
end
