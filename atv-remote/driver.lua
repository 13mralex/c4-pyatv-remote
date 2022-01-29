require "json"
JSON=(loadstring(json.JSON_LIBRARY_CHUNK))()

do	--Globals
	OPC = OPC or {}
	EC = EC or {}
	MSP = {}
	PYATV = {}
	artwork_info = {}
	g_data = {}
	Timer = Timer or {}
	playstate = ""
	already_started = "no"
	device_array = {}
	device_list = {}
	device_list["state"] = "initial"
	device_id = {}
	current_pairing_device = {}
	init = "fresh"
	oldDashboardInfo = {}

	MSP_PROXY = 5001
	PASSTHROUGH_PROXY = 5001		-- set this to the proxy ID that should handle all passthrough commands from minidrivers
	SWITCHER_PROXY = 5002			-- set this to the proxy ID of the SET_INPUT capable device that has the RF_MINI_APP connections
	USES_DEDICATED_SWITCHER = true	-- set this to false if the driver did not need the dedicated avswitch proxy (e.g. this is a TV/receiver)
	MINIAPP_BINDING_START = 3101	-- set this to the first binding ID in the XML for the RF_MINI_APP connections
	MINIAPP_BINDING_END = 3125		-- set this to the last binding ID in the XML for the RF_MINI_APP connections
	MINIAPP_TYPE = 'APPLE_TV'		-- set this to your unique name as defined in the minidriver SERVICE_IDS table

	CMDS = {
		UP 				= 'up',
		DOWN 			= 'down',
		LEFT 			= 'left',
		RIGHT 			= 'right',
		ENTER 			= 'select',
		START_UP 			= 'up',
		START_DOWN 		= 'down',
		START_LEFT 		= 'left',
		START_RIGHT 		= 'right',
		STOP_UP 			= 'up',
		STOP_DOWN 		= 'down',
		STOP_LEFT 		= 'left',
		STOP_RIGHT 		= 'right',
		PLAY 			= 'play',
		PAUSE 			= 'pause',
		PLAYPAUSE			= 'play',
		STOP 			= 'stop',
		SCAN_FWD 			= 'next',
		SCAN_REV 			= 'previous',
		SKIP_FWD 			= 'next',
		SKIP_REV 			= 'previous',
		START_SCAN_FWD 	= 'next',
		START_SCAN_REV 	= 'previous',
		STOP_SCAN_FWD 		= 'next',
		STOP_SCAN_REV 		= 'previous'
	}

	APP_LIST = {} --- For dynamic app list pulled from PyATV :)
	APP_SELECT = {} --- For app loading in Actions menu 

	-----------------------------------------------------------------------------------------------
	--------- PRE-DEFINED MINI APP DRIVER NAMES THAT THE DYNAMIC LIST DOESNT MAP PROPERLY ---------
	------------------------------- ADD MORE IN AS YOU FIND THEM ----------------------------------
	-----------------------------------------------------------------------------------------------
	APPLE_TV = { 
		['Apple TV']			= 'com.apple.TVWatchList', -- Returned as "TV" from ATV App List
		['Disney Plus']		= 'com.disney.disneyplus', -- Returned as "Disney+" from ATV App List
		['Amazon Prime Video']	= 'com.amazon.aiv.AIVApp', -- Returned as "Prime Video" from ATV App List
		['ABC iView']			= 'au.net.abc.ABCiView',   -- Returned as "ABC iview" from ATV App List
		['TenPlay']			= 'com.networkten.epg',    -- Returned as "10 play" from ATV App List
		['Hulu']				= 'com.hulu.plus',
		['YouTube']			= 'com.google.ios.youtube',
	} --['C4 Mini App Name']    = 'ATV App ID'             -- ATV App List output to Lua Output window by turning on Debug Mode and run Test Connection in actions.
	
	APPLE_BUNDLES = {}
	APPLE_BUNDLES["name"] = {
	   ["com.apple.Arcade"]			= "Apple Arcade",
	   ["com.apple.TVAppStore"]		= "App Store",
	   ["com.apple.TVHomeSharing"]	= "Home Sharing",
	   ["com.apple.TVMovies"]		= "iTunes Movies",
	   ["com.apple.TVMusic"]			= "Apple Music",
	   ["com.apple.TVPhotos"]		= "Photos",
	   ["com.apple.podcasts"]		= "Apple Podcasts",
	   ["com.apple.TVSearch"]		= "Search",
	   ["com.apple.TVSettings"]		= "Settings",
	   ["com.apple.TVWatchList"]		= "Apple TV+",
	   ["com.apple.TVShows"]			= "iTunes Shows",
     }
	APPLE_BUNDLES["iOS Bundle"] = {
	   ["com.apple.TVMusic"]			= "com.apple.Music",
	   ["com.apple.TVSearch"]		= "com.apple.tv",
	   ["com.apple.TVWatchList"]		= "com.apple.tv",
	   ["com.apple.TVShows"]			= "com.apple.tv",
     }

end

function dbg (strDebugText, ...)
	if (DEBUGPRINT) then print (os.date ('%x %X : ')..(strDebugText or ''), ...) end
end

