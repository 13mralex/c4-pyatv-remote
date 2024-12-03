-- Copyright 2024 Snap One, LLC. All rights reserved.

Metrics = require ('drivers-common-public.module.metrics')
require ('drivers-common-public.global.lib')

COMMON_HANDLERS_VER = 28

do -- define globals
	DEBUG_RFN = false
end

--[[ Inbound Driver Functions:

		-- ExecuteCommand (strCommand, tParams)
		FinishedWithNotificationAttachment ()
		GetNotificationAttachmentURL ()
		GetNotificationAttachmentFile ()
		GetNotificationAttachmentBytes ()
		GetPrivateKeyPassword (idBinding, nPort)
		ListEvent (strEvent, param1, param2)
		ListMIBReceived (strCommand, nCount, tParams)
		ListNewControl (strContainer, strNavID, idDevice, tParams)
		ListNewList (nListID, nItemCount, strName, nIndex, strContainer, strCategory, strNavID)
		--OnBindingChanged (idBinding, strClass, bIsBound, otherDeviceID, otherBindngID)
		--OnConnectionStatusChanged (idBinding, nPort, strStatus)
		OnDriverDestroyed () -- in MSP
		OnDriverInit ()		 -- in MSP
		OnDriverLateInit ()	 -- in MSP
		OnDriverRemovedFromProject ()
		--OnDeviceEvent (firingDeviceId, eventId)
		OnNetworkBindingChanged (idBinding, bIsBound)
		OnPoll (idBinding, bIsBound)
		-- OnPropertyChanged (strProperty)
		OnReflashLockGranted ()
		OnReflashLockRevoked ()
		OnServerConnectionStatusChanged (nHandle, nPort, strStatus)
		OnServerDataIn (nHandle, strData, strclientAddress, strPort)
		OnServerStatusChanged (nPort, strStatus)
		-- OnSystemEvent (event)
		OnTimerExpired (idTimer)
		-- OnVariableChanged (strVariable)
		-- OnWatchedVariableChanged (idDevice, idVariable, strValue)
		OnZigbeeOnlineStatusChanged (strStatus, strVersion, strSkew)
		OnZigbeePacketIn (strPacket, nProfileID, nClusterID, nGroupID, nSourceEndpoint, nDestinationEndpoint)
		OnZigbeePacketFailed (strPacket, nProfileID, nClusterID, nGroupID, nSourceEndpoint, nDestinationEndpoint)
		OnZigbeePacketSuccess (strPacket, nProfileID, nClusterID, nGroupID, nSourceEndpoint, nDestinationEndpoint)
		-- ReceivedAsync (ticketId, strData, responseCode, tHeaders, strError)
		-- ReceivedFromNetwork (idBinding, nPort, strData)
		-- ReceivedFromProxy (idBinding, strCommand, tParams)
		ReceivedFromSerial (idBinding, strData)
		--TestCondition (strConditionName, tParams)
		--UIRequest (strCommand, tParams)


		DoPersistSave ()
		SetProperty ()
		SetGlobal ()

		OnBindingValidate (idBinding, strClass)

		OnUsbSerialDeviceOnline (idDevice, strManufacturer, strProduct, strSerialNum, strHostname, nFirstPort, nNumPorts)
		OnUsbSerialDeviceOffline ()

		Attach ()
		OnEndDebugSession ()

]]

