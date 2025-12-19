#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Error on line $LINENO. Aborting."; exit 1' ERR

# --------------------------------------------------
# Root check
# --------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)."
  exit 1
fi

echo "========================================"
echo " Fedora 43 Minimal → MangoWC Post-Install"
echo "========================================"

# --------------------------------------------------
# User input
# --------------------------------------------------
read -rp "Is this a Laptop or Desktop? [l/d]: " SYSTEM_TYPE
read -rp "GPU type: Intel / AMD / NVIDIA? [i/a/n]: " GPU_TYPE

SYSTEM_TYPE=$(echo "$SYSTEM_TYPE" | tr '[:upper:]' '[:lower:]')
GPU_TYPE=$(echo "$GPU_TYPE" | tr '[:upper:]' '[:lower:]')

if [[ ! "$SYSTEM_TYPE" =~ ^(l|d)$ ]]; then
  echo "Invalid system type."
  exit 1
fi

if [[ ! "$GPU_TYPE" =~ ^(i|a|n)$ ]]; then
  echo "Invalid GPU type."
  exit 1
fi

# --------------------------------------------------
# System update
# --------------------------------------------------
dnf -y upgrade --refresh

# --------------------------------------------------
# Enable RPM Fusion
# --------------------------------------------------
dnf -y install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# --------------------------------------------------
# Enable Terra repo (mangowc source)
# --------------------------------------------------
dnf -y install \
  https://terra.fyralabs.com/repos/terra-release-$(rpm -E %fedora).noarch.rpm

# --------------------------------------------------
# Base system utilities
# --------------------------------------------------
dnf -y install \
  sudo \
  curl wget \
  git \
  vim nano \
  htop \
  fastfetch \
  unzip p7zip \
  bash-completion

# --------------------------------------------------
# Wayland + MangoWC
# --------------------------------------------------
dnf -y install \
  mangowc \
  wlroots \
  wayland wayland-utils \
  xwayland \
  seatd \
  dbus polkit \
  xdg-desktop-portal \
  xdg-desktop-portal-wlr

systemctl enable --now seatd

# --------------------------------------------------
# Audio (PipeWire)
# --------------------------------------------------
dnf -y install \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  pipewire-jack-audio-connection-kit \
  wireplumber \
  pavucontrol

# --------------------------------------------------
# Networking & Bluetooth
# --------------------------------------------------
dnf -y install \
  NetworkManager \
  network-manager-applet \
  bluez blueman

systemctl enable --now NetworkManager
systemctl enable --now bluetooth

# --------------------------------------------------
# GPU drivers
# --------------------------------------------------
case "$GPU_TYPE" in
  i)
    dnf -y install \
      mesa-dri-drivers \
      mesa-vulkan-drivers \
      intel-media-driver \
      libva-utils
    ;;
  a)
    dnf -y install \
      mesa-dri-drivers \
      mesa-vulkan-drivers \
      mesa-va-drivers \
      libva-utils
    ;;
  n)
    dnf -y install \
      akmod-nvidia \
      xorg-x11-drv-nvidia-cuda \
      mesa-vulkan-drivers
    ;;
esac

# --------------------------------------------------
# UI utilities (minimal & required)
# --------------------------------------------------
dnf -y install \
  waybar \
  wofi \
  mako \
  wl-clipboard \
  grim slurp swaybg kanshi

# --------------------------------------------------
# Terminal & file manager
# --------------------------------------------------
dnf -y install \
  foot \
  thunar \
  thunar-archive-plugin \
  file-roller

# --------------------------------------------------
# Fonts (Wayland-safe)
# --------------------------------------------------
dnf -y install \
  jetbrains-mono-fonts \
  google-noto-fonts-all \
  fontconfig

# --------------------------------------------------
# Power management (exclusive)
# --------------------------------------------------
dnf -y install tlp power-profiles-daemon

if [[ "$SYSTEM_TYPE" == "l" ]]; then
  systemctl disable --now power-profiles-daemon || true
  systemctl enable --now tlp
else
  systemctl disable --now tlp || true
  systemctl enable --now power-profiles-daemon
fi

# --------------------------------------------------
# Gaming stack
# --------------------------------------------------
dnf -y install \
  steam \
  gamemode \
  mangohud \
  gamescope

# --------------------------------------------------
# greetd (Wayland-native login)
# --------------------------------------------------
dnf -y install greetd greetd-regreet
systemctl enable greetd

cat > /etc/greetd/config.toml << 'EOF'
[terminal]
vt = 1

[default_session]
command = "mangowc"
user = "greeter"
EOF

# --------------------------------------------------
# Dotfiles skeleton (safe defaults)
# --------------------------------------------------
SKEL="/etc/skel/.config"
mkdir -p "$SKEL"/{mangowc,waybar,wofi,mako,foot}

cat > "$SKEL/mangowc/config" << 'EOF'
exec waybar
exec mako

bind SUPER+Return exec foot
bind SUPER+D exec wofi --show drun
bind SUPER+Q close
bind SUPER+Shift+E exit
EOF

cat > "$SKEL/waybar/config.json" << 'EOF'
{
  "layer": "top",
  "modules-left": ["clock"],
  "modules-center": ["mangowc/workspaces"],
  "modules-right": ["pulseaudio", "network", "battery", "tray"]
}
EOF

cat > "$SKEL/waybar/style.css" << 'EOF'
* {
  font-family: JetBrains Mono;
  font-size: 13px;
}
EOF

cat > "$SKEL/wofi/config" << 'EOF'
show=drun
EOF

cat > "$SKEL/mako/config" << 'EOF'
border-radius=6
EOF

# --------------------------------------------------
# Completion
# --------------------------------------------------
echo ""
echo "========================================"
echo "        MangoWC system ready            "
echo "========================================"
echo ""
echo "Reboot now."
[[ "$GPU_TYPE" == "n" ]] && echo "⚠ NVIDIA users: reboot is REQUIRED."
