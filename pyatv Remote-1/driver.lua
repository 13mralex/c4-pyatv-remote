require "scan"
JSON = (require "JSON")

do	--Globals
	RFP = {}
     artwork_info = {}
	g_data = {}
	Timer = Timer or {}
	playstate = ""
	device_array = {}
	init = "fresh"
	DEBUGPRINT = false
end

function dbg (strDebugText, ...)
	if (DEBUGPRINT) then print (os.date ('%x %X : ') .. (strDebugText or ''), ...) end
end

function ExecuteCommand (strCommand, tParams)
--[[
This function call is triggered by a programming script running that contains a <command> from this driver, or by selecting an <action> from the Actions tab in this driver in Composer

--parameters
strCommand - the <name> of the <command> in the driver.xml if a programming command, or LUA_ACTION if an <action> selected from the Actions tab in Composer
tParams - the table of key/value pairs defined in the driver.xml for this <action> or <command>.  Additionally contains ACTION key with value of <name> if an <action>.

--effect
prints the name of the function, the name of the command and then a list of all the parameters to the function
--]]
	local output = {'--- ExecuteCommand', strCommand, '----PARAMS----'}
	for k,v in pairs (tParams) do table.insert (output, tostring (k) .. ' = ' .. tostring (v)) end
	table.insert (output, '---')
	dbg (table.concat (output, '\r\n'))
	
	
  if (strCommand == "LUA_ACTION") then
   if tParams ~= nil then
     for cmd,cmdv in pairs(tParams) do 
       --print (cmd,cmdv)
       if cmd == "ACTION" then
         if cmdv == "send_pairing_req" then
	      
           print("Pair request action...")
		 pair_request()
		 
	    elseif cmdv == "test_connection" then
	      --print("Test connection action...")
		 connect_device()
		 
	    elseif cmdv == "scan_devices" then
	      scan_devices()
         else
           print("From ExecuteCommand Function - Undefined Action")
           print("Key: " .. cmd .. "  Value: " .. cmdv)
         end
       else
         print("From ExecuteCommand Function - Undefined Command")
         print("Key: " .. cmd .. "  Value: " .. cmdv)
       end
     end
   end
 end
 
 if (strCommand == "Launch App") then
    
    print("Launching app: "..tParams["App ID"])
    ip = Properties["Server IP"].."/launch_app/"..Properties["Device ID"].."/"..tParams["App ID"]
    call_ip(ip)
    
 end
 
end

function OnDriverDestroyed ()
	KillAllTimers ()
end

function OnDriverInit()
    connect_device()
    C4:AddVariable("Play State", "Not Playing", "STRING")
    C4:AddVariable("Media Type", "Not Playing", "STRING")
    init = "new"
end

function OnDriverLateInit ()
	KillAllTimers ()
	if (C4.AllowExecute) then C4:AllowExecute (true) end

	--C4:urlSetTimeout (5)
	--preMakeImageList()
     pollMediaInfo()
	for property, _ in pairs (Properties) do
		OnPropertyChanged (property)
	end

	if (OnDriverLateInitTasks and type (OnDriverLateInitTasks) == 'function') then
		-- this is so that when we template out the driver later it's possible to move the registered C4 callback functions (like OnDriverLateInit into the template)+
		OnDriverLateInitTasks ()
	end
end

function OnPropertyChanged (strProperty)
	local value = Properties[strProperty]
	if (value == nil) then
		value = ''
	end
	
	if (strProperty == "Device Selector") then
	   pair(value)
	end
	if (strProperty == "Protocol to Pair") then
	   pair2(value)
	end
	
	if (strProperty == "Pairing Code") then
	   pair3(value)
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
		local output = {'--- ReceivedFromProxy: ' .. idBinding, strCommand, '----PARAMS----'}
		for k,v in pairs (tParams) do table.insert (output, tostring (k) .. ' = ' .. tostring (v)) end
		table.insert (output, '-----ARGS-----')
		for k,v in pairs (args) do table.insert (output, tostring (k) .. ' = ' .. tostring (v)) end
		table.insert (output, '---')
		print (table.concat (output, '\r\n'))
	end

	if (RFP and RFP [strCommand]) then
		RFP [strCommand] (tParams, args, idBinding)
	end

	if (tParams.SEQ and tParams.NAVID) then
		DataReceived (5001, tParams.NAVID, tParams.SEQ) -- this is something we'll be getting to in a future example - it's to do with providing data back to the UI on Navigator requests
	end
