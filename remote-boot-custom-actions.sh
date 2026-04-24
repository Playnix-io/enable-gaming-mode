#!/bin/bash
#Change this to create updates
VERSION_ID_TARGET="1.4"
PACMAN_TARGET_DATE="2026/03/09"
ENABLED_UPDATE=false
UUID=$(cat "/etc/.uuid")
UUID_HASH=$(echo "$UUID" | md5sum | tr -d 'a-f' | cut -c1-8)
UUID_NUM=$((16#$UUID_HASH))
ROLLOUT_PERCENTAGE=$((UUID_NUM % 100))
ROLLOUT_TARGET=0  # % will get this update
LOG_FILE="/tmp/boot-custom-actions.log"
VERSION_ID_CURRENT=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2)
PACMAN_CURRENT_DATE=$(cat /etc/playnix-repo-date 2>/dev/null || echo "none")

if [ $ROLLOUT_PERCENTAGE -lt $ROLLOUT_TARGET ]; then
   ENABLED_UPDATE=true
fi

if [[ "${UUID:-}" == "testbed" ]]; then
   ENABLED_UPDATE=true
fi


version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

_ASKPASS="/tmp/.askpass_$$"
printf '#!/bin/bash\necho "playnix"\n' > "$_ASKPASS"
chmod +x "$_ASKPASS"
export SUDO_ASKPASS="$_ASKPASS"

sudo(){
    command sudo -A "$@"
}


check_sudo(){                  
   local retries=10
   local delay=3
   for ((i=1; i<=retries; i++)); do
      if sudo pwd > /dev/null 2>&1; then
         return 0
      fi 
      echo "sudo not ready, attempt $i/$retries..." >> $LOG_FILE
      faillock --user playnix --reset 2>/dev/null
      sleep $delay           
   done
   echo "sudo error after $retries attempts! --- $(date +%s) ---" >> $LOG_FILE            
   exit 1 
}
progress_bar() {
    check_sudo
    local progress=$1
    local width=40
    local filled=$(( progress * width / 100 ))
    local empty=$(( width - filled ))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    echo -ne "\r\033[38;5;214m [${bar}] ${progress}% \033[0m" | sudo tee /dev/tty1 > /dev/null
}
check_pacman_health(){
    check_sudo
    if [[ "$VERSION_ID_CURRENT" < "1.1" ]]; then
        sudo curl -L -o /etc/pacman.conf "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/pacman.conf"
    fi
    
    if [ -f /var/lib/pacman/db.lck ]; then
        echo "⚠ Pacman lock found. Checking if process exists..." >> "$LOG_FILE"
        if ! pgrep -x pacman >/dev/null; then
            echo "Lock is stale. Removing..." >> "$LOG_FILE"
            sudo rm -f /var/lib/pacman/db.lck
        else
            echo "Another pacman process is running. Exiting..." >> "$LOG_FILE"
        fi
    fi
    pacman -Q plasma-meta &>/dev/null && sudo pacman -Rdd plasma-meta --noconfirm
    pacman -Q krdp &>/dev/null && sudo pacman -Rns krdp freerdp2 --noconfirm
    sudo pacman -Sy archlinux-keyring --noconfirm
    sudo rm -rf /usr/lib/firmware/nvidia/ad103 /usr/lib/firmware/nvidia/ad104 /usr/lib/firmware/nvidia/ad106 /usr/lib/firmware/nvidia/ad107
}
set_version(){
   check_sudo
cat << EOF | sudo tee /etc/os-release > /dev/null
NAME="Playnix OS"
PRETTY_NAME="Playnix OS Gaming Edition"
ID=playnix
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://www.playnix.io/"
DOCUMENTATION_URL="https://manual.playnix.io"
SUPPORT_URL="https://support.playnix.io"
BUG_REPORT_URL="https://support.playnix.io"
LOGO=playnix
VERSION_CODENAME="Playnix OS"
VERSION_ID=${VERSION_ID_TARGET}
VARIANT="Playnix OS"
VARIANT_ID=${UUID}
EOF
}
update_pacman(){
    check_sudo
    check_pacman_health
    # Actualizar pacman.conf
    sudo sed -i "s|archive.archlinux.org/repos/.*/\$repo|archive.archlinux.org/repos/${PACMAN_TARGET_DATE}/\$repo|g" /etc/pacman.conf
    sudo pacman -Sy --noconfirm archlinux-keyring >> $LOG_FILE 2>&1
    progress_bar 70
    sudo pacman-key --populate archlinux >> $LOG_FILE 2>&1
    progress_bar 80
    sudo pacman -Syyu --noconfirm >> $LOG_FILE 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        check_sudo
        echo "$PACMAN_TARGET_DATE" | sudo tee /etc/playnix-repo-date
        echo "✓ Repo updated to $PACMAN_TARGET_DATE" >> "$LOG_FILE"
        echo "✓ Pacman completed: $(date)" >> "$LOG_FILE"
    else
        echo "✗ Update failed, reverting..." >> "$LOG_FILE"
        echo "✗ Pacman Failed: $(date)" >> "$LOG_FILE"
        if [[ "$PACMAN_CURRENT_DATE" != "none" ]]; then
            sudo sed -i "s|archive.archlinux.org/repos/.*/\$repo|archive.archlinux.org/repos/${PACMAN_CURRENT_DATE}/\$repo|g" /etc/pacman.conf
        fi
    fi    
    return $EXIT_CODE
}

#Fixes
fix_audio(){
    check_sudo
    # Fix audio lag
    mkdir -p ~/.config/pipewire/pipewire.conf.d && cat > ~/.config/pipewire/pipewire.conf.d/99-gaming.conf << 'EOF'
context.properties = {
   default.clock.rate = 48000
   default.clock.quantum = 2048
   default.clock.min-quantum = 2048
   default.clock.max-quantum = 2048
}
EOF
    sudo pacman -S rtkit --noconfirm
    cat > ~/.config/pipewire/pipewire.conf.d/99-gaming.conf << 'EOF'
context.properties = {
   default.clock.rate = 48000
   default.clock.quantum = 2048
   default.clock.min-quantum = 2048
   default.clock.max-quantum = 2048
}

context.modules = [
   { name = libpipewire-module-rtkit
       args = {
           nice.level = -15
           rt.prio = 88
           rt.time.soft = 200000
           rt.time.hard = 200000
       }
       flags = [ ifexists nofail ]
   }
]
EOF
    systemctl --user restart pipewire pipewire-pulse wireplumber    
}
fix_timeout(){
    CURRENT_TIMEOUT=$(grep TimeoutStartSec /etc/systemd/system/boot-custom-actions.service | grep -oE '[0-9]+')
    if [[ "$CURRENT_TIMEOUT" -le 90 ]]; then
        check_sudo
        sudo sed -i 's/TimeoutStartSec=.*/TimeoutStartSec=6000/' /etc/systemd/system/boot-custom-actions.service
        sudo systemctl daemon-reload    
        echo ">>> Timeout was 90, rebooting to apply new timeout..." >> "$LOG_FILE"
        progress_bar 100
        sudo reboot
    fi
}
fix_sonic_mania(){
    if ! pacman -Q lib32-vulkan-radeon &>/dev/null; then
        check_sudo
        sudo pacman -S lib32-vulkan-radeon --noconfirm >> $LOG_FILE 2>&1
        sudo pacman -Rdd nvidia-utils lib32-nvidia-utils --noconfirm >> $LOG_FILE 2>&1 || true
        echo "✓ fix_sonic_mania applied" >> $LOG_FILE
    fi
}
fix_timezone(){
    check_sudo
    echo "playnix ALL=(ALL) NOPASSWD: /usr/bin/timedatectl set-timezone *" | sudo tee /etc/sudoers.d/99-timedatectl
    sudo chmod 440 /etc/sudoers.d/99-timedatectl
}
fix_emudeck(){
    check_sudo
    sudo pacman -Syu --noconfirm jq zenity flatpak unzip bash fuse2 git rsync libnewt python >> $LOG_FILE 2>&1
}

fix_branch_message(){
      
   BRANCH_FILE="/usr/lib/os-branch-select"        
   if [[ ! -f "$BRANCH_FILE" ]]; then
   
      check_sudo
   
sudo tee /usr/lib/os-branch-select << 'EOF'
#!/usr/bin/bash

BRANCHES=("stable" "beta")
BRANCH_FILE="/var/lib/playnix/branch"

if [[ $# -eq 0 ]]; then
    for b in "${BRANCHES[@]}"; do
        echo "$b"
    done
else
    SELECTED="$1"
    for b in "${BRANCHES[@]}"; do
        if [[ "$b" == "$SELECTED" ]]; then
            echo "$SELECTED" > "$BRANCH_FILE"
            exit 0
        fi
    done
    echo "Unknown branch: $SELECTED" >&2
    exit 1
fi
EOF

      sudo chmod +x /usr/lib/os-branch-select   
      sudo mkdir -p /var/lib/playnix
      sudo chown playnix:playnix /var/lib/playnix
   fi
}

update_boot_scripts(){
   check_sudo
   sudo curl -L -o /usr/local/bin/boot-custom-actions.sh "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/boot-custom-actions.sh"
   sudo chmod +x /usr/local/bin/boot-custom-actions.sh
}

#Features
add_sd_automount(){
    RULES_FILE="/usr/lib/udev/rules.d/99-steamos-automount.rules"        
    if [[ ! -f "$RULES_FILE" ]]; then    
        check_sudo
        HWSUPPORT="/usr/libexec/hwsupport"
        REPO_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/automount"
                
        sudo mkdir -p "$HWSUPPORT"
        
        for f in block-device-event.sh common-functions steamos-automount.sh; do
            sudo curl -fsSL -o "$HWSUPPORT/$f" "$REPO_URL/hwsupport/$f"
        done
        sudo chmod +x "$HWSUPPORT"/*.sh
        
        sudo curl -fsSL -o "$RULES_FILE" "$REPO_URL/udev/99-steamos-automount.rules"
        
        sudo udevadm control --reload
        sudo udevadm trigger       
    fi
}

add_thermal_guard(){
   SERVICE="/etc/systemd/system/thermal-guard.service"
   SCRIPT="/usr/local/bin/thermal-guard.sh"
   BASE_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/thermal"
   
   if [[ -f "$SERVICE" && -f "$SCRIPT" ]]; then
      return 0
   fi
   
   check_sudo
   if ! sudo curl -fL --retry 3 -o "$SERVICE" "$BASE_URL/thermal-guard.service"; then
      echo "ERROR: failed to download thermal-guard.service" >> $LOG_FILE 2>&1
      return 1
   fi
   
   if ! sudo curl -fL --retry 3 -o "$SCRIPT" "$BASE_URL/thermal-guard.sh"; then
      echo "ERROR: failed to download thermal-guard.sh" >> $LOG_FILE 2>&1
      return 1
   fi
   
   sudo chmod +x "$SCRIPT"
   sudo systemctl daemon-reload
   sudo systemctl enable thermal-guard.service --now
}

echo "Remote code! --- $(date +%s) ---" >> $LOG_FILE


if [ "$ENABLED_UPDATE" = true ]; then

    echo -e "\033[2J\033[H" | sudo tee /dev/tty1 > /dev/null
    echo -e "\033[38;5;214m Updating PlaynixOS... \033[0m" | sudo tee /dev/tty1 > /dev/null
    progress_bar 0

    echo "Running as: $(whoami)" >> "$LOG_FILE"        
    
   #Update the boot custom actions just in case
   REMOTE_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/boot-custom-actions.sh"       
   LOCAL_FILE="/usr/local/bin/boot-custom-actions.sh" 
   TMP_FILE="/tmp/boot-custom-actions.sh.tmp"         
   curl -sL -o "$TMP_FILE" "$REMOTE_URL"              
   if [ $? -eq 0 ] && [ -s "$TMP_FILE" ]; then
       if ! cmp -s "$TMP_FILE" "$LOCAL_FILE"; then  
           sudo mv "$TMP_FILE" "$LOCAL_FILE"   
           sudo chmod +x "$LOCAL_FILE"
       else     
           rm -f "$TMP_FILE"
       fi
   else            
       rm -f "$TMP_FILE"
   fi

    
    #Fix timeout on 1.0
    fix_timeout
        
    echo "✓ UUID in rollout group (${ROLLOUT_PERCENTAGE}% < ${ROLLOUT_TARGET}%)"
    echo "BEGIN REMOTE CODE --- $(date +%s) ---" >> "$LOG_FILE"    
    progress_bar 50
    if [[ "$VERSION_ID_CURRENT" < "$VERSION_ID_TARGET" ]]; then
        EXIT_CODE=0 
        progress_bar 60
        #Update dependencies
        
        #if [[ "$PACMAN_CURRENT_DATE" != "$PACMAN_TARGET_DATE" ]]; then
            echo ">>> Updating repo from $PACMAN_CURRENT_DATE to $PACMAN_TARGET_DATE..." >> "$LOG_FILE"

            update_pacman
            EXIT_CODE=$?            
            progress_bar 90
            
            # Specific versions patches
            if [ $EXIT_CODE -eq 0 ]; then     
               (         
                if version_lt "$VERSION_ID_CURRENT" "1.1"; then               
                  fix_emudeck
                  fix_timezone
                fi  
                if version_lt "$VERSION_ID_CURRENT" "1.3"; then       
                  fix_sonic_mania            
                  fix_branch_message
                  add_sd_automount
                  update_boot_scripts
                fi
                if version_lt "$VERSION_ID_CURRENT" "1.4"; then   
                  add_thermal_guard
                fi
                
               ) && set_version      
            fi 

        #fi    
    else
        echo "System up to date..." >> "$LOG_FILE"
    fi

    progress_bar 100
    echo -e "\033[32m Done! \033[0m" | sudo tee /dev/tty1 > /dev/null
    
else
    echo "UPDATES not enabled for you --- $(date +%s) ---" >> "$LOG_FILE"
fi

rm -f "$_ASKPASS"
exit 0