--[[ C4 System Events (from C4SystemEvents global) - valid values for OSE keys
	1	OnAll
	2	OnAlive
	3	OnProjectChanged
	4	OnProjectNew
	5	OnProjectLoaded
	6	OnPIP
	7	OnItemAdded
	8	OnItemNameChanged
	9	OnItemDataChanged
	10	OnDeviceDataChanged
	11	OnItemRemoved
	12	OnItemMoved
	13	OnDriverAdded
	14	OnDeviceIdentified
	15	OnBindingAdded
	16	OnBindingRemoved
	17	OnNetworkBindingAdded
	18	OnNetworkBindingRemoved
	19	OnNetworkBindingRegistered
	20	OnNetworkBindingUnregistered
	21	OnCodeItemAdded
	22	OnCodeItemRemoved
	23	OnCodeItemMoved
	24	OnMediaInfoAdded
	25	OnMediaInfoModified
	26	OnMediaRemovedFromDevice
	27	OnMediaDataRemoved
	28	OnSongAddedToPlaylist
	29	OnSongRemovedFromPlaylist
	30	OnPhysicalDeviceAdded
	31	OnPhysicalDeviceRemoved
	32	OnDataToUI
	33	OnAccessModeChanged
	34	OnVariableAdded
	35	OnUserVariableAdded
	36	OnVariableRemoved
	37	OnVariableRenamed
	38	OnVariableChanged
	39	OnVariableBindingAdded
	40	OnVariableBindingRemoved
	41	OnVariableBindingRenamed
	42	OnVariableAddedToBinding
	43	OnVariableRemovedFromBinding
	44	OnMediaDeviceAdded
	45	OnMediaDeviceRemoved
	46	OnProjectLocked
	47	OnProjectLeaveLock
	48	OnDeviceOnline
	49	OnDeviceOffline
	50	OnSearchTypeFound
	51	OnNetworkBindingStatusChanged
	52	OnZipcodeChanged
	53	OnLatitudeChanged
	54	OnLongitudeChanged
	55	OnDeviceAlreadyIdentified
	56	OnControllerDisabled
	57	OnDeviceFirmwareChanged
	58	OnLocaleChanged
	59	OnZigbeeNodesChanged
	60	OnZigbeeZapsChanged
	61	OnZigbeeMeshChanged
	62	OnZigbeeZserverChanged
	63	OnSysmanResponse
	64	OnTimezoneChanged
	65	OnMediaSessionAdded
	66	OnMediaSessionRemoved
	67	OnMediaSessionChanged
	68	OnMediaDeviceChanged
	69	OnProjectEnterLock
	70	OnDeviceIdentifiedNoLicense
	71	OnZigBeeStickPresent
	72	OnZigBeeStickRemoved
	73	OnZigbeeNodeUpdateStatus
	74	OnZigbeeNodeUpdateSucceeded
	75	OnZigbeeNodeUpdateFailed
	76	OnZigbeeNodeOnline
	77	OnZigbeeNodeOffline
	78	OnSDDPDeviceStatus
	79	OnSDDPDeviceDiscover
	80	OnAccountInfoUpdated
	81	OnAccountInfoUpdating
	82	OnBindingEntryAdded
	83	OnBindingEntryRemoved
	84	OnProjectClear
	85	OnSystemShutDown
	86	OnSystemUpdateStarted
	87	OnDevicePreIdentify
	88	OnDeviceIdentifying
	89	OnDeviceCancelIdentify
	90	OnDirectorIPAddressChanged
	91	OnDeviceDiscovered
	92	OnDeviceUserInitiatedRemove
	93	OnDriverDisabled
	94	OnDiscoveredDeviceAdded
	95	OnDiscoveredDeviceRemoved
	96	OnDiscoveredDeviceChanged
	97	OnDeviceIPAddressChanged
	98	OnCIDRRulesChanged
	99	OnBindingEntryRenamed
	100	OnCodeItemEnabled
	101	OnCodeItemCommandUpdated
	102	OnSystemUpdateFinished
	103	OnTimeChanged
	104	OnMediaSessionDiscreteMuteChanged
	105	OnMediaSessionMuteStateChanged
	106	OnMediaSessionDiscreteVolumeChanged
	107	OnMediaSessionVolumeLevelChanged
	108	OnMediaSessionMediaInfoChanged
	109	OnMediaSessionVolumeSliderStateChanged
	110	OnScheduledEvent
	111	OnMediaSessionSliderTargetVolumeReached
	112	OnCodeItemAddedToExpression
	113	OnProjectPropertyChanged
	114	OnEventAdded
	115	OnEventModified
	116	OnEventRemoved
	117	OnZigbeeNetworkHealth
]]

