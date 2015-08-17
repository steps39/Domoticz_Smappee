-- ~/energy/Smappee.lua

function print_to_log(logmessage)
  print(os.date("%Y-%m-%d %H:%M:%S")..' - '..tostring(logmessage))
end

function domoticzdata(envvar)
  -- loads get environment variable and prints in log
  localvar = os.getenv(envvar)
  if localvar ~= nil then
    print_to_log(envvar..": "..localvar)
  else
    print_to_log(envvar.." not found check /etc/profile.d/DomoticzData.sh")
  end
  return localvar
end

function checkpath(envpath)
  if string.sub(envpath,-2,-1) ~= "/" then
    envpath = envpath .. "/"
  end
  return envpath
end

function variable_list()
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type=command&param=getuservariables"
  jresponse = nil
  domoticz_tries = 1
  -- Domoticz seems to take a while to respond to getuservariables after start-up
  -- So just keep trying after 1 second sleep
  while (jresponse == nil) do
    print_to_log ("JSON request <"..t..">");
    jresponse, status = http.request(t)
    if (jresponse == nil) then
      socket.sleep(1)
      domoticz_tries = domoticz_tries + 1
      if domoticz_tries > 100 then
        print_to_log('Domoticz not sending back user variable list')
        break
      end
    end
  end
  print_to_log('Domoticz returned getuservariables after '..domoticz_tries..' attempts')
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

function idx_from_variable_name(DeviceName)
  local idx, k, record, decoded_response
  decoded_response = variable_list()
  result = decoded_response["result"]
  for k,record in pairs(result) do
    if type(record) == "table" then
      if string.lower(record['Name']) == string.lower(DeviceName) then
        print_to_log(record['idx'])
        idx = record['idx']
      end
    end
  end
  return idx
end

function get_variable_value(idx)
  local t, jresponse, decoded_response
  t = server_url.."/json.htm?type=command&param=getuservariable&idx="..tostring(idx)
  print_to_log ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  print_to_log('Decoded '..decoded_response["result"][1]["Value"])
  return decoded_response["result"][1]["Value"]
end

function set_variable_value(idx,name,value)
  local t, jresponse, decoded_response
  t = server_url.."/json.htm?type=command&param=updateuservariable&idx="..idx.."&vname="..name.."&vtype=2&vvalue="..tostring(value)
  print_to_log ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  return
end

function device_list(DeviceType)
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type="..DeviceType.."&order=name"
  print_to_log ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

function idx_from_name(DeviceName,DeviceType)
  local idx, k, record, decoded_response
  decoded_response = device_list(DeviceType)
  result = decoded_response["result"]
  for k,record in pairs(result) do
    if type(record) == "table" then
      if string.lower(record['Name']) == string.lower(DeviceName) then
        print_to_log(record['idx'])
        idx = record['idx']
      end
    end
  end
  return idx
end

function retrieve_Domoticz_variable(DomoticzName)
-- Get stored variable from Domoticz
  dvidx = idx_from_variable_name(DomoticzName)
  if dvidx == nil then
    print_to_log(DomoticzName ..' user variable does not exist in Domoticz')
    os.exit()
  else
    print_to_log(DomoticzName..' idx '..dvidx)
  end
  dv = get_variable_value(dvidx)
  return dvidx, dv
end       

function store_Domoticz_Variable(DomoticzName,DomoticzValue)
-- Update variable in Domoticz
  dvidx = idx_from_variable_name(DomoticzName)
  if dvidx == nil then
    print_to_log(DomoticzName ..' user variable does not exist in Domoticz')
    os.exit()
  else
    print_to_log(DomoticzName..' idx '..dvidx)
  end
  dv = set_variable_value(dvidx,DomoticzName,DomoticzValue)
  return dvidx
end

print_to_log ("-------------------------------------------")
print_to_log ("Starting Smappee to Domoticz Energy Handler")
print_to_log ("-------------------------------------------")

