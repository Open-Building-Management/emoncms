# Changelog

## alpine3.20_emoncms11.9.10

Emoncms Core v11.9.10
App v3.1.5
Dashboard v2.4.3
Device v2.3.3
Graph v2.2.7
Backup v2.3.5
Postprocess v2.4.9
Sync v3.2.2
EmonScripts v1.8.16

## alpine3.20_emoncms11.7.3

allow anonymous mqtt

Emoncms Core v11.7.3
Graph v2.2.5
EmonScripts v1.8.8

## alpine3.20_emoncms11.7.2

Emoncms Core v11.7.2
App v3.1.3
Dashboard v2.4.1
Device v2.2.6
Graph v2.2.4
Backup v2.3.4
Postprocess v2.4.8
Sync v3.2.0
EmonScripts v1.8.7

sync, backup, postprocess and core modified to add ability to update modules through admin UI

cf https://github.com/Open-Building-Management/emoncms/issues/38

## alpine3.20_emoncms11.6.10

device module addition @jeremyakers

if upgrading from an existing installation, update the database structure after upgrading

- Emoncms Core v11.6.10
- App v3.0.1
- Dashboard v2.4.1
- Device v2.2.6
- Graph v2.2.4
- Backup v2.3.4
- Postprocess v2.4.7
- Sync v3.2.0

## alpine3.20_emoncms11.6.5

emoncms 11.6.5

with modules :

- postprocess 2.4.7
- sync 3.1.7
- graph 2.2.4
- dashboard 2.4.0
- backup 2.3.3

this version of sync introduces with the ability to automatically synchronize feeds from a sensor to another

if using an existing database, dont forget to update your database structure through the emoncms admin module

## alpine3.19.1_emoncms11.5.7

emoncms 11.5.7

with unique identifier UUID generator

## alpine3.19.1_emoncms11.5.2

emoncms 11.5.2

## alpine3.19_emoncms11.5.0_1

ability to customize the topic the mqtt worker is listening to

## alpine3.19_emoncms11.5.0

ingress version :-)

## alpine3.19_emoncms11.4.11_1

Adding a CUSTOM_APACHE_CONF option so the user can inject its custom headers in apache :
previously introduced security headers are removed by default

redirecting :

- apache access log to standard output
- apache error log to error output

## alpine3.19_emoncms11.4.11

alpine3.19

adding some security headers on apache :

- X-Content-Type-Options
- Strict-Transport-Security
- X-Frame-Options, to defend against clickjacking
- Referrer-Policy
- Permissions-Policy

Plus X-XSS-Protection

Nota : too much inline javascript to add Content-Security-Policy...

## alpine3.18_emoncms11.4.11

ability to configure TLS/HTTPS

new tagging process integrating emoncms version number

## alpine3.16.3

ability to mute the feedwriter and to leave the low write mode

ability to modulate the emoncms log level (1,2,3)

## alpine3.16.2

addition of the app module

## alpine3.16.1

adding the ability to configure timezone, mqtt host and log level

fixed format for mqtt level to something more readable than unix timestamp

## alpine3.16

emoncms 11.3.22

with modules :

- postprocess 2.4.7
- sync 2.1.4
- graph 2.2.3
- dashboard 2.3.3
- backup 2.3.2
