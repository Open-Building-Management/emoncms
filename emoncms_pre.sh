#!/command/with-contenv sh

cp /usr/share/zoneinfo/$TZ /etc/localtime

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

OPTIONS_JSON=/data/options.json

if [ -f $OPTIONS_JSON ]; then
    USER=$(jq --raw-output '.MQTT_USER // empty' $OPTIONS_JSON)
    PASSWORD=$(jq --raw-output '.MQTT_PASSWORD // empty' $OPTIONS_JSON)
    LOG_LEVEL=$(jq --raw-output '.MQTT_LOG_LEVEL // empty' $OPTIONS_JSON)
    HOST=$(jq --raw-output '.MQTT_HOST // empty' $OPTIONS_JSON)
    if [ "$USER" ]; then MQTT_USER=$USER; fi
    if [ "$PASSWORD" ]; then MQTT_PASSWORD=$PASSWORD; fi
    if [ "$LOG_LEVEL" ]; then MQTT_LOG_LEVEL=$LOG_LEVEL; fi
    if [ "$HOST" ]; then MQTT_HOST=$HOST; fi
    LOCAL_TZ=$(jq --raw-output '.TZ // empty' $OPTIONS_JSON)
    if [ "$LOCAL_TZ" ]; then TZ=$LOCAL_TZ; fi
    LOG_LEVEL=$(jq --raw-output '.EMONCMS_LOG_LEVEL // empty' $OPTIONS_JSON)
    if [ "$LOG_LEVEL" ]; then EMONCMS_LOG_LEVEL=$LOG_LEVEL; fi
    REDIS_BUFFER=$(jq --raw-output 'if .LOW_WRITE_MODE==true then 1 else 0 end' $OPTIONS_JSON)
    CRT=$(jq --raw-output '.CRT_FILE // empty' $OPTIONS_JSON)
    KEY=$(jq --raw-output '.KEY_FILE // empty' $OPTIONS_JSON)
    NAME=$(jq --raw-output '.CNAME // empty' $OPTIONS_JSON)
    if [ "$CRT" ]; then CRT_FILE=$CRT; fi
    if [ "$KEY" ]; then KEY_FILE=$KEY; fi
    if [ "$NAME" ]; then CNAME=$NAME; fi
fi

cd $OEM_DIR

# REGENERATING CONF FILES FROM ENV VARS
echo "CUSTOMIZING APACHE CONF FOR EMONCMS"
#CNAME=$(openssl x509 -noout -subject -in $CERT_FILE | sed 's/.*CN = //')
mv /etc/apache2/conf.d/ssl.conf /etc/apache2/conf.d/ssl.old
# double quotes in order to use a shell var
sed -i "s/^#ServerName.*/ServerName $CNAME/" $HTTP_CONF
sed -i '/LoadModule rewrite_module/s/^#//g' $HTTP_CONF
#sed -i 's/^#LoadModule rewrite/LoadModule rewrite/' $HTTP_CONF
# delete between 2 patterns with sed
# https://techstop.github.io/delete-lines-strings-between-two-patterns-sed/
#sed -i '/<Directory "\/var\/www\/localhost\/htdocs\">/,/<\/Directory>/d' $HTTP_CONF
# replace all occurences of localhost/htdocs by emoncms
sed -i 's/localhost\/htdocs/emoncms/g' $HTTP_CONF
VIRTUAL_HOST=/etc/apache2/conf.d/emoncms.conf
echo "<VirtualHost *:80>" > $VIRTUAL_HOST
#echo "    ServerName $CNAME" >> $VIRTUAL_HOST
echo "    <Directory $WWW/emoncms>" >> $VIRTUAL_HOST
echo "        Options FollowSymLinks" >> $VIRTUAL_HOST
echo "        AllowOverride All" >> $VIRTUAL_HOST
echo "        DirectoryIndex index.php" >> $VIRTUAL_HOST
echo "        Require all granted" >> $VIRTUAL_HOST
echo "    </Directory>" >> $VIRTUAL_HOST
echo "</VirtualHost>" >> $VIRTUAL_HOST
echo "LoadModule ssl_module modules/mod_ssl.so" >> $VIRTUAL_HOST
echo "LoadModule socache_shmcb_module modules/mod_socache_shmcb.so" >> $VIRTUAL_HOST
echo "Listen 443" >> $VIRTUAL_HOST
echo "SSLSessionCache \"shmcb:/var/cache/mod_ssl/scache(512000)\"" >> $VIRTUAL_HOST
echo "SSLSessionCacheTimeout 300" >> $VIRTUAL_HOST
echo "<VirtualHost *:443>" >> $VIRTUAL_HOST
echo "    SSLEngine on" >> $VIRTUAL_HOST
echo "    SSLcertificateFile $CRT_FILE" >> $VIRTUAL_HOST
echo "    SSLCertificateKeyFile $KEY_FILE" >> $VIRTUAL_HOST
#echo "    ServerName $CNAME" >> $VIRTUAL_HOST
echo "    <Directory $WWW/emoncms>" >> $VIRTUAL_HOST
echo "        Options FollowSymLinks" >> $VIRTUAL_HOST
echo "        AllowOverride All" >> $VIRTUAL_HOST
echo "        DirectoryIndex index.php" >> $VIRTUAL_HOST
echo "        Require all granted" >> $VIRTUAL_HOST
echo "    </Directory>" >> $VIRTUAL_HOST
echo "</VirtualHost>" >> $VIRTUAL_HOST

echo "CREATING /etc/my.cnf"
mv /etc/my.cnf /etc/my.old
echo "[mysqld]" >> /etc/my.cnf
echo "datadir=$EMONCMS_DATADIR/mysql" >> /etc/my.cnf

echo "CREATING MQTT CONF"
echo "persistence false" > $MQTT_CONF
echo "allow_anonymous false" >> $MQTT_CONF
echo "listener 1883" >> $MQTT_CONF
echo "password_file /etc/mosquitto/passwd" >> $MQTT_CONF
echo "log_dest stdout" >> $MQTT_CONF
echo "log_timestamp_format %Y-%m-%dT%H:%M:%S" >> $MQTT_CONF
for level in $MQTT_LOG_LEVEL; do echo "log_type $level" >> $MQTT_CONF; done;

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
echo "host = '$MQTT_HOST'" >> settings.ini
echo "user = '$MQTT_USER'" >> settings.ini
echo "password = '$MQTT_PASSWORD'" >> settings.ini
echo "[feed]" >> settings.ini
echo "engines_hidden = [0,6,10]" >> settings.ini
echo "redisbuffer[enabled] = $REDIS_BUFFER" >> settings.ini
echo "redisbuffer[sleep] = 300" >> settings.ini
echo "phpfina[datadir] = '$EMONCMS_DATADIR/phpfina/'" >> settings.ini
echo "phptimeseries[datadir] = '$EMONCMS_DATADIR/phptimeseries/'" >> settings.ini
echo "[interface]" >> settings.ini
echo "enable_admin_ui = true" >> settings.ini
echo "feedviewpath = 'graph/'" >> settings.ini
echo "favicon = 'favicon_emonpi.png'" >> settings.ini
echo "[log]" >> settings.ini
echo "; Log Level: 1=INFO, 2=WARN, 3=ERROR" >> settings.ini
echo "level = $EMONCMS_LOG_LEVEL" >> settings.ini
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
printf "$REDIS_BUFFER" > /var/run/s6/container_environment/REDIS_BUFFER