do --Globals
	EC = EC or { suppressDebug = {}, }
	OBC = OBC or { suppressDebug = {}, }
	ODE = ODE or { suppressDebug = {}, }
	OCS = OCS or { suppressDebug = {}, }
	OPC = OPC or { suppressDebug = {}, }
	OSE = OSE or { suppressDebug = {}, }
	OVC = OVC or { suppressDebug = {}, }
	OWVC = OWVC or { suppressDebug = {}, }
	RFN = RFN or { suppressDebug = {}, }
	RFP = RFP or { suppressDebug = {}, }
	TC = TC or { suppressDebug = {}, }
	UIR = UIR or { suppressDebug = {}, }

	ValidVarTypes = {
		BOOL = true,
		DEVICE = true,
		FLOAT = true,
		INT = true,
		MEDIA = true,
		NUMBER = true,
		ROOM = true,
		STRING = true,
		STATE = true,
		TIME = true,
		ULONG = true,
		XML = true,
		LEVEL = true,
		LIST = true,
	}
end

do --Setup Metrics
	MetricsHandler = Metrics:new ('dcp_handler', COMMON_HANDLERS_VER)
end

function HandlerDebug (init, tParams, args)
	if (not DEBUGPRINT) then
		return
	end

	if (type (init) ~= 'table') then
		return
	end

	local output = init
	for k, v in pairs (output) do output [k] = "  " .. v end

	if (type (tParams) == 'table' and next (tParams) ~= nil) then
		table.insert (output, '        ----PARAMS----')
		for k, v in pairs (tParams) do
			local line = string.format ("  %-20s = %s", tostring (k), tostring (v))
			table.insert (output, line)
		end
	end

	if (type (args) == 'table' and next (args) ~= nil) then
		table.insert (output, '        ----ARGS----')
		for k, v in pairs (args) do
			local line = string.format ("  %-20s = %s", tostring (k), tostring (v))
			table.insert (output, line)
		end
	end

	local t, ms
	if (C4.GetTime) then
		t = C4:GetTime ()
		ms = '.' .. tostring (t % 1000)
		t = math.floor (t / 1000)
	else
		t = os.time ()
		ms = ''
	end
	local s = string.format ("%-21s : ", os.date ('%x %X') .. ms)

	table.insert (output, 1, s)
	table.insert (output, 1, '-->')
	table.insert (output, '<--')
	output = table.concat (output, '\r\n')
	print (output)
	C4:DebugLog (output)
end

function ExecuteCommand (strCommand, tParams)
	tParams = tParams or {}

	local suppressDebug = Select (EC, 'suppressDebug', strCommand)

	if (not suppressDebug) then
		local init = {
			'ExecuteCommand: ' .. strCommand,
		}
		HandlerDebug (init, tParams)
	end

	if (strCommand == 'LUA_ACTION') then
		if (tParams.ACTION) then
			strCommand = tParams.ACTION
			tParams.ACTION = nil
		end
	end

	strCommand = string.gsub (strCommand, '%s+', '_')

	local success, ret

	if (EC and EC [strCommand] and type (EC [strCommand]) == 'function') then
		success, ret = pcall (EC [strCommand], tParams)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_ExecuteCommand')
		print ('ExecuteCommand error: ', ret, strCommand)
	elseif (DEBUGPRINT) then
		print ('Unhandled ExecuteCommand')
	end
end

