Emoncms is a webapp for real time data monitoring

It uses :

- a self crafted binary timeserie called phpfina and mariadb to store metadatas.
- the eclipse mosquitto broker
- redis as a data buffer when writing to disk on timeseries
- three main workers to achieve background operations : emoncms_mqtt, service-runner and feedwriter
- the sync_upload service to automatically upload feeds from an emoncms instance to another one and keep then synchronised

For more information, see https://github.com/emoncms/emoncms

# ingress

The addon runs in ingress mode a but you can also expose port(s)

# customize apache configuration and manage security headers

Activate the `CUSTOM_APACHE_CONF` option. It will enable the TLS (Transport Layer Security) protocol.

Open `/config/security.conf` with the File Editor addon and adapt the apache configuration to your needs.

# post data to the mqtt broker

Supposing the IP of your Home Assistant running the emoncms add-on to be 192.168.1.53, you can post datas from your local network :

```
mosquitto_pub -h 192.168.1.53 -p 9883 -u "emonpi" -P "emonpimqtt2016" -t 'emon/test/t3' -m 43.67
```

If you dont have mosquitto_pub installed and have a machine on your local network running debian/ubuntu : `sudo apt-get install mosquitto-clients`

You can change the mosquitto username and password in the add-on configuration

# what's inside the emoncms add-on ?

Servers :

- apache server
- mosquitto eclipse broker

Databases :

- mariadb
- redis

Languages :

- php 8
- python

Extensions :

- phpredis - https://github.com/phpredis/phpredis
- redis-py - https://github.com/redis/redis-py
- Mosquitto-PHP - https://github.com/openenergymonitor/Mosquitto-PHP
