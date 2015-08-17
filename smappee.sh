#! /bin/sh
. /etc/profile.d/DomoticzData.sh
lua /home/pi/energy/smappee.lua >>/var/tmp/smappee.log 2>>/var/tmp/smappee.log.errors
