JSON = require ('drivers-common-public.module.json')
WebSocket = require ('drivers-common-public.module.websocket')

do	--Globals
	OPC = OPC or {}
	EC = EC or {}
	MSP = {}
	PYATV = {}
	Timer = Timer or {}
	DeviceList = {}
	PairingDevice = {}
	USER_LIST = {}
	PRESETS = {}
	WS = nil
	init = "fresh"

	MSP_PROXY = 5001
	PASSTHROUGH_PROXY = 5001		-- set this to the proxy ID that should handle all passthrough commands from minidrivers
	SWITCHER_PROXY = 5002			-- set this to the proxy ID of the SET_INPUT capable device that has the RF_MINI_APP connections
	USES_DEDICATED_SWITCHER = true	-- set this to false if the driver did not need the dedicated avswitch proxy (e.g. this is a TV/receiver)
	MINIAPP_BINDING_START = 3101	-- set this to the first binding ID in the XML for the RF_MINI_APP connections
	MINIAPP_BINDING_END = 3125		-- set this to the last binding ID in the XML for the RF_MINI_APP connections
	MINIAPP_TYPE = 'APPLE_TV'		-- set this to your unique name as defined in the minidriver SERVICE_IDS table

	REMOTE_MAPPINGS = {
		values = {
			['Power On']	= 'turn_on',
			['Power Off']	= 'turn_off',
			['Do Nothing']	= nil,
			['Home']		= 'top_menu',
			['Menu']		= 'menu',
			['Dashboard']	= 'home_hold',
			['Screensaver']	= 'screensaver',
			['Play/Pause']	= 'play_pause',
		}
	}

	REMOTE_CMDS = {
		DEVICE_SELECTED = '', -- ON is not called on 'listen'
		OFF				= '',
		PVR				= 'screensaver',
		STAR			= '',
		POUND			= '',
		RECORD			= 'play_pause',
		UP 				= 'up',
		DOWN 			= 'down',
		LEFT 			= 'left',
		RIGHT 			= 'right',
		PULSE_CH_UP		= 'channel_up',
		PULSE_CH_DOWN	= 'channel_down',
		PLAY 			= 'play',
		PAUSE 			= 'pause',
		PLAYPAUSE		= 'play',
		STOP 			= 'stop',
		SCAN_FWD 		= 'skip_forward',
		SCAN_REV 		= 'skip_backward',
		SKIP_FWD 		= 'next',
		SKIP_REV 		= 'previous',
	}

	REMOTE_HOLD_CMDS = {
		MENU			= '',
		GUIDE			= '',
		INFO			= '',
		CANCEL			= '',
		ENTER 			= 'begin_select',
		START_UP 		= 'start_up',
		START_DOWN 		= 'start_down',
		START_LEFT 		= 'start_left',
		START_RIGHT 	= 'start_right',
		START_SCAN_FWD 	= 'start_skip_forward',
		START_SCAN_REV 	= 'start_skip_backward',
		END_MENU		= '',
		END_GUIDE		= '',
		END_INFO		= '',
		END_CANCEL		= '',
		END_ENTER		= 'end_select',
		STOP_UP 		= 'stop_up',
		STOP_DOWN 		= 'stop_down',
		STOP_LEFT 		= 'stop_left',
		STOP_RIGHT 		= 'stop_right',
		STOP_SCAN_FWD 	= 'stop_skip_forward',
		STOP_SCAN_REV 	= 'stop_skip_backward',
	}

	KEYBOARD_CMDS = {
		NUMBER_0		= '0',
		NUMBER_1		= '1',
		NUMBER_2		= '2',
		NUMBER_3		= '3',
		NUMBER_4		= '4',
		NUMBER_5		= '5',
		NUMBER_6		= '6',
		NUMBER_7		= '7',
		NUMBER_8		= '8',
		NUMBER_9		= '9',
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
		['Pandora']			= 'com.pandora',		  -- Returned as no name
	} --['C4 Mini App Name']    = 'ATV App ID'             -- ATV App List output to Lua Output window by turning on Debug Mode and run Test Connection in actions.

end

--WEBSOCKET

function PYATV.ConnectWebsocket()

    wsURL = "ws://"..Properties["Server Address"].."/ws/"..PersistData.DeviceID
	
	dbg("Starting Websocket: "..wsURL)
	
    if (WS) then
		WS:delete()
	end
	WS = WebSocket:new(wsURL)

	local pm = function(self, data)
		dbg('WS Message Received: ' .. data)
		PYATV.WSDataReceived(data)
	end

	local est = function(self)
		dbg('ws connection established')
	end

	local offline = function(self)
		dbg('ws connection offline')
		PYATV.ReconnetWebsocket()
	end

	local closed = function(self)
		dbg('ws connection closed by remote host')
		PYATV.ReconnetWebsocket()
	end

	WS:SetProcessMessageFunction(pm)
	WS:SetEstablishedFunction(est)
	WS:SetOfflineFunction(offline)
	WS:SetClosedByRemoteFunction(closed)

	WS:Start()

	--Run reconnect in case no connection on init
	PYATV.ReconnetWebsocket()