function PYATV.ScanDevices () -- ORIGINAL: scan_devices
    print ("---Scan Devices---")
    url = Properties["Server IP"]..":"..Properties["Server Port"].."/scan"
    dbg ("URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				--print ("Start ReceivedAsync")
				array = JSON:decode(strData)
				device_list = array["devices"]
				devices = ""
				num = 0
				print ("---Devices Found---")
				for k, v in pairs(array["devices"]) do
					for x, y in pairs(v["services"]) do
						p2 = PYATV.ConvertProtocol(y["protocol"])
						if (p2 == "Companion") then
							name = v["name"]
							id = v["identifier"]
							num = v
							devices = devices..name..","
							device_id[name] = k
							print (name)
							print ("..ID: "..id)
							print (".."..p2..": "..y["port"])
						end
					end
				end
				print ("---Scan Complete---")
				devices = devices:sub(1, -2)
				device_list["state"] = "scanned"
				C4:UpdatePropertyList("Device Selector", devices)
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.BeginPairing (name)  -- ORIGINAL: pair
	print ("---Begin Pairing---")
	if (device_list["state"]=="initial") then
		print("Scanning not complete, please re-scan for devices.")
	else
		protocols = ""
		x = device_id[name]
		id = device_list[x]["identifier"]
		current_pairing_device["name"] = name
		current_pairing_device["id"] = id
		print (name.." ID: "..id)
		C4:UpdateProperty("Device ID", id)
		for k,v in pairs(device_list[x]["services"]) do
			protocol = PYATV.ConvertProtocol(v["protocol"])
			if (protocol == "RAOP") then
				-- do nothing for RAOP. Only after AirPlay and Companion protocols.
			else
				protocols = protocols..protocol..","
			end
		end
		protocols = protocols:sub(1, -2)
		--print ("Protocols: "..dump(protocols))
		C4:UpdatePropertyList("Protocol to Pair", protocols)
	end
end

function PYATV.PairProtocol (protocol)  -- ORIGINAL: pair2
	print ("---Pairing with Protocol---")
	name = current_pairing_device["name"]
	id = current_pairing_device["id"]
	current_pairing_device["protocol"] = protocol
	print ("Begin protocol "..protocol.." pairing for "..name.." ("..id..")")
	url = Properties["Server IP"]..":"..Properties["Server Port"].."/pair/"..id.."/"..protocol
	dbg ("Calling URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				-- nothing to do
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.PairWithPIN (pin)  -- ORIGINAL: pair3
	print ("---Pairing With PIN---")
	name = current_pairing_device["name"] or ''
	id = current_pairing_device["id"] or ''
	protocol = current_pairing_device["protocol"] or ''
	if (id == "") and (protocol == "") and (name == "") then
		return --silently stop pairing with pin, something went wrong..
	end
	--print ("Sending PIN "..pin.." to "..name)
	url = Properties["Server IP"]..":"..Properties["Server Port"].."/pair/"..id.."/"..protocol.."/"..pin
	dbg ("URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				dbg ("Result: "..strData)
				array = JSON:decode(strData)
				dbg ("Result: "..array["status"])
				dbg ("---UPDATING "..array["protocol"].." Credentials".." TO value"..array["credentials"])
				dbg ("------")
				C4:UpdateProperty(array["protocol"].." Credentials", array["credentials"])
				C4:UpdateProperty("Pairing Code", "")
				C4:UpdateProperty("Protocol to Pair", "")
				PYATV.ConnectDevice()
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.ConnectDevice () -- ORIGINAL: connect_device
	print ("---Connect Device---")
	airplay_creds = Properties["AirPlay Credentials"] or nil
	companion_creds = Properties["Companion Credentials"] or nil
	name = Properties["Device Selector"] or nil
	id = Properties["Device ID"] or nil
	if (airplay_creds == "") and (companion_creds == "") then
		print("No credentials found")
		return
	end
	if (airplay_creds == "") then
		url = Properties["Server IP"]..":"..Properties["Server Port"].."/connect/"..id.."?companion="..companion_creds
	elseif (companion_creds == "") then
		url = Properties["Server IP"]..":"..Properties["Server Port"].."/connect/"..id.."?airplay="..airplay_creds
	else
		url = Properties["Server IP"]..":"..Properties["Server Port"].."/connect/"..id.."?airplay="..airplay_creds.."&companion="..companion_creds
	end
	print ("Connecting to "..name)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				print ("Result: "..strData)
				PYATV.GetAppList()
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.GetAppList ()
	dbg ("---Get App List---")
	if (Properties["Device ID"] == "") then
		print("Not connected to Device")
	end	
	url = Properties["Server IP"]..":"..Properties["Server Port"].."/app_list/"..Properties["Device ID"]
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				dbg ("App List Results: ")
				dbg (strData)
				array = JSON:decode(strData)
				for k, v in pairs(array["Apps"]) do
					APP_LIST[tostring(k)] = tostring(v)
				end
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.SendCommand (url) -- ORIGINAL: call_ip
	dbg ("---Send Command---")
	dbg ("URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				strData = strData or ''
				responseCode = responseCode or 0
				tHeaders = tHeaders or {}
				if (responseCode == 0) then
					print("FAILED retrieving: "..url.." Error: "..strError)
				end
				if (strData == "") then
					print("FAILED -- No Data returned")
				end
				if (responseCode == 200) then
					dbg ("SUCCESS retrieving: "..url.." Response: "..strData)
				end
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.RemoteCommand (cmd) -- ORIGINAL: remote
	dbg ("---Remote Command---")
	dbg ("CMD: "..cmd)
	url = Properties["Server IP"]..":"..Properties["Server Port"].."/remote_control/"..Properties["Device ID"].."/"..cmd
	dbg ("URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				strData = strData or ''
				responseCode = responseCode or 0
				tHeaders = tHeaders or {}
				if (responseCode == 0) then
					print("FAILED retrieving: "..url.." Error: "..strError)
				end
				if (strData == "") then
					print("FAILED -- No Data returned")
				end
				if (responseCode == 200) then
					dbg ("SUCCESS retrieving: "..url.." Response: "..strData)
				end
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.pollMediaInfo (source, navId, roomId, seq) --pollMediaInfo
	url = Properties["Server IP"]..":"..Properties["Server Port"].."/playing/"..Properties["Device ID"]
	dbg ("---Poll Media---")
	dbg ("URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				--array = ConvertToArray(strData)
				array = JSON:decode(strData)
				--if (array["title"]) then
				--	array["hash"] = C4:Base64Encode(array["title"])
				--end
				if (array["device_state"] ~= "idle") then
					imageURL = "http://"..Properties["Server IP"]..":"..Properties["Server Port"].."/art/"..Properties["Device ID"].."/art.png"
					array["ImageUrl"] = imageURL
					if (array["hash"] ~= nil) then
						array["image"] = C4:Base64Encode(imageURL.."?"..C4:Base64Encode(array["hash"]))
					end
				--else
				--	array["image"] = C4:Base64Encode("controller://driver/atv-remote/icons/default_cover_art.png")
				end
				if (array["app_id"]) then
				    --dbg ("---ID & Name Match: "..array["app"])
				    array["app"] = APPLE_BUNDLES["name"][array["app_id"]] or array["app"]
				    --dbg ("---ID & Name Change to: "..APPLE_BUNDLES["name"][array["app_id"]])
				end
				if (init == "new") then
					PYATV.preMakeImageList(array)
				end
				if (array["state"]) then
					array["device_state"] = array["state"]
				end
				if (source == "proxy") then
					dbg ("Media request from proxy")
					UpdateMediaInfo(array)
					UpdateQueue(array)
					UpdateDashboard(array,true)
					UpdateProgress(array)
				end
				if (device_array["hash"] == array["hash"]) then
					dbg ("Arrays equal, not updating")
				else
					dbg ("Arrays not equal, updating")
					if (init=="old") then
					   dbg ("init: "..init)
					   --dbg ("device array: "..device_array["title"].." array: "..array["title"])
				     else
					   dbg ("init: "..init)
				     end
					UpdateMediaInfo(array)
					UpdateQueue(array)
					UpdateDashboard(array,false)
				end
				if (device_array["position"] == array["position"]) then
					dbg ("Progress equal, not updating")
				else
					dbg ("Progress not equal, updating")
					UpdateProgress(array)
					UpdateDashboard(array,false)
				end
				device_array = array
				if (array["device_state"]) and (array["media_type"]) then
					C4:SetVariable("Play State", array["device_state"])
					C4:SetVariable("Media Type", array["media_type"])
				end
				if (array["app"]) then
				    C4:SetVariable("Service", array["app_id"])
				end
				dbg ("---Polling Complete---")
				init = "old"
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.preMakeImageList(array) -- ORIGINAL: preMakeImageList
	dbg ("---preMakeImageList---")
	url = Properties["Server IP"]..":"..Properties["Server Port"].."/art/"..Properties["Device ID"].."/stats"
	dbg ("URL: "..url)
	C4:urlGet(url, {}, false,
		function(ticketId, strData, responseCode, tHeaders, strError)
			if (strError == nil) then
				a = strData:match("',%s(.*)")
				if (a ~= nil) then
					b = a:match("',%s(.*)")
					c,d = b:match("([^,]+),([^,]+)")
					d = d:sub(1, -2)
					e = c:match("=(.*)")
					f = d:match("=(.*)")
					art_url = "http://"..Properties["Server IP"]..":"..Properties["Server Port"].."/art/"..Properties["Device ID"].."/art.png"
					art_url = art_url.."?"..C4:Base64Encode(array["hash"])
					artwork_info["width"] = e
					artwork_info["height"] = f
					artwork_info["url"] = art_url
				--else
				--     artwork_info["width"] = 512
				--	artwork_info["height"] = 512
				--	artwork_info["url"] = "controller://driver/atv-remote/icons/default_cover_art.png"
				end
			else
				print("C4:urlGet() failed: "..strError)
			end
		end
	)
end

function PYATV.ConvertProtocol (p) -- ORIGINAL: convertProtocol
    p2 = ""
    if (p == "mrp") then
        p2 = "MRP"
    elseif (p == "airplay") then
        p2 = "AirPlay"
    elseif (p == "companion") then
        p2 = "Companion"
    elseif (p == "raop") then
        p2 = "RAOP"
    elseif (p == "dmap") then
        p2 = "DMAP"
    else
        print("Protocol mismatch: "..p)
    end
    return p2
end

function PYATV.RefreshInterval (cmd) -- ORIGINAL: RefreshInterval
	dbg ("---Refresh Interval---")
	--timer0 = nil
	if (cmd == "start") then
		if (already_started == "no") then
			already_started = "yes"
		end
		C4:SetTimer(1000, function(timer)
			PYATV.pollMediaInfo()
			if (already_started == "no") then
				timer:Cancel()
				dbg ("Stopping timer.")
			end
		end, true)
		dbg ("Starting timer.")
	elseif (cmd == "stop") then
		already_started = "no"
		dbg ("Stopping timer.")
	else
	end
end

function ExecuteCommand (strCommand, tParams)
	tParams = tParams or {}
    if (DEBUGPRINT) then
        local output = {"--- ExecuteCommand", strCommand, "----PARAMS----"}
        for k, v in pairs(tParams) do
            table.insert(output, tostring(k).." = "..tostring(v))
        end
        table.insert(output, "---")
        print (table.concat(output, "\r\n"))
    end
    if (strCommand == "LUA_ACTION") then
        if (tParams.ACTION) then
            strCommand = tParams.ACTION
            tParams.ACTION = nil
        end
    end
    local success, ret
    strCommand = string.gsub(strCommand, "%s+", "_")
    if (EC and EC[strCommand] and type(EC[strCommand]) == "function") then
        success, ret = pcall(EC[strCommand], tParams)
    end
    if (success == true) then
        return (ret)
    elseif (success == false) then
        print ("ExecuteCommand Lua error: ", strCommand, ret)
    end
end

function EC.Launch_App (tParams)
	print ("---Launch App---")
	local id = tParams["App"]
	if (id) then
		print ("App ID: "..id)
		url = Properties["Server IP"]..":"..Properties["Server Port"].."/launch_app/"..Properties["Device ID"].."/"..id
		PYATV.SendCommand (url)
	end
end

function EC.ScanDevices (tParams)
	PYATV.ScanDevices()
end

function EC.TestConnection (tParams)
	PYATV.ConnectDevice()
end

function AppSelection (currentValue) 	-- CUSTOM_SELECT from Actions and Programming Action.
	for k,v in pairs(APP_SELECT) do APP_SELECT[k] = nil end -- clear table!
	for strAppName, strAppId in orderedPairs(APP_LIST) do
		table.insert(APP_SELECT, { text = strAppName, value = strAppId })
	end
	return APP_SELECT
end

function OnDriverDestroyed ()
	KillAllTimers()
end

function OnDriverInit ()
	PYATV.ConnectDevice()
	C4:AddVariable("Play State", "Not Playing", "STRING")
	C4:AddVariable("Media Type", "Not Playing", "STRING")
	C4:AddVariable("Service", "Not Playing", "STRING")
	init = "new"
end


function OnDriverLateInit ()
    KillAllTimers()
    if (C4.AllowExecute) then
        C4:AllowExecute(true)
    end
    C4:urlSetTimeout(10)
    --PYATV.preMakeImageList()
    PYATV.pollMediaInfo()
    for property, _ in pairs(Properties) do
        OnPropertyChanged(property)
    end
    if (USES_DEDICATED_SWITCHER) then
        HideProxyInAllRooms(SWITCHER_PROXY)
    end
    RegisterRooms()
end

function OnSystemEvent (event)
	local eventname = string.match (event, '.-name="(.-)"')
	if (eventname == 'OnPIP') then
		RegisterRooms()
	end
end

function OnWatchedVariableChanged (idDevice, idVariable, strValue)
	if (RoomIDs and RoomIDs [idDevice]) then
		local roomId = tonumber (idDevice)
		if (idVariable == 1000) then
			local deviceId = tonumber (strValue) or 0
			RoomIDSources [roomId] = deviceId
		end
	end
end

function OnPropertyChanged (strProperty)
	local value = Properties [strProperty]
	if (value == nil) then
		value = ''
	end
	if (DEBUGPRINT) then
		local output = {"--- OnPropertyChanged: "..strProperty, value}
		print (output)
	end
	local success, ret
	strProperty = string.gsub (strProperty, '%s+', '_')
	if (OPC and OPC [strProperty] and type (OPC [strProperty]) == 'function') then
		success, ret = pcall (OPC [strProperty], value)
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('OnPropertyChanged Lua error: ', strProperty, ret)
	end
end

function OPC.Debug_Mode (value)
	if (DEBUGPRINT) then
		DEBUGPRINT = false
	end
	if (value == 'On') then
		DEBUGPRINT = true
	end
end

function OPC.Device_Selector (value)
	if (Properties["AirPlay Credentials"] == "") or (Properties["Companion Credentials"] == "") then
		dbg ("Pairing..")
		PYATV.BeginPairing(value)
	else
		dbg ("Connecting..")
		PYATV.ConnectDevice()
	end
end

function OPC.Protocol_to_Pair (value)
	local credentials = value.." Credentials"
	dbg (credentials)
	if (Properties[credentials] == "") then
		PYATV.PairProtocol(value)
	else
		PYATV.ConnectDevice()
	end
end

function OPC.Pairing_Code (value)
	PYATV.PairWithPIN(value)
end

function OPC.On_Power_Off (value)
	if (value == 'Do Nothing') then
		CMDS.OFF = nil
	elseif (value == 'Home') then
		CMDS.OFF = 'top_menu'
	elseif (value == 'Back') then
		CMDS.OFF = 'cancel'
	elseif (value == 'Menu') then
		CMDS.OFF = 'menu'
	end
end

function OPC.On_Power_On (value)
	if (value == 'Do Nothing') then
		CMDS.ON = nil
	elseif (value == 'Home') then
		CMDS.ON = 'top_menu'
	elseif (value == 'Back') then
		CMDS.ON = 'cancel'
	elseif (value == 'Menu') then
		CMDS.ON = 'menu'
	end
end

function OPC.MENU_Button (value)
	if (value == 'Do Nothing') then
		CMDS.MENU = nil
	elseif (value == 'Home') then
		CMDS.MENU = 'top_menu'
	elseif (value == 'Back') then
		CMDS.MENU = 'cancel'
	elseif (value == 'Menu') then
		CMDS.MENU = 'menu'
	end
end

function OPC.GUIDE_Button (value)
	if (value == 'Do Nothing') then
		CMDS.GUIDE = nil
	elseif (value == 'Home') then
		CMDS.GUIDE = 'top_menu'
	elseif (value == 'Back') then
		CMDS.GUIDE = 'cancel'
	elseif (value == 'Menu') then
		CMDS.GUIDE = 'menu'
	end
end

function OPC.INFO_Button (value)
	if (value == 'Do Nothing') then
		CMDS.INFO = nil
	elseif (value == 'Home') then
		CMDS.INFO = 'top_menu'
	elseif (value == 'Back') then
		CMDS.INFO = 'cancel'
	elseif (value == 'Menu') then
		CMDS.INFO = 'menu'
	end
end

function OPC.CANCEL_Button (value)
	if (value == 'Do Nothing') then
		CMDS.CANCEL = nil
	elseif (value == 'Home') then
		CMDS.CANCEL = 'top_menu'
	elseif (value == 'Back') then
		CMDS.CANCEL = 'cancel'
	elseif (value == 'Menu') then
		CMDS.CANCEL = 'menu'
	end
end

function OPC.PVR_Button (value)
	if (value == 'Do Nothing') then
		CMDS.PVR = nil
	elseif (value == 'Home') then
		CMDS.PVR = 'top_menu'
	elseif (value == 'Back') then
		CMDS.PVR = 'cancel'
	elseif (value == 'Menu') then
		CMDS.PVR = 'menu'
	end
end

function OPC.STAR_Button (value)
	if (value == 'Do Nothing') then
		CMDS.STAR = nil
	elseif (value == 'Home') then
		CMDS.STAR = 'top_menu'
	elseif (value == 'Back') then
		CMDS.STAR = 'cancel'
	elseif (value == 'Menu') then
		CMDS.STAR = 'menu'
	end
end

function OPC.POUND_Button (value)
	if (value == 'Do Nothing') then
		CMDS.POUND = nil
	elseif (value == 'Home') then
		CMDS.POUND = 'top_menu'
	elseif (value == 'Back') then
		CMDS.POUND = 'cancel'
	elseif (value == 'Menu') then
		CMDS.POUND = 'menu'
	end
end

function ReceivedFromProxy (idBinding, strCommand, tParams)
	strCommand = strCommand or ''
	tParams = tParams or {}
	local args = {}
	if (tParams.ARGS) then
		local parsedArgs = C4:ParseXml(tParams.ARGS)
		for _, v in pairs(parsedArgs.ChildNodes) do
			args[v.Attributes.name] = v.Value
		end
		tParams.ARGS = nil
	end
	if (DEBUGPRINT) then
		local output = {"--- ReceivedFromProxy: "..idBinding, strCommand, "----PARAMS----"}
		for k, v in pairs(tParams) do table.insert(output, tostring(k).." = "..tostring(v)) end
		table.insert(output, "-----ARGS-----")
		for k, v in pairs(args) do table.insert(output, tostring(k).." = "..tostring(v)) end
		table.insert(output, "---")
		print (table.concat(output, "\r\n"))
	end
	if (idBinding == SWITCHER_PROXY and strCommand == 'PASSTHROUGH') then
		idBinding = PASSTHROUGH_PROXY
		strCommand = tParams.PASSTHROUGH_COMMAND
	end
	if (idBinding == MSP_PROXY) then
		if (strCommand == 'DEVICE_SELECTED') then
			PYATV.pollMediaInfo ("proxy")
			PYATV.RefreshInterval ("start")
			MSP.ON (idBinding, strCommand, tParams, args)
		elseif (strCommand == 'DEVICE_DESELECTED') then
			-- Device is no longer needed in the room
			PYATV.RefreshInterval ("stop")
		elseif (strCommand == 'GetDashboard') then
			-- A navigator has requested an update of the dashboard
			PYATV.pollMediaInfo ("proxy")
			return ('')
		elseif (strCommand == 'GetQueue') then
			-- A navigator has requested an update of the queue
			--UpdateQueue()
			PYATV.pollMediaInfo ("proxy")
			return ('')
		elseif (strCommand == 'ToggleRepeat') then
			-- Repeat button pressed on the Now Playing screen (ToggleRepeat defined as Command for the "Repeat" Action in XML)
			REPEAT = not (REPEAT)
			--UpdateQueue()
		elseif (strCommand == 'ToggleShuffle') then
			-- Shuffle button pressed on the now playing screen (ToggleShuffle defined as Command for the "Shuffle" Action in XML)
			SHUFFLE = not (SHUFFLE)
			--UpdateQueue()
		elseif (strCommand == 'OFF') then
			PYATV.RefreshInterval ("stop")
		end
		if (MSP[strCommand] ~= nil) and (type(MSP[strCommand])=='function') then
			MSP[strCommand] (idBinding, strCommand, tParams, args)
		end
	end
	if (idBinding == SWITCHER_PROXY) then
		if (strCommand == 'SET_INPUT') then
			local input = tonumber (tParams.INPUT)
			if (input >= MINIAPP_BINDING_START and input <= MINIAPP_BINDING_END) then
				-- Get the device ID of the proxy handling the miniapp switch on this driver
				local proxyDeviceId, _ = next (C4:GetBoundConsumerDevices (C4:GetDeviceID(), idBinding))
				-- Get the device ID of the minidriver proxy connected to the requested input on this driver
				local appProxyId = C4:GetBoundProviderDevice (proxyDeviceId, input)
				-- Get the device ID of the minidriver protocol connected to the minidriver proxy
				local appDeviceId = C4:GetBoundProviderDevice (appProxyId, 5001)
				-- get the details for the app for this kind of universal-minidriver-compatible type
				local appId = GetRelevantUniversalAppId (appDeviceId, MINIAPP_TYPE)
				local appName = GetRelevantUniversalAppId (appDeviceId, 'APP_NAME')
				local tValues = ""
				if (APP_LIST[appName]) then
					dbg ("PyATV Dynamic App ID found: "..APP_LIST[appName])
					tValues = { ['App'] = APP_LIST[appName] }
				elseif (APPLE_TV[appName]) then
					dbg ("Apple TV Pre-defined App ID found: "..APPLE_TV[appName])
					tValues = { ['App'] = APPLE_TV[appName] }
				else
					print ("No App ID found for Application: "..appName)
					return
				end
				ExecuteCommand ('Launch_App', tValues) -- utilize existing mini app drivers without modifications.
				if ((Properties ['Passthrough Mode'] or 'On') ~= 'On') then
					local passthroughProxyDeviceId, _ = next (C4:GetBoundConsumerDevices (C4:GetDeviceID(), PASSTHROUGH_PROXY))
					local _timer = function (timer)
						dbg ('Looking for '..appProxyId)
						for roomId, deviceId in pairs (RoomIDSources) do
							if (deviceId == appProxyId) then
								C4:SendToDevice (roomId, 'SELECT_VIDEO_DEVICE', {deviceid = passthroughProxyDeviceId})
							end
						end
					end
					C4:SetTimer (500, _timer)
				end
			end
		end
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('ReceivedFromProxy Lua error: ', idBinding, strCommand, ret)
	end
	if (tParams.SEQ and tParams.NAVID) then
		DataReceived(5001, tParams.NAVID, tParams.SEQ) -- this is something we'll be getting to in a future example - it's to do with providing data back to the UI on Navigator requests
	end
end

function GetRelevantUniversalAppId (deviceId, source)
	local vars = C4:GetDeviceVariables (deviceId)
	for _, var in pairs (vars) do
		if (var.name == source) then
			return (var.value)
		end
	end
	if (source ~= 'APP_ID') then
		-- try getting pre-universal minidriver app ID to launch.
		return (GetRelevantUniversalAppId (deviceId, 'APP_ID'))
	end
end

function HideProxyInAllRooms (idBinding)
	idBinding = idBinding or 0
	if (idBinding == 0) then return end -- silently fail if no binding passed in
	-- Get Bound Proxy's Device ID / Name.
	local id, name = next (C4:GetBoundConsumerDevices (C4:GetDeviceID(), idBinding))
	dbg ('Hiding '..name..' in all rooms')
	-- Send hide command to all rooms, for 'ALL' Navigator groups.
	for roomId, roomName in pairs (C4:GetDevicesByC4iName ('roomdevice.c4i') or {}) do
		dbg ('Hiding '..name..' in '..roomName)
		C4:SendToDevice (roomId, 'SET_DEVICE_HIDDEN_STATE', {PROXY_GROUP = 'ALL', DEVICE_ID = id, IS_HIDDEN = true})
	end
end

function RegisterRooms ()
	RoomIDs = C4:GetDevicesByC4iName ('roomdevice.c4i')
	RoomIDSources = {}
	for roomId, _ in pairs (RoomIDs) do
		RoomIDSources [roomId] = tonumber (C4:GetDeviceVariable (roomId, 1000)) or 0
		C4:UnregisterVariableListener (roomId, 1000)
		C4:RegisterVariableListener (roomId, 1000)
	end
end

function MSP.ON (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.OFF (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.MENU (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.GUIDE (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.INFO (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.CANCEL (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.PVR (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STAR (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.POUND (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.UP (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.DOWN (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.LEFT (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.RIGHT (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.ENTER (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.START_UP (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.START_DOWN (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.START_LEFT (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.START_RIGHT (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP_UP (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP_DOWN (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP_LEFT (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP_RIGHT (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.PLAY (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.PAUSE (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.PLAYPAUSE (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.SCAN_FWD (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.SCAN_REV (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.SKIP_FWD (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.SKIP_REV (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.START_SCAN_FWD (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.START_SCAN_REV (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP_SCAN_FWD (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function MSP.STOP_SCAN_REV (idBinding, strCommand, tParams, args)
	local pytvCommand = CMDS [strCommand]
	if (pytvCommand ~= nil) then
		PYATV.RemoteCommand (pytvCommand)
	end
end

function DataReceivedError (idBinding, navId, seq, msg)
	local tParams = {
		NAVID = navId,
		SEQ = seq,
		DATA = '',
		ERROR = msg,
	}
	C4:SendToProxy (idBinding, 'DATA_RECEIVED', tParams)
end

function DataReceived (idBinding, navId, seq, args)
    -- Returns data to a specific Navigator in response to a specific request made by Navigator.  Can't be triggered asynchronously, each seq request can only get one response.
    local data = ""
    if (type(args) == "string") then
        data = args
    elseif (type(args) == "boolean" or type(args) == "number") then
        data = tostring(args)
    elseif (type(args) == "table") then
        data = XMLTag(nil, args, false, false)
    else
        dbg ("arg type failed to match")
        data = args
    end
    local tParams = {
        NAVID = navId,
        SEQ = seq,
        DATA = data,
        EVTARGS = data
    }
    dbg ("----DATA RECEIVED-----")
    dbg ("--tParams: "..dump(tParams))
    dbg ("--------DONE----------")
    dbg ("DataRX args: "..dump(data))
    C4:SendToProxy(idBinding, "DATA_RECEIVED", tParams)
end

function SendEvent (idBinding, navId, roomId, name, args)
    -- Send an asyncronous notification to specific Navigator(s), specific Room(s) or all (nil value for navId and roomId).
    -- Used for DriverNotification, QueueChanged, DashboardChanged and ProgressChanged events
    local data = ""
    if (type(args) == "string") then
        data = args
    elseif (type(args) == "boolean" or type(args) == "number") then
        data = tostring(args)
    elseif (type(args) == "table") then
        data = XMLTag(nil, args, false, false)
    else
        dbg ("arg type failed to match")
        data = args
    end
    local tParams = {
        NAVID = navId,
        ROOMS = roomId,
        NAME = name,
        EVTARGS = data,
        QUEUEID = 10100
    }
    dbg ("----SEND EVENT-----")
    dbg ("--tParams: "..dump(tParams))
    dbg ("------DONE---------")
    C4:SendToProxy(idBinding, "SEND_EVENT", tParams, "COMMAND")
end

-- Update Navigator
function MakeImageList (iconInfo)
	--dbg ("MakeImageList Starting..")
	if (iconInfo == nil) then
		print("MakeImageList data nil, ending..")
		return
	end
    --local defaultItem = data["url"]
    defaultSizes = {512}
    image_list = {}
    w = iconInfo["width"]
    h = iconInfo["height"]
    if (h and w) then
	   h = tonumber(iconInfo["height"])
	   w = tonumber(iconInfo["width"])
	   
	   --print("INIT make image list... URL: "..iconInfo["url"].." width: "..w.." height: "..h)
	    if (iconInfo["url"]) and w and h then
		    --print("START Make image list...URL: "..iconInfo["url"])
		    --for _, size in ipairs(defaultSizes) do
			    imageUrl = iconInfo["url"].."?"..C4:Base64Encode(os.date ('%x %X : '))
			    width = w
			    height = h
			    table.insert (image_list, '<image_list width="'..width..'" height="'..height..'">'..imageUrl..'</image_list>')
		    --end
	    else
		  --print("FAIL Make image list...")
	    end
		--print("FINISH Make image list...")
	   return image_list
    else
	   return
    end
    
end

function UpdateDashboard (data, isForced)
    -- These are all 5 of the Id values of the Transport items from the Dashboard section of the XML
    
    local dashboardInfo = {}
    local possibleItems = {
        "Play",
        "Pause",
        "Stop",
        "SkipFwd",
        "SkipRev"
    }
    position = data["position"] or 0
    if (position == "none") then
	   position = 0
    end
    total_time = data["total_time"] or "none"
    live = false
    if (total_time) then
        if total_time ~= "none" then
            dbg ("Song is not live... Progress: "..position)
            live = false
            dbg (position.." --|-- "..total_time)
            label = ConvertTime(position - 0).." / -"..ConvertTime(total_time - position)
        else
            dbg ("Song is live... Progress: "..position)
            live = true
            label = "LIVE"
        end
    end
    if (live == true) and (data["device_state"] == "playing") then
        dashboardInfo = {
            Items = "Stop" -- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
        }
    elseif (live == true) and (data["device_state"] == "paused") then
        dashboardInfo = {
            Items = "Play" -- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
        }
    elseif (data["device_state"] == "playing") then
        dashboardInfo = {
            Items = "SkipRev Pause SkipFwd" -- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
        }
    else
        dashboardInfo = {
            Items = "SkipRev Play SkipFwd" -- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
        }
    end
    playstate = data["device_state"]
    --DataReceived(5001, navId, seq, dashboardInfo)
    
    if (dump(dashboardInfo) ~= dump(oldDashboardInfo)) then
	   SendEvent(5001, nil, nil, "DashboardChanged", dashboardInfo)
	   dbg("DBs not equal, updating")
	   --print("New DB: "..dump(dashboardInfo))
	   --print("Old DB: "..dump(oldDashboardInfo))
    else
	   dbg("DBs equal, not updating")
	   --print("New DB: "..dump(dashboardInfo))
	   --print("Old DB: "..dump(oldDashboardInfo))
    end
    
    if (isForced) then
	   SendEvent(5001, nil, nil, "DashboardChanged", dashboardInfo)
    end
    
    oldDashboardInfo = dashboardInfo
end

function UpdateMediaInfo (data, navId, roomId, seq)
    -- Updates the Now Playing area of the media bar and also the main section on the left of the Now Playing screen.  Doesn't affect the Queue side at all.
    
    local args = {
        TITLE = data["title"] or '',
        ALBUM = data["album"] or '',
        ARTIST = data["artist"] or '',
        GENRE = data["genre"] or '',
        IMAGEURL = data["image"] --or C4:Base64Encode('controller://driver/atv-remote/icons/default_cover_art.png')
    }
    
    if (data["app_id"] == "com.apple.TVAirPlay" and args["TITLE"] == "") then
	   args["TITLE"] = "AirPlay"
    end
    
    for k,v in pairs(args) do
	   if (v == "none") then
		  args[k] = nil
	   end
    end
    
    --if (data["image"] ~= nil) then
		--local decoded_img = C4:Base64Decode(data["image"])
		--print("Image: "..decoded_img)
	--end
    --DataReceived(5001, navId, seq, args)
    C4:SendToProxy(5001, "UPDATE_MEDIA_INFO", args, "COMMAND", true)
    --UpdateQueue(data,image)
end

function UpdateProgress (data, navId, roomId, seq)
    label = "Not playing"
    position = data["position"] or 0
    if (position == "none") then
	   position = 0
    end
    total_time = data["total_time"] or "none"
    live = false
    if (total_time) then
        if total_time ~= "none" then
            dbg ("Song is not live... Progress: "..position)
            live = false
            dbg (position.." --|-- "..total_time)
            label = ConvertTime(position - 0).." / -"..ConvertTime(total_time - position)
        else
            dbg ("Song is live... Progress: "..position)
            live = true
            label = "LIVE"
		  total_time = nil
		  position = nil
        end
    end
    --local duration = math.random (100, 500)
    --local elapsed = math.random (1, duration)
    --local label = ConvertTime (prog)..' / -'..ConvertTime (duration - elapsed)
    label0 = label
    local progressInfo = {
        length = total_time, -- integer for setting size of duration bar
        offset = position, -- integer for setting size of elapsed indicator inside duration bar
        label = label0 -- text string to be displayed next to duration bar
    }
    --DataReceived(5001, navId, seq, progressInfo)
    SendEvent(5001, nil, nil, "ProgressChanged", progressInfo)
end

function UpdateQueue (data, navId, roomId, seq)
	dbg ("UpdateQueue starting")
	if (data == nil) then
		print("UpdateQueue no data, exiting!")
		return
	end
    --prog = data["position"]
    local queue = {}
    duration = 0
    position = data["position"] or 0
    if (position == "none") then
	   position = 0
    end
    total_time = data["total_time"] or 0
    live = false
    if (total_time) then
        if total_time ~= "none" then
            dbg ("Song is not live... Progress: "..position)
            live = false
            dbg (position.." --|-- "..total_time)
            label = ConvertTime(position - 0).." / -"..ConvertTime(total_time - position)
		  duration = ConvertTime(total_time - 0)
        else
            dbg ("Song is live... Progress: "..position)
            live = true
            label = "LIVE"
		  duration = nil
        end
    end
    for k,v in pairs(data) do
	   if (v == "none") then
		  data[k] = nil
	   end
    end
    
    if (data["app_id"] == "com.apple.TVAirPlay") then
	   data["app_icon"] = "controller://driver/atv-remote/icons/airplay.png"
    end
    
	if next(data) then
	   i = 0
	    if (data["title"] or data["artist"]) then
		     i = i+1
		     queue[i] = {title = 'Now Playing', isHeader = true}
			i = i+1
			queue[i] = {title = data["title"], subtitle = data["artist"], duration = duration, ImageUrl = artwork_info["url"]}
	    end
	    
	    if data["app"] then
		     i = i+1
			queue[i] = {title = 'Service', isHeader = true}
			i = i+1
			
			if (data["app_id"] == "com.apple.TVAirPlay" and data["app"] ~= "AirPlay") then
			    queue[i] = {title = data["app"], subtitle = "AirPlay", ImageUrl = data["app_icon"]}
		     else
			    queue[i] = {title = data["app"], ImageUrl = data["app_icon"]}
		     end

	    end
     else
	   dbg ("data is nil, queue: "..dump(queue))
	end
	--print("APP ICON URL: "..data["app_icon"])
	--print("SONG ICON URL: "..data["ImageUrl"])
    local tags = {
        can_shuffle = true,
        can_repeat = true,
        shufflemode = (SHUFFLE == true),
        repeatmode = (REPEAT == true)
    }
    local list = {}
    if next(queue) then
	     --dbg("Queue not empty, = "..dump(queue))
	     icon = {}
	     icon["url"] = data["app_icon"]
		icon["width"] = 512
		icon["height"] = 512
	
		for _, item in ipairs(queue) do
			 
			 --if (item["title"] == nil) then
			 --	item["title"] = ""
			 --end
		
			 if (item["title"] == 'Now Playing') then
				table.insert(list, XMLTag("item", item))
			 end
			 if (item["title"] == data["title"]) then
				--print("make image list for Now Playing")
				item.image_list = MakeImageList(artwork_info)
				table.insert(list, XMLTag("item", item))
			 --else
				--dbg("Queue titles not equal... "..item["title"].." ~= "..data["title"])
			 end
			 if (item["title"] == 'Service') then
				table.insert(list, XMLTag("item", item))
			 end
			 if (item["title"] == data["app"]) then
				--print("make image list for App")
				item.image_list = MakeImageList(icon)
				table.insert(list, XMLTag("item", item))
			 end
		end
		

		list = table.concat(list)
		
		queueInfo = {
			List = list, -- The entire list that will be displayed for the queue
			NowPlayingIndex = 1, -- The item (0-indexed) that will be marked as current in the queue (blue marker on the Android navigators)
			NowPlaying = XMLTag(tags) -- The tags that will be applied to all ActionIds from the NowPlaying section of the XML to determine what actions are shown
		}

    else
		dbg ("queue is nil")
		
		queue = {
			{title = "Not Playing"}
		}
		
		for _, item in ipairs(queue) do
		  table.insert(list, XMLTag("item", item))
	     end
		
		list = table.concat(list)
		
		queueInfo = {
			List = list, -- The entire list that will be displayed for the queue
			NowPlayingIndex = 1, -- The item (0-indexed) that will be marked as current in the queue (blue marker on the Android navigators)
			NowPlaying = XMLTag(tags) -- The tags that will be applied to all ActionIds from the NowPlaying section of the XML to determine what actions are shown
		}
		
    end
    --DataReceived(5001, navId, seq, queueInfo)
	if (queueInfo) then
		SendEvent(5001, nil, nil, "QueueChanged", queueInfo)
		dbg ("Queue Done")
     else
	   dbg ("queueInfo is nil")
	end
end

-- Useful functions
function KillAllTimers ()
    for name, timer in pairs(Timer) do
        if (type(timer) == "userdata") then
            timer:Cancel()
        end
        Timer[name] = nil
    end
end

function ConvertToArray (data) -- ORIGINAL: convert_to_array
	arr1 = {}
    for line in data:gmatch("([^\n]*)\n?") do
        if (line ~= "") then
			a, b = line:match("%s+(.-):%s(.+)")
			if (a) and (b) then
				arr1[a] = b
			end
        else
        end
    end
    return arr1
end

function __genOrderedIndex(t)
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex, cmp_multitype )
    return orderedIndex
end

function orderedNext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    return orderedNext, t, nil
end

function dump (o)
   if type(o) == 'table' then
	  local s = '{ '
	  for k,v in pairs(o) do
		 if type(k) ~= 'number' then k = '"'..k..'"' end
		 s = s..'['..k..'] = '..dump(v)..','
	  end
	  return s..'} '
   else
	  return tostring(o)
   end
end

function XMLDecode (s)
	if (s == nil) then return end
	s = string.gsub (s, '%<%!%[CDATA%[(.-)%]%]%>', function (a) return (a) end)
	s = string.gsub (s, '\&quot\;'	, '"')
	s = string.gsub (s, '\&lt\;'	, '<')
	s = string.gsub (s, '\&gt\;'	, '>')
	s = string.gsub (s, '\&apos\;'	, '\'')
	s = string.gsub (s, '&#x(.-);', function (a) return string.char (tonumber (a, 16) % 256) end )
	s = string.gsub (s, '&#(.-);', function (a) return string.char (tonumber (a) % 256) end )
	s = string.gsub (s, '\&amp\;'	, '&')
	return s
end

function XMLEncode (s)
	if (s == nil) then return end
	s = string.gsub (s, '&', '\&amp\;')
	s = string.gsub (s, '"', '\&quot\;')
	s = string.gsub (s, '<', '\&lt\;')
	s = string.gsub (s, '>', '\&gt\;')
	s = string.gsub (s, "'", '\&apos\;')
	return s
end

function XMLTag (strName, tParams, tagSubTables, xmlEncodeElements)
	local retXML = {}
	if (type (strName) == 'table' and tParams == nil) then
		tParams = strName
		strName = nil
	end
	if (strName) then
		table.insert (retXML, '<')
		table.insert (retXML, tostring (strName))
		table.insert (retXML, '>')
	end
	if (type (tParams) == 'table') then
		for k, v in pairs (tParams) do
			if (v == nil) then v = '' end
			if (type (v) == 'table') then
				if (k == 'image_list') then
					for _, image_list in pairs (v) do
						table.insert (retXML, image_list)
					end
				elseif (tagSubTables == true) then
					table.insert (retXML, XMLTag (k, v))
				end
			else
				if (v == nil) then v = '' end
				table.insert (retXML, '<')
				table.insert (retXML, tostring (k))
				table.insert (retXML, '>')
				if (xmlEncodeElements ~= false) then
					table.insert (retXML, XMLEncode (tostring (v)))
				else
					table.insert (retXML, tostring (v))
				end
				table.insert (retXML, '</')
				table.insert (retXML, string.match (tostring (k), '^(%S+)'))
				table.insert (retXML, '>')
			end
		end
	elseif (tParams) then
		if (xmlEncodeElements ~= false) then
			table.insert (retXML, XMLEncode (tostring (tParams)))
		else
			table.insert (retXML, tostring (tParams))
		end

	end
	if (strName) then
		table.insert (retXML, '</')
		table.insert (retXML, string.match (tostring (strName), '^(%S+)'))
		table.insert (retXML, '>')
	end
	return (table.concat (retXML))
end

function ConvertTime (data, incHours)
	-- Converts a string of [HH:]MM:SS to an integer representing the number of seconds
	-- Converts an integer number of seconds to a string of [HH:]MM:SS. If HH is zero, it is omitted unless incHours is true
	if (data == nil) then
		return (0)
	elseif (type (data) == 'number') then
		local strTime = ''
		local minutes = ''
		local seconds = ''
		local hours = string.format('%d', data / 3600)
		data = data - (hours * 3600)

		if (hours ~= '0' or incHours) then
			strTime = hours..':'
			minutes = string.format('%02d', data / 60)
		else
			minutes = string.format('%d', data / 60)
		end

		data = data - (minutes * 60)
		seconds = string.format('%02d', data)
		strTime = strTime..minutes..':'..seconds
		return strTime

	elseif (type (data) == 'string') then
		local hours, minutes, seconds = string.match (data, '^(%d-):(%d-):?(%d-)$')

		if (hours == '') then hours = nil end
		if (minutes == '') then minutes = nil end
		if (seconds == '') then seconds = nil end

		if (hours and not minutes) then minutes = hours hours = 0
		elseif (minutes and not hours ) then hours = 0
		elseif (not minutes and not hours) then minutes = 0 hours = 0 seconds = seconds or 0
		end

		hours, minutes, seconds = tonumber (hours), tonumber (minutes), tonumber (seconds)
		return ((hours * 3600) + (minutes * 60) + seconds)
	end
end