end

-- RFP functions
function RFP.DEVICE_SELECTED (tParams, args, idBinding)
	-- Device has been selected from the Listen/Watch screen in a room
	pollMediaInfo ("proxy")
end

function RFP.DEVICE_DESELECTED (tParams, args, idBinding)
	-- Device is no longer needed in the room
	--pollMediaInfo ()
end

function RFP.GetDashboard (tParams, args, idBinding)
	-- A navigator has requested an update of the dashboard
	pollMediaInfo ("proxy")
	--nav_timer(tParams["NAVID"])
	return ('')
end

function RFP.GetQueue (tParams, args, idBinding)
	-- A navigator has requested an update of the queue
	--UpdateQueue ()
	pollMediaInfo ("proxy")
	return ('')
end

function RFP.ToggleRepeat (tParams, args, idBinding)
	-- Repeat button pressed on the Now Playing screen (ToggleRepeat defined as Command for the "Repeat" Action in XML)
	REPEAT = not (REPEAT)
	--UpdateQueue ()
end

function RFP.ToggleShuffle (tParams, args, idBinding)
	-- Shuffle button pressed on the now playing screen (ToggleShuffle defined as Command for the "Shuffle" Action in XML)
	SHUFFLE = not (SHUFFLE)
	--UpdateQueue ()
end

function RFP.PLAY (tParams, args, idBinding)
	remote("play")
end

function RFP.PAUSE (tParams, args, idBinding)
	remote("pause")
end

function RFP.STOP (tParams, args, idBinding)
	remote("stop")
end

function RFP.SKIP_FWD (tParams, args, idBinding)
	remote("next")
end

function RFP.SKIP_REV (tParams, args, idBinding)
	remote("previous")
end

function RFP.UP (tParams, args, idBinding)
	remote("up")
end

function RFP.DOWN (tParams, args, idBinding)
	remote("down")
end

function RFP.LEFT (tParams, args, idBinding)
	remote("left")
end

function RFP.RIGHT (tParams, args, idBinding)
	remote("right")
end

function RFP.MENU (tParams, args, idBinding)
	remote("top_menu")
end

function RFP.CANCEL (tParams, args, idBinding)
	remote("menu")
end

function RFP.ENTER (tParams, args, idBinding)
	remote("select")
end

function RFP.OFF()
     RefreshInterval("stop")
end

function RFP.DEVICE_SELECTED()
     RefreshInterval("start")
end

--Common MSP functions
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
	local data = ''

	if (type (args) == 'string') then
		data = args
	elseif (type (args) == 'boolean' or type (args) == 'number') then
		data = tostring (args)
	elseif (type (args) == 'table') then
		data = XMLTag (nil, args, false, false)
     else
	   --print("arg type failed to match")
	   data = args
	end
	
	local tParams = {
		NAVID = navId,
		SEQ = seq,
		DATA = data,
		EVTARGS = data,
	}
     --print("----DATA RECEIVED-----")
	--print("--tParams: "..dump(tParams))
	--print("--------DONE----------")
	--print("DataRX args: "..dump(data))
	C4:SendToProxy (idBinding, 'DATA_RECEIVED', tParams)
end

function SendEvent (idBinding, navId, roomId, name, args)
-- Send an asyncronous notification to specific Navigator(s), specific Room(s) or all (nil value for navId and roomId).
-- Used for DriverNotification, QueueChanged, DashboardChanged and ProgressChanged events
	local data = ''

	if (type (args) == 'string') then
		data = args
	elseif (type (args) == 'boolean' or type (args) == 'number') then
		data = tostring (args)
	elseif (type (args) == 'table') then
		data = XMLTag (nil, args, false, false)
     else
	   --print("arg type failed to match")
	   data = args
	end

	local tParams = {
		NAVID = navId,
	     ROOMS = roomId,
		NAME = name,
		EVTARGS = data,
		QUEUEID = 10100,
		}
     --print("----SEND EVENT-----")
	--print("--tParams: "..dump(tParams))
	--print("------DONE---------")
	C4:SendToProxy (idBinding, 'SEND_EVENT', tParams, 'COMMAND')
end