end

function PYATV.ReconnetWebsocket()
	dbg("Attempt WS reconnect in 5 seconds...")

	if (Timer.WS) then
		Timer.WS:Cancel()
	end

	Timer.WS = C4:SetTimer(5000, function(timer)
		if (WS.connected) then
			timer:Cancel()
		else
			dbg("WS reports not connected, trying again in 5 seconds...")
			PYATV.ConnectWebsocket()
		end
	end, true)
end

function PYATV.WSDataReceived(data)
    dbg("---WS Data received---")

    jsonData = JSON:decode(data)
	if (jsonData.connected == false) then
		PYATV.ReconnectDevice()
	else
    	PYATV.MediaCallback(jsonData,nil,"ws")
	end
end

--HELPERS

function dbg(strDebugText, ...)
	if (DEBUGPRINT) then print (os.date ('%x %X : ')..(strDebugText or ''), ...) end
end

function LoadProperties()
	local properties = {
		"On Power On",
		"On Power Off",
		"Debug Mode",
		"MENU Button",
		"GUIDE Button",
		"INFO Button",
		"CANCEL Button",
		"PVR Button",
		"STAR Button",
		"POUND Button",
		"RECORD Button",
	}

	for i,property in pairs(properties) do
        OnPropertyChanged(property)
    end
end

function PYATV.UpdateStatus(status)
	C4:UpdateProperty("Latest Status",status)
end

function PYATV.UrlCall(uri, callback, method, data, callbackData)
	dbg ("---URL Call---")
	method = method or "get"
	local baseUrl = Properties["Server Address"]
	local url = baseUrl..uri
	dbg ("URL "..method..": "..url)

	if (method=="get") then
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
						local jsonData = JSON:decode(strData)
						if (jsonData["status"]) then
							PYATV.UpdateStatus(jsonData["status"])
						elseif (jsonData["connected"]~=nil) then
							if (not jsonData["connected"]) then
								PYATV.ReconnectDevice()
							end
						end
						if (callback) then
							callback(jsonData,callbackData)
						end
					end
				else
					print("C4:urlGet() failed: "..strError)
				end
			end
		)
	elseif (method=="post") then
		local postData = JSON:encode(data)
		local headers = {
			["Content-Type"] = "application/json"
		}
		dbg("Post data:",postData)
		C4:urlPost(url, postData, headers, false,
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
						local jsonData = JSON:decode(strData)
						if (jsonData["status"]) then
							PYATV.UpdateStatus(jsonData["status"])
						elseif (jsonData["connected"]~=nil) then
							if (not jsonData["connected"]) then
								PYATV.ReconnectDevice()
							end
						end
						if (callback) then
							callback(jsonData,callbackData)
						end
					end
				else
					print("C4:urlGet() failed: "..strError)
				end
			end
		)
	end
end

function PYATV.MigrateOldData()
	--Migrate old server ip:port to address
	local ip = Properties["Server IP"] or ""
	local port = Properties["Server Port"] or ""
	if (ip~="" and port~="") then
		local address = ip..":"..port
		C4:UpdateProperty("Server Address",address)
		C4:UpdateProperty("Server IP","")
		C4:UpdateProperty("Server Port","")
	end

	--Migrate ID
	local id = Properties["Device ID"] or ""
	if (id~="") then
		PersistData["DeviceID"] = id
		C4:UpdateProperty("Device ID","")
	end

	--Migrate credentials
	local creds_ap = Properties["AirPlay Credentials"] or ""
	local creds_cm = Properties["Companion Credentials"] or ""
	if (not PersistData["creds"]) then
		PersistData["creds"] = {}
	end
	if (creds_ap~="") then
		PersistData["creds"]["AirPlay"] = creds_ap
		C4:UpdateProperty("AirPlay Credentials","")
	end
	if (creds_cm~="") then
		PersistData["creds"]["Companion"] = creds_cm
		C4:UpdateProperty("Companion Credentials","")
	end

	--Migrate properties
	local properties = {
		"MENU Button",
		"GUIDE Button",
		"INFO Button",
		"CANCEL Button",
		"PVR Button",
		"STAR Button",
		"POUND Button",
		"RECORD Button"
	}

	local map = {
		["Back"] = "Menu",
		["Dashboard (Hold TV Button)"] = "Dashboard"
	}

	for i,property in pairs(properties) do
		local value = Properties[property]
		if (property=="PVR Button" and value=="Back") then
			C4:UpdateProperty(property,"Screensaver")
		elseif (map[value]) then
			C4:UpdateProperty(property,map[value])
		end
	end

end

function PYATV.GenerateMediaHash(data)

	local title = data.title or ""
	local artist = data.artist or ""
	local album = data.album or ""
	local time = data.total_time or ""

	local hash = title..artist..album..time
	local encoded = C4:Base64Encode(hash)

	return encoded

end

--PAIRING

