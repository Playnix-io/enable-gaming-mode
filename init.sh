#!/bin/bash
(

sddmConf="/etc/sddm.conf.d/kde_settings.conf"
sudoers_file="/etc/sudoers.d/sddm_config_edit"

echo "playnix" | sudo -S pwd
echo "8"
echo "#Installing Steam"
echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
sudo pacman -Sy steam --noconfirm
yay -S gamescope-session-steam-git --noconfirm --sudoloop
echo "24"
echo "#Setting up auto login"
sudo curl -L -o "/usr/bin/steamos-session-select" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/steamos-session-select"
sudo chmod +x /usr/bin/steamos-session-select
echo "ALL ALL=(ALL) NOPASSWD: /usr/bin/sed -i s/^Session=*/Session=*/ ${sddmConf}" | sudo tee $sudoers_file > /dev/null
sudo chmod 440 $sudoers_file
echo "32"
echo "#Installing dependences"
sudo pacman -S mangohud gamescope bluez bluez-utils inputplumber --noconfirm
echo "40"
echo "#Applying fixes"
sudo usermod -a -G video playnix
echo 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"' | sudo tee -a /etc/udev/rules.d/backlight.rules
#Intel
sudo pacman -S vulkan-intel lib32-vulkan-intel mesa lib32-mesa lib32-glibc lib32-giflib lib32-libpulse \
 lib32-libxcomposite lib32-libxrandr \
 lib32-alsa-plugins lib32-alsa-lib --noconfirm
echo "48"
echo "#Creating desktop icon"
curl -L -o "$HOME/Desktop/back.desktop" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/back.desktop"
chmod +x "$HOME/Desktop/back.desktop"

#Setting up autoupdater
curl -L -o "$HOME/.bashrc" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/.bashrc"
curl -L "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/playnix.pub" | gpg --import

echo "56"
echo "#Enabling Bluetooth"
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

echo "64"
echo "#Setting up Sleep Button"
git clone https://github.com/ShadowBlip/steam-powerbuttond.git
cd steam-powerbuttond
chmod +x install.sh
bash install.sh
cd ..
rm -rf steam-powerbuttond
echo "72"
echo "#Installing Decky"
curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
echo "80"
echo "#Setting Plymouth Theme"
git clone https://github.com/arvigeus/plymouth-theme-steamos
sudo mkdir -p /usr/share/plymouth/themes/steamos
sudo cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
sudo plymouth-set-default-theme -R steamos
echo "88"
echo "#Setting Playnix update channel"
sudo curl -L -o /etc/pacman.conf "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/pacman.conf"
sudo curl -L -o /etc/systemd/system/auto-update.service "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/auto-update.service"
sudo curl -L -o /etc/systemd/system/auto-update.timer "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/auto-update.timer"
sudo systemctl enable --now auto-update.timer

rm -rf "$HOME/Desktop/enable-gaming.desktop"

echo "100"

steamos-session-select gamescope

) |
zenity --progress \
  --title="Enabling Gaming Mode" \
  --text="Please wait..." \
  --percentage=0 \
  --auto-close

if [ "$?" = -1 ] ; then
        zenity --error \
          --text="Update canceled."
fi