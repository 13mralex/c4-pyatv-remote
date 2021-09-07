MEDIA_SERVICE_PROXY_BINDING_ID = 5001

JSON=require "json"

function gettext(key)
	return key
end

function JSON:assert()
	-- We don't want the JSON library to assert but rather return nil in case of parsing errors
end

g_status = nil
g_name = nil
g_ignoreSourceVolume = true
g_controllerValid = true

function UpdateStatus(status)
	if (not g_controllerValid) then
		C4:UpdateProperty("Status", "This driver is not supported on this controller or version.")
	else
		C4:UpdateProperty("Status", status or g_status or "Unknown")
	end
end

----------------------------------------- Misc ---------------------------------

g_roomMapInfo = nil

function OnWatchedVariableChanged(idDevice, idVariable, strValue)
	if (idDevice == 100002) then
		if (idVariable == 1009) then
			-- Update the room map
			local oldMap = g_roomMapInfo
			if (string.len(strValue) > 0) then
				g_roomMapInfo = C4:ParseXml(strValue)
			else
				g_roomMapInfo = nil
			end
		end
	end
end

function stopDebugTimer()
	if (g_DebugTimer) then
		g_DebugTimer:Cancel()
		g_DebugTimer = nil
	end
end
   
function startDebugTimer()
	stopDebugTimer()
	g_DebugTimer = C4:SetTimer(15 * 60 * 1000, function(timer)
		g_DebugTimer = nil
		dbg("Turning Debug Mode back to Print [default] (timer expired)")
		C4:UpdateProperty("Debug Mode", "Print")
	end)
end

function dbg(strDebugText)
  if (g_debugprint) then print(os.date("%x %X") .. " " .. strDebugText) end
  if (g_debuglog) then C4:ErrorLog(strDebugText) end
end

function PrintPacket(msg, packet)
  if (g_debugprint) then
	 print("........Hex Packet: " .. msg)
	 hexdump(packet)
  end
end

function OnPropertyChanged(strProperty, init)
	if (strProperty == "Debug Mode") then
		if (Properties[strProperty] == "Off") then
			g_debugprint = false
			g_debuglog = false
			stopDebugTimer()
		 end
		 if (Properties[strProperty] == "Print") then
			g_debugprint = true
			g_debuglog = false
			startDebugTimer()
		 end
		 if (Properties[strProperty] == "Log") then
			g_debugprint = false
			g_debuglog = true
			startDebugTimer()
		 end
		 if (Properties[strProperty] == "Print and Log") then
			g_debugprint = true
			g_debuglog = true
			startDebugTimer()
		 end
	elseif (strProperty == "Broadcast Name") then
		if (g_name ~= Properties[strProperty]) then
			g_name = Properties[strProperty]
			C4:InvalidateState()
			if (not init) then
				restartInstance()
			end
		end
	elseif (strProperty == "Auto Room(s) Select") then
		C4:InvalidateState()
	elseif (strProperty == "Ignore Source Volume") then
		C4:InvalidateState()
		local value = Properties[strProperty] == "True"
		if (g_ignoreSourceVolume ~= value) then
			g_ignoreSourceVolume = value
			if (not init) then
				restartInstance()
			end
		end
	--elseif(strProperty == "Disabled") then
	--	if (Properties[strProperty] == "True") then
	--		SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "DISABLE_DRIVER", {}, "COMMAND")
	--	elseif (CheckControllerTypeAndVersion() ) then
	--		SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "ENABLE_DRIVER", {}, "COMMAND")
	--	end
	--	C4:InvalidateState()
	elseif (strProperty == "Auto Room(s) Off") then
		C4:InvalidateState()
	end
end

function ExecuteCommand(strCommand, tParams)
	dbg("ExecuteCommand function called with : " .. strCommand)
	if (tParams == nil) then
		if (strCommand =="GET_PROPERTIES") then
		--nyi CMDS.GET_PROPERTIES()
		print()
		else
			print ("From ExecuteCommand Function - Unutilized command: " .. strCommand)
		end
	end
	if (strCommand == "LUA_ACTION") then
		if tParams ~= nil then
			for cmd,cmdv in pairs(tParams) do
				print (cmd,cmdv)
				if cmd == "ACTION" then
					proxyDev = C4:GetProxyDevices()
					if (proxyDev) then
					  C4:MediaSetDeviceContext(proxyDev)
					end

					dbg("From ExecuteCommand Function - Undefined Action")
					dbg("Key: " .. cmd .. "  Value: " .. cmdv)
				else
					dbg("From ExecuteCommand Function - Undefined Command")
					dbg("Key: " .. cmd .. "  Value: " .. cmdv)
				end
			end
		end
	elseif (strCommand == "Select") then
		Select(tParams)
	end
end

----------------------------------------- Other Functions -----------------------------------------

g_instances = {}

function restartInstance()
	stopAllInstances(function()
		startInstance(g_name, function(err, inst)
			if (err ~= nil) then
				UpdateStatus(err)
			end
		end)
	end)
end

function stopInstance(name, callback)
	local inst = g_instances[name]
	if (inst ~= nil) then
		dbg("Stopping instance " .. tostring(name) .. "...")
		inst:disconnect(false, function()
			dbg("Instance " .. tostring(name) .. " stopped.")
			if (callback) then
				callback()
			end
		end)
	end
end

function stopAllInstances(callback)
	local cnt = 0
	local stoppedHandler = function()
		cnt = cnt - 1
		if (cnt == 0) then
			dbg("All instances stopped.")
			if (callback) then
				callback()
			end
		end
	end
	for name,_ in pairs(g_instances) do
		cnt = cnt + 1
		stopInstance(name, stoppedHandler)
	end
	if (cnt == 0 and callback) then
		dbg("No instances to stop.")
		C4:CallAsync(callback)
	end
end

