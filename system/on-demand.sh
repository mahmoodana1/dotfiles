#!/usr/bin/env bash
# Root half of "idle services sleep until asked for". Run once:
#     sudo ~/dotfiles/system/on-demand.sh
#
#   docker     not started at boot; docker.socket starts it on the first
#              docker command, docker-idle-stop.timer stops it again when no
#              containers run (checked every 15 min)
#   tailscaled not started at boot; `tailscale up` starts it, `tailscale down`
#              stops it (shell/.zshrc function + polkit rule, no password)
#   sddm       Wayland greeter (weston), so its Xorg doesn't outlive the login
#
# The user half (OpenClaw gateway on demand, nm-applet only in waybar mode)
# lives in desktop/.config/systemd/user and hypr/, deployed by stow.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
cd "$(dirname "$0")"

pacman -S --needed --noconfirm weston

install -Dm644 etc/systemd/system/docker-idle-stop.service /etc/systemd/system/docker-idle-stop.service
install -Dm644 etc/systemd/system/docker-idle-stop.timer   /etc/systemd/system/docker-idle-stop.timer
install -Dm644 etc/polkit-1/rules.d/50-tailscaled.rules    /etc/polkit-1/rules.d/50-tailscaled.rules
install -Dm644 etc/sddm.conf.d/10-wayland-greeter.conf     /etc/sddm.conf.d/10-wayland-greeter.conf
systemctl daemon-reload

# docker: socket-activated; running containers are left alone until idle
systemctl disable docker.service
systemctl enable docker.socket
systemctl enable --now docker-idle-stop.timer

# tailscale: off until `tailscale up`
systemctl disable --now tailscaled.service

echo "done — the SDDM greeter change applies from the next boot"