-- All these values are set in /etc/profile.d/DomoticzData.sh
SmappeeClientSecret = domoticzdata("SmappeeClientSecret")   -- Request a client_secret by sending an email to support(AT)smappee.com
SmappeeClientID = domoticzdata("SmappeeClientID")           -- Request a client_id by sending an email to support(AT)smappee.com
SmappeeUsername = domoticzdata("SmappeeUsername")              -- Your Smappee username
SmappeePassword = domoticzdata("SmappeePassword")              -- Your Smappee password
DomoticzUsername = domoticzdata("DomoticzUsername")            -- Domoticz username
DomoticzPassword = domoticzdata("DomoticzPassword")            -- Domoticz password
DomoticzIP = domoticzdata("DomoticzIP")
DomoticzPort = domoticzdata("DomoticzPort")
SmappeeHousehold = domoticzdata("SmappeeHousehold")
SmappeeSolar = domoticzdata("SmappeeSolar")

-- Load necessary Lua libraries
http = require "socket.http";
socket = require "socket";
https = require "ssl.https";
ltn12 = require('ltn12')
JSON = require "JSON";

SmappeeURL = "https://app1pub.smappee.net/dev/v1/"
server_url = "http://"..DomoticzIP..":"..DomoticzPort

NameSmappeeAccessToken = 'SmappeeAccessToken'
NameSmappeeRefreshToken = 'SmappeeRefreshToken'
NameSmappeeExpiresAt = 'SmappeeExpiresAt'

function get_energy_level(DeviceName)
  idx = idx_from_name(DeviceName,'devices')
  if idx == nil then
    return DeviceName, -999, -999, 0
  end
-- Determine Energy level
  t = server_url.."/json.htm?type=devices&rid=" .. idx
  print_to_log ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  result = decoded_response["result"]
  record = result[1]
  Energy = tonumber(string.match (record["Data"], "%d*%.?%d+"))
  Power = tonumber(string.match (record["Usage"], "%d*%.?%d+"))
  LastUpdate = record["LastUpdate"]
  DeviceName = record["Name"]
  return idx, Energy, Power, LastUpdate;
end

function energy(DeviceName)
  local response = ""
  DeviceIdx, Energy, Power, LastUpdate = get_energy_level(DeviceName)
  if Energy == -999 then
    print_to_log(DeviceName..' does not exist')
    return 1, DeviceName..' does not exist'
  end
  print_to_log(DeviceName .. ' Cumulative energy consumption is ' .. Energy .. 'Kwh, Current Power is '..Power.. 'watts')
  return status, Energy, Power, DeviceIdx;
end

function smappee_process_authentication(responseToDecode, NameSmappeeAccessToken, NameSmappeeRefreshToken, NameSmappeeExpiresAt)
--print(response)
  print('hello')
  decoded_response = JSON:decode(responseToDecode)
  print('hello1')
  smappee_access_token = decoded_response['access_token']
  print_to_log('Smappee Access Token: '..smappee_access_token)
  store_Domoticz_Variable(NameSmappeeAccessToken, smappee_access_token)
  smappee_refresh_token = decoded_response['refresh_token']
  print('hello2')
  print_to_log('Smappee Refresh Token: '..smappee_refresh_token)
  store_Domoticz_Variable(NameSmappeeRefreshToken, smappee_refresh_token)
  smappee_token_expires_in = decoded_response['expires_in']
  print('hello3')
  print_to_log('Smappee Token Expires In: '..smappee_token_expires_in)
  store_Domoticz_Variable(NameSmappeeExpiresAt, tonumber(smappee_token_expires_in)+os.time()-1)
  print('hello4')
  return smappee_access_token, smappee_refresh_token, smappee_token_expires_in
end