function PYATV.ScanDevices(idBinding,tParams,callback)
    print("---Scan Devices---")
	PYATV.UpdateStatus("Scanning...")
    
	local function cb(data)
		DeviceList = data["results"]
		local devicesStr = ""

		print ("---Devices Found---")

		for i,device in orderedPairs(DeviceList) do
			local name = device["name"]
			print(name)
			devicesStr = devicesStr..name..","
		end

		devicesStr = devicesStr:sub(1, -2)
		
		C4:UpdatePropertyList("Device Selector", devicesStr)
		PYATV.UpdateStatus("Please select a device...")

		--Used for navigators
		if (callback) then
			callback(idBinding,tParams,DeviceList)
		end
	end

	PYATV.UrlCall("/scan",cb)
end

function PYATV.BeginPairing(deviceName)
	print ("---Begin Pairing---")

	if (init~="idle") then
		dbg("Halted pairing, driver is still init...")
		return
	end

	PairingDevice = {}

	for i,d in ipairs(DeviceList) do
		local name = d["name"]
		if (deviceName==name) then
			PairingDevice = d
			dbg("Got device info for "..name)
			break
		end
	end

	local protocolList = PairingDevice["services"]
	local protocols = ","

	for i,p in ipairs(protocolList) do
		local protocol = p["name"]
		local enabled = p["enabled"]

		if (enabled) then
			protocols = protocols..protocol..","
		end
	end

	protocols = protocols:sub(1, -2)

	C4:UpdatePropertyList("Protocol to Pair", protocols)
	PYATV.UpdateStatus("Please select a protocol...")
end

function PYATV.PairProtocol(protocol)
	print ("---Pairing with Protocol---")

	if (init~="idle") then
		dbg("Halted pairing, driver is still init...")
		return
	end
	
	local deviceId = PairingDevice["identifier"]
	local data = {
		id = deviceId,
		protocol = protocol
	}

	PYATV.UrlCall("/pair",nil,"post",data)
end

function PYATV.PairWithPIN(pin)
	print ("---Pairing With PIN---")

	if (init~="idle") then
		dbg("Halted pairing, driver is still init...")
		return
	end
	
	local deviceId = PairingDevice["identifier"]
	local protocol = Properties["Protocol to Pair"]
	local data = {
		id = deviceId,
		protocol = protocol,
		pin = pin
	}

	PYATV.UrlCall("/pair",PYATV.PairingComplete,"post",data)
end

function PYATV.PairingComplete(data)

	if (init~="idle") then
		dbg("Halted pairing, driver is still init...")
		return
	end

	local protocol = Properties["Protocol to Pair"]
	local creds = data["creds"]

	if (not PersistData["creds"]) then
		PersistData["creds"] = {}
	end

	PersistData["creds"][protocol] = creds
	PersistData["DeviceID"] = PairingDevice["identifier"]
	C4:UpdateProperty("Protocol to Pair", "")
	C4:UpdateProperty("Pairing Code","")
end

function PYATV.ConnectDevice()
	print ("---Connect Device---")

	local data = {
		id = PersistData["DeviceID"],
		creds = PersistData["creds"]
	}

	PYATV.UrlCall("/connect",nil,"post",data)
	PYATV.GetAppList()
	PYATV.GetUserList()
end

function PYATV.ReconnectDevice()
	dbg("Attempting to reconnect device in 10 seconds...")
	Timer.Device = C4:SetTimer(10000, function(timer)
		PYATV.ConnectDevice()
		timer:Cancel()
	end, true)
end

function PYATV.Connect()
	PYATV.ConnectDevice()
	PYATV.ConnectWebsocket()
end

--APPS

function PYATV.GetAppList()
	dbg ("---Get App List---")

	APP_LIST = {}

	local function cb(data)
		for i,app in pairs(data.apps) do
			APP_LIST[app.name] = {
				id = app.id,
				icon = app.icon
			}
		end
	end
	
	local uri = "/apps/"..PersistData.DeviceID
	PYATV.UrlCall(uri,cb)

end

function PYATV.LaunchApp(appId)
	local data = {
		id = PersistData["DeviceID"],
		appId = appId
	}

	PYATV.UrlCall("/app_launch",nil,"post",data)
end

--USERS

function PYATV.GetUserList()
	dbg ("---Get User List---")

	local function cb(data)
		USER_LIST = data.users
	end
	
	local uri = "/users/"..PersistData.DeviceID
	PYATV.UrlCall(uri,cb)

end

function PYATV.SwitchUser(userId)
	local data = {
		id = PersistData["DeviceID"],
		userId = userId
	}

	PYATV.UrlCall("/users/",nil,"post",data) --the trailing slash is important
end

--REMOTE

function PYATV.RemoteCommand(cmd,action)
	dbg ("---Remote Command---")
	dbg ("CMD: "..cmd)

	--top menu does not accept action parameter
	if ((cmd=="top_menu" or cmd=="home_hold") and action=="Hold") then
		cmd = "home_hold"
		action = nil
	end
	
	local data = {
		id = PersistData["DeviceID"],
		command = cmd,
		action = action
	}

	PYATV.UrlCall("/remote",nil,"post",data)
end