function OnBindingChanged (idBinding, strClass, bIsBound, otherDeviceId, otherBindingId)
	local suppressDebug = Select (OBC, 'suppressDebug', idBinding)

	if (not suppressDebug) then
		local init = {
			'OnBindingChanged: ' .. idBinding,
		}
		local tParams = {
			strClass = strClass,
			bIsBound = tostring (bIsBound),
			otherDeviceId = otherDeviceId,
			otherBindingId = otherBindingId,
		}
		HandlerDebug (init, tParams)
	end

	local success, ret

	if (OBC and OBC [idBinding] and type (OBC [idBinding]) == 'function') then
		success, ret = pcall (OBC [idBinding], idBinding, strClass, bIsBound, otherDeviceId, otherBindingId)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnBindingChanged')
		print ('OnBindingChanged error: ', ret, idBinding, strClass, bIsBound, otherDeviceId, otherBindingId)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnBindingChanged')
	end
end

function OnConnectionStatusChanged (idBinding, nPort, strStatus)
	local suppressDebug = Select (OCS, 'suppressDebug', idBinding)

	if (not suppressDebug) then
		local init = {
			'OnConnectionStatusChanged: ' .. idBinding,
		}
		local tParams = {
			nPort = nPort,
			strStatus = strStatus,
		}
		HandlerDebug (init, tParams)
	end

	local success, ret

	if (OCS and OCS [idBinding] and type (OCS [idBinding]) == 'function') then
		success, ret = pcall (OCS [idBinding], idBinding, nPort, strStatus)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnConnectionStatusChanged')
		print ('OnConnectionStatusChanged error: ', ret, idBinding, nPort, strStatus)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnConnectionStatusChanged')
	end
end

function RegisterDeviceEvent (firingDeviceId, eventId, callback)
	if (firingDeviceId == nil or eventId == nil) then
		MetricsHandler:SetCounter ('Error_RegisterDeviceEvent')
		print ('RegisterDeviceEvent error (Invalid idDevice / idVariable): ', tostring (firingDeviceId),
			tostring (eventId), tostring (callback))
		return
	end

	C4:UnregisterDeviceEvent (firingDeviceId, eventId)

	ODE [firingDeviceId] = ODE [firingDeviceId] or {}

	if (type (callback) == 'function') then
		ODE [firingDeviceId] [eventId] = callback
		C4:RegisterDeviceEvent (firingDeviceId, eventId)
	else
		MetricsHandler:SetCounter ('Error_RegisterDeviceEvent')
		print ('RegisterDeviceEvent error (callback not a function): ', firingDeviceId, eventId, callback)
	end
end

function UnregisterDeviceEvent (firingDeviceId, eventId)
	if (firingDeviceId == nil or eventId == nil) then
		MetricsHandler:SetCounter ('Error_UnregisterDeviceEvent')
		print ('UnregisterDeviceEvent error (Invalid idDevice / idVariable): ', tostring (firingDeviceId),
			tostring (eventId))
		return
	end

	C4:UnregisterDeviceEvent (firingDeviceId, eventId)

	if (ODE and ODE [firingDeviceId]) then
		ODE [firingDeviceId] [eventId] = nil
	end

	if (ODE [firingDeviceId] and not next (ODE [firingDeviceId])) then
		ODE [firingDeviceId] = nil
	end
end

function OnDeviceEvent (firingDeviceId, eventId)
	local suppressDebug = Select (ODE, 'suppressDebug', firingDeviceId, eventId)

	if (not suppressDebug) then
		local init = {
			'OnDeviceEvent: ' .. C4:GetDeviceDisplayName (firingDeviceId) .. ' [' .. firingDeviceId .. ']',
			eventId,
		}
		HandlerDebug (init)
	end

	local success, ret

	if (ODE and ODE [firingDeviceId] and ODE [firingDeviceId] [eventId] and type (ODE [firingDeviceId] [eventId]) == 'function') then
		success, ret = pcall (ODE [firingDeviceId] [eventId], firingDeviceId, eventId)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnDeviceEvent')
		print ('OnDeviceEvent error: ', ret, firingDeviceId, eventId)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnDeviceEvent')
	end
end