function smappee_authenticate(AuthenticateType, refresh_token, NameSmappeeAccessToken, NameSmappeeRefreshToken, NameSmappeeExpiresAt)
  -- Request authentication token
  attempt = 0
  repeat
    if AuthenticateType == "Refresh" then
      response, status = https.request(SmappeeURL.."oauth2/token?grant_type=refresh_token&refresh_token="..refresh_token.."&client_id="..SmappeeClientID.."&client_secret="..SmappeeClientSecret)
      print_to_log(SmappeeURL.."oauth2/token?grant_type=refresh_token&refresh_token="..refresh_token.."&client_id="..SmappeeClientID.."&client_secret="..SmappeeClientSecret)
    else
      response, status = https.request(SmappeeURL.."oauth2/token?grant_type=password&client_id="..SmappeeClientID.."&client_secret="..SmappeeClientSecret.."&username="..SmappeeUsername.."&password="..SmappeePassword)
      print_to_log(SmappeeURL.."oauth2/token?grant_type=password&client_id="..SmappeeClientID.."&client_secret="..SmappeeClientSecret.."&username="..SmappeeUsername.."&password="..SmappeePassword)
    end
    attempt = attempt + 1
    if Refresh then
      print_to_log('Refresh authentication status '..status)
    else
      print_to_log('Authentication status '..status)
    end
  until (status == 200) or (attempt>5)
  if status ~= 200 then
    if Refresh then
      print_to_log('Refresh authentication request not answered')
      -- Try to get a new authtentication
      return smappee_authenticate("New", refresh_token, NameSmappeeAccessToken, NameSmappeeRefreshToken, NameSmappeeExpiresAt)
    else
      print_to_log('Authentication request not answered')
      os.exit()
    end
  else
    if response == nil then
      print_to_log('Empty authentication token returned')
      os.exit()
    else
      access_token, refresh_token, token_expires_in = smappee_process_authentication(response, NameSmappeeAccessToken, NameSmappeeRefreshToken, NameSmappeeExpiresAt)
      return access_token, refresh_token, token_expires_in
    end
  end
end

-- Retrieve the authentication data from Domoticz
ATidx, smappee_access_token=retrieve_Domoticz_variable(NameSmappeeAccessToken)
RTidx, smappee_refresh_token=retrieve_Domoticz_variable(NameSmappeeRefreshToken)
EIidx, smappee_token_expires_at=retrieve_Domoticz_variable(NameSmappeeExpiresAt)
smappee_token_expires_at = tonumber(smappee_token_expires_at)

-- Get a new token if the old token has expired
if (os.time() > smappee_token_expires_at) then
  print_to_log('Token Expired')
  smappee_access_token, smappee_refresh_token, smappee_token_expires_at = smappee_authenticate("Refresh", smappee_refresh_token, NameSmappeeAccessToken, NameSmappeeRefreshToken, NameSmappeeExpiresAt)
  print_to_log('New token '..smappee_access_token)
end

t = {}
--smappee_access_token = 1
attempt = 0
repeat
-- Get Service Location number
  stuff, status, response = https.request{url = SmappeeURL.."servicelocation", headers = {["authorization"] = "Bearer "..smappee_access_token}, source=ltn12.source.string(""), sink = ltn12.sink.table(t), method = 'GET'}
  attempt = attempt + 1
  print(status)
  if status == 401 then
    --if os.time() > smappee_token_expires_at then
    smappee_access_token, smappee_refresh_token, smappee_token_expires_in = smappee_authenticate("Refresh", smappee_refresh_token, NameSmappeeAccessToken, NameSmappeeRefreshToken, NameSmappeeExpiresAt)
    print_to_log('New token '..smappee_access_token)
    -- Need to set status to something other than 200 otherwise could get out without a service location
    status = 401
    --end
  end
until (status == 200) or (attempt>5)

if status ~= 200 then
  print_to_log('Service location request not answered')
else
  if t == nil then
    print_to_log('Empty service location returned')
  else
--    print_to_log(t[1])
    decoded_response = JSON:decode(t[1])
    smappee_service_locations = decoded_response["serviceLocations"]
    smappee_service_location = smappee_service_locations[1]["serviceLocationId"]
    print_to_log('Smappee Service Location: '..smappee_service_location)
    -- Read in time last read in seconds and add 1 second to avoid picking up previous data
    STidx, smappee_start_time=retrieve_Domoticz_variable('SmappeeTimeStamp')
    -- When first set up need to avoid retrieving too much data, so set last measurement as 400 second ago 
    if smappee_start_time == 1 then
      smappee_start_time = os.time() - 400
    end
    smappee_start_time=tonumber(smappee_start_time) + 1
    print_to_log('Previous Time Stamp '..smappee_start_time)
    -- Get UTC time in seconds
    smappee_end_time = os.time()
    print_to_log('Current Time Stamp: '..smappee_end_time)
    t = {}

    -- Get Consumption
    newurl = SmappeeURL.."servicelocation/"..smappee_service_location.."/consumption?aggregation=1&from="..tostring(smappee_start_time).."000&to="..tostring(smappee_end_time).."000"
    print_to_log(newurl)
    stuff, status, response = https.request{url = newurl, headers = {["authorization"] = "Bearer "..smappee_access_token}, source=ltn12.source.string(""), sink = ltn12.sink.table(t), method = 'GET'}
    print_to_log(status)
    smappee_consumption = 0
    smappee_solar = 0
    if status ~= 200 then
      print_to_log('Consumptions not returned')
    else
      if t == nil then
        print_to_log('Empty consumptions returned')
      else
