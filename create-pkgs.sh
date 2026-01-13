#!/bin/bash

MONTH=$(date +%Y-%m)
mkdir -p "$HOME/arch-repo/$MONTH/x86_64"
cp /var/cache/pacman/pkg/*.pkg.tar.zst "$HOME/arch-repo/$MONTH/x86_64/"
cd "$HOME/arch-repo/$MONTH/x86_64" || return
repo-add playnix.db.tar.gz ./*.pkg.tar.zst


STAGING_REPO=~/arch-repo/$MONTH/
WEB_USER=almalinux            # el usuario SSH en el webserver
WEB_HOST=os.playnix.io
WEB_REPO=/var/www/vhosts/os.playnix.io/html/arch-repo/$MONTH/x86_64/

# 1) Copia paquetes y DB
rsync -av --delete "$STAGING_REPO" "$WEB_USER@$WEB_HOST:$WEB_REPO"