-- Update Navigator
function MakeImageList (data)
	--local defaultItem = data["url"]
	defaultSizes = {512}

	image_list = {}
	print("Make image list...URL: "..artwork_info["url"])
	for _, size in ipairs (defaultSizes) do
	     imageUrl = artwork_info["url"].."?"..data["hash"]
	     width = artwork_info["width"]
	     height = artwork_info["height"]
		table.insert (image_list, '<image_list width="' .. width .. '" height="' .. height .. '">' .. imageUrl .. '</image_list>')
	end


	return image_list
end

function UpdateDashboard (data,navId,roomId,seq)
	-- These are all 5 of the Id values of the Transport items from the Dashboard section of the XML
     local dashboardInfo = {}
	local possibleItems = {
		'Play',
		'Pause',
		'Stop',
		'SkipFwd',
		'SkipRev',
	}
    
    prog = data["Position"]
    live = false
    duration = 0
    if string.find(prog, "/") then
	   --print("Song is not live... Progress: "..prog)
	   prog = prog:gsub('%b()', '')
	   prog = prog:sub(1, -3)
	   live = false
	   elapsed,duration = prog:match("(.+)/(.+)")
	   --print(elapsed.." --|-- "..duration)
	   label = ConvertTime (elapsed-0) .. ' / -' .. ConvertTime (duration-elapsed)
    else
	   --print("Song is live... Progress: "..prog)
	   live = true
	   elapsed = prog
	   label = "LIVE"
    end
	
    if (live == true) and (data["Device state"] == "Playing") then
	   dashboardInfo = {
		Items = "Stop",	-- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
	   }
    elseif (live == true) and (data["Device state"] == "Paused") then
	   dashboardInfo = {
		Items = "Play",	-- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
	   }
    elseif (data["Device state"] == "Playing") then
	   dashboardInfo = {
		Items = "SkipRev Pause SkipFwd",	-- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
	   }
    else
	   dashboardInfo = {
		Items = "SkipRev Play SkipFwd",	-- items to display, in order, on Dashboard of Now Playing bar.  Single-space separated list of Id values
	   }
    end
    playstate = data["Device state"]
    
    --print("Sending data to nav: "..navId..", SEQ: "..seq)
    --DataReceived(5001, navId, seq, dashboardInfo)
	SendEvent (5001, nil, nil, 'DashboardChanged', dashboardInfo)
end

function UpdateMediaInfo (data,navId,roomId,seq)
	-- Updates the Now Playing area of the media bar and also the main section on the left of the Now Playing screen.  Doesn't affect the Queue side at all.
	local args = {
		TITLE = data["Title"],
		ALBUM = data["Album"],
		ARTIST = data["Artist"],
		GENRE = data["Genre"],
		IMAGEURL = data["image"],
	}
	--print("Title: "..data["Title"])
	--DataReceived(5001, navId, seq, args)
	C4:SendToProxy (5001, 'UPDATE_MEDIA_INFO', args, 'COMMAND', true)
	--UpdateQueue(data,image)
end

function UpdateProgress (prog,navId,roomId,seq)
     prog = prog["Position"]
     live = nil
	a,b = nil
	label = "Not playing"
	duration = 0
	elapsed = 0
     if string.find(prog, "/") then
	   print("Song is not live... Progress: "..prog)
	   prog = prog:gsub('%b()', '')
	   prog = prog:sub(1, -3)
	   live = false
	   elapsed,duration = prog:match("(.+)/(.+)")
	   --print(elapsed.." --|-- "..duration)
	   label = ConvertTime (elapsed-0) .. ' / -' .. ConvertTime (duration-elapsed)
     else
	   print("Song is live... Progress: "..prog)
	   live = true
	   elapsed = prog
	   label = "LIVE"
     end
	--local duration = math.random (100, 500)
	--local elapsed = math.random (1, duration)

	--local label = ConvertTime (prog) .. ' / -' .. ConvertTime (duration - elapsed)
     label0 = label
	local progressInfo = {
		length = duration,	-- integer for setting size of duration bar
		offset = elapsed,	-- integer for setting size of elapsed indicator inside duration bar
		label = label0,		-- text string to be displayed next to duration bar
	}
	--DataReceived(5001, navId, seq, progressInfo)
	SendEvent (5001, nil, nil, 'ProgressChanged', progressInfo)
end

