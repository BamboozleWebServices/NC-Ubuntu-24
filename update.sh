#!/bin/bash
# Nextcloud update script
#
# - Changes:
# - Detect the enabled Nextcloud apps ($NEXTCLOUDAPPS)
# - Stop, disable, re-enable and start the web server
# - Re-enable the apps that were active before the update ($NEXTCLOUDAPPS)
#
# ---------------------------------------------------------------
# Set these parameters to match your Nextcloud installation
# ---------------------------------------------------------------
WEBSERVER="nginx"
# alternative: "apache2"

PHPVERSION="8.4"
# alternative: "8.3"

DPATH="/var/www/nextcloud"
# alternative: "/path/to/nextcloud"

SPATH="/backup/sql"
SNPATH="/backup/nextcloud"
# Backup directories

# --------------------------------------------------------------
# >>> Do NOT change anything below this line! <<<
# --------------------------------------------------------------
clear
if [ -f /tmp/nc-update.lock ]; then
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo " » The update script is already running - *ABORTING*"
        echo " » Or was a previous run interrupted?"
	    echo ""
	    echo " » "$(ls /tmp/nc-update.lock)
	    echo ""
        echo " » If needed, remove the lock file with this command:"
        echo " » sudo rm -f /tmp/nc-update.lock"
        echo ""
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        exit 1
fi
if [ "$USER" != "root" ]
then
    echo ""
    echo " » NO ROOT PERMISSIONS"
    echo ""
    echo "------------------------------------------------------------"
    echo " » Please run this script as root using:  'sudo ./update.sh'"
    echo "------------------------------------------------------------"
    echo ""
    exit 1
fi
touch /tmp/nc-update.lock
echo ""
echo " » Reading the Nextcloud parameters..."
echo ""
NEXTCLOUDVERSION=$(sudo -u www-data php $DPATH/occ config:system:get version)
NEXTCLOUDDATEN=$(sudo -u www-data php $DPATH/occ config:system:get datadirectory)
NEXTCLOUDDBTYPE=$(sudo -u www-data php $DPATH/occ config:system:get dbtype)
NEXTCLOUDDBHOST=$(sudo -u www-data php $DPATH/occ config:system:get dbhost)
NEXTCLOUDDB=$(sudo -u www-data php $DPATH/occ config:system:get dbname)
NEXTCLOUDDBUSER=$(sudo -u www-data php $DPATH/occ config:system:get dbuser)
NEXTCLOUDDBPASSWORD=$(sudo -u www-data php $DPATH/occ config:system:get dbpassword)
NEXTCLOUDDBTYPE=$(sudo -u www-data php $DPATH/occ config:system:get dbtype)
NEXTCLOUDAPPS=$(sudo -u www-data php $DPATH/occ app:list --enabled --output=json | jq -r '.enabled|keys[]' | xargs)
SDATE="nextcloud.sql"
apt update
if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    apt-mark unhold pgsql*
    apt-mark unhold postgresql*
    apt-mark unhold postgresql-*
    else
    apt-mark unhold mariadb-*
    apt-mark unhold mysql-*
    apt-mark unhold galera-*
    fi
apt-mark unhold $WEBSERVER* $WEBSERVER-*
apt-mark unhold redis*
apt-mark unhold php-* php$PHPVERSION-*
apt-mark unhold elasticsearch*
apt install -y jq
apt upgrade -V
if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    apt-mark hold pgsql*
    apt-mark hold postgresql*
    apt-mark hold postgresql-*
else
    apt-mark hold mariadb-*
    apt-mark hold mysql-*
    apt-mark hold galera-*
    fi
apt-mark hold $WEBSERVER* $WEBSERVER-*
apt-mark hold redis*
apt-mark hold php-* php$PHPVERSION-*
apt-mark hold elasticsearch*
apt autoremove
apt autoclean
# chown -R www-data:www-data $DPATH
# find $DPATH/ -type d -exec chmod 750 {} \;
# find $DPATH/ -type f -exec chmod 640 {} \;
if [ -d "$DPATH/apps/notify_push" ]; then
    sudo chmod ug+x $DPATH/apps/notify_push/bin/x86_64/notify_push
    fi
