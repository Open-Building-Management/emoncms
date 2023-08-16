#!/command/with-contenv sh

NEW_INSTALL=0

if ! [ -d "$EMONCMS_DATADIR" ]; then
    echo "Creating timeseries folders"
    mkdir -p "$EMONCMS_DATADIR"
    mkdir -p "$EMONCMS_DATADIR/backup"
    mkdir -p "$EMONCMS_DATADIR/backup/uploads"
    for i in $TS; do mkdir -p "$EMONCMS_DATADIR/$i"; done
    chown -R "$DAEMON" "$EMONCMS_DATADIR"
    
else
    echo "Using existing timeseries"
fi

if ! [ -d "$EMONCMS_DATADIR/mysql" ]; then 
    echo "Creating a new mariadb"
    mysql_install_db --user=mysql --datadir=$EMONCMS_DATADIR/mysql > /dev/null
    # --skip-name-resolve --skip-test-db
    NEW_INSTALL=1
else
    echo "Using existing mariadb"
fi

cd $OEM_DIR

# REGENERATING CONF FILES FROM ENV VARS
echo "CREATING /etc/my.cnf"
mv /etc/my.cnf /etc/my.old
echo "[mysqld]" >> /etc/my.cnf
echo "datadir=$EMONCMS_DATADIR/mysql" >> /etc/my.cnf

echo "GENERATING EMONCMS SETTINGS.INI"
echo "emoncms_dir = '$EMONCMS_DIR'" > settings.ini
echo "openenergymonitor_dir = '$OEM_DIR'" >> settings.ini
echo "[sql]" >> settings.ini
echo "server = 'localhost'" >> settings.ini
echo "database = '$MYSQL_DATABASE'" >> settings.ini
echo "username = '$MYSQL_USER'" >> settings.ini
echo "password = '$MYSQL_PASSWORD'" >> settings.ini
echo "dbtest   = true" >> settings.ini
echo "[redis]" >> settings.ini
echo "enabled = true" >> settings.ini
echo "prefix = ''" >> settings.ini
echo "[mqtt]" >> settings.ini
echo "enabled = true" >> settings.ini
echo "user = '$MQTT_USER'" >> settings.ini
echo "password = '$MQTT_PASSWORD'" >> settings.ini
echo "[feed]" >> settings.ini
echo "engines_hidden = [0,6,10]" >> settings.ini
echo "redisbuffer[enabled] = true" >> settings.ini
echo "redisbuffer[sleep] = 300" >> settings.ini
echo "phpfina[datadir] = '$EMONCMS_DATADIR/phpfina/'" >> settings.ini
echo "phptimeseries[datadir] = '$EMONCMS_DATADIR/phptimeseries/'" >> settings.ini
echo "[interface]" >> settings.ini
echo "enable_admin_ui = true" >> settings.ini
echo "feedviewpath = 'graph/'" >> settings.ini
echo "favicon = 'favicon_emonpi.png'" >> settings.ini
echo "[log]" >> settings.ini
echo "; Log Level: 1=INFO, 2=WARN, 3=ERROR" >> settings.ini
echo "level = 2" >> settings.ini
cp settings.ini $WWW/emoncms/settings.ini

echo "CREATING USER/PWD FOR MOSQUITTO"
touch /etc/mosquitto/passwd;\
mosquitto_passwd -b /etc/mosquitto/passwd $MQTT_USER $MQTT_PASSWORD;\

echo "GENERATING config.cfg for BACKUP MODULE"
echo "user=$DAEMON" > config.cfg
echo "backup_script_location=$EMONCMS_DIR/modules/backup" >> config.cfg
echo "emoncms_location=$WWW/emoncms" >> config.cfg
echo "backup_location=$EMONCMS_DATADIR/backup" >> config.cfg
echo "database_path=$EMONCMS_DATADIR" >> config.cfg
echo "emonhub_config_path=" >> config.cfg
echo "emonhub_specimen_config=" >> config.cfg
echo "backup_source_path=$EMONCMS_DATADIR/backup/uploads" >> config.cfg 
cp config.cfg $EMONCMS_DIR/modules/backup/config.cfg

echo "GENERATING backup.ini PHP extension"
echo "post_max_size=3G" > $PHP_CONF/backup.ini
echo "upload_max_filesize=3G" >> $PHP_CONF/backup.ini
echo "upload_tmp_dir=$EMONCMS_DATADIR/backup/uploads" >> $PHP_CONF/backup.ini

printf "$NEW_INSTALL" > /var/run/s6/container_environment/NEW_INSTALL