function PYATV.RemoteCommandHold(rawCmd,tParams)
	dbg ("---Remote Command (Hold)---")
	dbg ("Raw cmd: "..rawCmd)

	local cmd = rawCmd
	local action = nil
	

	local actions = {"start","stop","begin","end"}
	for i,a in pairs(actions) do
		local str = rawCmd:match(a.."_(.*)")
		if (str) then
			action = a
			cmd = str
			dbg("CMD: "..cmd.." Action: "..action)
		end
	end
	
	if (action=="start") then
	   dbg("Starting hold timer...")
	   PYATV.RemoteCommand(cmd)
	   Timer["holdAction"] = C4:SetTimer(100, function(timer)
			PYATV.RemoteCommand(cmd)
		end, true)
	
    elseif (action=="begin") then
		local timeout = Properties["Button Hold Threshold"] + 250 --give some overhead in case of signal delays
		dbg("Begin timeout timer for "..timeout.."ms")
		Timer["endAction"] = C4:SetTimer(timeout, function(timer)
			if (Timer["endAction"] ~= nil) then
				PYATV.RemoteCommand(cmd,"Hold")
			else
				dbg("Timer is nil, stopping...")
				timer:Cancel()
			end
		end, false)
		return

	elseif (action=="end" and Timer["endAction"]) then
		dbg("Stopping end timer...")
	    Timer["endAction"] = nil
	   
    elseif (action=="stop" and Timer["holdAction"]) then
		dbg("Stopping hold timer...")
	    Timer["holdAction"]:Cancel()
    end

	local duration = tonumber(tParams.DURATION)
	local threshold = tonumber(Properties["Button Hold Threshold"])
	dbg("Button duration: "..duration)
	if (duration and (duration < threshold)) then
		dbg("Duration "..duration.." is less than threshold, sending non-hold command...")
		PYATV.RemoteCommand(cmd)
		Timer["endAction"] = nil
		return
	end
	   
end

function PYATV.SetRemoteMapping(button,value)
	local cmd = REMOTE_MAPPINGS.values[value]

	if (cmd==nil) then
		dbg("nil button, skipping: "..button)
		return
	end

	dbg("Remapping "..button.." to "..cmd)

	if (REMOTE_CMDS[button]) then
		REMOTE_CMDS[button] = cmd
	elseif (REMOTE_HOLD_CMDS[button]) then
		REMOTE_HOLD_CMDS[button] = cmd
	end

	--Map actions, prefix begin_ for timers
	--Could be cleaned up a bit with for loops
	local action = nil
	local testAction = "END_"..button

	if (REMOTE_CMDS[testAction]) then
		action = "end_"..cmd
		REMOTE_CMDS[testAction] = action
		action = "begin_"..cmd
		REMOTE_CMDS[button] = action
	elseif (REMOTE_HOLD_CMDS[testAction]) then
		action = "end_"..cmd
		REMOTE_HOLD_CMDS[testAction] = action
		action = "begin_"..cmd
		REMOTE_HOLD_CMDS[button] = action
	end

	if (action) then
		dbg("Remapping "..testAction.." to "..action)
	end

end

--KEYBOARD

function PYATV.Keyboard(str,action)
	local data = {
		id = PersistData["DeviceID"],
		string = str,
		action = action
	}

	PYATV.UrlCall("/keyboard",nil,"post",data)
end

--MEDIA GENERATION

function PYATV.GenerateMediaInfo(data)

	local media = data.media

	local imgUrl = ""
	local hash = PYATV.GenerateMediaHash(media)

	if (data.media.artwork) then
		imgUrl = "http://"..Properties["Server Address"].."/artwork/"..PersistData.DeviceID.."/art.png?"..hash or ""
	end

	local args = {
        TITLE = media.title or data.app.name,
        ALBUM = media.album,
        ARTIST = media.artist,
        GENRE = media.genre,
        IMAGEURL = C4:Base64Encode(imgUrl)
    }
    
    C4:SendToProxy(5001, "UPDATE_MEDIA_INFO", args, "COMMAND", true)

	local state = media.state or ""
	local mediaType = media.media_type or ""
	local service = data.app.name or ""

	C4:SetVariable("Play State", string.lower(state))
	C4:SetVariable("Media Type", string.lower(mediaType))
	C4:SetVariable("Service", service)
end

function PYATV.GenerateDashboard(idBinding,tParams,data)

	dbg("Generate dashboard...")

	local state = data.media.state
	local total_time = data.media.total_time
	local features = data.features
	local items = ""

	local sh = data.media.shuffle=="Off" and "ShuffleOn" or "ShuffleOff"
	local rp = data.media["repeat"]=="Off" and "RepeatOn" or "RepeatOff"

	--Feature = dashboard
	local itemTable = {
		Shuffle = sh,
		Repeat = rp,
		Previous = "SkipRev",
		Next = "SkipFwd",
		Play = "Play",
		Pause = "Pause",
		Stop = "Stop",
	}

	local possibleItems = {
		playing = {
			"Shuffle", "Previous", "Pause", "Next", "Repeat"
		},
		live = {
			"Stop"
		},
		idle = {
			"Shuffle", "Previous", "Play", "Next", "Repeat"
		}
	}

	local function parseItems(data)
		for i,v in orderedPairs(data) do
			local feature = features.v
			if (feature=="Available") then
				items = items..itemTable.v.." "
			end
		end
	end
	
	if (state=="Playing" and total_time) then
		parseItems(possibleItems.playing)
	elseif (state=="Playing" and not total_time) then
		parseItems(possibleItems.live)
	elseif (state~="Playing" and not total_time) then
		parseItems(possibleItems.idle)
	else
		parseItems(possibleItems.idle)
	end

    local dashboardInfo = {
		Items = items
	}

	dbg("Final dashboard data:\n"..dump(dashboardInfo))

	SendEvent(5001, nil, nil, "DashboardChanged", dashboardInfo) -- Logic needed for tParams? nil placeholder for now
