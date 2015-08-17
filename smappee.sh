#! /bin/sh
. /etc/profile.d/DomoticzData.sh
lua /home/pi/energy/smappee.lua >>$TempFileDir'smappee.log' 2>>$TempFileDir'smappee.log.errors'
