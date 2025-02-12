#!/bin/bash

#Dependencies
sudo pacman -Sy
sudo pacman -S --noconfirm --needed ryzenadj yay meson base-devel ninja podman libgudev steam
# No longer needed since February
#yay -S inputplumber-bin --no-confirm --answerdiff None --answerclean None
pamac install --no-confirm steam-deckify

#Launch steam
/usr/bin/steam > /dev/null 2>&1 &
#Finish Steam
while [ ! -f "$HOME/.steam/steam/config/config.vdf" ]; do
    echo "Waiting for Steam Config..."
    sleep 1
done
kill -15 $(pidof steam)
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

#Login Fix
registry="$HOME/.steam/registry.vdf"
curl -L -o $registry "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/registry.vdf"


#Rebooting
sudo reboot
