#!/bin/bash

# Inspired by https://github.com/unlbslk/arch-deckify/
(
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | echo "playnix" | sudo -S tee -a /etc/pacman.conf
    fi

    #Dependencies
    echo "playnix" | sudo -S pacman -Syu --noconfirm
    echo "15"
    echo "playnix" | sudo -S pacman -S --noconfirm --needed ryzenadj yay meson base-devel ninja podman mangohud gamescope libgudev steam bluez bluez-utils steam-devices lib32-glu lib32-libpulse lib32-alsa-plugins lib32-alsa-lib lib32-libvdpau wine wine-mono wine-gecko winetricks gamemode lib32-gamemode
    yay -S inputplumber-bin --no-confirm --answerdiff None --answerclean None
    yay -S gamescope-session-steam-git --noconfirm --echo "playnix" | sudo -Sloop
    echo "30"
    #Auto login
    if [ -f /etc/sddm.conf.d/kde_settings.conf ]; then
        CONFIG_FILE="/etc/sddm.conf.d/kde_settings.conf"
    else
        CONFIG_FILE="/usr/lib/sddm/sddm.conf.d/default.conf"
    fi
    echo "playnix" | sudo -S sed -i "s/^Relogin=false/Relogin=true/; s/^User=.*/User=$(whoami)/" "$CONFIG_FILE"

    echo '#!/usr/bin/bash

    if [ -f /etc/sddm.conf.d/kde_settings.conf ]; then
        CONFIG_FILE="/etc/sddm.conf.d/kde_settings.conf"
    else
        CONFIG_FILE="/usr/lib/sddm/sddm.conf.d/default.conf"
    fi

    # If no arguments are provided, list valid arguments
    if [ $# -eq 0 ]; then
        echo "Valid arguments: plasma, gamescope"
        exit 0
    fi

    # If the argument is "plasma"
    # IMPORTANT: If you want to use a desktop environment other than KDE Plasma, do not change the IF command.
    # Steam always runs this file as "steamos-session-select plasma" to switch to the desktop.
    # Instead, change the code below that edits the config file.

    if [ "$1" == "plasma" ] || [ "$1" == "desktop" ]; then

        echo "Switching session to Desktop."
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "SDDM config file could not be found at $CONFIG_FILE."
            exit 1
        fi
        NEW_SESSION='plasma' # For other desktops, change here.
        echo "playnix" | sudo -S sed -i "s/^Session=.*/Session=${NEW_SESSION}/" "$CONFIG_FILE"
        steam -shutdown

    # If the argument is "gamescope"
    elif [ "$1" == "gamescope" ]; then

        echo "Switching session to Gamescope."
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "SDDM config file could not be found at $CONFIG_FILE."
            exit 1
        fi
        NEW_SESSION="gamescope-session-steam"
        echo "playnix" | sudo -S sed -i "s/^Session=.*/Session=${NEW_SESSION}/" "$CONFIG_FILE"
        dbus-send --session --type=method_call --print-reply --dest=org.kde.Shutdown /Shutdown org.kde.Shutdown.logout || gnome-session-quit --logout --no-prompt || cinnamon-session-quit --logout --no-prompt || loginctl terminate-session $XDG_SESSION_ID
    else
        echo "Valid arguments are: plasma, gamescope."
        exit 1
    fi' | echo "playnix" | sudo -S tee /usr/bin/steamos-session-select > /dev/null

    echo "playnix" | sudo -S chmod +x /usr/bin/steamos-session-select

    echo "playnix" | sudo -Sers_file="/etc/echo "playnix" | sudo -Sers.d/sddm_config_edit"
    if [ ! -f "$echo "playnix" | sudo -Sers_file" ]; then
        echo "ALL ALL=(ALL) NOPASSWD: /usr/bin/sed -i s/^Session=*/Session=*/ ${CONFIG_FILE}" | echo "playnix" | sudo -S tee "$echo "playnix" | sudo -Sers_file" > /dev/null
        echo "playnix" | sudo -S chmod 440 "$echo "playnix" | sudo -Sers_file"
    fi

    echo "playnix" | sudo -S usermod -a -G video $(whoami)
    if ! grep -q 'ACTION=="add", SUBSYSTEM=="backlight"' /etc/udev/rules.d/backlight.rules; then
        echo 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"' | echo "playnix" | sudo -S tee -a /etc/udev/rules.d/backlight.rules
    fi
    echo "50"
    #Launch steam
    /usr/bin/steam > /dev/null 2>&1 &

    #Enable inputplumber
    echo "playnix" | sudo -S systemctl enable inputplumber
    echo "playnix" | sudo -S systemctl enable inputplumber-suspend
    echo "playnix" | sudo -S systemctl start inputplumber
    echo "playnix" | sudo -S systemctl enable bluetooth.service
    echo "playnix" | sudo -S systemctl start bluetooth.service

    #DeckyLoader
    curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh

    #Power button suspend
    git clone https://github.com/ShadowBlip/steam-powerbuttond.git
    cd steam-powerbuttond
    chmod +x install.sh
    bash install.sh
    cd ..
    rm -rf steam-powerbuttond

    #boot animation https://github.com/arvigeus/plymouth-theme-steamos
    git clone https://github.com/arvigeus/plymouth-theme-steamos
    echo "playnix" | sudo -S mkdir -p /usr/share/plymouth/themes/steamos
    echo "playnix" | sudo -S cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
    echo "playnix" | sudo -S plymouth-set-default-theme -R steamos
    echo "60"
    #Clean up
    rm -rf "$HOME/Desktop/enable-gaming.desktop"

    #Finish Steam
    while [ ! -f "$HOME/.steam/steam/config/config.vdf" ]; do
        echo "Waiting for Steam Config..."
        sleep 1
    done
    kill -15 $(pidof steam)
    echo "90"
    #Login Fix
    registry="$HOME/.steam/registry.vdf"
    curl -L -o $registry "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/registry.vdf"

    #Back to game mode icon
    curl -L -o "$HOME/Desktop/back.desktop" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/back.desktop"
    cp "$HOME/Desktop/back.desktop" "/usr/share/applications/back.desktop"
    chmod +x "$HOME/Desktop/back.desktop"
    chmod +x "/usr/share/applications/back.desktop"
    echo "100"
) |
zenity --progress \
  --title="Enabling Gaming Mode" \
  --text="Please wait..." \
  --percentage=0

if [ "$?" = -1 ] ; then
        zenity --error \
          --text="Update canceled."
fi