end

function PYATV.GenerateQueue(idBinding,tParams,data)

	dbg("Generate queue...")

	local title = data.media.title
	local artist = data.media.artist
	local total_time = data.media.total_time
	local imgUrl = ""
	local hash = PYATV.GenerateMediaHash(data.media)

	if (data.media.artwork) then
		imgUrl = "http://"..Properties["Server Address"].."/artwork/"..PersistData.DeviceID.."/art.png?"..hash or ""
	end

	local appName = data.app.name
	local appIcon = data.app.icon or ""

	local np = [[
		<NowPlaying>
			<actions_list>UICreatePreset UIReconnect</actions_list>
		</NowPlaying>
	]]

	local q = np.."<List>"

	if (title or artist) then
		q = q.."<item><title>"..XMLEncode(title or '').."</title>"
		q = q.."<subtitle>"..XMLEncode(artist or '').."</subtitle>"
		q = q.."<image_list>"..imgUrl.."</image_list>"

		if (total_time) then
			local time = ConvertTime(total_time)
			q = q.."<duration>"..time.."</duration>"
		end

		q = q.."</item>"
	end
	
	if (appName) then
		q = q.."<item><title>Service</title><isHeader>true</isHeader></item>"
		q = q.."<item><title>"..XMLEncode(appName).."</title>"
		q = q.."<image_list>"..appIcon.."</image_list></item>"
	end

	q = q.."</List>"

	dbg("Final queue data:\n"..q)

	SendEvent(5001, nil, nil, "QueueChanged", q) -- Logic needed for tParams? nil placeholder for now
end

function PYATV.GenerateProgress(data,source)
	dbg("Generate progress...")

	local state = data.media.state
	local pos = data.media.position
	local total_time = data.media.total_time

	local progress = {
		offset = pos,
		length = total_time,
		--label = "PROGRESS" -- nothing shows in UI
	}

	if (state=="Playing" and total_time) then
		if (Timer.progress) then
			Timer.progress:Cancel()
		end

		Timer.progress = C4:SetTimer(1000, function(timer)
			progress.offset = progress.offset+1

			if (progress.offset > progress.length) then
				dbg("Stop progress, exceeded length: "..dump(progress))
				timer:Cancel()
			else
				dbg("Send progress: "..dump(progress))
				SendEvent(5001, nil, nil, "ProgressChanged", progress)
			end
		end, true)
	elseif (state~="Playing" and Timer.progress) then
		dbg("Cancel progress, state: "..state..", timer: "..dump(Timer.progress))
		Timer.progress:Cancel()
    elseif (not total_time and Timer.progress) then
		dbg("Cancel progress, state: "..state..", timer: "..dump(Timer.progress))
		Timer.progress:Cancel()
	else
    	dbg("Nothing progress, state: "..state..", timer: "..dump(Timer.progress))
		SendEvent(5001, nil, nil, "ProgressChanged", progress)
	end
end

function PYATV.GetMedia(source,idBinding,tParams)
	local uri = "/info/"..PersistData.DeviceID
	local cbData = {
		source = source,
		idBinding = idBinding,
		tParams = tParams
	}
	PYATV.UrlCall(uri,PYATV.MediaCallback,nil,nil,cbData)
end

function PYATV.MediaCallback(jsonData,callbackData,source)

	dbg("Media callback...")

	--Came from Dashboard or Queue request
	if (callbackData) then
		dbg("Callback data:",dump(callbackData))
		local source = callbackData.source
		local idBinding = callbackData.idBinding
		local tParams = callbackData.tParams
		
		if (source=="dashboard") then
			PYATV.GenerateDashboard(idBinding,tParams,jsonData)
		elseif (source=="queue") then
			PYATV.GenerateQueue(idBinding,tParams,jsonData)
		end
	end

	--Send Dashboard or Queue on generic inbound msg
	if (source=="ws") then
		PYATV.GenerateDashboard(nil,nil,jsonData)
		PYATV.GenerateQueue(nil,nil,jsonData)
	end

	--Always send progress
	PYATV.GenerateProgress(jsonData,source)

	--Send data always just in case
	PYATV.GenerateMediaInfo(jsonData)

end

--EXECUTE COMMAND

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
		PYATV.LaunchApp(id)
	end
end

