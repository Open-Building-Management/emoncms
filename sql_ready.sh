#!/command/with-contenv sh
while ! mysql -e "" 2> /dev/null; do
    sleep 1
done

echo "mysql running, so workers can be started"

if [ "$NEW_INSTALL" -eq 1 ]; then
    echo "Securing mysql, creating database $MYSQL_DATABASE and user $MYSQL_USER"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'; FLUSH PRIVILEGES;"
    mysql -e "CREATE DATABASE $MYSQL_DATABASE DEFAULT CHARACTER SET utf8;";\
    mysql -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
    mysql -e "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost'; flush privileges;"
fi
