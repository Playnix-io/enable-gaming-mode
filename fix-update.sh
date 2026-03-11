#!/bin/bash
#Script to fix gpg keys in case it's broken
gpgconf --kill all
rm -rf ~/.gnupg
gpg --list-keys
curl -L "https://raw.githubusercontent.com/Playnix-io/enable-gaming-mode/main/playnix-signing-key.pub" | gpg --import