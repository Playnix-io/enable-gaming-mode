#!/bin/bash
# SD Card auto-mount script for Playnix OS
# Called by sdcard-mount@.service via udev rules
# Usage: sdcard-mount.sh mount|unmount <device>

LOG_FILE="/tmp/sdcard-mount.log"
ACTION="$1"
DEVICE="$2"
DEV_PATH="/dev/${DEVICE}"
USER_NAME="playnix"
MOUNT_BASE="/run/media/${USER_NAME}"
MOUNT_POINT="${MOUNT_BASE}/${DEVICE}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${DEVICE}] $1" >> "$LOG_FILE"
}

detect_fs() {
    lsblk -nrpo FSTYPE "$DEV_PATH" 2>/dev/null | head -n1
}

get_mount_opts() {
    local fstype="$1"
    case "$fstype" in
        ext4)
            echo "defaults,noatime"
            ;;
        btrfs)
            echo "defaults,noatime,compress=zstd"
            ;;
        vfat)
            echo "defaults,uid=$(id -u $USER_NAME),gid=$(id -g $USER_NAME),umask=0022"
            ;;
        exfat)
            echo "defaults,uid=$(id -u $USER_NAME),gid=$(id -g $USER_NAME),umask=0022"
            ;;
        ntfs3)
            echo "defaults,uid=$(id -u $USER_NAME),gid=$(id -g $USER_NAME),umask=0022"
            ;;
        *)
            echo "defaults"
            ;;
    esac
}

add_sdcard_steam_library() {
    local mount_path="$1"
    local LIB_ROOT="${mount_path}/SteamLibrary"
    local VDF_FILE="${LIB_ROOT}/libraryfolder.vdf"
    local STEAM_CONFIG="/home/${USER_NAME}/.local/share/Steam/config/libraryfolders.vdf"

    log ">>> Setting up Steam library on SD card..."

    # Create SteamLibrary directory
    mkdir -p "${LIB_ROOT}/steamapps"

    # Create libraryfolder.vdf if it doesn't exist
    if [[ ! -f "${VDF_FILE}" ]]; then
        log ">>> Creating ${VDF_FILE}..."
        CONTENT_ID="$(( RANDOM * RANDOM ))"
        cat > "${VDF_FILE}" <<EOF
"libraryfolder"
{
        "contentid"     "${CONTENT_ID}"
        "label"         ""
}
EOF
    else
        log ">>> ${VDF_FILE} already exists, skipping creation."
    fi

    # Set ownership
    chown -R "${USER_NAME}:${USER_NAME}" "${LIB_ROOT}"
    log ">>> SteamLibrary ready on ${LIB_ROOT}"

    # Add to Steam's libraryfolders.vdf if it exists
    if [[ ! -f "$STEAM_CONFIG" ]]; then
        log ">>> Steam config not found (${STEAM_CONFIG}), skipping library registration."
        log ">>> Steam library will be detected on next Steam launch."
        return 0
    fi

    # If already present, skip
    if grep -Fq "${LIB_ROOT}" "$STEAM_CONFIG"; then
        log ">>> Library path already in Steam config: ${LIB_ROOT}"
        return 0
    fi

    # Don't modify if Steam is running
    if pgrep -x steam >/dev/null; then
        log ">>> Steam is running, skipping config modification."
        log ">>> Steam library will be detected on next Steam restart."
        return 0
    fi

    # Backup
    cp "$STEAM_CONFIG" "${STEAM_CONFIG}.bak.$(date +%s)"

    # Detect highest numeric key
    LAST_INDEX=$(grep -E '^[[:space:]]*"[0-9]+"' "$STEAM_CONFIG" | tail -n1 | grep -oE '[0-9]+' | tail -n1)
    LAST_INDEX=${LAST_INDEX:-0}
    NEXT_INDEX=$((LAST_INDEX + 1))

    # Escape slashes for sed/awk
    ESCAPED_PATH=$(printf '%s' "$LIB_ROOT" | sed 's/\//\\\//g')

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
    chown "${USER_NAME}:${USER_NAME}" "$STEAM_CONFIG"

    log ">>> Added SD card library ${LIB_ROOT} as index ${NEXT_INDEX}"
}

do_mount() {
    log "=== MOUNT triggered ==="

    if [[ ! -b "$DEV_PATH" ]]; then
        log "ERROR: ${DEV_PATH} does not exist"
        exit 1
    fi

    # Detect filesystem
    FSTYPE=$(detect_fs)
    if [[ -z "$FSTYPE" ]]; then
        log "ERROR: Could not detect filesystem on ${DEV_PATH}"
        exit 1
    fi
    log "Detected filesystem: ${FSTYPE}"

    # Get mount options
    MOUNT_OPTS=$(get_mount_opts "$FSTYPE")
    log "Mount options: ${MOUNT_OPTS}"

    # Create mount point
    mkdir -p "$MOUNT_POINT"

    # Mount
    if mount -t "$FSTYPE" -o "$MOUNT_OPTS" "$DEV_PATH" "$MOUNT_POINT"; then
        log "Mounted ${DEV_PATH} on ${MOUNT_POINT}"
    else
        log "ERROR: Failed to mount ${DEV_PATH}"
        rmdir "$MOUNT_POINT" 2>/dev/null
        exit 1
    fi

    # Set ownership for ext4/btrfs (vfat/exfat/ntfs handle it via mount opts)
    case "$FSTYPE" in
        ext4|btrfs)
            chown -R "${USER_NAME}:${USER_NAME}" "$MOUNT_POINT"
            log "Set ownership to ${USER_NAME}:${USER_NAME}"
            ;;
    esac

    # Set up Steam library
    add_sdcard_steam_library "$MOUNT_POINT"

    log "=== MOUNT complete ==="
}

do_unmount() {
    log "=== UNMOUNT triggered ==="

    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        # Lazy unmount to handle open files gracefully
        if umount -l "$MOUNT_POINT"; then
            log "Unmounted ${MOUNT_POINT}"
        else
            log "ERROR: Failed to unmount ${MOUNT_POINT}"
        fi
    else
        log "Not mounted: ${MOUNT_POINT}"
    fi

    # Clean up mount point directory
    rmdir "$MOUNT_POINT" 2>/dev/null

    log "=== UNMOUNT complete ==="
}

# Main
if [[ -z "$ACTION" ]] || [[ -z "$DEVICE" ]]; then
    echo "Usage: $0 mount|unmount <device>"
    exit 1
fi

case "$ACTION" in
    mount)
        do_mount
        ;;
    unmount)
        do_unmount
        ;;
    *)
        log "ERROR: Unknown action: ${ACTION}"
        echo "Usage: $0 mount|unmount <device>"
        exit 1
        ;;
esac
