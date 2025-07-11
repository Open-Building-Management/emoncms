ARG BUILD_FROM=alpine:3.19

FROM $BUILD_FROM

ARG \
	TARGETPLATFORM \
	S6_OVERLAY_VERSION=3.1.6.2 \
	S6_SRC=https://github.com/just-containers/s6-overlay/releases/download \
	S6_DIR=/etc/s6-overlay/s6-rc.d \
	PRIMOS="apache2 redis mosquitto mariadb" \
	SECONDOS="emoncms_mqtt service-runner feedwriter sync_upload" \
	# PHP_VER needed to install the php-dev apk package and for the path to PHP CONF/INI files
	PHP_VER=82 \
	# we dont modify php.ini, we create new extensions in conf.d
	PHP_CONF=/etc/php82/conf.d \
	REDIS_CONF=/etc/redis.conf \
	USE_REDISPY_APK=1 \
	# source for Mosquitto-PHP extension
	# original repo is https://github.com/mgdm/Mosquitto-PHP
	# but it does not work for php8
	MOSQUITTO_PHP=https://github.com/openenergymonitor/Mosquitto-PHP \
	# this is only for the makefile
	SYMLINKED_MODULES_URL=https://github.com/emoncms \
	EMONCMS_SRC=https://github.com/alexandrecuer/emoncms \
	BRANCH=master

# ENV vars used during build PLUS when starting the container
# DAEMON is the user running the workers
# it must be the same as the one running the webserver
# on alpine, httpd user is apache and not www-data
ENV \
	DAEMON=apache \
	WWW=/var/www \
	OEM_DIR=/opt/openenergymonitor \
	EMONCMS_DIR=/opt/emoncms \
	EMONCMS_LOG_LOCATION=/var/log/emoncms \
	MQTT_CONF=/etc/mosquitto/mosquitto.conf

# /data creation and apk installation
# php-gettext available via apk
RUN mkdir -p /data;\
	mkdir -p /config;\
	apk update && apk upgrade;\
	apk add --no-cache tzdata xz bash git make tar jq;\
	apk add --no-cache sed nano;\
	apk add --no-cache python3;\
	apk add --no-cache ca-certificates wget;\
	apk add --no-cache apache2 apache2-ssl gettext;\
	apk add --no-cache mariadb mariadb-client;\
	apk add --no-cache redis;\
	apk add --no-cache mosquitto;\
	apk add --no-cache php php-gettext php-apache2 php-mysqli;\
	apk add --no-cache php-gd php-curl php-common php-mbstring;\
	apk add --no-cache php-session php-ctype

# it is possible to install s6-overlay with apk but it does not provide user2
#RUN apk add --no-cache s6-overlay
# if using the s6-overlays tarballs & execlineb is missing : apk add --no-cache execline
RUN set -x;\
	case $TARGETPLATFORM in \
	"linux/amd64")  S6_ARCH="x86_64"  ;; \
	"linux/arm/v7") S6_ARCH="arm"  ;; \
	"linux/arm64") S6_ARCH="aarch64"  ;; \
	esac;\
	wget -P /tmp $S6_SRC/v$S6_OVERLAY_VERSION/s6-overlay-$S6_ARCH.tar.xz --no-check-certificate;\
	wget -P /tmp $S6_SRC/v$S6_OVERLAY_VERSION/s6-overlay-noarch.tar.xz --no-check-certificate;\
	tar -C / -Jxpf /tmp/s6-overlay-$S6_ARCH.tar.xz;\
	tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

# creating folders, setting permissions and cloning emoncms sources
RUN set -x;\
	mkdir -p $OEM_DIR;\
	mkdir -p $EMONCMS_LOG_LOCATION;\
	mkdir -p $EMONCMS_DIR;\
	chown $DAEMON $EMONCMS_LOG_LOCATION;\
	touch $EMONCMS_LOG_LOCATION/emoncms.log;\
	chmod 666 $EMONCMS_LOG_LOCATION/emoncms.log;\
	# needed for emoncms_mqtt and feedwriter which create a lock at startup
	chown $DAEMON /var/lock;\
	# needed for the backup module when importing a tar.gz
	chown $DAEMON /tmp;\
	cd $WWW && git clone -b $BRANCH $EMONCMS_SRC;\
	mkdir -p /run/mysqld;\
	chown -R mysql:mysql /run/mysqld

WORKDIR $OEM_DIR

COPY security.conf makefile ./

# the following 3 lines are for the admin module : not nice ;-(
# in container the admin module is just to see emoncms log
# solution could be not to use admin module anymore
# for this set enable_admin_ui to false
RUN set -x;\
	git config --system --replace-all safe.directory '*';\
	git clone https://github.com/openenergymonitor/EmonScripts;\
	cp EmonScripts/install/emonsd.config.ini EmonScripts/install/config.ini