function UpdateQueue (data,navId,roomId,seq)
    prog = data["Position"]
	duration = 0
     if string.find(prog, "/") then
	   --print("Song is not live... Progress: "..prog)
	   prog = prog:gsub('%b()', '')
	   prog = prog:sub(1, -3)
	   live = false
	   elapsed,duration = prog:match("(.+)/(.+)")
	   --print(elapsed.." --|-- "..duration)
	   --label = ConvertTime (elapsed-0) .. ' / -' .. ConvertTime (duration-elapsed)
     else
	   --print("Song is live... Progress: "..prog)
	   live = true
	   prog = prog:sub(1, -2)
	   duration = prog
	   label = "LIVE"
     end

	local queue = {
		{title = 'Now Playing', isHeader = true},
		{title = data["Title"], subtitle = data["Artist"], duration = ConvertTime(duration-0), ImageUrl = data["ImageUrl"]},
	}

	local tags = {
		can_shuffle = true,
		can_repeat = true,
		shufflemode = (SHUFFLE == true),
		repeatmode = (REPEAT == true),
	}

	local list = {}
	for _, item in ipairs (queue) do
		item.image_list = MakeImageList (data)
		table.insert (list, XMLTag ('item', item))
	end
	list = table.concat (list)
     
	local queueInfo = {
		List = list,	-- The entire list that will be displayed for the queue
		NowPlayingIndex = 1, -- The item (0-indexed) that will be marked as current in the queue (blue marker on the Android navigators)
		NowPlaying = XMLTag (tags), -- The tags that will be applied to all ActionIds from the NowPlaying section of the XML to determine what actions are shown
	}

	--DataReceived(5001, navId, seq, queueInfo)
	SendEvent (5001, nil, nil, 'QueueChanged', queueInfo)
	--print("Queue Done")
end

-- Useful functions
function KillAllTimers ()
	for name, timer in pairs (Timer) do
		if (type (timer) == 'userdata') then
			timer:Cancel ()
		end
		Timer [name] = nil
	end

	if (DEBUGPRINT) then DEBUGPRINT = DEBUGPRINT:Cancel () end
end

function Print (data)
	if (type (data) == 'table') then
		for k, v in pairs (data) do print (k, v) end
	elseif (type (data) ~= 'nil') then
		print (type (data), data)
	else
		print ('nil value')
	end
end

function MakeURL (path, args)
	local url = {}
	if (path) then
		if (string.find (path, '?')) then
			local params
			args = args or {}

			path, params = string.match (path, '(.+)%?(.*)')
			for pair in string.gmatch (params or '', '[^%&]+') do
				local k, v = string.match (pair, '(.+)%=(.+)')
				if (args [k] == nil) then
					args [k] = v
				end
			end
		end
		if (APIBase and not (string.find (path, '^http'))) then
			table.insert (url, APIBase)
		end
		table.insert (url, path)
	end

	if (args and type (args == 'table' and table.getn (args) > 0)) then
		if (path) then
			table.insert (url, '?')
		end

		local urlargs = {}
		for k, v in pairs (args) do
			table.insert (urlargs, URLEncode (k) .. '=' .. URLEncode (v))
		end
		urlargs = table.concat (urlargs, '&')
		table.insert (url, urlargs)
	end
	url = table.concat (url)
	return (url)
end

function URLEncode (s, spaceAsPercent)
	s = string.gsub (s, '([^%w%-%.%_%~% ])', function (c)
										return string.format ('%%%02X', string.byte (c))
									end)

	if (spaceAsPercent) then
		s = string.gsub (s, ' ', '%%20')
	else
		s = string.gsub (s, ' ', '+')
	end
	return s
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
			strTime = hours .. ':'
			minutes = string.format('%02d', data / 60)
		else
			minutes = string.format('%d', data / 60)
		end

		data = data - (minutes * 60)
		seconds = string.format('%02d', data)
		strTime = strTime .. minutes .. ':' .. seconds
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

-- Functions from CUSTOM_SELECT commands/actions
function CustomSelectDemoFunction (currentValue, callbackWhenDone, search, filter)

