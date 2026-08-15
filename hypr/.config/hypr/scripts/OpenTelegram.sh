#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
# Script to open Telegram and switch to workspace 5

# Target workspace
TARGET_WS=5

# First switch to workspace 5
hyprctl dispatch workspace $TARGET_WS

# Get Telegram window info using JSON
TELEGRAM_INFO=$(hyprctl -j clients | jq -r '.[] | select(.class == "org.telegram.desktop") | "\(.address) \(.workspace.id)"' | head -1)

if [ -n "$TELEGRAM_INFO" ]; then
    # Telegram exists
    read ADDR CURRENT_WS <<< "$TELEGRAM_INFO"
    echo "Telegram window exists at $ADDR on workspace $CURRENT_WS"
    
    if [ "$CURRENT_WS" -ne "$TARGET_WS" ]; then
        echo "Moving Telegram to workspace $TARGET_WS"
        hyprctl dispatch movetoworkspacesilent $TARGET_WS,address:$ADDR
    else
        echo "Telegram already on workspace $TARGET_WS"
    fi
else
    # Telegram not running, launch it
    echo "Launching Telegram..."
    Telegram &
    # Give it a moment to start
    sleep 2
fi

# Focus the Telegram window (Hyprland will focus it if it's on current workspace)
# Optionally bring to front
# hyprctl dispatch focuswindow address:$ADDR 2>/dev/null || true