MONTH=$(date +%Y-%m)
mkdir -p ~/arch-repo/$MONTH/x86_64
cp /var/cache/pacman/pkg/*.pkg.tar.zst ~/arch-repo/$MONTH/x86_64/
cd ~/arch-repo/$MONTH/x86_64
repo-add --sign playnix.db.tar.gz *.pkg.tar.zst


STAGING_REPO=~/arch-repo/$MONTH/
WEB_USER=almalinux            # el usuario SSH en el webserver
WEB_HOST=os.playnix.io
WEB_REPO=/var/www/html/vhosts/os.playnix.io/arch-repo/x86_64/$MONTH/

# 1) Copia paquetes y DB
rsync -av --delete "$STAGING_REPO" "$WEB_USER@$WEB_HOST:$WEB_REPO"