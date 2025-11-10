#!/bin/bash
UUID=$(cat "/etc/.uuid")
LOG_FILE="/tmp/boot-custom-actions.log"

echo "Remote code! --- $(date +%s) ---" >> $LOG_FILE

if [[ "${UUID:-}" == "testbed" ]]; then

    echo "BEGIN --- $(date +%s) ---" >> "$LOG_FILE"

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

    sudo pacman -Syu --noconfirm | sudo tee -a $LOG_FILE
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✓ Pacman completed: $(date)" >> "$LOG_FILE"
    else
        echo "✗ Pacman Failed: $(date)" >> "$LOG_FILE"
    fi
fi

add_nvme2(){
    echo "playnix" | sudo -S pwd
    DEV="/dev/nvme1n1p1"
    MOUNT_POINT="/run/media/playnix/nvme2"
    FSTAB="/etc/fstab"

    echo ">>> Checking if $DEV exists..."
    if [[ ! -b "$DEV" ]]; then
      echo "ERROR: $DEV does not exist or is not a block device."  >> "$LOG_FILE"
      exit 1
    else
      echo "SUCESS: $DEV exist, continue."  >> "$LOG_FILE"
    fi


    echo ">>> Getting filesystem type and UUID..."  >> "$LOG_FILE"
    FSTYPE=$(lsblk -nrpo FSTYPE "$DEV" | head -n1)
    UUID=$(lsblk -nrpo UUID "$DEV" | head -n1)

    if [[ -z "$FSTYPE" || -z "$UUID" ]]; then
      echo "ERROR: Could not detect filesystem type or UUID for $DEV."  >> "$LOG_FILE"
      echo "Make sure the partition is formatted."  >> "$LOG_FILE"
      exit 1
    fi

    echo "  - FSTYPE: $FSTYPE"  >> "$LOG_FILE"
    echo "  - UUID:   $UUID" >> "$LOG_FILE"

    echo ">>> Checking if $UUID or $MOUNT_POINT already exists in fstab..." >> "$LOG_FILE"
    if grep -qE "UUID=${UUID}|[[:space:]]${MOUNT_POINT}[[:space:]]" "$FSTAB"; then
      echo "✓ Disk already present in $FSTAB. Skipping mount and setup." >> "$LOG_FILE"
      exit 0
    fi

    echo ">>> Creating mount point: $MOUNT_POINT" >> "$LOG_FILE"
    sudo mkdir -p "$MOUNT_POINT"

    # Build the fstab line
    FSTAB_LINE="UUID=${UUID}  ${MOUNT_POINT}  ${FSTYPE}  defaults,noatime  0  2"

    echo ">>> Backing up $FSTAB to ${FSTAB}.bak" >> "$LOG_FILE"
    sudo cp "$FSTAB" "${FSTAB}.bak"

    echo ">>> Checking if entry already exists in fstab..." >> "$LOG_FILE"
    if grep -qE "UUID=${UUID}|[[:space:]]${MOUNT_POINT}[[:space:]]" "$FSTAB"; then
      echo "An entry for this UUID or mount point already exists in $FSTAB." >> "$LOG_FILE"
      echo "Not adding a duplicate line. Current matching lines:" >> "$LOG_FILE"
      grep -nE "UUID=${UUID}|[[:space:]]${MOUNT_POINT}[[:space:]]" "$FSTAB" || true
    else
      echo "Adding new fstab entry:" >> "$LOG_FILE"
      echo "$FSTAB_LINE" >> "$LOG_FILE"
      echo -e "$FSTAB_LINE" | sudo tee -a $FSTAB
    fi

    echo ">>> Mounting $MOUNT_POINT using fstab..." >> "$LOG_FILE"
    sudo mount "$MOUNT_POINT"

    echo ">>> Done!" >> "$LOG_FILE"
    echo "$DEV is now mounted on $MOUNT_POINT and will auto-mount on boot." >> "$LOG_FILE"


    chown -R "${USER_NAME}:${USER_NAME}" "${BASE_MOUNT}"
    sudo systemctl daemon-reload

    add_nvme2_library

}

