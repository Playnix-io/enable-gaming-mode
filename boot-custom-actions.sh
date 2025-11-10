#!/bin/bash
LOG_FILE="/tmp/boot-custom-actions.log"
MAX_RETRIES=10
RETRY_DELAY=1

REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/remote-boot-custom-actions.sh"
REMOTE_SIG_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/remote-boot-custom-actions.sh.asc"
GPG_KEY_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/playnix-signing-key.pub"
GPG_KEY_FINGERPRINT="53BA244384BF21E9"


add_nvme2(){
    echo "Checking for 2nd NVME drive..." >> "$LOG_FILE"
    echo "playnix" | sudo -S pwd
    DEV="/dev/nvme1n1p1"
    MOUNT_POINT="/run/media/playnix/nvme2"
    FSTAB="/etc/fstab"

    echo ">>> Checking if $DEV exists..."
    if [[ ! -b "$DEV" ]]; then
      echo "ERROR: $DEV does not exist or is not a block device."  >> "$LOG_FILE"
      return 1
    else
      echo "SUCESS: $DEV exist, continue."  >> "$LOG_FILE"
    fi


    echo ">>> Getting filesystem type and UUID..."  >> "$LOG_FILE"
    FSTYPE=$(lsblk -nrpo FSTYPE "$DEV" | head -n1)
    UUID=$(lsblk -nrpo UUID "$DEV" | head -n1)

    if [[ -z "$FSTYPE" || -z "$UUID" ]]; then
      echo "ERROR: Could not detect filesystem type or UUID for $DEV."  >> "$LOG_FILE"
      echo "Make sure the partition is formatted."  >> "$LOG_FILE"
      return 1
    fi

    echo "  - FSTYPE: $FSTYPE"  >> "$LOG_FILE"
    echo "  - UUID:   $UUID" >> "$LOG_FILE"

    echo ">>> Checking if $UUID or $MOUNT_POINT already exists in fstab..." >> "$LOG_FILE"
    if grep -qE "UUID=${UUID}|[[:space:]]${MOUNT_POINT}[[:space:]]" "$FSTAB"; then
      echo "✓ Disk already present in $FSTAB. Skipping mount and setup." >> "$LOG_FILE"
      return 0
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
      return 1
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

    USER_NAME="playnix"
    STEAM_CONFIG="${HOME}/.local/share/Steam/config/libraryfolders.vdf"
    NEW_LIBRARY="/run/media/${USER_NAME}/nvme2/SteamLibrary"

    # Ensure Steam is not running
    if pgrep -x steam >/dev/null; then
      echo "✗ Steam is running. Please close it before continuing." >> "$LOG_FILE"
      return 1
    fi

    # Check existing file
    if [[ ! -f "$STEAM_CONFIG" ]]; then
      echo "✗ Cannot find $STEAM_CONFIG"
      echo "Make sure Steam has been started at least once." >> "$LOG_FILE"
      return 1
    fi

    # Backup
    cp "$STEAM_CONFIG" "${STEAM_CONFIG}.bak.$(date +%s)"
    echo "🧩 Backup created: ${STEAM_CONFIG}.bak.$(date +%s)" >> "$LOG_FILE"

    # If already present, skip
    if grep -Fq "$NEW_LIBRARY" "$STEAM_CONFIG"; then
      echo "✓ Library path already present: $NEW_LIBRARY" >> "$LOG_FILE"
      return 0
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

echo "=== Boot Custom Actions started as $(whoami): $(date) ===" > "$LOG_FILE"

add_nvme2

if ! gpg --list-keys "$GPG_KEY_FINGERPRINT" &> /dev/null; then
    echo "Importing GPG public key..." >> "$LOG_FILE"
    curl -sL "$GPG_KEY_URL" | gpg --import >> "$LOG_FILE" 2>&1

    # Marcar la clave como confiable
    echo "$GPG_KEY_FINGERPRINT:6:" | gpg --import-ownertrust >> "$LOG_FILE" 2>&1
fi

echo "Waiting for internet..." >> "$LOG_FILE"
RETRIES=0

while [ $RETRIES -lt $MAX_RETRIES ]; do
    if ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
        echo "✓ Internet OK after $RETRIES attempts" >> "$LOG_FILE"
        break
    fi

    RETRIES=$((RETRIES + 1))
    sleep $RETRY_DELAY
done

if ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
    echo "Executing remote script..." >> "$LOG_FILE"

    TIMESTAMP=$(date +%s)

    curl --max-time 30 -sL -o /tmp/remote-boot-custom-actions.sh "$REMOTE_SCRIPT_URL?t=$TIMESTAMP" 2>> "$LOG_FILE"
    curl --max-time 30 -sL -o /tmp/remote-boot-custom-actions.sh.asc "$REMOTE_SIG_URL?t=$TIMESTAMP" 2>> "$LOG_FILE"

    if [ ! -f /tmp/remote-boot-custom-actions.sh ] || [ ! -f /tmp/remote-boot-custom-actions.sh.asc ]; then
        echo "✗ Failed to download script or signature: $(date)" >> "$LOG_FILE"
        return 1
    fi

    echo "Verifying GPG signature..." >> "$LOG_FILE"
    if gpg --verify /tmp/remote-boot-custom-actions.sh.asc /tmp/remote-boot-custom-actions.sh >> "$LOG_FILE" 2>&1; then
        echo "✓ Signature verified, executing remote script..." >> "$LOG_FILE"

        bash /tmp/remote-boot-custom-actions.sh >> "$LOG_FILE" 2>&1
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo "✓ Remote code completed successfully: $(date)" >> "$LOG_FILE"
        else
            echo "✗ Remote code failed (exit code: $EXIT_CODE): $(date)" >> "$LOG_FILE"
        fi
    else
        echo "✗ ❌ SIGNATURE VERIFICATION FAILED! Script NOT executed: $(date)" >> "$LOG_FILE"
        echo "✗ This could indicate tampering or MITM attack!" >> "$LOG_FILE"
    fi

    rm -f /tmp/remote-boot-custom-actions.sh /tmp/remote-boot-custom-actions.sh.asc
    echo "✓ Done: $(date)" >> "$LOG_FILE"

else
    echo "✗ No internet after ${MAX_RETRIES} attempts: $(date)" >> "$LOG_FILE"
fi

echo "=== END ===" >> "$LOG_FILE"
exit 0