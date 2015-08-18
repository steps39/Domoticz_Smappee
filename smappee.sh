#! /bin/sh
. /etc/profile.d/DomoticzData.sh
lua /home/pi/domoticz_smappee/smappee.lua >>$TempFileDir'smappee.log' 2>>$TempFileDir'smappee.log.errors'
