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
    DEV_DISK="/dev/nvme1n1"
    MOUNT_POINT="/run/media/playnix/nvme2"
    FSTAB="/etc/fstab"

    echo ">>> Checking if $DEV_DISK exists..." >> "$LOG_FILE"
    if [[ ! -b "$DEV_DISK" ]]; then
      echo "INFO: $DEV_DISK does not exist. No 2nd NVME drive found." >> "$LOG_FILE"
      return 0  # No es error, simplemente no hay disco
    else
      echo "SUCCESS: $DEV_DISK exists, continue." >> "$LOG_FILE"
    fi

    # Verificar si el UUID actual está en fstab
    FSTAB_UUID=$(grep "$MOUNT_POINT" "$FSTAB" | grep -oP 'UUID=\K[^ ]+' | head -1)

    if [[ -n "$FSTAB_UUID" ]] && [[ -b "$DEV" ]]; then
        CURRENT_UUID=$(lsblk -nrpo UUID "$DEV" | head -n1)

        if [[ -n "$CURRENT_UUID" ]] && [[ "$CURRENT_UUID" == "$FSTAB_UUID" ]]; then
            echo "✓ NVME2 already configured correctly (UUID: $CURRENT_UUID)" >> "$LOG_FILE"

            # Solo montar si no está montado
            if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
                sudo mkdir -p "$MOUNT_POINT"
                if sudo mount "$MOUNT_POINT" 2>/dev/null; then
                    echo "✓ Mounted successfully" >> "$LOG_FILE"
                    sudo chown -R "playnix:playnix" "$MOUNT_POINT"
                fi
            else
                echo "✓ Already mounted" >> "$LOG_FILE"
            fi

            return 0
        else
            echo "⚠ Different disk detected!" >> "$LOG_FILE"
            echo "  - Expected UUID: $FSTAB_UUID" >> "$LOG_FILE"
            echo "  - Current UUID:  ${CURRENT_UUID:-none}" >> "$LOG_FILE"
            echo ">>> Cleaning old fstab entry..." >> "$LOG_FILE"
            sudo sed -i "\|$MOUNT_POINT|d" "$FSTAB"
        fi
    fi

    # Verificar si existe alguna partición en el disco
    EXISTING_PARTITIONS=$(lsblk -nrpo NAME "$DEV_DISK" | grep -v "^${DEV_DISK}$" | wc -l)

    if [[ $EXISTING_PARTITIONS -gt 0 ]]; then
      echo ">>> Found $EXISTING_PARTITIONS existing partition(s)" >> "$LOG_FILE"

      # Verificar si la primera partición es ext4
      if [[ -b "$DEV" ]]; then
        FSTYPE=$(lsblk -nrpo FSTYPE "$DEV" 2>/dev/null | head -n1)

        # Si hay más de 1 partición O no es ext4, reformatear todo
        if [[ $EXISTING_PARTITIONS -gt 1 ]] || [[ "$FSTYPE" != "ext4" ]]; then
          echo ">>> Disk needs repartitioning (multiple partitions or wrong format)" >> "$LOG_FILE"
          echo ">>> Current format: ${FSTYPE:-none}, Partitions: $EXISTING_PARTITIONS" >> "$LOG_FILE"

          # Desmontar todas las particiones del disco
          echo ">>> Unmounting all partitions..." >> "$LOG_FILE"
          for part in $(lsblk -nrpo NAME "$DEV_DISK" | grep -v "^${DEV_DISK}$"); do
            sudo umount "$part" 2>/dev/null || true
          done

          # Eliminar todas las particiones y crear nueva tabla GPT
          echo ">>> Wiping disk and creating new partition table..." >> "$LOG_FILE"
          sudo wipefs -a "$DEV_DISK" >> "$LOG_FILE" 2>&1

          # Crear nueva tabla de particiones GPT
          sudo parted -s "$DEV_DISK" mklabel gpt >> "$LOG_FILE" 2>&1

          # Crear nueva partición que ocupe TODO el disco
          echo ">>> Creating new partition spanning entire disk..." >> "$LOG_FILE"
          sudo parted -s "$DEV_DISK" mkpart primary ext4 0% 100% >> "$LOG_FILE" 2>&1

          # Informar al kernel
          sudo partprobe "$DEV_DISK"
          sleep 3

          if [[ ! -b "$DEV" ]]; then
            echo "ERROR: Failed to create partition $DEV" >> "$LOG_FILE"
            return 1
          fi
          echo "✓ New partition created successfully" >> "$LOG_FILE"

          # Marcar que necesita formateo
          NEEDS_FORMAT=true
        else
          echo ">>> Single ext4 partition found" >> "$LOG_FILE"
          NEEDS_FORMAT=false
        fi
      else
        # No existe /dev/nvme1n1p1 pero hay particiones, reformatear
        echo ">>> Unexpected partition layout, reformatting..." >> "$LOG_FILE"

        # Desmontar todo
        for part in $(lsblk -nrpo NAME "$DEV_DISK" | grep -v "^${DEV_DISK}$"); do
          sudo umount "$part" 2>/dev/null || true
        done

        sudo wipefs -a "$DEV_DISK" >> "$LOG_FILE" 2>&1
        sudo parted -s "$DEV_DISK" mklabel gpt >> "$LOG_FILE" 2>&1
        sudo parted -s "$DEV_DISK" mkpart primary ext4 0% 100% >> "$LOG_FILE" 2>&1
        sudo partprobe "$DEV_DISK"
        sleep 3

        if [[ ! -b "$DEV" ]]; then
          echo "ERROR: Failed to create partition $DEV" >> "$LOG_FILE"
          return 1
        fi

        NEEDS_FORMAT=true
      fi
    else
      # No hay particiones, crear desde cero
      echo ">>> No partitions found, creating new partition table..." >> "$LOG_FILE"
      sudo wipefs -a "$DEV_DISK" >> "$LOG_FILE" 2>&1
      sudo parted -s "$DEV_DISK" mklabel gpt >> "$LOG_FILE" 2>&1
      sudo parted -s "$DEV_DISK" mkpart primary ext4 0% 100% >> "$LOG_FILE" 2>&1
      sudo partprobe "$DEV_DISK"
      sleep 3

      if [[ ! -b "$DEV" ]]; then
        echo "ERROR: Failed to create partition $DEV" >> "$LOG_FILE"
        return 1
      fi
      echo "✓ Partition created successfully" >> "$LOG_FILE"
      NEEDS_FORMAT=true
    fi

    # Formatear si es necesario
    if [[ "$NEEDS_FORMAT" == true ]]; then
      echo ">>> Formatting $DEV as ext4..." >> "$LOG_FILE"

      # Asegurar que está desmontado
      sudo umount "$DEV" 2>/dev/null || true

      # Formatear como ext4
      echo "Running mkfs.ext4 on $DEV..." >> "$LOG_FILE"
      sudo mkfs.ext4 -F "$DEV" >> "$LOG_FILE" 2>&1

      if [ $? -eq 0 ]; then
        echo "✓ Successfully formatted $DEV as ext4" >> "$LOG_FILE"
      else
        echo "ERROR: Failed to format $DEV" >> "$LOG_FILE"
        return 1
      fi

      sleep 2
    fi

    echo ">>> Getting UUID..." >> "$LOG_FILE"
    UUID=$(lsblk -nrpo UUID "$DEV" | head -n1)

    if [[ -z "$UUID" ]]; then
      echo "ERROR: Could not detect UUID for $DEV." >> "$LOG_FILE"
      return 1
    fi

    FSTYPE="ext4"
    echo "  - FSTYPE: $FSTYPE" >> "$LOG_FILE"
    echo "  - UUID:   $UUID" >> "$LOG_FILE"

    # Verificar tamaño final
    DISK_SIZE=$(lsblk -nrpo SIZE "$DEV_DISK" | head -n1)
    PART_SIZE=$(lsblk -nrpo SIZE "$DEV" | head -n1)
    echo "  - Disk size: $DISK_SIZE" >> "$LOG_FILE"
    echo "  - Partition size: $PART_SIZE" >> "$LOG_FILE"

    echo ">>> Checking if $UUID already exists in fstab..." >> "$LOG_FILE"
    if grep -qE "UUID=${UUID}" "$FSTAB"; then
      echo "✓ UUID already present in $FSTAB. Skipping." >> "$LOG_FILE"

      if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        echo ">>> Mounting..." >> "$LOG_FILE"
        sudo mkdir -p "$MOUNT_POINT"
        sudo mount "$MOUNT_POINT"
      fi

      return 0
    fi

    echo ">>> Creating mount point: $MOUNT_POINT" >> "$LOG_FILE"
    sudo mkdir -p "$MOUNT_POINT"

    FSTAB_LINE="UUID=${UUID}  ${MOUNT_POINT}  ${FSTYPE}  defaults,noatime,nofail,x-systemd.device-timeout=5  0  2"

    echo ">>> Backing up $FSTAB to ${FSTAB}.bak" >> "$LOG_FILE"
    sudo cp "$FSTAB" "${FSTAB}.bak"

    echo ">>> Adding new fstab entry:" >> "$LOG_FILE"
    echo "$FSTAB_LINE" >> "$LOG_FILE"
    echo "$FSTAB_LINE" | sudo tee -a "$FSTAB" > /dev/null

    echo ">>> Mounting $MOUNT_POINT..." >> "$LOG_FILE"
    sudo mount "$MOUNT_POINT"

    if [ $? -eq 0 ]; then
      echo "✓ Successfully mounted $MOUNT_POINT" >> "$LOG_FILE"

      # Mostrar tamaño final montado
      MOUNTED_SIZE=$(df -h "$MOUNT_POINT" | tail -1 | awk '{print $2}')
      echo "  - Mounted size: $MOUNTED_SIZE" >> "$LOG_FILE"
    else
      echo "ERROR: Failed to mount $MOUNT_POINT" >> "$LOG_FILE"
      return 1
    fi

    echo ">>> Setting ownership..." >> "$LOG_FILE"
    sudo chown -R "playnix:playnix" "$MOUNT_POINT"

    echo ">>> Reloading systemd..." >> "$LOG_FILE"
    sudo systemctl daemon-reload

    echo ">>> Done!" >> "$LOG_FILE"
    echo "$DEV is now mounted on $MOUNT_POINT and will auto-mount on boot." >> "$LOG_FILE"

    add_nvme2_library
}

