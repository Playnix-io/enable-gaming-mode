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

    echo "✓ UUID in rollout group (${ROLLOUT_PERCENTAGE}% < ${ROLLOUT_TARGET}%)"
    echo "BEGIN REMOTE CODE --- $(date +%s) ---" >> "$LOG_FILE"

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
else
    echo "UPDATES not enabled for you --- $(date +%s) ---" >> "$LOG_FILE"
fi