--[[
This function call is triggered by pressing the ... button next to a CUSTOM_SELECT type parameter to a command or action in Composer, and by moving through the menu structure in the popup.
The name of the function is specified with the type : <type>CUSTOM_SELECT:CustomSelectDemoFunction</type> will trigger the function named CustomSelectDemoFunction

--parameters
currentValue (string) - the "value" of the chosen item in the popup, or the "value" of an item that is a folder to drill into
callbackWhenDone (function) - a reference to a Lua function (callback) used to return the list and other options.  Can be used instead of returning values from the current function.
search (string, optional - default nil) - the text typed into the search text box in Composer (and then Enter pressed or a filter chosen to trigger this function call).
filter (string, optional - default nil) - the name attribute from the filter selected in Composer as defined in the <filters> section in the driver.xml

--arguments to callbackWhenDone / return (list, back, searchable)
list (table, required)- a 1-indexed table (array-like) of tables, each containing the following keys:
				text (string, required) - the text that will be displayed in Composer for this item
				value (string, required) - the value for this item that will be sent to ExecuteCommand when triggered
				folder (boolean, optional - default false) - whether this item can be double clicked in Composer to display a new list of "child" items
				selectable (boolean, optional - default true unless folder is true) - if this item is selected in Composer, can the OK button be pressed to "choose" this item for the parameter
			The list will be displayed in order in Composer.

back (string, optional - default nil) - if not nil, shows a Back button in the popup in Composer and defines what currentValue will be set to when it is pressed

searchable (boolean, optional, default true) - if true, enables the search dialog in the popup in Composer

--]]
	print ('CustomSelectDemoFunction', currentValue, search, filter)

	local back = nil
	local searchable = true
	local list = {}

	if (search and filter) then
		--demonstrates using the callbackWhenDone function as a callback later when we've entered a search string.  currentValue can be used as a mask inside the filter if your API supports that (for example, only searching by filter artists with search Soul when you've selected the Genre 90s in the browse list)
		CallbackFunction (currentValue, callbackWhenDone, search, filter)
		return
	end

	if (currentValue == 'popular') then
		back = '' -- Back to the root menu
		for i = 1, 10 do
			table.insert (list, {text = 'Channel #' .. i, value = 'popular' .. i})
		end

	elseif (currentValue == 'playlists') then
		back = '' -- Back to the root menu
		table.insert (list, {text = 'Mine', value = 'myplaylists', folder = true})
		for i = 1, 5 do
			table.insert (list, {text = 'Playlist ' .. i, value = 'playlists' .. i})
		end

	elseif (currentValue == 'myplaylists') then
		back = 'playlists' -- Back to the Playlists menu
		for i = 1, 2 do
			table.insert (list, {text = 'My playlist ' .. i, value = 'myplaylists' .. i})
		end

	elseif (currentValue == 'favorites') then
		back = '' -- Back to the root menu
		for i = 1, 3 do
			table.insert (list, {text = 'Favorite ' .. i, value = 'favorites' .. i})
		end

	else
		table.insert (list, {text = 'Playlists', value = 'playlists', folder = true})
		table.insert (list, {text = 'Favorites', value = 'favorites', folder = true})
		table.insert (list, {text = 'Most popular', value = 'popular', folder = true, selectable = true})
		for i = 1, 5 do
			table.insert (list, {text = 'Channel ' .. i, value = 'channel' .. i})
		end
	end

	return list, back, searchable
end

function CallbackFunction (currentValue, callbackWhenDone, search, filter)
--[[
This function call is triggered by working with searches in the main CustomSelectDemoFunction above.  It has the exact same arguments, and is here to show using the "callbackWhenDone" callback function to return data.
--]]
	print ('CallbackFunction', currentValue, callbackWhenDone, search, filter)

	local list = {}
	local back = currentValue -- return to previous position in list browse if Back pressed
	local searchable = false -- make search results not searchable

	if (filter == 'popular') then
		table.insert (list, {text = 'Popular search result 1 for ' .. search .. ' in ' .. currentValue, value = 'search:' .. filter .. ':' .. search .. ':1'})
		table.insert (list, {text = 'Popular search result 2 for ' .. search .. ' in ' .. currentValue, value = 'search:' .. filter .. ':' .. search .. ':2'})
	elseif (filter == 'playlists') then
		table.insert (list, {text = 'Playlists search result 1 for ' .. search .. ' in ' .. currentValue, value = 'search:' .. filter .. ':' .. search .. ':1'})
		table.insert (list, {text = 'Playlists search result 2 for ' .. search .. ' in ' .. currentValue, value = 'search:' .. filter .. ':' .. search .. ':2'})
	elseif (filter == 'favorites') then
		table.insert (list, {text = 'Favorites search result 1 for ' .. search .. ' in ' .. currentValue, value = 'search:' .. filter .. ':' .. search .. ':1'})
		table.insert (list, {text = 'Favorites search result 2 for ' .. search .. ' in ' .. currentValue, value = 'search:' .. filter .. ':' .. search .. ':2'})
	end

	callbackWhenDone (list, back, searchable)