echo ""
echo -n " » Create a database and Nextcloud file backup [y|n]? "
read answer
if [ "$answer" != "${answer#[YyjJ]}" ];then
    echo ""
    echo -n " » Delete the previous backups [y|n]? "
    read answer
    if [ "$answer" != "${answer#[YyjJ]}" ];then
    rm -Rf $SPATH-* $SNPATH-*
    fi
    if [ ! -d $SPATH-$NEXTCLOUDVERSION ]; then
        mkdir -p $SPATH-$NEXTCLOUDVERSION
    fi
    if  [ ! -d $SNPATH-$NEXTCLOUDVERSION ]; then
        mkdir -p $SNPATH-$NEXTCLOUDVERSION
    fi
    echo ""
    sudo -u www-data php $DPATH/occ maintenance:mode --on
    echo ""
    echo " » Starting the database backup..."
    if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    	PGPASSWORD="$NEXTCLOUDDBPASSWORD" pg_dump $NEXTCLOUDDB -h $NEXTCLOUDDBHOST -U $NEXTCLOUDDBUSER -f $SPATH-$NEXTCLOUDVERSION/$SDATE
    else
	    mariadb-dump --single-transaction --routines -h $NEXTCLOUDDBHOST -u$NEXTCLOUDDBUSER -p$NEXTCLOUDDBPASSWORD -e $NEXTCLOUDDB > $SPATH-$NEXTCLOUDVERSION/$SDATE
    fi
    echo ""
    echo " » Determining the database size..."
    echo -e "\033[32m » $(du -sh $SPATH-$NEXTCLOUDVERSION | awk '{ print $1 }')\033[0m"
    echo ""
    echo " » Backing up the Nextcloud directory..."
    echo " » $(du -sh $DPATH | awk '{ print $1 }') expected..."
    rsync -a $DPATH/ $SNPATH-$NEXTCLOUDVERSION
    echo -e "\033[32m » $(du -sh $SNPATH-$NEXTCLOUDVERSION | awk '{ print $1 }')\033[0m backed up"
    echo ""
    sudo -u www-data php $DPATH/occ maintenance:mode --off
    echo ""
fi
echo ""
echo " » Disabling the web server..."
systemctl stop $WEBSERVER.service
systemctl disable $WEBSERVER.service
# systemctl status $WEBSERVER.service
echo ""
echo -n " » Run Nextcloud updates [y|n]? "
read answer
if [ "$answer" != "${answer#[YyjJ]}" ] ;then
    echo ""
    sudo -u www-data php $DPATH/updater/updater.phar --no-backup
    sudo -u www-data php $DPATH/occ status
    sudo -u www-data php $DPATH/occ -V
    sudo -u www-data php $DPATH/occ db:add-missing-primary-keys
    sudo -u www-data php $DPATH/occ db:add-missing-indices
    sudo -u www-data php $DPATH/occ db:add-missing-columns
    sudo -u www-data php $DPATH/occ db:convert-filecache-bigint
    sudo -u www-data php $DPATH/occ maintenance:repair --include-expensive
    sudo -u www-data sed -i "s/output_buffering=.*/output_buffering=0/" $DPATH/.user.ini
    echo ""
    echo " » Re-enabling Nextcloud apps if needed"
    sudo -u www-data php $DPATH/occ app:enable $NEXTCLOUDAPPS
    echo ""
    echo " » List of apps to be updated:"
    echo ""
    sudo -u www-data php $DPATH/occ app:update --showonly -v
    echo ""
    echo -n " » Update the Nextcloud apps [y|n]? "
    read answer
    if [ "$answer" != "${answer#[YyjJ]}" ] ;then
        sudo -u www-data php $DPATH/occ app:update --all -v
        sudo -u www-data php $DPATH/occ app:list | grep -i richdocuments &> /dev/null
        if [ $? -eq 0 ]; then
        sudo -u www-data php $DPATH/occ richdocuments:update-empty-templates
        fi
    else
        echo " » Nextcloud apps were not updated."
        echo ""
    fi
else
    echo " » Nextcloud was not updated/checked."
    echo ""
fi
echo ""
echo " » Updating acme.sh"
su - acmeuser -c ".acme.sh/acme.sh --upgrade --auto-upgrade"
sleep 2
echo ""
echo " » Starting web server and Nextcloud setup check..."
echo ""
systemctl enable --now $WEBSERVER.service
echo ""
sudo -u www-data php $DPATH/occ setupchecks
echo ""
echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo " » Restarting services..."
echo ""
echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
dpkg -s elasticsearch &> /dev/null
if [ $? -eq 0 ]; then
echo " » Restarting Elasticsearch first"
systemctl daemon-reload && systemctl restart elasticsearch.service
else
echo " » Elasticsearch is not installed!"
fi
echo ""
if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    systemctl restart postgresql.service redis-server.service php$PHPVERSION-fpm.service $WEBSERVER.service
else
    systemctl restart mariadb.service redis-server.service php$PHPVERSION-fpm.service $WEBSERVER.service
fi
if [ -e /var/run/reboot-required ]; then
        echo -e " »\e[1;31m WARNING: A SERVER REBOOT IS REQUIRED.\033[0m"
        echo ""
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
else
        echo -e " »\033[32m No server reboot required.\033[0m"
        echo ""
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
fi
echo ""
rm -f /tmp/nc-update.lock
exit 0