--    print(t[1])
        decoded_response = JSON:decode(t[1])
--    print(decoded_response)
--    for i,v in ipairs(decoded_response) do
--      print(i)
--    end
        smappee_consumptions = decoded_response["consumptions"]
        smappee_number_consumptions = #smappee_consumptions
        print_to_log('Length consumptions '..smappee_number_consumptions)
        if smappee_number_consumptions > 0 then
          -- Get old readings from Domoticz
          status, HouseholdEnergy, HouseholdPower, HouseholdIdx = energy(SmappeeHousehold)
          status, SolarEnergy, SolarPower, SolarIdx = energy(SmappeeSolar)
          -- Energies returned in kWh from Domoticz so convert to Wh
          HouseholdEnergy = HouseholdEnergy * 1000
          SolarEnergy = SolarEnergy * 1000
          consumptions_processed = 0
          for i,consumption in ipairs(smappee_consumptions) do 
            -- Don't use data that has already been processed
            smappee_timestamp = consumption["timestamp"]
            if smappee_timestamp > smappee_start_time*1000 then
              consumptions_processed = consumptions_processed + 1
              smappee_consumption = consumption["consumption"]
              HouseholdEnergy = HouseholdEnergy + smappee_consumption
              --print('Smappee Consumption: '..smappee_consumption)
              smappee_solar = consumption["solar"]
              SolarEnergy = SolarEnergy + smappee_solar
              --print('Smappee Solar: '..smappee_solar)
              smappee_alwaysOn = consumption["alwaysOn"]
              --print('Smappee Always On: '..smappee_alwaysOn)
              print_to_log('Processing timestamp: '..smappee_timestamp)
            else
              print_to_log('Skipping timestamp: '..smappee_timestamp)
              smappee_consumption = 0
            end
          end
          if consumptions_processed > 0 then
            print_to_log('Consumptions Processed '..consumptions_processed)
            -- Calculate new values to send to Domoticz
            -- Sum of 5 minutes in Wh so average power is 60/5 x
            HouseholdPower = smappee_consumption * 12
            print_to_log('Household: '..HouseholdPower..':'..HouseholdEnergy)
            t = server_url.."/json.htm?type=command&param=udevice&idx="..HouseholdIdx.."&nvalue=0&svalue="..tostring(HouseholdPower)..";"..tostring(HouseholdEnergy)
            print_to_log ("JSON request <"..t..">");
            jresponse, status = http.request(t)
            -- Only send back a 0 solar power value if previous solar power was not 0
            if not (SolarPower == 0 and smappee_solar == 0)  then
              SolarPower = smappee_solar * 12
              print_to_log('Solar: '..SolarPower..':'..SolarEnergy)
              t = server_url.."/json.htm?type=command&param=udevice&idx="..SolarIdx.."&nvalue=0&svalue="..tostring(SolarPower)..";"..tostring(SolarEnergy)
              print_to_log ("JSON request <"..t..">");
              jresponse, status = http.request(t)
            end
            -- Set timestamp in Domoticz to last timestamp retrieved to ensure no double counting
            smappee_timestamp = tostring(math.floor(smappee_timestamp/1000))
            set_variable_value(STidx,'SmappeeTimestamp',tostring(smappee_timestamp))
            print_to_log('Setting SmappeeTimestamp '..tostring(smappee_timestamp))
          else
            print_to_log('Nothing new so nothing to return to Domoticz')
          end
        end
      end
    end
  end
end