end

--function ExecuteCommand(strCommand, tParams)



--end

function call_ip(ip,type)
    print("Calling URL: "..ip)
    result = "Error"
    C4:urlSetTimeout(10)
    C4:urlGet(ip)
    
    
    function ReceivedAsync0(ticketId, strData, responseCode, tHeaders, strError )

	   strData = strData or ""
	   errMsg = errMsg or "None"
	   responseCode = responseCode or 0
	   tHeaders = tHeaders or {}

	   --print("------------------------------------------------------------------")
	   if (responseCode == 0) then
		  --local _, _, url, err = strData:find("Failed to get (.-): (.*)")
		  print("FAILED retrieving: " .. url .. " Error: " .. strError)
	   end

	   if (strData == "") then
		  print("FAILED -- No Data returned")
	   end
	   --convert_to_array(strData)
	   
	   if (type=="metadata") then
		  array = convert_to_array(strData)
		  --print(dump(array))
		  if (playstate ~= "Idle") then
			 imageURL = "http://"..Properties["Server IP"].."/art/"..Properties["Device ID"].."/art.png"
			 array["Image"] = C4:Base64Encode(imageURL.."?"..C4:Base64Encode(array["Title"]))
		  else
			 array["Image"] = nil
		  end
		  --print("IMAGE URL: "..array["Image"])
		  UpdateMediaInfo(array)
		  UpdateQueue(array)
		  UpdateDashboard(array)
		  UpdateProgress(array["Position"])
		  preMakeImageList()
		  print("URL Success: metadata")
	   
	   elseif (type=="artwork") then
		  --print("Starting Artwork Poll.")
	   
		  a = strData:match("',%s(.*)")
            --print("Result: "..a)

            b = a:match("',%s(.*)")

		  --print("Restult2: "..b)

            c,d = b:match("([^,]+),([^,]+)")

            d = d:sub(1, -2)

            --print("Restult3: "..c)
            --print("Result4: "..d)
		  e = c:match("=(.*)")
		  f = d:match("=(.*)")
		  print("Final dimensions: "..e.."x"..f)
		  
		  art_url = "http://"..Properties["Server IP"].."/art/"..Properties["Device ID"].."/art.png"
		  art_url = art_url.."?"..C4:Base64Encode(array["Title"])
		  
		  artwork_info["width"] = e
		  artwork_info["height"] = f
		  artwork_info["url"] = art_url
		  
		  --print("Calling MakeImageList")
		  print("URL Success: Artwork Stats")
	   else
		  print("URL type did not match. type: "..type)
		  return "success"
	   end
    end

end

function convert_to_array(data)
arr1 = {}

for line in data:gmatch("([^\n]*)\n?") do

  if (line ~= "") then
    a,b = line:match("%s+(.-):%s(.+)")
    arr1[a] = b
    --print(a..": "..b)
  
  else
  end
  
end
--print(arr1["Title"])
--print(dump(arr1))
return arr1
end

function pollMediaInfoJSON()
    
    url = Properties["Server IP"].."/playing/"..Properties["Device ID"]
    print("---Poll Media---")
    C4:urlGet(url)
    function ReceivedAsync(ticketId, strData)
	   array = JSON:decode(strData)
	   print("Result: "..array["result"])
	   hash = array["hash"]
	   array["hash"] = C4:Base64Encode(hash)
	   if (array["device_state"] ~= "Idle") then
		  imageURL = "http://"..Properties["Server IP"].."/art/"..Properties["Device ID"].."/art.png"
		  array["ImageUrl"] = imageURL
		  array["image"] = C4:Base64Encode(imageURL.."?"..array["hash"])
	   else
		  array["image"] = nil
	   end
	   --print("IMAGE URL: "..array["Image"])
	   if (init == "new") then
		  preMakeImageList(array)
	   end
	   --print("0")
	   UpdateMediaInfo(array)
	   --print("1")
	   UpdateQueue(array)
	   --print("2")
	   UpdateDashboard(array)
	   --print("3")
	   UpdateProgress(array)
	   --print("4")
	   device_array = array
	   print("---Polling Complete---")
	   init = "old"
    end

