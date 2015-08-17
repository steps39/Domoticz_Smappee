    1 Introduction
    2 Installing smappee
        2.1 Installing Lua Libraries
        2.2 Customisation File
        2.3 Setting Up Domoticz for smappee.lua
        2.4 Installing Smappee Program
    3 Checking Functioning

Introduction

Smappee is an energy monitor, which logs your energy consumption back to a server. Smappee have released an api to access the stored energy consumption remotely.

The api is fairly simple, involving authorisation, selection of system for data to be retrieved about, then data retreival and can be accessed from a bash script as here - http://www.domoticz.com/forum/viewtopic.php?f=31&t=7312#p50197

Unfortunately the server does not always return data when it should, in order to avoid loosing data then a more complex Lua script is required, which correctly handles both authorisation and occassions when there is no data or multiple sets of data.

Domoticz incorporates Lua and in principle data could be retrieved from smappee from within Domoticz, but authorisation with the smappee server can take up to 20 seconds, but Domoticz only allows Lua programs to run for 10 seconds in case they get into an infinite loop and makes Domoticz irresponsive.

N.B. Smappee returns the energy consumed in a 5 minute period, so this is used by smappee.lua to calculate an "average" power used over 5 minutes, so peak power measurements will be lower than those reported in domoticz from more direct energy measurement devices. The energy reported back from smappee.lua to Domoticz, is logged by Domoticz as the time at which the data is recorded in Domoticz, so if there are any issues with data being returned from Smappee then while the total consumption should be correct, the power will be an averaged figure over different time periods of time.
Installing smappee

These instructions are for use on a Raspberry Pi, using Lua 5.2, for other systems you will need to find / compile the necessary Lua libraries yourself. The current program expects both household energy consumption and solar energy generation, the Smappee hardware is also able to monitor a single phase consumption with solar energy and 3 phase with / without solar energy.
Installing Lua Libraries

smappee is a Lua program and requires Lua 5.2 plus https / json ability to interact, (json, socket and ssl libraries).

First install Lua 5.2 if it is not already on your system and git as we will need it later:

sudo apt-get update
sudo apt-get install lua5.2 git-core

Now, you will need to install the necessary libraries for Lua. I have compiled these and made them availalbe on the forum - dtgbot - Domoticz TeleGram BOT. Download the two tar.gz files to a temporary directory (~/temp).

sudo mkdir -p /usr/local/share/lua/5.2/ #Only needed if this directory does not exist
cd /usr/local/share/lua/5.2/
sudo tar -xvf ~/temp/usrlocalsharelua52.tar.gz
sudo mkdir -p /usr/local/lib/lua/5.2/ #Only needed if this directory does not exist
cd /usr/local/lib/lua/5.2/
sudo tar -xvf ~/temp/usrlocalliblua52.tar.gz

Customisation File

In order to avoid accidentally passing system specific information, I have included all the system customisation data in a single shell script.

In order to create this file you need to edit the suggested file below with your email address, your Smappe user name, your Smappee password, your Smappee client id, your Smappee secret and details of your Domoticz set-up. It is good to have a temporary directory set up for the log file, I would recommend using a ram disk for the temporary directory, have a look here - http://www.domoticz.com/wiki/Setting_up_a_RAM_drive_on_Raspberry_Pi.

Create your customisation file:

sudo nano /etc/profile.d/DomoticzData.sh

#!/bin/bash
 
# Variables to avoid having to set local system information in individual automation scripts
 
#I can't get the next line to work during start-up so have gone to 127 instead
#export DomoticzIP=$(hostname -I|sed 's/[ ]*$//')
export DomoticzIP="127.0.0.1"
export DomoticzPort="8080"
export DomoticzUsername=""                # Can be left blank if you are not using security 
export DomoticzPassword=""
export TempFileDir="/var/tmp/"            # If you use dtgbot then just add the four lines
export SmappeeClientSecret="yNb3c47PfW"   # Request a client_secret by sending an email to support(AT)smappee.com
export SmappeeClientID="YourName"         # Request a client_id by sending an email to support(AT)smappee.com
export SmappeeUsername="username"         # Your Smappee username
export SmappeePassword="password"         # Your Smappee password
export SmappeeHousehold="Household1"      # Domoticz Household Energy Name
export SmappeeSolar="Solar1"              # Domoticz Solar Energy Name

And set it to be executable:

sudo chmod +x /etc/profile.d/DomoticzData.sh

This single file avoids you having to customise the Lua program.
Setting Up Domoticz for smappee.lua

Create household and solar energy meters in Domoticz with the names set in the environment variables SmappeeHousehold and SmappeeSolar.

To create one energy meter - Go to Setup - Hardware - Dummy - Create Virtual Centre - Electric (Instant + Counter), this will added to devices, so go to Setup - Devices - select the new device and give it the correct name to add it to Utility tab.

Then create 4 user string variables all containing the single number one - 1 : Setup - More Options - User Variables : SmappeeAccessToken, SmappeeRefreshToken, SmappeeExpiresAt, SmappeeTimeStamp - these are used by smappee.lua to avoid having to request a new authorisation token every 5 minutes.
Installing Smappee Program

The smappee program is now on github, so the program is installed using git, along with a bash script, which is made executable and then added to cron so that data is collected from Smappee every 5 minutes and transferred into Domoticz:

cd ~
# This will create the domoticz_smappee directory
git clone https://github.com/steps39/domoticz_smappee.git
cd domoticz_smappee
# Make sure the script is executable
sudo chmod +x smappee.sh
# Make the program run every 5 minutes
sudo crontab -e

Add this single line to cron:

*/5  * * * * /home/pi/domoticz_energy/smappee.sh

Then save this (ctrl o) and exit (ctrl x).

Assuming all the steps have been completed then smappee.lua is now running once every 5 minutes.
Checking Functioning

If smappee.lua is running properly, then smappee.log will have been created and data will be uploaded to Domoticz.

Wait 5 minutes and data should have appeared in Domoticz, on at least one of the virtual energy meters.

Check smappee.log which will have been created if smappee.lua has excuted.

If there is a problem with the program, then smappee.log.errors will have been created. 