function UpdateProperty (strProperty, strValue, notifyChange)
	if (type (strProperty) ~= 'string') then
		MetricsHandler:SetCounter ('Error_UpdateProperty')
		print ('UpdateProperty error (strProperty not string): ', tostring (strProperty), tostring (strValue))
		return
	end

	if (Properties [strProperty] == nil) then
		MetricsHandler:SetCounter ('Error_UpdateProperty')
		print ('UpdateProperty error (Property not present in Properties table): ', tostring (strProperty),
			tostring (strValue))
		return
	end

	if (strValue == nil) then
		strValue = ''
	elseif (type (strValue) ~= 'string') then
		strValue = tostring (strValue)
	end

	if (Properties [strProperty] ~= strValue) then
		C4:UpdateProperty (strProperty, strValue)
	end
	if (notifyChange == true) then
		OnPropertyChanged (strProperty)
	end
end

function OnPropertyChanged (strProperty)
	local value = Properties [strProperty]
	if (type (value) ~= 'string') then
		value = ''
	end

	local suppressDebug = Select (OPC, 'suppressDebug', strProperty)

	if (not suppressDebug) then
		local init = {
			'OnPropertyChanged: ' .. strProperty,
			value,
		}
		HandlerDebug (init)
	end

	strProperty = string.gsub (strProperty, '%s+', '_')

	local success, ret

	if (OPC and OPC [strProperty] and type (OPC [strProperty]) == 'function') then
		success, ret = pcall (OPC [strProperty], value)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnPropertyChanged')
		print ('OnPropertyChanged error: ', ret, strProperty, value)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnPropertyChanged')
	end
end

function OnSystemEvent (event)
	local eventName = string.match (event, '.-name="(.-)"')

	local suppressDebug = Select (OSE, 'suppressDebug', eventName)

	if (not suppressDebug) then
		local init = {
			'OnSystemEvent: ' .. eventName,
			event,
		}
		HandlerDebug (init)
	end

	local success, ret

	if (OSE) then
		eventName = string.gsub (eventName, '%s+', '_')
		if (OSE [eventName] and type (OSE [eventName]) == 'function') then
			success, ret = pcall (OSE [eventName], event)
		end
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnSystemEvent')
		print ('OnSystemEvent error: ', ret, eventName, event)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnSystemEvent')
	end
end

function conformVariable (var)
	local ret
	if (type (var) == 'boolean') then
		ret = (var and '1') or '0'
	elseif (type (var) ~= 'string') then
		ret = tostring (var)
	else
		ret = var
	end
	return ret
end

function AddVariable (strVariable, strValue, varType, readOnly, hidden)
	if (type (strVariable) ~= 'string') then
		MetricsHandler:SetCounter ('Error_AddVariable')
		print ('AddVariable error (Invalid strVariable): ', tostring (strVariable), type (strVariable))
		return
	end

	if (type (varType) ~= 'string') then
		MetricsHandler:SetCounter ('Error_AddVariable')
		print ('AddVariable error (varType not string): ', tostring (varType), type (varType))
		return
	end

	if (not (ValidVarTypes [varType])) then
		MetricsHandler:SetCounter ('Error_AddVariable')
		print ('AddVariable error (Invalid varType): ', tostring (varType))
		return
	end

	strValue = conformVariable (strValue)

	if (Variables [strVariable]) then
		SetVariable (strVariable, strValue)
		return
	end

	if (readOnly ~= true) then
		readOnly = false
	end

	if (hidden ~= true) then
		hidden = false
	end

	C4:AddVariable (strVariable, strValue, varType, readOnly, hidden)
end

function SetVariable (strVariable, strValue, notifyChange)
	if (type (strVariable) ~= 'string') then
		MetricsHandler:SetCounter ('Error_SetVariable')
		print ('AddVariable error (Invalid strVariable): ', tostring (strVariable), type (strVariable))
		return
	end

	if (strValue == nil) then
		MetricsHandler:SetCounter ('Error_SetVariable')
		print ('SetVariable error (Invalid strValue): nil')
		return
	end

	strValue = conformVariable (strValue)

	if (Variables [strVariable] ~= strValue) then
		C4:SetVariable (strVariable, strValue)
	end
	if (notifyChange == true) then
		OnVariableChanged (strVariable)
	end
