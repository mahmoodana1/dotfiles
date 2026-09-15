#!/bin/sh
# SUPER+T target: focus taskvim if it is already running, otherwise launch it
# on workspace 8. The window rules in lua/windowrules.lua pin the `taskvim`
# class to workspace 8 and force fullscreen, so placement happens before the
# window maps — no sleep, no flicker on the current workspace.
#
# Note: this Hyprland build (0.56, Lua config) evaluates `hyprctl dispatch`
# arguments as Lua, so dispatches must use hl.dsp.* call syntax — the legacy
# `dispatch workspace 8` form is a Lua syntax error here.

CLASS=taskvim

hyprctl dispatch 'hl.dsp.focus({ workspace = 8 })'

if ! hyprctl clients -j | grep -q "\"class\": \"$CLASS\""; then
  # Dedicated class (not plain "alacritty") so the window rules and this
  # already-running check only ever match taskvim.
  #
  # Two things alacritty needs that kitty did not:
  #   * the binary is lowercase `alacritty` — `Alacritty` is the WM_CLASS, not
  #     a command, so calling it that way fails silently under setsid;
  #   * the program must follow `-e`. kitty accepts a bare trailing command,
  #     alacritty treats it as an unrecognised argument and refuses to start.
  setsid -f "${TERMINAL:-alacritty}" --class "$CLASS" -T taskvim -e "$HOME/.local/bin/taskvim" \
    >/dev/null 2>&1
fi