function EC.Select_Preset (tParams)
	print ("---Select Preset---")
	local id = tParams.Preset
	if (id) then
		local data = {
			id = id
		}
		MSP.jumpToFavorite(nil, nil, nil, data)
	end
end

function EC.Refresh_Connection (tParams)
	print ("---Refresh Connection---")
	PYATV.Connect()
end

function EC.ScanDevices (tParams)
	PYATV.ScanDevices()
end

function EC.RefreshConnection (tParams)
	PYATV.Connect()
end

function AppSelection (currentValue) 	-- CUSTOM_SELECT from Actions and Programming Action.
	for k,v in pairs(APP_SELECT) do APP_SELECT[k] = nil end -- clear table!
	for strAppName, strAppProperties in orderedPairs(APP_LIST) do
		table.insert(APP_SELECT, { text = strAppName, value = strAppProperties.id })
	end
	return APP_SELECT
end

function PresetSelection (currentValue)
	local presets = {}
	for k,v in orderedPairs(PersistData.presets) do
		local name = v.UIPresetName
		local id = k
		table.insert(presets, { text = name, value = id })
	end
	return presets
end

function OnDriverDestroyed ()
	if (WS) then
		WS:delete()
	end
	KillAllTimers()
end

function OnDriverInit()
	C4:AddVariable("Play State", "Not Playing", "STRING")
	C4:AddVariable("Media Type", "Not Playing", "STRING")
	C4:AddVariable("Service", "Not Playing", "STRING")
end

function OnDriverLateInit()
	init = "new"
	PYATV.MigrateOldData()
    
	KillAllTimers()
    C4:urlSetTimeout(10)

	LoadProperties()

	--Hide app switcher in all rooms
    if (USES_DEDICATED_SWITCHER) then
        HideProxyInAllRooms(SWITCHER_PROXY)
    end
    RegisterRooms()

	init = "idle"

	PYATV.Connect()
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

--ON PROPERTY CHANGED

function OnPropertyChanged (strProperty)
	local value = Properties [strProperty]
	if (value == nil) then
		value = ''
	end
	if (DEBUGPRINT) then
		local output = "--- OnPropertyChanged: "..strProperty..": "..value
		print (output)
	end
	local success, ret
	strProperty = string.gsub (strProperty, '%s+', '_')
	dbg("strProperty: "..strProperty)

	--Check for buttons
	local button = string.match(strProperty,"(.*)_Button")
	if (button) then
		PYATV.SetRemoteMapping(button,value)
	elseif (OPC and OPC [strProperty] and type (OPC [strProperty]) == 'function') then
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

function OPC.Device_Selector(value)
	dbg ("Begin pairing for "..value)
	PYATV.BeginPairing(value)
end

function OPC.Protocol_to_Pair (value)
	PYATV.PairProtocol(value)
end

function OPC.Pairing_Code (value)
	PYATV.PairWithPIN(value)
end

function OPC.On_Power_Off (value)
	PYATV.SetRemoteMapping("OFF",value)
end

function OPC.On_Power_On (value)
	PYATV.SetRemoteMapping("DEVICE_SELECTED",value)
end

--RECEIVED FROM PROXY

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
		if (REMOTE_CMDS[strCommand]) then
			PYATV.RemoteCommand(REMOTE_CMDS[strCommand])
		elseif (REMOTE_HOLD_CMDS[strCommand]) then
			PYATV.RemoteCommandHold(REMOTE_HOLD_CMDS[strCommand],tParams)
		elseif (KEYBOARD_CMDS[strCommand]) then
			PYATV.Keyboard(strCommand,"append")
		elseif (MSP[strCommand] ~= nil) and (type(MSP[strCommand])=='function') then
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
					dbg ("PyATV Dynamic App ID found: "..APP_LIST[appName].id)
					tValues = { ['App'] = APP_LIST[appName].id }
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

--MSP REMOTE

function MSP.ShuffleOn(idBinding, strCommand, tParams, args)
	PYATV.RemoteCommand("set_shuffle","Songs")
end

function MSP.ShuffleOff(idBinding, strCommand, tParams, args)
	PYATV.RemoteCommand("set_shuffle","Off")
end

function MSP.RepeatOn(idBinding, strCommand, tParams, args)
	PYATV.RemoteCommand("set_repeat","All")
end

function MSP.RepeatOff(idBinding, strCommand, tParams, args)
	PYATV.RemoteCommand("set_repeat","Off")
end

--NAVIGATOR UI

function MSP.GetDashboard(idBinding, strCommand, tParams, args)
	PYATV.GetMedia("dashboard",idBinding,tParams)
end

function MSP.GetQueue(idBinding, strCommand, tParams, args)
	PYATV.GetMedia("queue",idBinding,tParams)
end

