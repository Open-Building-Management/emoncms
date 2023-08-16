Emoncms is a webapp for real time data monitoring

It uses :
- a self crafted binary timeserie called phpfina and mariadb to store metadatas.
- the eclipse mosquitto broker
- redis as a data buffer when writing to disk on timeseries
- three main workers to achieve background operations : emoncms_mqtt, service-runner and feedwriter

For more information, see https://github.com/emoncms/emoncms

# post data to the mqtt broker

supposing the IP of your Home Assistant running the emoncms add-on to be 192.168.1.53, you can post datas from your local network :

```
mosquitto_pub -h 192.168.1.53 -p 7883 -u "emonpi" -P "emonpimqtt2016" -t 'emon/test/t3' -m 43.67
```

if you dont have mosquitto_pub installed and have a machine on your local network running debian/ubuntu : `sudo apt-get install mosquitto-clients`

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