add_nvme2_library(){
    USER_NAME="playnix"
    BASE_MOUNT="/run/media/${USER_NAME}/nvme2"
    LIB_ROOT="${BASE_MOUNT}/SteamLibrary"
    VDF_FILE="${LIB_ROOT}/libraryfolder.vdf"

    if ! mountpoint -q "/run/media/playnix/nvme2"; then
        echo "WARNING: NVME2 not mounted, skipping Steam library" >> "$LOG_FILE"
        return 0
    fi

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

#Creates random UUID on first boot
if [ ! -f /etc/.uuid ]; then

    echo "playnix" | sudo -S pwd
    CONTENT_ID="$(( RANDOM * RANDOM ))"
    echo $CONTENT_ID > "/home/playnix/.uuid"
    echo $CONTENT_ID | sudo tee -a /etc/.uuid

cat << EOF | sudo tee /etc/os-release > /dev/null
NAME="Playnix OS"
PRETTY_NAME="Playnix OS Gaming Edition"
ID=playnix
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://shop.playnix.io/"
DOCUMENTATION_URL="https://manual.playnix.io"
SUPPORT_URL="https://support.playnix.io"
BUG_REPORT_URL="https://support.playnix.io"
LOGO=playnix
VERSION_CODENAME="Playnix OS"
VERSION_ID=1.0
VARIANT="Playnix OS"
VARIANT_ID=${CONTENT_ID}
EOF

fi


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
    if gpg --trust-model always --verify /tmp/remote-boot-custom-actions.sh.asc /tmp/remote-boot-custom-actions.sh >> "$LOG_FILE" 2>&1; then
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