function startInstance(name, done)
	if (not g_controllerValid) then
		dbg("Cannot start instance " .. tostring(name) .. ": Controller is not supported!")
		C4:CallAsync(function()
			done("Controller is not supported!")
		end)
		return
	end
	
	if (name == nil or string.len(name) == 0) then
		name = GetBroadcastName()
	end
	
	local inst = g_instances[name]
	if (inst ~= nil) then
		dbg("Starting instance " .. tostring(name) .. ": Already running.")
		C4:CallAsync(function()
			done(nil, inst)
		end)
	else
		dbg("Starting instance " .. tostring(name) .. "...")
		local cli = C4:CreateTCPClient()
		
		local startReconnect = function()
			UpdateStatus("Reconnecting to instance...")
			C4:SetTimer(1000, function()
				if (g_instances[name] == inst) then
					cli:Connect("!local", 6730)
				end
			end)
		end
		
		inst = {
			_reading = false,
			_connected = false,
			--_startRetryTimer = nil,
			--_onStartDone = nil,
			--_startLastErr = nil,
			_error = false,
			_reconnect = true,
			_responseHandlers = {},
			_asyncData = {},
			--_url = nil,
			--_onAsync = nil,
			--_onDisconnect = nil,
			--_onStopped = nil,
			--_onConnect = nil,
			--_onRestarted = nil,
			onAsync = function(self, cb)
				self._onAsync = cb
			end,
			onConnect = function(self, cb)
				self._onConnect = cb
			end,
			onDisconnect = function(self, cb)
				self._onDisconnect = cb
			end,
			restart = function(self, cb)
				dbg("Restarting instance " .. tostring(name))
				self._reconnect = true
				if (cb ~= nil) then
					if (self._onRestarted == nil) then
						self._onRestarted = {}
					end
					table.insert(self._onRestarted, cb)
				end
				cli:Close()
				C4:CallAsync(function()
					if (g_instances[name] == self) then
						cli:Connect("!local", 6730)
					end
				end)
			end,
			disconnect = function(self, err, cb)
				self._reconnect = false
				self._error = err
				if (cb ~= nil) then
					if (self._onStopped == nil) then
						self._onStopped = {}
					end
					table.insert(self._onStopped, cb)
				end
				cli:Close()
			end,
			url = function(self)
				return self._url or ""
			end,
			send = function(self, data, done)
				if (done ~= nil) then
					table.insert(self._responseHandlers, done)
				end
				cli:Write(JSON:encode(data) .. "\0")
				if (not self._reading) then
					self._reading = true
					local ret = cli:ReadUntil("\0")
				end
			end,
			_callRestartHandlers = function(self, err)
				if (self._onRestarted ~= nil) then
					for i = 1, #self._onRestarted do
						pcall(self._onRestarted[i], err)
					end
					self._onRestarted = nil
				end
			end,
			detach = function(self)
				self._onAsync = nil
				self._onConnect = nil
				self._onDisconnect = nil
				self:_callRestartHandlers("aborted")
			end,
			attach = function(self)
				-- Deliver all cached async data
				if (self._onAsync ~= nil) then
					for i,v in pairs(self._asyncData) do
						self._onAsync({ [i] = v })
					end
				end
			end,
			checkAutoSelect = function(self)
				local roomIds = Properties["Auto Room(s) Select"]
				if (string.len(roomIds) > 0) then
					local queue = findQueueByInstance(self)
					if (queue == nil) then
						dbg("Auto-selecting rooms " .. roomIds)
						StartPlay(name, roomIds, volume, function(err, inst)
							if (err ~= nil) then
								dbg("Auto-selecting failed: " .. tostring(err))
							else
								dbg("Auto-selecting succeeded")
							end
						end)
					end
				end
			end,
			process = function(self, str)
				local data = JSON:decode(str)
				if (data ~= nil) then
					if (data.error ~= nil or data.response ~= nil) then
						if (next(self._responseHandlers) ~= nil) then
							pcall(self._responseHandlers[1], data.error, data.response)
							table.remove(self._responseHandlers, 1)
						else
							dbg("Got response, but no one is listening")
						end
					elseif (data.async ~= nil) then
						if (data.async.status ~= nil) then
							local status = data.async.status.status
							if (status == "playing") then
								self:checkAutoSelect()
							end
							
							self._asyncData["status"] = data.async.status
						end
						if (data.async.progress ~= nil) then
							self._asyncData["progress"] = data.async.progress
						end
						
						if (self._onAsync ~= nil) then
							self._onAsync(data.async)
						end
					end
				else
					dbg("Failed to decode json: " .. str)
				end
				cli:ReadUntil("\0")
			end,
			connected = function(self, done)
				self._reading = false
				self._connected = true
				self._error = false
				self._asyncData = {}
				local attempts = 0
				local reportStartErr, doStart
				reportStartErr = function(reason)
					local details = reason .. " (retry in 15 seconds, #" .. attempts .. ")"
					dbg("Failed to start instance " .. tostring(name) .. ": " .. details)
					UpdateStatus("Failed to start instance: " .. details)
					
					self._startLastErr = reason
					self._onStartDone = done
					self._startRetryTimer = C4:SetTimer(15 * 1000, doStart)
					
					self:_callRestartHandlers(reason)
				end
				doStart = function()
					attempts = attempts + 1
					self:send({ method = "start", args = { name = name, ignore_volume = g_ignoreSourceVolume }}, function(err, data)
						if (self._startRetryTimer ~= nil) then
							self._startRetryTimer:Cancel()
							self._startRetryTimer = nil
						end
						
						if (not self._connected) then
							reportStartErr("Connection lost");
						elseif (err ~= nil) then
							reportStartErr(tostring(err.detail or err.message))
						else
							self._onStartDone = nil
							self._startLastErr = nil

							dbg("Instance " .. tostring(name) .. " running.")
							UpdateStatus("Instance running")
							self._url = data.url
							if (done ~= nil) then
								done(nil, self)
							end
							if (self._onConnect ~= nil) then
								self._onConnect()
							end
							
							self:_callRestartHandlers(nil)
						end
					end)
				end
				
				doStart()
			end,
			disconnected = function(self)
				self._connected = false
				if (self._startRetryTimer ~= nil) then
					self._startRetryTimer:Cancel()
					self._startRetryTimer = nil
				end
				if (self._onStartDone ~= nil) then
					local done = self._onStartDone
					self._onStartDone = nil
					done(self._startLastErr or "Unknown error")
				end
				if (self._reconnect) then
					if (self._onDisconnect ~= nil) then
						self._onDisconnect(true)
					end
					startReconnect()
				else
					g_instances[name] = nil
					if (self._onDisconnect ~= nil) then
						self._onDisconnect(false)
					end
					
					if (not self._error) then
						UpdateStatus("Instance terminated")
					end
					
					if (self._onStopped ~= nil) then
						for i = 1, #self._onStopped do
							self._onStopped[i]()
						end
					end
				end
			end
		}
		
		g_instances[name] = inst
		
		local firstConnected = true
		cli
			:OnConnect(function(cli)
				if (firstConnected) then
					firstConnected = false
					inst:connected(done)
				else
					inst:connected(nil)
				end
			end)
			:OnError(function(cli, code, msg)
				startReconnect()
			end)
			:OnDisconnect(function(cli)
				inst:disconnected()
			end)
			:OnRead(function(cli, data)
				inst:process(data)
			end)
			:Connect("!local", 6730)
	end
end

function string.is_nil_or_empty(str)
	return str == nil or str:len() == 0
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,Sub)
  return string.sub(String,string.len(String)-string.len(Sub)+1)==Sub
end

