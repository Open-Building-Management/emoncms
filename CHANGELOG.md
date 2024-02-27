# Changelog

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

