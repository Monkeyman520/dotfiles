if status is-interactive
    # Commands to run in interactive sessions can go here
end

if string match -q "$TERM_PROGRAM" "kiro"
    and command -sq kiro
    . (kiro --locate-shell-integration-path fish)
end
