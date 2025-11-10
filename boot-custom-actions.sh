#!/bin/bash
LOG_FILE="/tmp/boot-custom-actions.log"
MAX_RETRIES=10
RETRY_DELAY=1

echo "=== Boot Custom Actions started as $(whoami): $(date) ===" > "$LOG_FILE"

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

    SCRIPT_URL="https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/remote-boot-custom-actions.sh?t=$(date +%s)"
    curl -sL "$SCRIPT_URL" | bash >> "$LOG_FILE" 2>&1

    echo "✓ Done: $(date)" >> "$LOG_FILE"
else
    echo "✗ No internet after ${MAX_RETRIES} attempts: $(date)" >> "$LOG_FILE"
fi

echo "=== END ===" >> "$LOG_FILE"
exit 0