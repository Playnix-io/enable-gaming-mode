#!/bin/bash
(

echo "playnix" | sudo -S pwd
#Make sure our time is up to date
sudo systemctl restart systemd-timesyncd

echo "playnix ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syu --noconfirm" | sudo tee /etc/sudoers.d/99-pacman-nopasswd
echo "playnix ALL=(ALL) NOPASSWD: /usr/bin/pacman -S * --noconfirm" | sudo tee -a /etc/sudoers.d/99-pacman-nopasswd
sudo chmod 440 /etc/sudoers.d/99-pacman-nopasswd

echo "Importing GPG signing key..."
curl -L "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/playnix-signing-key.pub" | gpg --import
echo "53BA244384BF21E9:6:" | gpg --import-ownertrust

sddmConf="/usr/lib/sddm/sddm.conf.d/default.conf"
if [ -f /etc/sddm.conf.d/kde_settings.conf ]; then
    sddmConf="/etc/sddm.conf.d/kde_settings.conf"
fi

sudoers_file="/etc/sudoers.d/sddm_config_edit"

#Missing fonts. To do - Move them to playnix pacman repo
sudo pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji parted --noconfirm
echo "playnix" | sudo -S pwd
echo "8"
echo "#Installing Steam"
sudo curl -L -o /etc/pacman.conf "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/pacman.conf"
echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
sudo pacman -Sy steam --noconfirm

sudo pacman -S nano curl git wget base-devel firefox plymouth gwenview fuse --noconfirm

git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
echo "playnix" | sudo -S pwd
yay -S gamescope-session-steam-git --noconfirm --sudoloop
echo "playnix" | sudo -S pwd
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
echo "playnix" | sudo -S pwd
echo "48"
echo "#Creating desktop icon"
curl -L -o "$HOME/Desktop/back.desktop" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/back.desktop"
chmod +x "$HOME/Desktop/back.desktop"

#Setting up autoupdater
#curl -L -o "$HOME/.bashrc" "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/.bashrc"
#curl -L "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/playnix.pub" | gpg --import

echo "56"
echo "#Enabling Bluetooth"
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

echo "64"
echo "#Setting up Sleep Button"
sudo cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak
sudo curl -L -o /etc/systemd/logind.conf "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/logind.conf"

echo "72"
echo "playnix" | sudo -S pwd
#echo "#Installing Decky"
#sh -c 'rm -f /tmp/user_install_script.sh; if curl -S -s -L -O --output-dir /tmp/ --connect-timeout 60 https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/user_install_script.sh; then bash /tmp/user_install_script.sh; else echo "Something went wrong, please report this if it is a bug"; read; fi'
echo "80"
echo "#Setting Plymouth Theme"
git clone https://github.com/arvigeus/plymouth-theme-steamos
sudo mkdir -p /usr/share/plymouth/themes/steamos
sudo cp -r ./plymouth-theme-steamos/* /usr/share/plymouth/themes/steamos/ && rm -rf plymouth-theme-steamos
sudo plymouth-set-default-theme -R steamos
echo "88"
echo "#Setting Playnix auto update channel"
sudo curl -L -o /usr/local/bin/boot-custom-actions.sh "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/boot-custom-actions.sh"
sudo curl -L -o /etc/systemd/system/boot-custom-actions.service "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/boot-custom-actions.service"
sudo chmod +x /usr/local/bin/boot-custom-actions.sh
sudo systemctl enable boot-custom-actions.service

#sudo systemctl enable --now sshd

rm -rf "$HOME/Desktop/enable-gaming.desktop"


echo "100"

#steamos-session-select gamescope

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