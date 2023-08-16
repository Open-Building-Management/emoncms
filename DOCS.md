# what's inside ?

emoncms is a webapp for real time data monitoring

It uses :
- a self crafted binary timeserie called phpfina and mariadb to store metadatas.
- the eclipse mosquitto broker
- redis as a data buffer when writing to disk on timeseries
- three main workers to achieve background operations : emoncms_mqtt, service-runner and feedwriter

For more information, see https://github.com/emoncms/emoncms

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