function MSP.TabsCommand(idBinding, strCommand, tParams, args)

	local tabs = "<Tabs></Tabs>"

    local allTabs = [[
    <Tabs>
		<Tab>
			<Id>Users</Id>
			<Name>Users</Name>
			<IconId>tab_explore</IconId>
			<ScreenId>UsersScreen</ScreenId>
		</Tab>
	   <Tab>
		<Id>Apps</Id>
		<Name>Apps</Name>
		<IconId>tab_explore</IconId>
		<ScreenId>AppsScreen</ScreenId>
	   </Tab>
	   <Tab>
		<Id>Presets</Id>
		<Name>Presets</Name>
		<IconId>tab_explore</IconId>
		<ScreenId>PresetsScreen</ScreenId>
	   </Tab>
	   <Tab>
		  <Id>Settings</Id>
		  <Name>Settings</Name>
		  <IconId>tab_explore</IconId>
		  <ScreenId>SettingsScreen</ScreenId>
	   </Tab>
    </Tabs>
    ]]

	local settingsOnly = [[
	<Tabs>
		<Tab>
			<Id>Settings</Id>
			<Name>Settings</Name>
			<IconId>tab_explore</IconId>
			<ScreenId>SettingsScreen</ScreenId>
		</Tab>
	</Tabs>
	]]

	local option = Properties["Device Selection Behavior"]

	if (option ~= "Now Playing Screen") then
		tabs = allTabs
	end
    
    local data = tabs
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], data)

end

function MSP.UIScanDevices(idBinding, strCommand, tParams, args)
    
    PYATV.ScanDevices(idBinding,tParams,MSP.UIScanDevicesCallback)

end

function MSP.UIScanDevicesCallback(idBinding,tParams,devices)

    local devicesXml = "<List>"
    
    for k,v in pairs(devices) do
	   local name = v["name"] or "No name"
	   local id = v["identifier"] or "No ID"
	   devicesXml = devicesXml.."<item><title>"..name.."</title><subtitle>"..id.."</subtitle><id>"..id.."</id></item>"
    end
    
    devicesXml = devicesXml.."</List>"

    dbg("Got data from callback: "..devicesXml)
    
    MSP.UIScanDevicesXML = devicesXml
    
end

function MSP.UIShowDevices(idBinding, strCommand, tParams, args)
    local screen = "<NextScreen>UIDevicesScreen</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.UIDevicesScreen(idBinding, strCommand, tParams, args)

    local data = MSP.UIScanDevicesXML
    
    if (not data) then
	   data = [[
		  <List>
			 <item>
				<title>No devices found</title>
				<subtitle>Scan may not be complete. Click to refresh.</subtitle>
				<action>UIShowDevices</action>
			 </item>
		  </List>
	   ]]
    end
    
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], data)

end

function MSP.UIReconnect(idBinding, strCommand, tParams, args)
    PYATV.Connect()
end

function MSP.Apps(idBinding, strCommand, tParams, args)

    local apps = "<List>"

    for appName,appProperties in orderedPairs(APP_LIST) do
		local id = appProperties.id
	   	local icon = appProperties.icon or ""
	   	local app = "<item><link>true</link><id>"..id.."</id><title>"..XMLEncode(appName).."</title><image_list>"..icon.."</image_list><default_action>AppLaunchUI</default_action></item>"
	   	apps = apps..app
	   
    end
    
    apps = apps.."</List>"
    
    local data = apps
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], data)


end

function MSP.AppLaunchUI(idBinding, strCommand, tParams, args)
	local id = args.id
	PYATV.LaunchApp(id)

	--Hotfix for iOS app, force Watch on selection
	C4:SendToDevice(tParams.ROOMID, 'SELECT_VIDEO_DEVICE', {deviceid = C4:GetProxyDevices()})

	local screen = "<NextScreen>#nowplaying</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.Users(idBinding, strCommand, tParams, args)

    local users = "<List>"

    for i,userData in orderedPairs(USER_LIST) do
		local id = userData.id
		local name = userData.name
	   	local user = "<item><link>true</link><id>"..id.."</id><title>"..XMLEncode(name).."</title><default_action>UserSwitchUI</default_action></item>"
	   	users = users..user
	   
    end
    
    users = users.."</List>"
    
    local data = users
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], data)


end

function MSP.UserSwitchUI(idBinding, strCommand, tParams, args)
	local id = args.id
	PYATV.SwitchUser(id)

	--Hotfix for iOS app, force Watch on selection
	C4:SendToDevice(tParams.ROOMID, 'SELECT_VIDEO_DEVICE', {deviceid = C4:GetProxyDevices()})

	local screen = "<NextScreen>#nowplaying</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.GetSettings(idBinding, strCommand, tParams, args)

    local settings = "<Settings><UIServerIP>"..Properties["Server Address"].."</UIServerIP>"
    
    settings = settings.."<UISelectedDevice>"..Properties["Device Selector"].."</UISelectedDevice></Settings>"


    local data = settings
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], data)
    
end

