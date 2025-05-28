#!/bin/bash
(

    echo "playnix" | sudo -S pwd

    #Enable mirrorlist
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf

    #Update system
    sudo pacman -Syu --noconfirm

    #Dependencies
    sudo pacman -S steam mangohud gamescope bluez bluez-utils --noconfirm

    #We launch Steam
    /usr/bin/steam -silent > /dev/null 2>&1 &

    #GameScope
    yay -S gamescope-session-steam-git --noconfirm --sudoloop

    #Autologin sddm
    sudo sed -i "s/^Relogin=false/Relogin=true/; s/^User=.*/User=playnix/" "/usr/lib/sddm/sddm.conf.d/default.conf"

    #Session changer
    sudo curl -L -o "/usr/bin/steamos-session-select" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/steamos-session-select"
    sudo chmod +x /usr/bin/steamos-session-select

    echo "ALL ALL=(ALL) NOPASSWD: /usr/bin/sed -i s/^Session=*/Session=*/ /usr/lib/sddm/sddm.conf.d/default.conf" | sudo tee "/etc/sudoers.d/sddm_config_edit" > /dev/null
    sudo chmod 440 "/etc/sudoers.d/sddm_config_edit"

    #More dependencies
    #sudo pacman -S mangohud gamescope bluez bluez-utils --noconfirm

    #Fix brightness slider
    sudo usermod -a -G video $(whoami)
    echo 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"' | sudo tee -a /etc/udev/rules.d/backlight.rules

    #Back to game mode icon
    curl -L -o "$HOME/Desktop/back.desktop" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/back.desktop"
    sudo cp "$HOME/Desktop/back.desktop" "/usr/share/applications/back.desktop"
    chmod +x "$HOME/Desktop/back.desktop"
    sudo chmod +x "/usr/share/applications/back.desktop"

    #Powerbutton fix
    git clone https://github.com/ShadowBlip/steam-powerbuttond.git
    cd steam-powerbuttond
    bash install.sh
    cd ..
    rm -rf steam-powerbuttond

    #services
    sudo systemctl enable bluetooth.service
    sudo systemctl start bluetooth.service
    #sudo systemctl enable inputplumber
    #sudo systemctl enable inputplumber-suspend
    #sudo systemctl start inputplumber

    #Decky
    curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh

    #Plymouth theme
    git clone https://github.com/arvigeus/plymouth-theme-steamos
    sudo mkdir -p /usr/share/plymouth/themes/steamos
    sudo cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
    sudo plymouth-set-default-theme -R steamos

    #Clean up
    rm -rf "$HOME/Desktop/enable-gaming.desktop"

    #Waiting for steam config vdf
    while [ ! -f "$HOME/.steam/steam/config/config.vdf" ]; do
        echo "Waiting for Steam Config file to be created..."
        sleep 1
    done
    kill -15 $(pidof steam)

    #OOBE Login Fix
    curl -L -o "$HOME/.steam/registry.vdf" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/registry.vdf"

    #Pacman playnix safe mirror
    #sudo curl -L -o /etc/pacman.conf "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/pacman.conf"
    #sudo curl -L -o /etc/systemd/system/auto-update.service "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/auto-update.service"
    #sudo curl -L -o /etc/systemd/system/auto-update.timer "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/auto-update.timer"

    #sudo systemctl enable --now auto-update.timer

) |
zenity --progress \
  --title="Enabling Gaming Mode" \
  --text="Please wait..." \
  --percentage=0

if [ "$?" = -1 ] ; then
        zenity --error \
          --text="Update canceled."
fi