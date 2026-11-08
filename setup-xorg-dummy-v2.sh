#!/usr/bin/env bash
set -euo pipefail

CONFIG=/etc/X11/xorg.conf
TEMP_CONFIG=$(mktemp)
trap 'rm -f -- "$TEMP_CONFIG"' EXIT

cat > "$TEMP_CONFIG" <<'EOF'
Section "Device"
    Identifier "Configured Video Device"
    Driver "dummy"
    VideoRam 262144
    DacSpeed 600
EndSection

Section "Monitor"
    Identifier "Configured Monitor"
    HorizSync 30-160
    VertRefresh 50-75

    Modeline "1280x720"   63.75 1280 1328 1360 1440 720 723 728 741 +hsync -vsync
    Modeline "1920x1080" 138.50 1920 1968 2000 2080 1080 1083 1088 1111 +hsync -vsync
    Modeline "2560x1440" 312.25 2560 2752 3024 3488 1440 1443 1448 1493 -hsync +vsync
    Modeline "3440x1440" 319.75 3440 3488 3520 3600 1440 1443 1453 1481 +hsync -vsync
    Modeline "3441x1440" 320.50 3441 3496 3528 3608 1440 1443 1453 1481 +hsync -vsync
    # Xorg dummy rejects the standard CVT reduced-blanking timing for 3680x1440.
    Modeline "3680x1440" 341.75 3680 3736 3768 3848 1440 1443 1453 1481 +hsync -vsync
    Modeline "3840x2160" 533.00 3840 3888 3920 4000 2160 2163 2168 2222 +hsync -vsync
    Modeline "3840x2400" 592.25 3840 3888 3920 4000 2400 2403 2409 2469 +hsync -vsync
EndSection

Section "Screen"
    Identifier "Default Screen"
    Monitor "Configured Monitor"
    Device "Configured Video Device"
    DefaultDepth 24

    SubSection "Display"
        Depth 24
        Virtual 3840 2400
        Modes "3440x1440" "3441x1440" "3680x1440" "2560x1440" "1920x1080" "1280x720" "3840x2160" "3840x2400"
    EndSubSection
EndSection
EOF

missing=()
for package in xserver-xorg-video-dummy x11-xserver-utils; do
    if [[ $(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true) != 'install ok installed' ]]; then
        missing+=("$package")
    fi
done
if ((${#missing[@]})); then
    sudo apt-get update
    sudo apt-get install -y -- "${missing[@]}"
fi

if [[ -f "$CONFIG" ]] && cmp -s -- "$CONFIG" "$TEMP_CONFIG"; then
    printf 'Already configured: %s\n' "$CONFIG"
    exit 0
fi

if [[ -e "$CONFIG" ]]; then
    BACKUP="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S-%N)"
    sudo cp -a -- "$CONFIG" "$BACKUP"
    printf 'Backup: %s\n' "$BACKUP"
fi
sudo install -m 644 -- "$TEMP_CONFIG" "$CONFIG"
printf 'Saved: %s\nLog out and back in after saving your work to apply the configuration.\n' "$CONFIG"