function string.split(str, sep)
	local ret = {}

	if (#str > 0) then
		local pos = 1
		while true do
			local found = string.find(str, sep, pos, true)
			if (found ~= nil) then
				table.insert(ret, string.sub(str, pos, found - 1))
				pos = found + #sep
			else
				table.insert(ret, string.sub(str, pos))
				break
			end
		end
	end
	
	return ret
end

-- string.make_localizable is called by a driver's lua code to build a string that navigators can localize
function string.make_localizable(str, vars)
	-- Escape the translatable string
	local ret = "#!\"" .. str:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\""
	if (vars) then
		-- Add on the variables and escape their values
		for var,value in pairs(vars) do
			ret = ret .. ";" .. var .. "=\"" .. value:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\""
		end
	end
	return ret
end

function string.do_not_localize(str)
	return string.make_localizable("{S}", { ["S"] = str })
end

function array_contains(arr, val)
	for i = 1, #arr do
		if (arr[i] == val) then
			return true
		end
	end
	return false
end

function url_parse(url)
	local sep = string.find(url, "://", 1, true)
	if (sep ~= nil) then
		local proto = string.sub(url, 1, sep - 1)
		local path = string.split(string.sub(url, sep + 3), "/")
		local host, port
		if (#path > 0) then
			sep = string.find(path[1], ":")
			if (sep ~= nil) then
				host = string.sub(path[1], 1, sep - 1)
				port = string.sub(path[1], sep + 1)
			else
				host = path[1]
			end
			table.remove(path, 1)
		end
		return proto, host, port, path
	end
end

-- Release things this driver had allocated...
function OnDriverDestroyed()
  Navigator:Destroy()
end

function SendToProxy(idBinding, strCommand, tParams, ...)
	--dbg("SendToProxy (" .. idBinding .. ", " .. strCommand .. ")")
	if ... then
		local callType = ...
		C4:SendToProxy(idBinding, strCommand, tParams, callType)
		--print("CALLTYPE: "..callType)
	else
		C4:SendToProxy(idBinding, strCommand, tParams)
	end
	print("---SEND TO PROXY "..idBinding.."---")
	print("-CMD: "..strCommand.." -PARAMS: "..dump(tParams))
	print("-------------------")
end

function DataReceivedError(idBinding, navId, seq, msg)
	local tParams = {}
	tParams["NAVID"] = navId
	tParams["SEQ"] = seq
	tParams["DATA"] = ""
	tParams["ERROR"] = msg
	SendToProxy(idBinding, "DATA_RECEIVED", tParams)
end

function DataReceived(idBinding, navId, seq, tdata)
	local tParams = {}
	tParams["NAVID"] = navId
	tParams["SEQ"] = seq
	
	if (tdata ~= nil) then
		if (type(tdata) == "table") then
			local data = ""
			for i,v in pairs(tdata) do
				data = data .. "<" .. i .. ">" .. v .. "</" .. i .. ">"
			end
			tParams["DATA"] = data
		else
			tParams["DATA"] = tostring(tdata)
		end
	else
		tParams["DATA"] = ""
	end
	--dbg("DATA_RECEIVED: " .. tParams["DATA"])
	SendToProxy(idBinding, "DATA_RECEIVED", tParams)
end

function UpdateMediaInfoForQueue(idBinding, queueId, info, streaming, force)
	local tParams = {}
	dbg("UpdateMediaInfoForQueue(idBinding: " .. idBinding .. " queue: " .. queueId)
	tParams["QUEUEID"] = queueId
	--if (info ~= nil) then
	--	tParams["IMAGEURL"] = info.image
	--	tParams["LINE1"] = info.line1
	--	tParams["LINE2"] = info.line2
	--	tParams["LINE3"] = info.line3
	--	tParams["LINE4"] = info.line4
	--end
	if (info ~= nil) then
		tParams["IMAGEURL"] = "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/SNice.svg/1200px-SNice.svg.png"
		tParams["LINE1"] = "LINE1"
		tParams["LINE2"] = "LINE2"
		tParams["LINE3"] = "LINE3"
		tParams["LINE4"] = "LINE4"
	end
	if (string.is_nil_or_empty(tParams["IMAGEURL"])) then
		tParams["IMAGEURL"] = string.format("http://%s/driver/ShairBridge/icons/default_cover_art/default_cover_art.png", C4:GetControllerNetworkAddress())
	end
	if (info == nil or (string.is_nil_or_empty(info.line1) and string.is_nil_or_empty(info.line2))) then
		if (streaming) then
			tParams["LINE1"] = C4:GetDeviceDisplayName(0)
			tParams["LINE2"] = "Now streaming"
		else
			force = true
		end
	end
	if (force) then
		tParams["FORCE"] = "true"
	end
	SendToProxy(idBinding, "UPDATE_MEDIA_INFO", tParams, "COMMAND")
end

----------------------------------------- Navigator Events -----------------------------------------

function SendEvent(idBinding, navId, tRooms, name, tArgs, needEscape)
	-- This function must have a registered navigator event set up
	local tParams = {}
	if (navId ~= nil) then
		tParams["NAVID"] = navId
		--dbg("SendEvent " .. name .. " to navigator " .. navId)
	elseif (tRooms ~= nil) then
		local rooms = table.concat(tRooms, ",")
		if (string.len(rooms) > 0) then
			tParams["ROOMS"] = rooms
		end
		--dbg("SendEvent " .. name .. " to navigators in rooms " .. rooms)
	else
		--dbg("SendEvent " .. name .. " to all navigators (broadcast)")
	end
	tParams["NAME"] = name
	tParams["EVTARGS"] = BuildSimpleXml(nil, tArgs, needEscape)
	--print("---SEND EVENT---")
	--print("-tParams: "..dump(tParams))
	--print("----------------")
	SendToProxy(idBinding, "SEND_EVENT", tParams, "COMMAND")
end

function BroadcastEvent(idBinding, name, tArgs, needEscape)
	SendEvent(idBinding, nil, nil, name, tArgs, needEscape)
end

function GetBroadcastName()
	local name = Properties["Broadcast Name"]
	if (name == nil or string.len(name) == 0) then
		name = C4:GetDeviceDisplayName(0)
	end
	return name
end

function StartPlay(name, roomIds, volume, callback)
	local queue, rids, joinRooms
	
	if (name == nil) then
		name = GetBroadcastName()
	end
	
	if (roomIds ~= nil) then
		rids = string.split(roomIds, ",")
		if (rids ~= nil and #rids > 0) then
			for i=1, #rids do
				local rid = rids[i]
				local queueId = GetQueueFromRoom(nil, rid)
				if (queueId ~= 0) then
					queue = g_queues[queueId]
					if (queue ~= nil) then
						break
					end
				end
			end
		end
	end
	
	if (queue == nil) then
		for id,q in pairs(g_queues) do
			-- Have a queue already, join the room(s) if they are not already in the queue
			queue = q
			break
		end
	end
	
	if (queue ~= nil and rids ~= nil) then
		local queueRoomIds = GetRoomsByQueue(nil, queue.id)
		if (queueRoomIds ~= nil and #queueRoomIds > 0) then
			-- Check if any of the roomIds passed in are not yet in the queue
			joinRooms = {}
			for j=1, #rids do
				local inQueue = false
				local qrid = rids[j]
				for k=1, #queueRoomIds do
					if (queueRoomIds[k] == qrid) then
						inQueue = true
						break
					end
				end
				
				if (not inQueue) then
					-- Room is not in the queue, so add it to the list of rooms that need to be joined
					table.insert(joinRooms, qrid)
				end
			end
		end
	end
	
	if (queue ~= nil) then
		if (joinRooms ~= nil) then
			-- joinRooms might be an empty array, in which case no action is needed...
			queue:join(joinRooms)
		else
			queue:play(nil, nil)
		end
		callback(nil, false)
	else
		queue = {
			--id = nil,
			--queuestate = nil,
			--apstate = nil,
			--inst = nil,
			--roomOffTimer = nil,
			--roomOffTimerCount = nil,
			metadata = {},
			dashboard = "",
			deleted = false,
			updated = {},
			attaching = false
		}
		function queue:initialize(rids)
			self.queuestate = nil
			self.apstate = nil
			self.metadata = {}
			self.dashboard = ""
			self.updated = {}
		end
		function queue:destroy()
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:destroy()")
			self:stopRoomOffTimer()
			self.deleted = true
			self.queuestate = nil
			self.apstate = nil
			if (self.inst ~= nil) then
				-- Restarting triggers the device to be kicked off
				dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]: Kicking device off")
				self.inst:restart(function(err)
					if (err == nil) then
						dbg("Instance was restarted")
					else
						dbg("Failed to restart instance: " .. tostring(err))
					end
				end)
			end
			self.inst = nil
			self:updateDashboard() -- Clear the media dashboard
		end
		function queue:resetUpdated()
			self.updated = {}
		end
		function queue:runUpdated()
			local upd = self.updated
			self.updated = {}
			local ret = {}
			for tpe,func in pairs(upd) do
				table.insert(ret, tpe)
				pcall(func)
			end
			return ret
		end
		function queue:shutOff()
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:shutOff()")
			self.deleted = true
			self.inst = nil
			if (self.id ~= nil) then
				local tRooms = GetRoomsByQueue(nil, self.id)

				C4:SendToDevice(100002, "REMOVE_QUEUE", { ["QUEUE_ID"] = self.id })

				-- Send a ROOM_OFF to each of the rooms as well
				if (tRooms ~= nil) then
					for i = 1, #tRooms do
						C4:SendToDevice(tRooms[i], "ROOM_OFF", {})
					end
				end
			end
		end
		function queue:isConnected()
			local ret = self.apstate ~= nil and self.apstate == "playing"
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:isConnected() returns " .. tostring(ret))
			return ret
		end
		function queue:haveMetadata()
			for i,v in pairs(self.metadata) do
				return true
			end
			return false
		end
		function queue:getNowPlayingItems()
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:getNowPlayingItems()")
			local ret = {}
			
			if (not self:isConnected()) then
				table.insert(ret, {
					["title"] = gettext("Please start streaming...")
				})
			elseif (not self:haveMetadata()) then
				table.insert(ret, {
					["title"] = gettext("Now streaming")
				})
			else
				table.insert(ret, {
					["title"] = self.metadata.line1,
					["subtitle"] = self.metadata.line2,
					["image"] = self.metadata.image
				})
			end
			local playingIndex = 0
			local nowPlayingData = {}
			return ret, playingIndex, nowPlayingData
		end
		function queue:doUpdate(tpe, func)
			if (self.attaching) then
				self.updated[tpe] = func
			else
				func()
			end
		end
		function queue:getDashboardByState(state)
			if (state == nil) then
				return "" -- queue is being destroyed
			end
			
			local ret = {}
			table.insert(ret, "SkipRev")
			if (state == "playing") then
				table.insert(ret, "Pause")
			else
				table.insert(ret, "Play")
			end
			table.insert(ret, "SkipFwd")

			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:getDashboardByState(" .. state .. ") returns " .. table.concat(ret, " "))
			return table.concat(ret, " ")
		end
		function queue:updateDashboard()
			local dashboard = self:getDashboardByState(self.apstate)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:updateDashboard() " .. self.dashboard .. " => " .. dashboard)
			if (dashboard ~= self.dashboard) then
				self.dashboard = dashboard
				self:doUpdate("dashboard", function()
					DashboardChanged(self.id, self.dashboard)
				end)
			end
		end
		function queue:updateMediaInfo(force)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:updateMediaInfo()")
			self:doUpdate("media", function()
				local metadata
				local connected = self:isConnected()
				if (connected and self.metadata.line1 ~= nil) then
					metadata = self.metadata
				end
				UpdateMediaInfoForQueue(MEDIA_SERVICE_PROXY_BINDING_ID, self.id, metadata, connected, force)
			end)
		end
		function queue:queueStateChanged(prevState, newState)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:queueStateChanged() " .. tostring(prevState) .. " => " .. newState)
			self.queuestate = newState
			self:updateDashboard()
			self:updateMediaInfo(true)
		end
		function queue:stopRoomOffTimer()
			if (self.roomOffTimer ~= nil) then
				self.roomOffTimer:Cancel()
				self.roomOffTimer = nil
				self.roomOffTimerCount = nil
				dbg("Canceled room off timer")
			end
		end
		function queue:getRoomOffSetting()
			return tonumber(Properties["Auto Room(s) Off"] or "1441")
		end
		function queue:startRoomOffTimer()
			local function cancelTimerAndTurnOff(reason)
				if (self.roomOffTimer ~= nil) then
					self.roomOffTimer:Cancel()
					self.roomOffTimer = nil
					self.roomOffTimerCount = nil
				end
				dbg(reason)
				self:shutOff()
			end
			
			local val = self:getRoomOffSetting()
			if (val == 0) then
				cancelTimerAndTurnOff("Turn off room with no delay")
			elseif (val ~= 1441 and self.roomOffTimer == nil) then
				dbg("Starting room off timer")
				self.roomOffTimerCount = 0
				self.roomOffTimer = C4:SetTimer(60 * 1000, function(tmr)
					local setting = self:getRoomOffSetting()
					if (not self.deleted and self.roomOffTimer ~= nil and self.roomOffTimerCount ~= nil) then
						self.roomOffTimerCount = self.roomOffTimerCount + 1
						if (setting == 0) then
							cancelTimerAndTurnOff("Turn off room with no delay (room off timer)")
						elseif (setting == 1441) then
							cancelTimerAndTurnOff("Cancel room off timer, it is now disabled (room off timer)")
						elseif (self.roomOffTimerCount >= setting) then
							cancelTimerAndTurnOff("Turn off room now (room off timer)")
						end
					else
						tmr:Cancel()
					end
				end, true)
			end
		end
		function queue:apStateChanged(prevState, newState)
			--dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:apStateChanged() " .. tostring(prevState) .. " => " .. newState)
			self.apstate = newState
			if (self.apstate == "playing") then
				UpdateStatus("Streaming");
				self:stopRoomOffTimer()
			else
				UpdateStatus("Stopped streaming");
				if (not self.attaching) then
					self:startRoomOffTimer()
				end
			end
			self:updateDashboard()
			self:updatePlayQueue()
			self:updateMediaInfo(true)
			if (prevState ~= newState) then
				self:updateProgress(nil)
			end
		end
		function queue:updatePlayQueue()
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:updatePlayQueue()")
			self:doUpdate("queue", function()
				Navigator:SendQueueChangedEvent(self.id)
			end)
		end
		function queue:updateProgress(progress)
			--dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:updateProgress()")
			self:doUpdate("progress", function()
				if (progress ~= nil) then
					Navigator:SendProgressEvent(self.id, progress.current, progress.length)
				else
					Navigator:SendProgressEvent(self.id, nil, nil)
				end
			end)
		end
		function queue:join(roomIds)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:join()")
			if (not JoinRoomsToQueue(self.id, roomIds)) then
				dbg("Could not join room(s) " .. table.concat(roomIds, ",") .. " to queue, try playing instead")
				self:play(roomIds, nil)
			end
		end
		function queue:play(roomIds, volume)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:play()")
			UpdateStatus("Starting instance...")
			startInstance(name, function(err, inst)
				if (err == nil) then
					inst:onAsync(function(data)
						if (data.progress ~= nil) then
							self:updateProgress(data.progress)
						elseif (data.metadata ~= nil) then
							local lns = {}
							if (data.metadata.title ~= nil and string.len(data.metadata.title) > 0) then
								table.insert(lns, data.metadata.title)
							end
							if (data.metadata.artist ~= nil and string.len(data.metadata.artist) > 0) then
								table.insert(lns, data.metadata.artist)
							end
							if (data.metadata.album ~= nil and string.len(data.metadata.album) > 0) then
								table.insert(lns, data.metadata.album)
							end
							if (data.metadata.genre ~= nil and string.len(data.metadata.genre) > 0) then
								table.insert(lns, data.metadata.genre)
							end
							if (data.metadata.comments ~= nil and string.len(data.metadata.comments) > 0) then
								table.insert(lns, data.metadata.comments)
							end
							
							for i,_ in pairs(self.metadata) do
								if (string.starts(i, "line")) then
									self.metadata[i] = nil
								end
							end
							
							for i = 1, #lns do
								self.metadata["line" .. i] = lns[i]
							end
							self:updateMediaInfo(false)
							self:updatePlayQueue()
						elseif (data.coverart ~= nil) then
							if (data.coverart.url ~= nil) then
								-- Generate a new "unique" URL each time...
								if (g_coverart_url_counter == nil) then
									g_coverart_url_counter = 1
								else
									g_coverart_url_counter = g_coverart_url_counter + 1
								end
								--self.metadata.image = data.coverart.url .. "?random=" .. g_coverart_url_counter
								local proto, host, port, path = url_parse(data.coverart.url)
								if (proto == "http" and (host == "director" or host == "localhost" or host == "127.0.0.1")) then
									self.metadata.image = "controller:" .. (port or "") .. "//" .. table.concat(path, "/") .. "?random=" .. g_coverart_url_counter
								else
									self.metadata.image = data.coverart.url .. "?random=" .. g_coverart_url_counter
								end
							else
								self.metadata.image = nil
							end
							dbg("coverart url: " .. tostring(self.metadata.image))
							self:updateMediaInfo(false)
							self:updatePlayQueue()
						elseif (data.status ~= nil) then
							local prevState = self.apstate
							self:apStateChanged(prevState, data.status.status)
						end
					end)
					inst:onDisconnect(function(reconnect)
						print("Disconnected from instance " .. name)
						if (not reconnect) then
							self:shutOff()
						end
					end)
					
					UpdateStatus("Instance started, starting playback...")
					
					local startPlayback = function()
						if (not self.deleted) then
							self.inst = inst
							SelectInternetRadio(self.id, roomIds, inst:url(), volume, self,
								function(queueId, info, context)
									if (self.deleted) then
										dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:play(): Queue was deleted")
										self.id = queueId
										self:shutOff()
									elseif (queueId ~= nil) then
										dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:play(): Playing URL " .. inst:url() .. " in queue " .. queueId)
										
										self.id = queueId
										
										-- Set the state to PLAY because we won't get a state change event if we're switching the queue from another MSP driver.
										-- This fixes the dashboard not showing up in such cases.
										self.queuestate = "PLAY"
										
										self:resetUpdated()
										
										self.attaching = true
										inst:attach()
										self.attaching = false
										
										-- Manually send updates if they haven't been triggered already
										local ran = self:runUpdated()
										if (not array_contains(ran, "queue")) then
											self:updatePlayQueue()
										end
										if (not array_contains(ran, "dashboard")) then
											self:updateDashboard()
										end
										
										self:updateMediaInfo(true)
										
										return {
											onQueueDeleted = function(queueId, info)
												dbg("StartPlay:onQueueDeleted: queue " .. queueId)
												info:destroy()	
												Navigator:SendQueueChangedEvent(queueId)
											end,
											onQueueStatusChanged = function(queueId, info, prevState, newState)
												dbg("StartPlay:onQueueStatusChanged: queue " .. queueId .. ": " .. prevState .. " -> " .. newState)
												info:queueStateChanged(prevState, newState)
											end,
											onQueueMediaInfoUpdated = function(queueId, info, mediaInfo)
												--dbg("StartPlay:onQueueMediaInfoUpdated: queue: " .. queueId .. " mediaInfo: " .. tostring(mediaInfo))
											end
										}
									end
								end, nil)
						end
					end
					
					startPlayback()
					
					inst:onConnect(startPlayback) -- update the playback url on a reconnect
				end
			end)
		end
		function queue:PLAY(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:PLAY()")
			if (self.inst ~= nil) then
				self.inst:send({ method = "play" })
			end
			return true
		end
		function queue:PAUSE(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:PAUSE()")
			if (self.inst ~= nil) then
				self.inst:send({ method = "pause" })
			end
			return true
		end
		function queue:STOP(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:STOP()")
			if (self.inst ~= nil) then
				self.inst:send({ method = "stop" })
			end
			return true
		end
		function queue:SKIP_FWD(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:SKIP_FWD()")
			if (self.inst ~= nil) then
				self.inst:send({ method = "nextitem" })
			end
			return true
		end
		function queue:SKIP_REV(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:SKIP_REV()")
			if (self.inst ~= nil) then
				self.inst:send({ method = "previtem" })
			end
			return true
		end
		function queue:SHUFFLE_ON(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:SHUFFLE_ON()")
			--self:setShuffle(roomId, true)
			return false
		end
		function queue:SHUFFLE_OFF(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:SHUFFLE_OFF()")
			--self:setShuffle(roomId, false)
			return false
		end
		function queue:REPEAT_ON(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:REPEAT_ON()")
			--self:setRepeat(roomId, true)
			return false
		end
		function queue:REPEAT_OFF(roomId)
			dbg("Q[" .. tostring(self) .. "::" .. tostring(self.id) .. "]:REPEAT_OFF()")
			--self:setRepeat(roomId, false)
			return false
		end
		
		queue:initialize(rids)
		queue:play(roomIds, volume)
		callback(nil, true)
	end
end

----------------------------------------- Digital Audio ----------------------------------------

g_selectId = 0
g_queueInfoMap = {} -- Map of queue info by selection id
g_queues = {} -- Map of queues by queue id

function findQueueByInstance(inst)
	for _,queue in pairs(g_queues) do
		if (queue.inst == inst) then
			return queue
		end
	end
	for _,info in pairs(g_queueInfoMap) do
		if (info.info.inst == inst) then
			return info.info
		end
	end
end

function JoinRoomsToQueue(queueId, roomIds)
	local tRooms = GetRoomsByQueue(nil, queueId)
	if (tRooms ~= nil and #tRooms > 0 and roomIds ~= nil) then
		if (#roomIds > 0) then
			local tParams = {
				["ROOM_ID"] = tRooms[1],
				["ROOM_ID_LIST"] = table.concat(roomIds, ",")
			}
			C4:SendToDevice(100002, "ADD_ROOMS_TO_SESSION", tParams)
		end
		return true
	end
	return false
end

function SelectInternetRadio(queueId, roomIds, url, volume, info, callback, context)
	g_selectId = g_selectId + 1
	g_queueInfoMap[g_selectId] = {
		callback = callback,
		context = context,
		info = info
	}
	if (roomIds == nil) then
		if (queueId == nil) then
			roomIds = tostring(C4:RoomGetId())
		else
			local tRooms = GetRoomsByQueue(nil, queueId)
			if (tRooms ~= nil) then
				for i,v in pairs(tRooms) do
					if (roomIds == nil) then
						roomIds = tostring(v)
					else
						roomIds = roomIds .. "," .. tostring(v)
					end
				end
				dbg("SelectInternetRadio(): Got rooms from queue " .. queueId .. ": " .. roomIds)
			end
		end
	end
	local tParams = {
		["REPORT_ERRORS"] = true, -- If SELECT_INTERNET_RADIO failed, sends a SELECT_INTERNET_RADIO_ERROR
		["ROOM_ID"] = roomIds,
		["STATION_URL"] = url,
		["QUEUE_INFO"] = g_selectId,
		["VOLUME"] = volume
	}
	SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "SELECT_INTERNET_RADIO", tParams, "COMMAND")
end

function OnSelectInternetRadioError(idBinding, tParams)
	local infoId = tonumber(tParams["QUEUE_INFO"])
	local info = g_queueInfoMap[infoId]
	if (info ~= nil) then
		g_queueInfoMap[infoId] = nil
		if (info.callback ~= nil) then
			info.callback(nil, info.info, info.context)
			info.callback = nil
		end
		info.context = nil
	else
		dbg("OnSelectInternetRadioError: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
	end
end

function OnInternetRadioSelected(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	local infoId = tonumber(tParams["QUEUE_INFO"])
	local info = g_queueInfoMap[infoId]
	if (info ~= nil) then
		info.queueId = queueId
		g_queues[queueId] = info.info
		if (info.callback ~= nil) then
			info.notifications = info.callback(queueId, info.info, info.context)
			info.callback = nil
		end
		info.context = nil
	else
		dbg("OnInternetRadioSelected: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
	end
end

function Select(tParams)
	-- This function is executed by programming
	local roomIds = string.split(tParams["Room(s)"], ",")
	local volume = tonumber(tParams["Volume"])
	if (volume < 0) then
		volume = nil
	end
	if (roomIds ~= nil and #roomIds > 0) then
		StartPlay(nil, table.concat(roomIds, ","), volume, function(err, inst)
			if (err ~= nil) then
				dbg("Select: Error: " .. tostring(err))
			else
				dbg("Select: Playing in room(s) " .. table.concat(roomIds, ",") .. " with volume " .. (volume or "[default]"))
			end
		end)
	else
		dbg("Select: No rooms selected")
	end
end

function OnDeviceSelected(idBinding, tParams)
	StartPlay(nil, tParams["idRoom"], nil, function(err, inst)
		if (err ~= nil) then
			dbg("OnDeviceSelected failed: " .. tostring(err))
		else
			dbg("OnDeviceSelected succeeded")
		end
	end)
end

function OnQueueDeleted(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	local infoId = tonumber(tParams["QUEUE_INFO"])
	local info = g_queueInfoMap[infoId]
	if (info ~= nil) then
		g_queueInfoMap[infoId] = nil
		if (info.queueId ~= nil) then
			g_queues[info.queueId] = nil
		end
		if (info.notifications ~= nil and info.notifications.onQueueDeleted ~= nil) then
			info.notifications.onQueueDeleted(queueId, info.info)
		end
	else
		dbg("OnQueueDeleted: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
	end
end

function OnQueueStreamStatusChanged(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	local infoId = tonumber(tParams["QUEUE_INFO"])
	local info = g_queueInfoMap[infoId]
	if (info ~= nil) then
		if (info.notifications ~= nil and info.notifications.onQueueStreamStatusChanged ~= nil) then
			info.notifications.onQueueStreamStatusChanged(queueId, info.info, tParams["STATUS"])
		end
	else
		dbg("OnQueueStreamStatusChanged: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
	end
end

function OnQueueInfoChanged(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	if (tParams["PREV_QUEUE_INFO"] ~= nil) then
		local infoId = tonumber(tParams["PREV_QUEUE_INFO"])
		local info = g_queueInfoMap[infoId]
		if (info ~= nil) then
			g_queueInfoMap[infoId] = nil
			local newInfo = g_queueInfoMap[tonumber(tParams["QUEUE_INFO"])]
			if (newInfo.info ~= info.info) then
				-- Only destroy the previous one if the queue info actually changed
				if (info.queueId ~= nil) then
					g_queues[info.queueId] = nil
				end
				if (newInfo.queueId ~= nil) then
					g_queues[newInfo.queueId] = newInfo.info
				end
				if (info.notifications ~= nil and info.notifications.onQueueDeleted ~= nil) then
					info.notifications.onQueueDeleted(queueId, info.info)
				end
			end
		else
			dbg("OnQueueInfoChanged: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
		end
	else
		dbg("OnQueueInfoChanged: No previous queue info available")
	end
end

function OnQueueStatusChanged(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	local infoId = tonumber(tParams["QUEUE_INFO"])
	local info = g_queueInfoMap[infoId]
	if (info ~= nil) then
		if (info.notifications ~= nil and info.notifications.onQueueStatusChanged ~= nil) then
			info.notifications.onQueueStatusChanged(queueId, info.info, tParams["PREV_STATE"], tParams["STATE"])
		end
	else
		dbg("OnQueueStatusChanged: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
	end
end

function OnQueueMediaInfoUpdated(idBinding, tParams)
	local queueId = tonumber(tParams["QUEUE_ID"])
	local infoId = tonumber(tParams["QUEUE_INFO"])
	local info = g_queueInfoMap[infoId]
	if (info ~= nil) then
		if (info.notifications ~= nil and info.notifications.onQueueMediaInfoUpdated ~= nil) then
			info.notifications.onQueueMediaInfoUpdated(queueId, info.info, tParams["MEDIA_INFO"])
		end
	else
		dbg("OnQueueMediaInfoUpdated: Could not find queue info for " .. tostring(tParams["QUEUE_INFO"]))
	end
end

function DashboardChanged(queueId, ids)
	dbg("DashboardChanged(" .. queueId .. ", " .. ids .. ")")

	local args = {}
	args["QueueId"] = queueId
	args["Items"] = ids
	BroadcastEvent(MEDIA_SERVICE_PROXY_BINDING_ID, "DashboardChanged", args, true)
end

function GetNodesByPath(xml, path)
	-- This function returns all nodes matching this path
	local ret = {}
	if (xml.ChildNodes ~= nil) then
		local found = string.find(path, "/", 1, true)
		if (found ~= nil) then
			local name = string.sub(path, 1, found - 1)
			for i,v in pairs(xml.ChildNodes) do
				local node = v
				if (node.Name == name) then
					local nodes = GetNodesByPath(node, string.sub(path, found + 1))
					if (nodes ~= nil) then
						for j,w in pairs(nodes) do
							table.insert(ret, w)
						end
					end
				end
			end
		else
			for i,v in pairs(xml.ChildNodes) do
				if (v.Name == path) then
					table.insert(ret, v)
				end
			end
		end
	end
	return ret
end

function GetNodeByPath(xml, path)
	-- This function assumes that only one node with the path exists and returns it
	for i,v in pairs(GetNodesByPath(xml, path)) do
		return v
	end
end

function GetNodeValueByPath(xml, path)
	-- This function assumes that only one node with the path exists and returns its value
	for i,v in pairs(GetNodesByPath(xml, path)) do
		return v.Value
	end
end

function GetNodesValuesByPath(xml, path)
	-- This function returns all values of all nodes with this path
	local ret = {}
	for i,v in pairs(GetNodesByPath(xml, path)) do
		table.insert(ret, v.Value)
	end
	return ret
end

function GetQueueFromRoom(map, roomId)
	-- This function queries digital audio for the room/queue map to figure out what
	-- queue id is used by a room
	if (map == nil) then
		map = g_roomMapInfo
	end
	if (type(roomId) ~= "number") then
		roomId = tonumber(roomId)
	end
	if (map ~= nil) then
		for i,v in pairs(GetNodesByPath(map, "audioQueueInfo/queue")) do
			local queueId = tonumber(GetNodeValueByPath(v, "id"))
			for j,w in pairs(GetNodesValuesByPath(v, "rooms/id")) do
				if (tonumber(w) == roomId) then
					return queueId
				end
			end
		end
	end
	
	return 0
end

function GetRoomsByQueue(map, queueId)
	-- This function returns an array of room ids in a given queue
	if (map == nil) then
		map = g_roomMapInfo
	end
	
	if (map ~= nil) then
		for i,v in pairs(GetNodesByPath(map, "audioQueueInfo/queue")) do
			local id = tonumber(GetNodeValueByPath(v, "id"))
			if (id == queueId) then
				local rooms = {}
				for j,w in pairs(GetNodesValuesByPath(v, "rooms/id")) do
					table.insert(rooms, tonumber(w))
				end
				return rooms
			end
		end
	end
end

----------------------------------------- Navigators -----------------------------------------
gNavigators = {}

function NetworkError(strError)
	dbg("Network error: " .. strError)
	error("Network error", 0) -- This is the error message that gets sent to the Navigators
end

Navigator = {}
function Navigator:Create(proxyBindingId, navId, locale)
	local n = {}
	
	n._destroyed = false
	n._nav = navId
	n._room = 0
	n._proxyBindingId = proxyBindingId
	
	function n:Destroy()
		dbg("Navigator.Destroy () for nav " .. self._nav)
		self._destroyed = true
	end
	
	function n:GetDashboard(args, done)
		-- This is called when navigators want to know the dashboard controls to be displayed.
		local queueId = GetQueueFromRoom(nil, self._room)
		
		local queue = g_queues[queueId]
		if (queue ~= nil) then
			dbg("GetDashboard for queue " .. queueId)
			DashboardChanged(queueId, queue.dashboard)
		else
			dbg("GetDashboard: queue not found: " .. queueId)
			DashboardChanged(queueId, "")
		end
		return {}
	end
	
	function n:GetQueue(args, done)
		-- This function triggers a QueueChanged event for the navigator that requested it
		
		dbg("Navigator.GetQueue() for nav " .. self._nav)
		
		local queue = g_queues[GetQueueFromRoom(nil, self._room)]
		if (queue ~= nil) then
			SendEvent(self._proxyBindingId, self._nav, nil, "QueueChanged", Navigator:BuildNowPlayingQueue(queue), false)
		end
		return {} -- Complete the call
	end
	
	function n:TabsCommand(args, done)
		dbg("Navigator.TabsCommand() for nav " .. self._nav)
		
		-- Start a new queue in this room, or join in this room if there is already a queue
		StartPlay(nil, self._room, nil, function(err, inst)
			if (err ~= nil) then
				dbg("TabsCommand: selecting failed: " .. tostring(err))
			end
			done({}) -- Complete the call
		end)
	end

	return n
end

function Navigator:Destroy()
	dbg("Navigator:Destroy ()")
	for i,v in pairs(gNavigators) do
		v:Destroy()
	end
end

function Navigator:BuildNowPlayingQueue(queue)
	local ret = {}
	local list = ""
	local data = ""
	local items, nowPlayingIndex, nowPlayingData = queue:getNowPlayingItems()
	for i,v in pairs(items) do
		list = list .. BuildSimpleXml("item", v, true)
	end
	if (nowPlayingData ~= nil) then
		data = BuildSimpleXml(nil, nowPlayingData, true)
	end
	ret["List"] = list
	ret["NowPlayingIndex"] = nowPlayingIndex
	ret["NowPlaying"] = data
	return ret
end

function Navigator:SendQueueChangedEvent(queueId)
	if (queueId == nil) then
		for id,_ in pairs(g_queues) do
			Navigator:SendQueueChangedEvent(id)
		end
	else
		local tRooms = GetRoomsByQueue(nil, queueId)
		if (tRooms ~= nil) then
			local queue = g_queues[queueId]
			if (queue ~= nil) then
				SendEvent(MEDIA_SERVICE_PROXY_BINDING_ID, nil, tRooms, "QueueChanged", Navigator:BuildNowPlayingQueue(queue), false)
			else
				SendEvent(MEDIA_SERVICE_PROXY_BINDING_ID, nil, tRooms, "QueueChanged", {
					["List"] = "",
					["NowPlayingIndex"] = 0,
					["NowPlaying"] = ""
				}, true)
			end
		end
	end
end

function FormatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds - (h * 3600)) / 60)
	local s = seconds - (h * 3600) - (m * 60)
	if (h > 0) then
		return string.format("%02d:%02d:%02d", h, m, s)
	else
		return string.format("%02d:%02d", m, s)
	end
end

function Navigator:SendProgressEvent(queueId, current, length)
	if (queueId ~= nil) then
		local tRooms = GetRoomsByQueue(nil, queueId)
		if (tRooms ~= nil) then
			local label = ""
			if (current ~= nil and length ~= nil) then
				label = FormatTime(current) .. " / " .. FormatTime(length)
			end
			SendEvent(MEDIA_SERVICE_PROXY_BINDING_ID, nil, tRooms, "ProgressChanged", {
				["offset"] = current,
				["length"] = length,
				["label"] = label
			}, false)
		end
	end
end

function Navigator:OnUpdateMediaInfo(queueId, mediaInfo)
	local nowPlaying = gNowPlaying[queueId]
	if (nowPlaying ~= nil) then
		local info = C4:ParseXml(mediaInfo)
		if (info ~= nil) then
			-- We actually have now playing information for this queue, 
			-- check if the now playing title has changed
			local title = GetNodeValueByPath(info, "title")
			
			-- Ignore certain "titles"...
			if ((title ~= nil) and (title ~= "Internet Radio") and (title ~= "Waiting for data...")) then
				local info = GetNodeValueByPath(info, "queueInfo")
				
				dbg("Navigator:OnUpdateMediaInfo on queue " .. queueId .. " for " .. info .. ", new title: " .. title)
			end
		end
	end
end

function BuildSimpleXml(tag, tData, escapeValue)
	local xml = ""
	
	if (tag ~= nil) then
		xml = "<" .. tag .. ">"
	end
	
	if (escapeValue) then
		for i,v in pairs(tData) do
			if (type(v) == "table") then
				for j,w in pairs(v) do
					if (type(j) == "string") then
						xml = xml .. "<" .. i .. "><" .. j .. ">" .. C4:XmlEscapeString(tostring(w)) .. "</" .. j .. "></" .. i .. ">"
					else
						-- Use the same name as the outer tag
						if (type(w) == "string") then
							xml = xml .. "<" .. i .. ">" .. C4:XmlEscapeString(tostring(w)) .. "</" .. i .. ">"
						else
							xml = xml .. "<" .. i
							if (w.Attributes ~= nil) then
								for k,x in pairs(w.Attributes) do
									xml = xml .. " " .. k .. '="' .. C4:XmlEscapeString(tostring(x)) .. '"'
								end
							end
							xml = xml .. ">"
							if (w.Value ~= nil) then
								xml = xml .. C4:XmlEscapeString(tostring(w.Value))
							end
							xml = xml .. "</" .. i .. ">"
						end
					end
				end
			else
				xml = xml .. "<" .. i .. ">" .. C4:XmlEscapeString(tostring(v)) .. "</" .. i .. ">"
			end
		end
	else
		for i,v in pairs(tData) do
			xml = xml .. "<" .. i .. ">" .. tostring(v) .. "</" .. i .. ">"
		end
	end
	
	if (tag ~= nil) then
		xml = xml .. "</" .. tag .. ">"
	end
	return xml
end

function printRxProxy(idBinding, strCommand, tParams)

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
		DEBUGPRINT = false
		if (DEBUGPRINT) then
		    local output = {'--- ReceivedFromProxy: ' .. idBinding, strCommand, '----PARAMS----'}
		    for k,v in pairs (tParams) do table.insert (output, tostring (k) .. ' = ' .. tostring (v)) end
		    table.insert (output, '-----ARGS-----')
		    for k,v in pairs (args) do table.insert (output, tostring (k) .. ' = ' .. tostring (v)) end
		    table.insert (output, '---')
		    print (table.concat (output, '\r\n'))
	     end

end

function ReceivedFromProxy(idBinding, strCommand, tParams)
	dbg("ReceivedFromProxy (" .. idBinding .. ", " .. strCommand .. ")")
	
	if (strCommand ~= nil) then
		if(tParams == nil)		-- initial table variable if nil
			then tParams = {}
		end
		--dbg("Received from Proxy: " .. strCommand .. " on binding " .. idBinding)
		if (idBinding == MEDIA_SERVICE_PROXY_BINDING_ID) then
			local navId = tParams["NAVID"]
			local nav = gNavigators[navId]
			if (strCommand == "DESTROY_NAV") then
				if (nav ~= nil) then
					dbg("ReceivedFromProxy: Destroying navigator")
					nav:Destroy()
					nav = nil
					gNavigators[navId] = nil
				end
			elseif (strCommand == "INTERNET_RADIO_SELECTED") then
				OnInternetRadioSelected(idBinding, tParams)
			elseif (strCommand == "SELECT_INTERNET_RADIO_ERROR") then
				OnSelectInternetRadioError(idBinding, tParams)
			elseif (strCommand == "QUEUE_STATE_CHANGED") then
				OnQueueStatusChanged(idBinding, tParams)
			elseif (strCommand == "QUEUE_INFO_CHANGED") then
				OnQueueInfoChanged(idBinding, tParams)
			elseif (strCommand == "QUEUE_DELETED") then
				OnQueueDeleted(idBinding, tParams)
			elseif (strCommand == "QUEUE_STREAM_STATUS_CHANGED") then
				OnQueueStreamStatusChanged(idBinding, tParams)
			elseif (strCommand == "QUEUE_MEDIA_INFO_UPDATED") then
				OnQueueMediaInfoUpdated(idBinding, tParams)
			elseif (strCommand == "PLAY" or strCommand == "PAUSE" or
				strCommand == "STOP" or strCommand == "SKIP_REV" or
				strCommand == "SKIP_FWD" or
				strCommand == "SHUFFLE_ON" or strCommand == "SHUFFLE_OFF" or
				strCommand == "REPEAT_ON" or strCommand == "REPEAT_OFF") then
				-- Handle notification
				local roomId = tParams["ROOM_ID"]
				local queueId = GetQueueFromRoom(nil, roomId)
				local success, ret
				if (queueId > 0) then
					local queue = g_queues[queueId]
					if (queue ~= nil) then
						success, ret = pcall(queue[strCommand], queue, roomId)
						if (not success) then
							dbg("Error handling queue command: " .. strCommand .. ": " .. tostring(ret))
						end
					end
				end
				if (success == true and ret ~= true) then
					return "<ret><handled>false</handled></ret>"
				else
					return "<ret><handled>true</handled></ret>"
				end
			elseif (strCommand == "DEVICE_SELECTED") then
				OnDeviceSelected(idBinding, tParams)
			elseif ((nav == nil) and (navId ~= nil)) then
				nav = Navigator:Create(idBinding, navId, tParams["LOCALE"])
				gNavigators[navId] = nav
			end
			if (nav ~= nil) then
				local cmd = nav[strCommand]
				
				if (cmd == nil) then
					dbg("ReceivedFromProxy: Unhandled command = " .. strCommand)
					return
				end

				nav._locale = tParams["LOCALE"] -- Update the local in case it has changed
				nav._room = tParams["ROOMID"] -- Update the room id in case it has changed

				local seq = tParams["SEQ"]
				local args = {}
				local parsedArgs = C4:ParseXml(tParams["ARGS"])
				if (parsedArgs ~= nil) then
					for i,v in pairs(parsedArgs.ChildNodes) do
						args[v.Attributes["name"]] = v.Value
					end
				else
					dbg("Could not parse ARGS: " .. (tParams["ARGS"] or "(nil)"))
				end
				
				local completed = false
				local scope = newproxy(true) -- newproxy() is not supported on lua 5.2 and newer
				getmetatable(scope).__gc = function()
					if (not completed) then
						dbg("Driver did not respond to command " .. strCommand)
						DataReceivedError(idBinding, nav._nav, seq, "Driver did not respond")
					end
				end
				function completionHandler(data, dataLength)
					local keepScope = scope
					if (type(data) == "table") then
						local ret = ""
						for i,v in pairs(data) do
							if (i == "List") then
								local xml = ""
								for j,w in pairs(v) do
									xml = xml .. BuildSimpleXml("item", w, true)
								end
								local tag
								if (dataLength ~= nil) then
									tag = "<List length=\"" .. dataLength .. "\">"
								else
									tag = "<List>"
								end
								ret = ret .. tag .. xml .. "</List>"
							elseif (i == "Collection") then
								ret = ret .. BuildSimpleXml("Collection", v, true)
							elseif (i == "Settings") then
								ret = ret .. BuildSimpleXml("Settings", v, true)
							else
								ret = ret .. "<" .. i .. ">" .. tostring(v) .. "</" .. i .. ">"
							end
						end
						completed = true
						DataReceived(idBinding, nav._nav, seq, ret)
					elseif (type(data) == "string") then
						completed = true
						DataReceivedError(idBinding, nav._nav, seq, data)
					else
						dbg("Unknown argument type: " .. type(data))
					end
				end
				
				local success, ret = pcall(cmd, nav, args, completionHandler)
				if (success) then
					if (ret ~= nil) then
						dbg("Called " .. strCommand .. ".  Returning data immediately")
						completionHandler(ret)
					else
						dbg("Called " .. strCommand .. ".  Defer returning data...")
					end
				else
					dbg("Called " .. strCommand .. ".  An error occured: " .. ret)
					completionHandler(ret)
				end
			end
		end
	end
	printRxProxy(idBinding, strCommand, tParams)
end

------------------- Initialization ---------------------

function VersionAtLeast(major, minor, rev)
	local ver = string.split(C4:GetVersionInfo().version, '.')
	local mj = tonumber(ver[1])
	local mn = tonumber(ver[2])
	local r = tonumber(ver[3])
	if (mj > major) then
		return true
	elseif (mj == major and mn > minor) then
		return true
	elseif (mj == major and mn == minor and r >= rev) then
		return true
	else
		return false
	end
end

function IsSupportedController(controllerType)
	-- Older controllers unsupported, 800 and beyond supported by default
	-- This large list exists out of paranoid desire to maintain exact functionality while
	-- changing a whitelist to a blacklist
	local deviceTypesSupported = {
		XDT_Windows = false,
		XDT_MediaController = false,
		XDT_HomeTheaterController = false,
		XDT_MiniTouchScreen = false,
		XDT_MiniTouchScreenV2 = false,
		XDT_SpeakerPoint = false,
		XDT_TouchPanel = false,
		XDT_Z10TouchPanel = false,
		XDT_Z7TouchPanel = false,
		XDT_Z7PTouchPanel = false,
		XDT_TouchPanelV2 = false,
		XDT_HomeController1000 = false,
		XDT_HomeController1000V2 = false,
		XDT_HomeController500 = false,
		XDT_HomeController300 = false,
		XDT_HomeController200 = false,
		XDT_HomeController300V2 = false,
		XDT_HomeController200V2 = false,
		XDT_HomeController250 = false,
		XDT_LGController200 = false,
		XDT_IOExtender = false,
		XDT_5Inch = false,
		XDT_7Inch = false,
		XDT_EnergyController100 = false,
		XDT_Sony_Receiver = false,
		XDT_BCM911211 = false,
		XDT_BCMDoorStation = false,
		XDT_BCMDoorStation_SC = false,
		XDT_BCM7Portable = false,
		XDT_BCM7TouchScreen = false
	}
	local supported = deviceTypesSupported[controllerType]
	return supported == nil or supported == true
end

function CheckControllerTypeAndVersion()
	local myType = C4:GetSystemType()
	
	if (IsSupportedController(myType)) then
		if (VersionAtLeast(2, 8, 0)) then
			return true
		end
		
		print("The controller version is insufficient for the ShairBridge driver.  A version of at least version 2.8.0 is required.  Please contact technical support.")
	else
		print("The controller type of " ..  myType .. " does not support ShairBridge.  Please contact technical support.")
	end
	return false
end

function CheckDriverDisabled()
	if (CheckControllerTypeAndVersion() ) then
		C4:UpdateProperty("Supported Controller",  "True")
		g_controllerValid = true
		--if (Properties["Disabled"] == "True") then
		--	SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "DISABLE_DRIVER", {}, "COMMAND")
		--else
			SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "ENABLE_DRIVER", {}, "COMMAND")
		--end
	else
		C4:UpdateProperty("Supported Controller", "False")
		g_controllerValid = false
		SendToProxy(MEDIA_SERVICE_PROXY_BINDING_ID, "DISABLE_DRIVER", {}, "COMMAND")
	end
end

SYSTEM_EVENT = {}
function SYSTEM_EVENT:OnItemNameChanged(params)
	if (tonumber(params["iditem"]) == C4:GetProxyDevicesById(C4:GetDeviceID())) then
		local name = Properties["Broadcast Name"]
		if (name == nil or string.len(name) == 0) then
			restartInstance()
		end
	end
end

function OnSystemEvent(data)
	local xml = C4:ParseXml(data)
	if (xml ~= nil) then
		local eventName = xml.Attributes["name"]
		if (eventName ~= nil) then
			local func = SYSTEM_EVENT[eventName]
			if (func ~= nil) then
				local params = {}
				local childNodes = GetNodesByPath(xml, "param")
				for i,v in pairs(childNodes) do
					params[v.Attributes["name"]] = v.Value
				end
				func(SYSTEM_EVENT, params)
			end
		end
	end
end

function OnDriverInit()
	g_name = nil
	if (PersistData == nil) then
		PersistData = {}
	end

	for k,v in pairs(Properties) do
		OnPropertyChanged(k, true)
	end
	
	UpdateStatus()
end

function OnDriverLateInit()
	g_roomMapInfo = C4:ParseXml(C4:GetVariable(100002, 1009))
	C4:RegisterVariableListener(100002, 1009) -- Watch digital audio's room map variable
	
	CheckDriverDisabled()
	
	C4:RegisterSystemEvent(C4SystemEvents["OnItemNameChanged"], C4:GetProxyDevicesById(C4:GetDeviceID()))
	
	restartInstance()
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