end

function pollMediaInfo(source,navId,roomId,seq)
    
    url = Properties["Server IP"].."/playing1/"..Properties["Device ID"]
    print("---Poll Media---")
    C4:urlGet(url)
    function ReceivedAsync(ticketId, strData)
	   array = convert_to_array(strData)
	   --print("Result: "..array["result"])
	   array["hash"] = C4:Base64Encode(array["Title"])
	   if (array["Device state"] ~= "Idle") then
		  imageURL = "http://"..Properties["Server IP"].."/art/"..Properties["Device ID"].."/art.png"
		  array["ImageUrl"] = imageURL
		  array["image"] = C4:Base64Encode(imageURL.."?"..array["hash"])
	   else
		  array["image"] = nil
	   end
	   --print("IMAGE URL: "..array["Image"])
	   if (init == "new") then
		  preMakeImageList(array)
	   end
	   array["Device state"] = array["state"]
	   array["total_time"] = 0
	   --print("0")
	   
	   if (source == "proxy") then
		  print("Media request from proxy")
		  UpdateMediaInfo(array)--,navId,roomId,seq)
		  UpdateQueue(array)--,navId,roomId,seq)
		  UpdateDashboard(array)--,navId,roomId,seq)
		  UpdateProgress(array)--,navId,roomId,seq)
	   end
	   
	   if (device_array["Title"] == array["Title"]) then
		  print("Arrays equal, not updating")
	   else
		  print("Arrays not equal, updating")
		  UpdateMediaInfo(array)--,navId,roomId,seq)
		  UpdateQueue(array)--,navId,roomId,seq)
		  UpdateDashboard(array)--,navId,roomId,seq)
		  --device_array = array
	   end
	   
	   if (device_array["Position"] == array["Position"]) then
		  print("Progress equal, not updating")
	   else
		  print("Progress not equal, updating")
		  UpdateProgress(array)--,navId,roomId,seq)
		  UpdateDashboard(array)
	   end
	   device_array = array
	   C4:SetVariable("Play State", array["Device state"])
	   C4:SetVariable("Media Type", array["Media type"])
	   print("---Polling Complete---")
	   init = "old"
    end

end

function preMakeImageList(array)
    url = Properties["Server IP"].."/art/"..Properties["Device ID"].."/stats"
    C4:urlGet(url)
    function ReceivedAsync(ticketId, strData)
		  --print("Starting Artwork Poll.")
	   a = strData:match("',%s(.*)")
		  --print("Result: "..a)
	   b = a:match("',%s(.*)")
		  --print("Restult2: "..b)
	   c,d = b:match("([^,]+),([^,]+)")
	   d = d:sub(1, -2)
		  --print("Restult3: "..c)
		  --print("Result4: "..d)
	   e = c:match("=(.*)")
	   f = d:match("=(.*)")
	   print("Final dimensions: "..e.."x"..f)
		  
	   art_url = "http://"..Properties["Server IP"].."/art/"..Properties["Device ID"].."/art.png"
	   art_url = art_url.."?"..array["hash"]
			 
	   artwork_info["width"] = e
	   artwork_info["height"] = f
	   artwork_info["url"] = art_url
			 
	   --print("Calling MakeImageList")
	   print("URL Success: Artwork Stats")
    end
end

function remote(cmd)

    url = Properties["Server IP"].."/remote_control/"..Properties["Device ID"].."/"..cmd
    C4:urlGet(url, {}, false,

       function(ticketId, strData, responseCode, tHeaders, strError)

             if (strError == nil) then

                    --pollMediaInfo()

             else

                    print("C4:urlGet() failed: " .. strError)

             end

       end
    )

end

already_started = "no"
function RefreshInterval(cmd)
    --timer0 = nil
    if (already_started == "no") then
	   already_started = "yes"
	   
	   C4:SetTimer(1000, function(timer)
         pollMediaInfo()
	    if (already_started == "no") then
		  timer:Cancel()
		  print("Stopping timer. Step 2")
	    end
	   end, true)

	   print("Starting timer.")
    
    elseif (cmd == "stop") then
	   already_started = "no"
	   print("Stopping timer. Step 1")
    else
    end

end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end