add_nvme2_library(){
    USER_NAME="playnix"
    BASE_MOUNT="/run/media/${USER_NAME}/nvme2"
    LIB_ROOT="${BASE_MOUNT}/SteamLibrary"
    VDF_FILE="${LIB_ROOT}/libraryfolder.vdf"

    echo ">>> Using user: ${USER_NAME}" >> "$LOG_FILE"
    echo ">>> Base mount: ${BASE_MOUNT}" >> "$LOG_FILE"

    if [[ ! -d "${BASE_MOUNT}" ]]; then
      echo "ERROR: ${BASE_MOUNT} doesn't exist" >> "$LOG_FILE"
      exit 1
    fi

    echo ">>> Creating new SteamLibrary..." >> "$LOG_FILE"
    mkdir -p "${LIB_ROOT}/steamapps"

    if [[ -f "${VDF_FILE}" ]]; then
      echo "libraryfolder.vdf existis in ${VDF_FILE}, skipping." >> "$LOG_FILE"
    else
      echo ">>> Creating ${VDF_FILE}..." >> "$LOG_FILE"
      # contentid: número cualquiera; Steam lo puede reescribir si quiere
      CONTENT_ID="$(( RANDOM * RANDOM ))"

      cat > "${VDF_FILE}" <<EOF
"libraryfolder"
{
        "contentid"     "${CONTENT_ID}"
        "label"         ""
}
EOF
fi

    echo ">>> Setting permissions for ${USER_NAME}..." >> "$LOG_FILE"
    chown -R "${USER_NAME}:${USER_NAME}" "${BASE_MOUNT}"

    echo "✓ SteamLibrary ready on ${LIB_ROOT}" >> "$LOG_FILE"

    USER_NAME="${playnix}"
    STEAM_CONFIG="${HOME}/.local/share/Steam/config/libraryfolders.vdf"
    NEW_LIBRARY="/run/media/${USER_NAME}/nvme2/SteamLibrary"

    # Ensure Steam is not running
    if pgrep -x steam >/dev/null; then
      echo "✗ Steam is running. Please close it before continuing." >> "$LOG_FILE"
      exit 1
    fi

    # Check existing file
    if [[ ! -f "$STEAM_CONFIG" ]]; then
      echo "✗ Cannot find $STEAM_CONFIG"
      echo "Make sure Steam has been started at least once." >> "$LOG_FILE"
      exit 1
    fi

    # Backup
    cp "$STEAM_CONFIG" "${STEAM_CONFIG}.bak.$(date +%s)"
    echo "🧩 Backup created: ${STEAM_CONFIG}.bak.$(date +%s)" >> "$LOG_FILE"

    # If already present, skip
    if grep -Fq "$NEW_LIBRARY" "$STEAM_CONFIG"; then
      echo "✓ Library path already present: $NEW_LIBRARY" >> "$LOG_FILE"
      exit 0
    fi

    # Detect highest numeric key
    LAST_INDEX=$(grep -E '^[[:space:]]*"[0-9]+"' "$STEAM_CONFIG" | tail -n1 | grep -oE '[0-9]+$' || echo 0)
    NEXT_INDEX=$((LAST_INDEX + 1))

    # Escape slashes
    ESCAPED_PATH=$(printf '%s' "$NEW_LIBRARY" | sed 's/\//\\\//g')

    # Build block
    BLOCK=$(cat <<EOF
\t\t"${NEXT_INDEX}"\n\t\t{\n\t\t\t"path"\t\t"${ESCAPED_PATH}"\n\t\t}
EOF
)

    # Insert before final closing brace of "libraryfolders"
    TMPFILE=$(mktemp)
    awk -v block="$BLOCK" '
    /^[[:space:]]*}$/ && inside==1 {
        print block
        inside=0
    }
    {
        print
    }
    /^[[:space:]]*"libraryfolders"/ {
        inside=1
    }' "$STEAM_CONFIG" > "$TMPFILE"

    mv "$TMPFILE" "$STEAM_CONFIG"

    echo "✓ Added library ${NEW_LIBRARY} as index ${NEXT_INDEX}" >> "$LOG_FILE"

}

add_nvme2