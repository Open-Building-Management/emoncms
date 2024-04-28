#!/command/with-contenv sh

cp "/usr/share/zoneinfo/$TZ" /etc/localtime

NEW_INSTALL=0

cd "$OEM_DIR"

if ! [ -d "$EMONCMS_DATADIR" ]; then
    echo "Creating timeseries folders"
    mkdir -p "$EMONCMS_DATADIR"
    mkdir -p "$EMONCMS_DATADIR/backup"
    mkdir -p "$EMONCMS_DATADIR/backup/uploads"
    for i in $TS; do mkdir -p "$EMONCMS_DATADIR/$i"; done
else
    echo "Using existing timeseries"
fi
chown -R "$DAEMON" "$EMONCMS_DATADIR"

if ! [ -f "/config/security.conf" ]; then
    echo "initializing a security.conf file in /config"
    cp security.conf /config/security.conf
fi

if ! [ -d "$EMONCMS_DATADIR/mysql" ]; then
    echo "Creating a new mariadb"
    mysql_install_db --datadir="$EMONCMS_DATADIR/mysql" > /dev/null
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
    MQTT_BASETOPIC=$(jq --raw-output '.MQTT_BASETOPIC // empty' $OPTIONS_JSON)
    LOCAL_TZ=$(jq --raw-output '.TZ // empty' $OPTIONS_JSON)
    if [ "$LOCAL_TZ" ]; then TZ=$LOCAL_TZ; fi
    LOG_LEVEL=$(jq --raw-output '.EMONCMS_LOG_LEVEL // empty' $OPTIONS_JSON)
    if [ "$LOG_LEVEL" ]; then EMONCMS_LOG_LEVEL=$LOG_LEVEL; fi
    REDIS_BUFFER=$(jq --raw-output 'if .LOW_WRITE_MODE==true then 1 else 0 end' $OPTIONS_JSON)
    CUSTOM_APACHE_CONF=$(jq --raw-output 'if .CUSTOM_APACHE_CONF==true then 1 else 0 end' $OPTIONS_JSON)
    CRT=$(jq --raw-output '.CRT_FILE // empty' $OPTIONS_JSON)
    KEY=$(jq --raw-output '.KEY_FILE // empty' $OPTIONS_JSON)
    NAME=$(jq --raw-output '.CNAME // empty' $OPTIONS_JSON)
    if [ "$CRT" ]; then CRT_FILE=$CRT; fi
    if [ "$KEY" ]; then KEY_FILE=$KEY; fi
    if [ "$NAME" ]; then CNAME=$NAME; fi
fi

# REGENERATING CONF FILES FROM ENV VARS
echo "CUSTOMIZING APACHE CONF FOR EMONCMS"
#CNAME=$(openssl x509 -noout -subject -in $CERT_FILE | sed 's/.*CN = //')
mv /etc/apache2/conf.d/ssl.conf /etc/apache2/conf.d/ssl.old
# double quotes in order to use a shell var
sed -i "s/^#ServerName.*/ServerName $CNAME/" "$HTTP_CONF"
sed -i '/LoadModule rewrite_module/s/^#//g' "$HTTP_CONF"
#sed -i 's/^#LoadModule rewrite/LoadModule rewrite/' "$HTTP_CONF"
# delete between 2 patterns with sed
# https://techstop.github.io/delete-lines-strings-between-two-patterns-sed/
#sed -i '/<Directory "\/var\/www\/localhost\/htdocs\">/,/<\/Directory>/d' "$HTTP_CONF"
# replace all occurences of localhost/htdocs by emoncms
sed -i 's/localhost\/htdocs/emoncms/g' "$HTTP_CONF"
# cf https://en.wikipedia.org/wiki/Standard_streams
# redirecting apache logs to docker
echo "APACHE ACCESS LOG TO STANDARD OUTPUT"
sed -ri -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' "$HTTP_CONF"
echo "APACHE ERROR LOG TO STANDARD ERROR"
sed -ri -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' "$HTTP_CONF"
if [ "$CUSTOM_APACHE_CONF" -eq 1 ]; then
  CUSTOM_CONF_DIR="IncludeOptional /config/*.conf"
  grep -qxF "$CUSTOM_CONF_DIR" "$HTTP_CONF" || echo "$CUSTOM_CONF_DIR">> "$HTTP_CONF"
