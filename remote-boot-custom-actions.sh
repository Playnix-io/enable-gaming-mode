#!/bin/bash
UUID=$(cat "/etc/.uuid")
UUID_HASH=$(echo "$UUID" | md5sum | tr -d 'a-f' | cut -c1-8)
UUID_NUM=$((16#$UUID_HASH))
ROLLOUT_PERCENTAGE=$((UUID_NUM % 100))
ROLLOUT_TARGET=5  # % will get this update
LOG_FILE="/tmp/boot-custom-actions.log"
VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2)

echo "Remote code! --- $(date +%s) ---" >> $LOG_FILE



#if [ $ROLLOUT_PERCENTAGE -lt $ROLLOUT_TARGET ]; then
if [[ "${UUID:-}" == "testbed" ]]; then

    (
        echo "Running as: $(whoami)" >> "$LOG_FILE"
        echo "playnix" | sudo -S pwd > /dev/null 2>&1
        echo 10; 
        #Fix timeout    
        CURRENT_TIMEOUT=$(grep TimeoutStartSec /etc/systemd/system/boot-custom-actions.service | grep -oE '[0-9]+')
        if [[ "$CURRENT_TIMEOUT" -le 90 ]]; then
            sudo sed -i '2i exec > /dev/tty1 2>&1' /usr/local/bin/boot-custom-actions.sh
            sudo sed -i 's/TimeoutStartSec=.*/TimeoutStartSec=600/' /etc/systemd/system/boot-custom-actions.service
            sudo systemctl daemon-reload    
            echo ">>> Timeout was 90, rebooting to apply new timeout..."
            echo ">>> Timeout was 90, rebooting to apply new timeout..." >> "$LOG_FILE"
            sudo reboot
        fi 
        echo 20; 
        # Deploy SD card auto-mount support if not already installed
        if [ ! -f /etc/udev/rules.d/99-sdcard-mount.rules ]; then
            echo ">>> Installing SD card auto-mount support..." >> "$LOG_FILE"
            sudo curl -sL -o /usr/local/bin/sdcard-mount.sh "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/sdcard-mount.sh"
            sudo chmod +x /usr/local/bin/sdcard-mount.sh
            sudo curl -sL -o /etc/udev/rules.d/99-sdcard-mount.rules "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/99-sdcard-mount.rules"
            sudo curl -sL -o /etc/systemd/system/sdcard-mount@.service "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/sdcard-mount@.service"
            sudo udevadm control --reload-rules
            echo ">>> SD card support installed" >> "$LOG_FILE"
        fi
        
        echo "✓ UUID in rollout group (${ROLLOUT_PERCENTAGE}% < ${ROLLOUT_TARGET}%)"
        echo 30; 
        echo "BEGIN REMOTE CODE --- $(date +%s) ---" >> "$LOG_FILE"
        
        # Fix audio lag
        #mkdir -p ~/.config/pipewire/pipewire.conf.d && cat > ~/.config/pipewire/pipewire.conf.d/99-gaming.conf << 'EOF'
        #context.properties = {
        #    default.clock.rate = 48000
        #    default.clock.quantum = 2048
        #    default.clock.min-quantum = 2048
        #    default.clock.max-quantum = 2048
        #}
        #EOF
        #sudo pacman -S rtkit --noconfirm
        #cat > ~/.config/pipewire/pipewire.conf.d/99-gaming.conf << 'EOF'
        #context.properties = {
        #    default.clock.rate = 48000
        #    default.clock.quantum = 2048
        #    default.clock.min-quantum = 2048
        #    default.clock.max-quantum = 2048
        #}
        #
        #context.modules = [
        #    { name = libpipewire-module-rtkit
        #        args = {
        #            nice.level = -15
        #            rt.prio = 88
        #            rt.time.soft = 200000
        #            rt.time.hard = 200000
        #        }
        #        flags = [ ifexists nofail ]
        #    }
        #]
        #EOF
        #systemctl --user restart pipewire pipewire-pulse wireplumber
    
        #OS Pacman update
        if [ -f /var/lib/pacman/db.lck ]; then
            echo "⚠ Pacman lock found. Checking if process exists..." >> "$LOG_FILE"
            if ! pgrep -x pacman >/dev/null; then
                echo "Lock is stale. Removing..." >> "$LOG_FILE"
                sudo rm -f /var/lib/pacman/db.lck
            else
                echo "Another pacman process is running. Exiting..." >> "$LOG_FILE"
            fi
        fi
        echo 50; 
        if [[ "$VERSION_ID" < "1.1" ]]; then
            sudo pacman -Rdd plasma-meta --noconfirm && sudo pacman -Rns krdp freerdp2 --noconfirm
            sudo pacman -Sy archlinux-keyring --noconfirm
            sudo rm -rf /usr/lib/firmware/nvidia/ad103 /usr/lib/firmware/nvidia/ad104 /usr/lib/firmware/nvidia/ad106 /usr/lib/firmware/nvidia/ad107
            
            echo 60; 
        
            #Update dependencies
            sudo pacman -Syyu --noconfirm >> $LOG_FILE 2>&1
            EXIT_CODE=$?
            echo 70; 
            if [ $EXIT_CODE -eq 0 ]; then
                echo "✓ Pacman completed: $(date)" >> "$LOG_FILE"
                if [[ "$VERSION_ID" < "1.1" ]]; then
                    sudo sed -i 's/VERSION_ID=.*/VERSION_ID=1.1/' /etc/os-release
                    #EmuDeck fix
                    echo 80; 
                    sudo pacman -Syu --noconfirm jq zenity flatpak unzip bash fuse2 git rsync libnewt python | sudo tee -a $LOG_FILE
                fi
            else
                echo "✗ Pacman Failed: $(date)" >> "$LOG_FILE"
            fi
            echo 100;
        else
            echo "System up to date..." >> "$LOG_FILE"
            echo 100;
        fi
    ) | whiptail --title "Playnix OS Update" --gauge "Updating, please wait..." 8 60 0 > /dev/tty1 2>&1
else
    echo "UPDATES not enabled for you --- $(date +%s) ---" >> "$LOG_FILE"
fi