end

function OnVariableChanged (strVariable, variableId)
	local value = Variables [strVariable]
	if (value == nil) then
		value = ''
	end

	local suppressDebug = Select (OVC, 'suppressDebug', strVariable) or
		Select (OVC, 'suppressDebug', variableId)

	if (not suppressDebug) then
		local init = {
			'OnVariableChanged: ' .. strVariable .. ' [' .. tostring (variableId) .. ']',
			value,
		}
		HandlerDebug (init)
	end

	strVariable = string.gsub (strVariable, '%s+', '_')

	local success, ret

	if (OVC and OVC [strVariable] and type (OVC [strVariable]) == 'function') then
		success, ret = pcall (OVC [strVariable], value)
	elseif (OVC and OVC [variableId] and type (OVC [variableId]) == 'function') then
		success, ret = pcall (OVC [variableId], value)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnVariableChanged')
		print ('OnVariableChanged error: ', ret, strVariable, value)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnVariableChanged')
	end
end

function RegisterVariableListener (idDevice, idVariable, callback)
	if (idDevice == nil or idVariable == nil) then
		MetricsHandler:SetCounter ('Error_RegisterVariableListener')
		print ('RegisterVariableListener error (Invalid idDevice / idVariable): ', tostring (idDevice),
			tostring (idVariable), tostring (callback))
		return
	end

	C4:UnregisterVariableListener (idDevice, idVariable)

	OWVC [idDevice] = OWVC [idDevice] or {}

	if (type (callback) == 'function') then
		OWVC [idDevice] [idVariable] = callback
		C4:RegisterVariableListener (idDevice, idVariable)
	else
		MetricsHandler:SetCounter ('Error_RegisterVariableListener')
		print ('RegisterVariableListener error (callback not a function): ', idDevice, idVariable, callback)
	end
end

function UnregisterVariableListener (idDevice, idVariable)
	if (idDevice == nil or idVariable == nil) then
		MetricsHandler:SetCounter ('Error_UnregisterVariableListener')
		print ('UnregisterVariableListener error (Invalid idDevice / idVariable): ', tostring (idDevice),
			tostring (idVariable))
		return
	end

	C4:UnregisterVariableListener (idDevice, idVariable)

	if (OWVC and OWVC [idDevice]) then
		OWVC [idDevice] [idVariable] = nil
	end

	if (OWVC [idDevice] and not next (OWVC [idDevice])) then
		OWVC [idDevice] = nil
	end
end

function OnWatchedVariableChanged (idDevice, idVariable, strValue)
	local suppressDebug = Select (OWVC, 'suppressDebug', idDevice, idVariable)

	if (not suppressDebug) then
		local init = {
			'OnWatchedVariableChanged: ' .. C4:GetDeviceDisplayName (idDevice) .. ' [' .. idDevice .. ']',
		}
		local varName = Select (C4:GetDeviceVariables (idDevice), tostring (idVariable), 'name') or ''
		varName = varName .. ' [' .. idVariable .. ']'

		local tParams = {
			[varName] = strValue,
		}
		HandlerDebug (init, tParams)
	end

	local success, ret

	if (OWVC and
			OWVC [idDevice] and
			OWVC [idDevice] [idVariable] and
			type (OWVC [idDevice] [idVariable]) == 'function') then
		success, ret = pcall (OWVC [idDevice] [idVariable], idDevice, idVariable, strValue)
	else
		success = false
		ret = 'Callback not available for registered variable'
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_OnWatchedVariableChanged')
		print ('OnWatchedVariableChanged error: ', ret, idDevice, idVariable, strValue)
	elseif (DEBUGPRINT) then
		print ('Unhandled OnWatchedVariableChanged')
	end