fi
VIRTUAL_HOST=/etc/apache2/conf.d/emoncms.conf
echo "<VirtualHost *:80>" > $VIRTUAL_HOST
{
  #echo "    ServerName $CNAME"
  echo "    <Directory $WWW/emoncms>"
  echo "        Options FollowSymLinks"
  echo "        AllowOverride All"
  echo "        DirectoryIndex index.php"
  echo "        Require all granted"
  echo "    </Directory>"
  echo "</VirtualHost>"
  echo "LoadModule ssl_module modules/mod_ssl.so"
  echo "LoadModule socache_shmcb_module modules/mod_socache_shmcb.so"
  echo "Listen 443"
  echo "SSLSessionCache \"shmcb:/var/cache/mod_ssl/scache(512000)\""
  echo "SSLSessionCacheTimeout 300"
  echo "<VirtualHost *:443>"
  echo "    SSLEngine on"
  echo "    SSLcertificateFile $CRT_FILE"
  echo "    SSLCertificateKeyFile $KEY_FILE"
  #echo "    ServerName $CNAME"
  echo "    <Directory $WWW/emoncms>"
  echo "        Options FollowSymLinks"
  echo "        AllowOverride All"
  echo "        DirectoryIndex index.php"
  echo "        Require all granted"
  echo "    </Directory>"
  echo "</VirtualHost>"
} >> $VIRTUAL_HOST
echo "CREATING /etc/my.cnf"
mv /etc/my.cnf /etc/my.old
echo "[mysqld]" >> /etc/my.cnf
echo "datadir=$EMONCMS_DATADIR/mysql" >> /etc/my.cnf

echo "CREATING MQTT CONF"
echo "persistence false" > "$MQTT_CONF"
{
  echo "allow_anonymous false"
  echo "listener 1883"
  echo "password_file /etc/mosquitto/passwd"
  echo "log_dest stdout"
  echo "log_timestamp_format %Y-%m-%dT%H:%M:%S"
  for level in $MQTT_LOG_LEVEL; do echo "log_type $level"; done;
} >> "$MQTT_CONF"

echo "GENERATING EMONCMS SETTINGS.INI"
echo "emoncms_dir = '$EMONCMS_DIR'" > settings.ini
{
  echo "openenergymonitor_dir = '$OEM_DIR'"
  echo "[sql]"
  echo "server = 'localhost'"
  echo "database = '$MYSQL_DATABASE'"
  echo "username = '$MYSQL_USER'"
  echo "password = '$MYSQL_PASSWORD'"
  echo "dbtest   = true"
  echo "[redis]"
  echo "enabled = true"
  echo "prefix = ''"
  echo "[mqtt]"
  echo "enabled = true"
  echo "host = '$MQTT_HOST'"
} >> settings.ini
if [ "$USE_HOSTNAME_FOR_MQTT_TOPIC_CLIENTID" -eq 1 ]; then
    BASETOPIC=$MQTT_BASETOPIC\_$HOSTNAME
    CLIENT_ID=$MQTT_CLIENT_ID\_$HOSTNAME
    echo "using a custom MQTT basetopic $BASETOPIC"
    echo "basetopic = '$BASETOPIC'" >> settings.ini
    echo "using a custom MQTT client_id $CLIENT_ID"
    echo "client_id = '$CLIENT_ID'" >> settings.ini
else
    echo "basetopic = '$MQTT_BASETOPIC'" >> settings.ini
    echo "client_id = '$MQTT_CLIENT_ID'" >> settings.ini
fi
{
  echo "user = '$MQTT_USER'"
  echo "password = '$MQTT_PASSWORD'"
  echo "[feed]"
  echo "engines_hidden = [0,6,10]"
  echo "redisbuffer[enabled] = $REDIS_BUFFER"
  echo "redisbuffer[sleep] = 300"
  echo "phpfina[datadir] = '$EMONCMS_DATADIR/phpfina/'"
  echo "phptimeseries[datadir] = '$EMONCMS_DATADIR/phptimeseries/'"
  echo "[interface]"
  echo "enable_admin_ui = true"
  echo "feedviewpath = 'graph/'"
  echo "favicon = 'favicon_emonpi.png'"
  echo "[log]"
  echo "; Log Level: 1=INFO, 2=WARN, 3=ERROR"
  echo "level = $EMONCMS_LOG_LEVEL"
} >> settings.ini
cp settings.ini "$WWW/emoncms/settings.ini"

echo "CREATING USER/PWD FOR MOSQUITTO"
touch /etc/mosquitto/passwd
mosquitto_passwd -b /etc/mosquitto/passwd "$MQTT_USER" "$MQTT_PASSWORD"

echo "GENERATING config.cfg for BACKUP MODULE"
echo "user=$DAEMON" > config.cfg
{
  echo "backup_script_location=$EMONCMS_DIR/modules/backup"
  echo "emoncms_location=$WWW/emoncms"
  echo "backup_location=$EMONCMS_DATADIR/backup"
  echo "database_path=$EMONCMS_DATADIR"
  echo "emonhub_config_path="
  echo "emonhub_specimen_config="
  echo "backup_source_path=$EMONCMS_DATADIR/backup/uploads"
} >> config.cfg
cp config.cfg "$EMONCMS_DIR/modules/backup/config.cfg"

echo "GENERATING backup.ini PHP extension"
echo "post_max_size=3G" > "$PHP_CONF/backup.ini"
echo "upload_max_filesize=3G" >> "$PHP_CONF/backup.ini"
echo "upload_tmp_dir=$EMONCMS_DATADIR/backup/uploads" >> "$PHP_CONF/backup.ini"

printf "%s" $NEW_INSTALL > /var/run/s6/container_environment/NEW_INSTALL
printf "%s" "$REDIS_BUFFER" > /var/run/s6/container_environment/REDIS_BUFFER
