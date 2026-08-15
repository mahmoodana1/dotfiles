# --- History Configuration ---
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
# Only run if we are in an interactive shell to avoid errors in scripts
if [[ -o interactive ]]; then
    if command -v fastfetch > /dev/null; then
        fastfetch \
            --logo arch_small \
            --structure Title:OS:Kernel:Packages:Memory \
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

# --- Machine-local secrets (not in the dotfiles repo) ---
# Defines OPENCLAW_TOKEN. See ~/dotfiles/templates/secrets.env.example.
[ -f "$HOME/.config/secrets.env" ] && source "$HOME/.config/secrets.env"

# OpenClaw TUI alias
alias octui='openclaw tui --token "$OPENCLAW_TOKEN"'
alias get_idf='. ~/esp-idf/export.sh'
