#!/bin/bash
LOG_FILE="/home/playnix/boot-custom-actions.log"

echo "=== Boot Custom Actions started: $(date) ===" >> "$LOG_FILE"

if ping -c 1 -W 5 1.1.1.1 &> /dev/null; then
    echo "Internet found, executing remote script..." >> "$LOG_FILE"

    curl -L https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/remote-boot-custom-actions.sh | bash >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✓ Remote code completed: $(date)" >> "$LOG_FILE"
    else
        echo "✗ Remote code failed (exit code: $EXIT_CODE): $(date)" >> "$LOG_FILE"
    fi
else
    echo "✗ No internet: $(date)" >> "$LOG_FILE"
fi

echo "=== END ===" >> "$LOG_FILE"
exit 0