# Managed via GNU Stow — edit ~/dotfiles/shell/.zshrc, not the ~/.zshrc symlink directly.

# --- History Configuration ---
# HISTSIZE = lines kept in memory for this session; SAVEHIST = lines written to HISTFILE on exit.
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# --- Basic Capabilities ---
autoload -U colors && colors
setopt prompt_subst

# --- Optimized Completion System ---
# Only regenerate the completion dump once a day to speed up startup
autoload -Uz compinit
zstyle ':completion:*' menu select
# Check if cache exists and is less than 24h old; otherwise regenerate
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit -C
else
  compinit -i
fi

# --- Git Integration (vcs_info) ---
autoload -Uz vcs_info
precmd() { vcs_info }

# Git status check optimization
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr ' *'
zstyle ':vcs_info:*' stagedstr ' +'
zstyle ':vcs_info:git:*' formats '%F{242}(git: %B%F{magenta}%b%F{yellow}%u%F{green}%c%f%F{242})%f '

# --- The Prompt Design ---
# Line 1: ╭─ Username in Directory (git info)
PROMPT=$'\n%F{cyan}╭─%B%F{cyan}%n%f%b %F{white}in%f %B%F{blue}%~%f%b ${vcs_info_msg_0_}
%F{cyan}╰─%f%(?.%F{green}➜%f.%F{red}➜%f) '

# --- Aliases ---
alias ls='ls --color=auto'
alias ll='ls -l'
alias grep='grep --color=auto'
alias c='clear'

# --- Path Exports (Grouped for speed) ---
export BUN_INSTALL="$HOME/.bun"
export NVM_DIR="$HOME/.config/nvm"
export PATH="$NVM_DIR/versions/node/v22.22.0/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$BUN_INSTALL/bin:$PATH"

# --- LAZY LOAD NVM (Major Speed Boost) ---
# NVM only initializes when you actually use these commands
function nvm node npm {
  unfunction nvm node npm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  "$0" "$@"
}

# --- Other Tool Completions ---
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
[ -f "$HOME/.openclaw/completions/openclaw.zsh" ] && source "$HOME/.openclaw/completions/openclaw.zsh"

# --- Visuals (Fastfetch) ---
# Only run if we are in an interactive shell to avoid errors in scripts.
# Skipped in panes tmux-keep just restored: they show their old text instead.
if [[ -o interactive && -z $TMUX_KEEP_REPLAY ]]; then
    if command -v fastfetch > /dev/null; then
        fastfetch \
            --logo arch_small \
            --structure Break:Break:Title:OS:Kernel:Packages:Memory \
            --color-title cyan
    fi
fi

# --- PLUGINS (Must be loaded last) ---
# 1. Autosuggestions
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# 2. Syntax Highlighting (ALWAYS LAST)
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# raylib/GLX fix for Wayland + Intel Iris + NVIDIA hybrid
export DISPLAY="${DISPLAY:-:1}"
export __GLX_VENDOR_LIBRARY_NAME=mesa
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330

source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# Rebind fzf-cd from Alt-C to Ctrl-F
bindkey -r '\ec'
bindkey '^F' fzf-cd-widget

# fzf: options live in a separate file so complex bindings stay readable
export FZF_DEFAULT_OPTS_FILE="$HOME/dotfiles/shell/fzf-options"

# Ctrl-T (file picker): preview file contents with syntax highlighting
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"

# Ctrl-F / Alt-C (dir picker): pretty directory preview with icons
export FZF_ALT_C_OPTS="--preview 'lsd -la --color=always --icon=always {}'"

# forgit: fuzzy git commands (ga, glo, gd, gcf, gss, etc.)
[ -f /usr/share/zsh/plugins/forgit-git/forgit.plugin.zsh ] && source /usr/share/zsh/plugins/forgit-git/forgit.plugin.zsh

# fnv: fuzzy-find a line across files in a directory, open in nvim at that line
# Usage: fnv            (searches current dir)
#        fnv ~/projects (searches given dir)
fnv() {
  local dir="${1:-.}"
  local pick
  pick=$(rg -n --no-heading --color=never "" "$dir" | fzf \
    --delimiter=: \
    --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
    --preview-window 'right:60%:+{2}/2') || return
  [ -z "$pick" ] && return
  local file line
  file=$(echo "$pick" | awk -F: '{print $1}')
  line=$(echo "$pick" | awk -F: '{print $2}')
  nvim "+$line" "$file"
}

# --- Machine-local secrets (not in the dotfiles repo) ---
# Defines OPENCLAW_TOKEN. See ~/dotfiles/templates/secrets.env.example.
[ -f "$HOME/.config/secrets.env" ] && source "$HOME/.config/secrets.env"

# OpenClaw TUI alias
alias octui='openclaw tui --token "$OPENCLAW_TOKEN"'
alias get_idf='. ~/esp-idf/export.sh'

# tailscaled is off until needed (system/on-demand.sh): `up` starts it,
# `down` stops it again. polkit lets systemctl do this without sudo.
tailscale() {
    case "${1:-}" in
        up|login|set|switch)
            systemctl is-active -q tailscaled || systemctl start tailscaled || return ;;
    esac
    command tailscale "$@" || return
    [ "${1:-}" = down ] && systemctl stop tailscaled
    return 0
}

# OpenClaw Completion
[ -f "/home/mahmood/.openclaw/completions/openclaw.zsh" ] && source "/home/mahmood/.openclaw/completions/openclaw.zsh"


# Added by Antigravity CLI installer
export PATH="/home/mahmood/.local/bin:$PATH"

# Note: Claude Code (below) needs the tmux-hiding wrapper because of the
# color-detection quirk described in its own comment.
# Claude Code truecolor inside tmux — CC gates 24-bit on $TERM whitelist
# (ignores COLORTERM/FORCE_COLOR/terminfo RGB), so masquerade as alacritty.
claude() {
  if [[ -n "$TMUX" ]]; then
    # Claude Code downgrades to 256-color when $TMUX is set, regardless of
    # FORCE_COLOR / COLORTERM / TERM. Hide tmux from it to get truecolor.
    env -u TMUX FORCE_COLOR=3 claude "$@"
  else
    command claude "$@"
  fi
}
unset TMUX_KEEP_REPLAY   # only the first shell of a restored tmux pane skips the greeting
