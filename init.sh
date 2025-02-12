#!/bin/bash

#Dependencies
sudo pacman -Sy
sudo pacman -S --noconfirm --needed ryzenadj yay meson base-devel ninja podman libgudev steam
yay -S inputplumber-bin
pamac install --no-confirm steam-deckify

#Launch steam
/usr/bin/steam &

#Login Fix
while [ ! -f "$HOME/.steam/registry.vdf" ]; do
    sleep 1
    kill -15 $(pidof steam)
done
registry="$HOME/.steam/registry.vdf"
curl -L -o $registry "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/registry.vdf"

#Enable inputplumber
sudo systemctl enable inputplumber
sudo systemctl enable inputplumber-suspend
sudo systemctl start inputplumber

#DeckyLoader
curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh

#DeckyPlugins

#Grub changes
GRUB_CONFIG="/etc/default/grub"
GRUB_CMDLINE="amd_pstate=active amd_prefcore=enable iomem=relaxed"
sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE /" "$GRUB_CONFIG"
sudo update-grub

#boot animation https://github.com/arvigeus/plymouth-theme-steamos
git clone https://github.com/arvigeus/plymouth-theme-steamos
sudo mkdir -p /usr/share/plymouth/themes/steamos
sudo cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
sudo plymouth-set-default-theme -R steamos

#Clean up
rm -rf "$HOME/Desktop/enable-gaming.desktop"


#Rebooting
sudo reboot
