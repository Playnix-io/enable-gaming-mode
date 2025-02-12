#!/bin/bash

#Dependencies
sudo pacman -Sy
sudo pacman -S --noconfirm --needed ryzenadj yay meson base-devel ninja podman libgudev steam
yay -S inputplumber-bin
pamac install --no-confirm steam-deckify

#Launch steam


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

#Login Fix
registry="$HOME/.steam/registry.vdf"
awk '
{
    print $0
    if ($0 ~ /"Rate"[[:space:]]+"30000"/) {
        print "\t\t\t\t\t\"CompletedOOBE\"\t\t\"1\""
    }
}' "$registry" > "${registry}.tmp" && mv "${registry}.tmp" "$registry"

#boot animation https://github.com/arvigeus/plymouth-theme-steamos
git clone https://github.com/arvigeus/plymouth-theme-steamos
mkdir -p /usr/share/plymouth/themes/steamos
sudo cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
sudo plymouth-set-default-theme -R steamos

#Clean up
rm -rf "$HOME/Desktop/enable-gaming.desktop"
#Rebooting
#reboot
echo "waiting for user"
read pause