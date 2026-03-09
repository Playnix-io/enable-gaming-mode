#!/bin/bash
UUID=$(cat "/etc/.uuid")
UUID_HASH=$(echo "$UUID" | md5sum | tr -d 'a-f' | cut -c1-8)
UUID_NUM=$((16#$UUID_HASH))
ROLLOUT_PERCENTAGE=$((UUID_NUM % 100))
ROLLOUT_TARGET=5  # % will get this update
LOG_FILE="/tmp/boot-custom-actions.log"

echo "Remote code! --- $(date +%s) ---" >> $LOG_FILE


#if [ $ROLLOUT_PERCENTAGE -lt $ROLLOUT_TARGET ]; then
if [[ "${UUID:-}" == "testbed" ]]; then

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

    #Pacman update
    if [ -f /var/lib/pacman/db.lck ]; then
        echo "⚠ Pacman lock found. Checking if process exists..." >> "$LOG_FILE"
        if ! pgrep -x pacman >/dev/null; then
            echo "Lock is stale. Removing..." >> "$LOG_FILE"
            sudo rm -f /var/lib/pacman/db.lck
        else
            echo "Another pacman process is running. Exiting..." >> "$LOG_FILE"
        fi
    fi
    
    sudo pacman -Rdd plasma-meta --noconfirm && sudo pacman -Rns krdp freerdp2 --noconfirm
    sudo pacman -Sy archlinux-keyring --noconfirm
    sudo rm -rf /usr/lib/firmware/nvidia/ad103 /usr/lib/firmware/nvidia/ad104 /usr/lib/firmware/nvidia/ad106 /usr/lib/firmware/nvidia/ad107
    
    #Update dependencies
    sudo pacman -Syyu --noconfirm | sudo tee -a $LOG_FILE    
    
    #EmuDeck fix
    sudo pacman -Syu --noconfirm jq zenity flatpak unzip bash fuse2 git rsync libnewt python | sudo tee -a $LOG_FILE
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✓ Pacman completed: $(date)" >> "$LOG_FILE"
    else
        echo "✗ Pacman Failed: $(date)" >> "$LOG_FILE"
    fi
else
    echo "UPDATES not enabled for you --- $(date +%s) ---" >> "$LOG_FILE"
fi