# emoncms modules
RUN set -x;\
	make module name=graph;\
	make module name=dashboard;\
	make module name=app;\
	make symodule name=sync;\
	make symodule name=postprocess;\
	make symodule name=backup;\
    make module name=device

# redis and mosquitto conf : simple
# build-base is required to compile with gcc
# mosquitto-dev is needed to compile mosquitto-PHP
# we need phpize so we install php-dev
RUN set -x;\
	apk add --no-cache build-base mosquitto-dev;\
	apk add --no-cache py3-pip php$PHP_VER-dev;\
	sed -i "s/^save 900 1/#save 900 1/" $REDIS_CONF;\
	sed -i "s/^save 300 1/#save 300 1/" $REDIS_CONF;\
	sed -i "s/^save 60 1/#save 60 1/" $REDIS_CONF;\
	git clone https://github.com/phpredis/phpredis;\
	cd phpredis && phpize && ./configure && make && make install;\
	printf "extension=redis.so" | tee $PHP_CONF/redis.ini 1>&2;\
	if [ "$USE_REDISPY_APK" -ne 0 ]; then apk add --no-cache py3-redis; fi;\
	if [ "$USE_REDISPY_APK" -eq 0 ]; then pip3 install redis; fi;\
	git clone $MOSQUITTO_PHP;\
	cd Mosquitto-PHP && phpize && ./configure && make && make install;\
	printf "extension=mosquitto.so" | tee $PHP_CONF/mosquitto.ini 1>&2;\
	apk del --no-cache build-base mosquitto-dev;\
	apk del --no-cache py3-pip php$PHP_VER-dev;\
	# this will remove sources for phpredis and Mosquitto-PHP
	rm -Rf $OEM_DIR/phpredis

COPY emoncms_pre.sh sql_ready.sh ./

# we create dynamically the database update script
# as it uses the $WWW env which will not be available at run time in php
RUN set -x;\
	echo "<?php" > emoncmsdbupdate.php;\
	echo "\$applychanges = true;" >> emoncmsdbupdate.php;\
	echo "define('EMONCMS_EXEC', 1);" >> emoncmsdbupdate.php;\
	echo "chdir('$WWW/emoncms');" >> emoncmsdbupdate.php;\
	echo "require 'process_settings.php';" >> emoncmsdbupdate.php;\
	echo "require 'core.php';" >> emoncmsdbupdate.php;\
	echo "\$mysqli = @new mysqli(" >> emoncmsdbupdate.php;\
	echo "    \$settings['sql']['server']," >> emoncmsdbupdate.php;\
	echo "    \$settings['sql']['username']," >> emoncmsdbupdate.php;\
	echo "    \$settings['sql']['password']," >> emoncmsdbupdate.php;\
	echo "    \$settings['sql']['database']," >> emoncmsdbupdate.php;\
	echo "    \$settings['sql']['port']" >> emoncmsdbupdate.php;\
	echo ");" >> emoncmsdbupdate.php;\
	echo "require_once 'Lib/dbschemasetup.php';" >> emoncmsdbupdate.php;\
	echo "print json_encode(db_schema_setup(\$mysqli,load_db_schema(),\$applychanges)).'\n';" >> emoncmsdbupdate.php

# if s6-overlay is installed via apk, use bin and not command for execlineb !!
# cf https://github.com/just-containers/s6-overlay/issues/449
RUN set -x;\
	# initialize timeseries and mariadb with a oneshot service called emoncms_pre
	mkdir $S6_DIR/emoncms_pre;\
	mkdir $S6_DIR/emoncms_pre/dependencies.d;\
	touch $S6_DIR/emoncms_pre/dependencies.d/base;\
	echo "oneshot" > $S6_DIR/emoncms_pre/type;\
	echo "$OEM_DIR/emoncms_pre.sh" > $S6_DIR/emoncms_pre/up;\
	touch $S6_DIR/user/contents.d/emoncms_pre;\
	# start primo services after emoncms_pre
	for i in $PRIMOS; do mkdir $S6_DIR/$i; done;\
	for i in $PRIMOS; do mkdir $S6_DIR/$i/dependencies.d; done;\
	for i in $PRIMOS; do touch $S6_DIR/$i/dependencies.d/emoncms_pre; done;\
	for i in $PRIMOS; do touch $S6_DIR/user/contents.d/$i; done;\
	for i in $PRIMOS; do echo "longrun" > $S6_DIR/$i/type; done;\
	for i in $PRIMOS; do echo "#!/command/execlineb -P" > $S6_DIR/$i/run; done;\
	echo "/command/foreground { rm -f /var/run/apache2/httpd.pid } /usr/sbin/httpd -D FOREGROUND" >> $S6_DIR/apache2/run;\
	echo "redis-server $REDIS_CONF" >> $S6_DIR/redis/run;\
	echo "mosquitto -c $MQTT_CONF" >> $S6_DIR/mosquitto/run;\
	# we run mysql as root !
	#echo "s6-setuidgid mysql" >> $S6_DIR/mariadb/run;\
	# use mysqld_safe if you want no verbosity on stdout
	echo "mysqld --user=root" >> $S6_DIR/mariadb/run