function MSP.GetPresets(idBinding, strCommand, tParams, args)


	local d = [[
		<List>
			<item><title>Create Preset</title><isHeader>true</isHeader></item>
			<item>
				<title>Click to create a preset</title>
				<action>UICreatePreset</action>
			</item>
			<item><title>Presets</title><isHeader>true</isHeader></item>
	]]

	if (PersistData.presets == nil) then
		PersistData.presets = {}
	end

	for k,v in pairs(PersistData.presets) do
		local p = "<item><title>"..v.UIPresetName.."</title>"
		p = p.."<image_list>"..XMLEncode(v.UIPresetIconURL).."</image_list>"
		p = p.."<actions_list>FavoriteToRoom UIModifyPreset UIDeletePreset</actions_list>"
		p = p.."<id>"..k.."</id>"
		p = p.."</item>"
		d = d..p
	end

	d = d.."</List>"
    
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], d)

end

function MSP.GetNewPreset(idBinding, strCommand, tParams, args)
	
	local p = "<Settings>"
	p = p.."<UIPresetName>"..PRESETS.Create.UIPresetName.."</UIPresetName>"
	p = p.."<UIPresetLaunchURL>"..XMLEncode(PRESETS.Create.UIPresetLaunchURL).."</UIPresetLaunchURL>"
	p = p.."<UIPresetIconURL>"..XMLEncode(PRESETS.Create.UIPresetIconURL).."</UIPresetIconURL>"
	p = p.."<UIPresetButtonEnabled>"..PRESETS.Create.UIPresetButtonEnabled.."</UIPresetButtonEnabled>"
	p = p.."<UIPresetButtonTime>"..PRESETS.Create.UIPresetButtonTime.."</UIPresetButtonTime>"

	p = p.."</Settings>"

    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], p)
end

function MSP.UICreatePreset(idBinding, strCommand, tParams, args)
	PRESETS.Create = {
		UIPresetName = "",
		UIPresetLaunchURL = "",
		UIPresetIconURL = "",
		UIPresetButtonEnabled = "off",
		UIPresetButtonTime = 3
	}
	PRESETS.CreateID = nil
    local screen = "<NextScreen>CreatePresetScreen</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.UIModifyPreset(idBinding, strCommand, tParams, args)

	local id = tonumber(args.id)
	local preset = PersistData.presets[id]

	PRESETS.Create = preset
	PRESETS.CreateID = id

    local screen = "<NextScreen>CreatePresetScreen</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.UIDeletePreset(idBinding, strCommand, tParams, args)

	local id = tonumber(args.id)
	PersistData.presets[id] = nil

    local screen = "<NextScreen>PresetsScreen</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.UIStorePreset(idBinding, strCommand, tParams, args)
    dbg("STORE PRESET")

	local preset = {
		UIPresetName = PRESETS.Create.UIPresetName,
		UIPresetLaunchURL = PRESETS.Create.UIPresetLaunchURL,
		UIPresetIconURL = PRESETS.Create.UIPresetIconURL,
		UIPresetButtonEnabled = PRESETS.Create.UIPresetButtonEnabled,
		UIPresetButtonTime = PRESETS.Create.UIPresetButtonTime
	}

	local id = PRESETS.CreateID

	if (id) then
		PersistData.presets[id] = PRESETS.Create
	else
		table.insert(PersistData.presets,preset)
	end

	PRESETS.Create = {
		UIPresetName = "",
		UIPresetLaunchURL = "",
		UIPresetIconURL = "",
		UIPresetButtonEnabled = "off",
		UIPresetButtonTime = 3
	}

	PRESETS.CreateID = nil

	local screen = "<NextScreen>PresetsScreen</NextScreen>"
    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], screen)
end

function MSP.FavoriteToRoom(idBinding, strCommand, tParams, args)

	local screen = args.screenId
	local id = args.id
	local favorite = ""

	if (screen=="PresetsScreen") then
		id = tonumber(id)
		local preset = PersistData.presets[id]

		local f = "<FavoriteResponse><Title>"..preset.UIPresetName.."</Title>"
		f = f.."<ImageUrl width='512' height='512'>"..XMLEncode(preset.UIPresetIconURL).."</ImageUrl>"
		f = f.."<Context><favoriteId>"..id.."</favoriteId></Context></FavoriteResponse>"
		favorite = f
	end

    DataReceived(idBinding, tParams["NAVID"], tParams["SEQ"], favorite)
end

function MSP.jumpToFavorite(idBinding, strCommand, tParams, args)
	local id = tonumber(args.id)
	local preset = PersistData.presets[id]
	local url = preset.UIPresetLaunchURL
	dbg("Launch preset with url: "..url)
	PYATV.LaunchApp(url)

	local buttonEnabled = preset.UIPresetButtonEnabled
	local buttonTime = tonumber(preset.UIPresetButtonTime)*1000
	if (buttonEnabled=="on") then
		local button = "select"
		dbg("Button is enabled. Will fire "..button.." after "..buttonTime.." seconds...")
		C4:SetTimer(buttonTime, function(timer)
			PYATV.RemoteCommand(button)
		end, false)
	end
end

function MSP.SettingChanged(idBinding, strCommand, tParams, args)
	local screen = args.ScreenId
	local property = args.PropertyName
	local value = args.Value

	if (screen=="CreatePresetScreen") then
		if (PRESETS.Create == nil) then
			PRESETS.Create = {}
		end
		PRESETS.Create[property] = value
	end
end

--Other misc from old driver

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