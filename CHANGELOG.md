# Changelog

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
