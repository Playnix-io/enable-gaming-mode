#!/bin/bash

#Dependencies
sudo pacman -Sy
sudo pacman -S --noconfirm  ryzenadj yay meson base-devel ninja podman libgudev steam && ~/.steam/steam -silent -nofriendsui -no-browser
yay -S inputplumber-bin
pamac install --no-confirm steam-deckify

#Enable inputplumber
sudo systemctl enable inputplumber
sudo systemctl enable inputplumber-suspend
sudo systemctl start inputplumber

#DeckyLoader
curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh

#Grub changes
GRUB_CONFIG="/etc/default/grub"
GRUB_CMDLINE="amd_pstate=active amd_prefcore=enable iomem=relaxed"
sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE /" "$GRUB_CONFIG"
sudo update-grub

#Login Fix
#sed -i '/"AutoLoginUser"/a \ \ \ \ \ \ \ \ "CompletedOOBE"\t\t"1"' "$HOME/.steam/registry.vdf"

#boot animation https://github.com/arvigeus/plymouth-theme-steamos
git clone https://github.com/arvigeus/plymouth-theme-steamos
mkdir -p /usr/share/plymouth/themes/steamos
sudo cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
sudo plymouth-set-default-theme -R steamos

#Clean up
rm -rf "$HOME/Desktop/enable-gaming.desktop"
#Rebooting
#reboot