# user2 level services = workers
RUN set -x;\
	# check if SQL is fully ready with a oneshot service
	mkdir $S6_DIR/sql_ready;\
	mkdir $S6_DIR/sql_ready/dependencies.d;\
	touch $S6_DIR/sql_ready/dependencies.d/legacy-services;\
	echo "oneshot" > $S6_DIR/sql_ready/type;\
	echo "$OEM_DIR/sql_ready.sh" > $S6_DIR/sql_ready/up;\
	touch $S6_DIR/user2/contents.d/sql_ready;\
	# start all long running workers after sql_ready
	for i in $SECONDOS; do mkdir $S6_DIR/$i; done;\
	for i in $SECONDOS; do mkdir $S6_DIR/$i/dependencies.d; done;\
	for i in $SECONDOS; do touch $S6_DIR/$i/dependencies.d/sql_ready; done;\
	for i in $SECONDOS; do touch $S6_DIR/user2/contents.d/$i; done;\
	for i in $SECONDOS; do echo "longrun" > $S6_DIR/$i/type; done;\
	for i in $SECONDOS; do echo "#!/command/execlineb -P" > $S6_DIR/$i/run; done;\
	echo "s6-setuidgid $DAEMON" >> $S6_DIR/emoncms_mqtt/run;\
	echo "php $WWW/emoncms/scripts/services/emoncms_mqtt/emoncms_mqtt.php" >> $S6_DIR/emoncms_mqtt/run;\
	echo "s6-setuidgid $DAEMON" >> $S6_DIR/service-runner/run;\
	echo "python3 $WWW/emoncms/scripts/services/service-runner/service-runner.py" >> $S6_DIR/service-runner/run;\
	echo "#!/command/with-contenv sh" > $S6_DIR/feedwriter/run;\
	echo "if [ \"\${REDIS_BUFFER}\" -ne 1 ]; then" >> $S6_DIR/feedwriter/run;\
	echo "    echo \"FEEDWRITER IS MUTED !\"" >> $S6_DIR/feedwriter/run;\
	echo "    s6-svc -O ." >> $S6_DIR/feedwriter/run;\
	echo "    exit 0" >> $S6_DIR/feedwriter/run;\
	echo "fi" >> $S6_DIR/feedwriter/run;\
	echo "exec s6-setuidgid $DAEMON php $WWW/emoncms/scripts/feedwriter.php" >> $S6_DIR/feedwriter/run;\
	echo "s6-setuidgid $DAEMON" >> $S6_DIR/sync_upload/run;\
	echo "php $EMONCMS_DIR/modules/sync/sync_upload.php all bg" >> $S6_DIR/sync_upload/run;\
	#chown $DAEMON $OEM_DIR;\
	chown -R $DAEMON $WWW/emoncms;\
	chown -R $DAEMON $EMONCMS_DIR;\
	chmod +x emoncms_pre.sh;\
	chmod +x sql_ready.sh

# ENV vars used when starting the container
# fixing S6_SERVICES_GRACETIME & S6_CMD_WAIT_FOR_SERVICES_MAXTIME :
# necessary as we launch mysql_install_db at startup
ENV \
	S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
	S6_SERVICES_GRACETIME=18000 \
	PHP_VER=$PHP_VER \
	PHP_CONF=$PHP_CONF
# ENV vars below can be customized by the user at runtime
# the sql database and the timeseries will be in /data/emoncms but it can be changed
ENV \
	TZ="Europe/Paris" \
	EMONCMS_DATADIR=/data/emoncms \
	TS="phpfina phpfiwa phptimeseries" \
	REDIS_BUFFER=1 \
	EMONCMS_LOG_LEVEL=2 \
	MYSQL_DATABASE=emoncms \
	MYSQL_USER=emoncms \
	MYSQL_PASSWORD=emonpiemoncmsmysql2016 \
	MQTT_ANONYMOUS=0 \
	MQTT_USER=emonpi \
	MQTT_PASSWORD=emonpimqtt2016 \
	MQTT_HOST=localhost \
	MQTT_BASETOPIC=emon \
	MQTT_CLIENT_ID=emoncms \
	MQTT_LOG_LEVEL=error \
	HTTP_CONF=/etc/apache2/httpd.conf \
	CRT_FILE=/etc/ssl/apache2/server.pem \
	KEY_FILE=/etc/ssl/apache2/server.key \
	CUSTOM_APACHE_CONF=0 \
	USE_HOSTNAME_FOR_MQTT_TOPIC_CLIENTID=0 \
	CNAME=localhost

EXPOSE 80 1883 443

ENTRYPOINT ["/init"]