end

function ReceivedFromNetwork (idBinding, nPort, strData)
	local suppressDebug = Select (RFN, 'suppressDebug', idBinding) or
		Select (SSDP, 'SearchTargets', idBinding) or
		(Select (WebSocket, 'Sockets', idBinding) and not DEBUG_WEBSOCKET)

	suppressDebug = suppressDebug and (not DEBUG_RFN)

	if (not suppressDebug) then
		local init = {
			'ReceivedFromNetwork: ' .. idBinding,
		}
		local tParams = {
			nPort = nPort,
			dataLen = #strData,
			data = (DEBUG_RFN and strData) or nil,
		}
		HandlerDebug (init, tParams)
	end

	local success, ret

	if (RFN and RFN [idBinding] and type (RFN [idBinding]) == 'function') then
		success, ret = pcall (RFN [idBinding], idBinding, nPort, strData)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_ReceivedFromNetwork')
		print ('ReceivedFromNetwork error: ', ret, idBinding, nPort, strData)
	elseif (DEBUGPRINT) then
		print ('Unhandled ReceivedFromNetwork')
	end
end

function ReceivedFromProxy (idBinding, strCommand, tParams)
	strCommand = strCommand or ''
	tParams = tParams or {}
	local args = {}
	if (tParams.ARGS) then
		local parsedArgs = C4:ParseXml (tParams.ARGS)
		for _, v in pairs (parsedArgs.ChildNodes) do
			args [v.Attributes.name] = v.Value
		end
		tParams.ARGS = nil
	end

	local suppressDebug = Select (RFP, 'suppressDebug', idBinding, strCommand)

	if (not suppressDebug) then
		local init = {
			'ReceivedFromProxy: ' .. idBinding,
			strCommand,
		}
		HandlerDebug (init, tParams, args)
	end

	local success, ret

	if (RFP and RFP [strCommand] and type (RFP [strCommand]) == 'function') then
		success, ret = pcall (RFP [strCommand], idBinding, strCommand, tParams, args)
	elseif (RFP and RFP [idBinding] and type (RFP [idBinding]) == 'function') then
		success, ret = pcall (RFP [idBinding], idBinding, strCommand, tParams, args)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_ReceivedFromProxy')
		print ('ReceivedFromProxy error: ', ret, idBinding, strCommand)
	elseif (DEBUGPRINT) then
		print ('Unhandled ReceivedFromProxy')
	end
end

function TestCondition (strConditionName, tParams)
	strConditionName = strConditionName or ''
	tParams = tParams or {}

	local suppressDebug = Select (TC, 'suppressDebug', strConditionName)

	if (not suppressDebug) then
		local init = {
			'TestCondition: ' .. strConditionName,
		}
		HandlerDebug (init, tParams)
	end

	local success, ret

	if (TC and TC [strConditionName] and type (TC [strConditionName]) == 'function') then
		success, ret = pcall (TC [strConditionName], strConditionName, tParams)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		MetricsHandler:SetCounter ('Error_TestCondition')
		print ('TestCondition error: ', ret, strConditionName)
	elseif (DEBUGPRINT) then
		print ('Unhandled TestCondition')
	end
end

function UIRequest (strCommand, tParams)
	strCommand = strCommand or ''
	tParams = tParams or {}

	local suppressDebug = Select (UIR, 'suppressDebug', strCommand)

	if (not suppressDebug) then
		local init = {
			'UIRequest: ' .. strCommand,
		}
		HandlerDebug (init, tParams)
	end

	local success, ret

	if (UIR and UIR [strCommand] and type (UIR [strCommand]) == 'function') then
		success, ret = pcall (UIR [strCommand], tParams)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ('UIRequest Lua error: ', strCommand, ret)
	elseif (DEBUGPRINT) then
		print ('Unhandled UIRequest')
	end
end
